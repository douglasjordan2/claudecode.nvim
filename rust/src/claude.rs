use crate::protocol::{ChatParams, Event};
use crate::session::SessionManager;
use serde_json::Value;
use std::process::Stdio;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::{Child, Command};
use tokio::sync::mpsc;

pub struct ClaudeProcess {
    child: Child,
    session: SessionManager,
}

impl ClaudeProcess {
    pub async fn spawn(
        params: &ChatParams,
        resume_session: Option<String>,
        session: SessionManager,
        event_tx: mpsc::UnboundedSender<Event>,
    ) -> Result<Self, String> {
        let mut cmd = Command::new("claude");
        cmd.arg("-p");
        cmd.arg("--output-format").arg("stream-json");
        cmd.arg("--verbose");
        cmd.arg("--include-partial-messages");

        if let Some(ref cwd) = params.cwd {
            cmd.current_dir(cwd);
        }

        if let Some(ref model) = params.model {
            cmd.arg("--model").arg(model);
        }

        if let Some(ref tools) = params.allowed_tools {
            cmd.arg("--allowed-tools").arg(tools.join(","));
        }

        if let Some(ref prompt) = params.append_system_prompt {
            cmd.arg("--append-system-prompt").arg(prompt);
        }

        if let Some(ref mode) = params.permission_mode {
            cmd.arg("--permission-mode").arg(mode);
        }

        if let Some(ref sid) = resume_session {
            cmd.arg("--resume").arg(sid);
        }

        cmd.stdin(Stdio::piped());
        cmd.stdout(Stdio::piped());
        cmd.stderr(Stdio::piped());

        let mut child = cmd.spawn().map_err(|e| format!("Failed to spawn claude: {}", e))?;

        let stdout = child.stdout.take().ok_or("No stdout")?;
        let stderr = child.stderr.take().ok_or("No stderr")?;
        let mut stdin = child.stdin.take().ok_or("No stdin")?;

        let prompt_text = if let Some(ref ctx) = params.context {
            format!("{}\n\n{}", ctx, params.prompt)
        } else {
            params.prompt.clone()
        };

        if !prompt_text.is_empty() {
            stdin
                .write_all(prompt_text.as_bytes())
                .await
                .map_err(|e| format!("Failed to write to stdin: {}", e))?;
        }
        drop(stdin);

        let err_tx = event_tx.clone();
        tokio::spawn(async move {
            let reader = BufReader::new(stderr);
            let mut lines = reader.lines();
            while let Ok(Some(line)) = lines.next_line().await {
                if !line.is_empty() {
                    let _ = err_tx.send(Event::Error {
                        message: format!("[stderr] {}", line),
                    });
                }
            }
        });

        let sess = session.clone();
        tokio::spawn(async move {
            let reader = BufReader::new(stdout);
            let mut lines = reader.lines();
            let mut accumulated_text = String::new();

            while let Ok(Some(line)) = lines.next_line().await {
                if line.is_empty() {
                    continue;
                }
                let parsed: Value = match serde_json::from_str(&line) {
                    Ok(v) => v,
                    Err(_) => continue,
                };

                let msg_type = parsed.get("type").and_then(|v| v.as_str()).unwrap_or("");

                match msg_type {
                    "system" => {
                        let subtype = parsed
                            .get("subtype")
                            .and_then(|v| v.as_str())
                            .unwrap_or("");
                        if subtype == "init" {
                            let sid = parsed
                                .get("session_id")
                                .and_then(|v| v.as_str())
                                .unwrap_or("")
                                .to_string();
                            let model = parsed
                                .get("model")
                                .and_then(|v| v.as_str())
                                .unwrap_or("unknown")
                                .to_string();
                            let tools: Vec<String> = parsed
                                .get("tools")
                                .and_then(|v| v.as_array())
                                .map(|arr| {
                                    arr.iter()
                                        .filter_map(|t| t.as_str().map(String::from))
                                        .collect()
                                })
                                .unwrap_or_default();

                            sess.set_active(sid.clone(), model.clone()).await;
                            let _ = event_tx.send(Event::Init {
                                session_id: sid,
                                model,
                                tools,
                            });
                        }
                    }
                    "stream_event" => {
                        if let Some(evt) = parsed.get("event") {
                            let evt_type =
                                evt.get("type").and_then(|v| v.as_str()).unwrap_or("");

                            match evt_type {
                                "content_block_delta" => {
                                    if let Some(delta) = evt.get("delta") {
                                        let delta_type = delta
                                            .get("type")
                                            .and_then(|v| v.as_str())
                                            .unwrap_or("");
                                        if delta_type == "text_delta" {
                                            if let Some(text) =
                                                delta.get("text").and_then(|v| v.as_str())
                                            {
                                                accumulated_text.push_str(text);
                                                let _ =
                                                    event_tx.send(Event::TextChunk {
                                                        text: text.to_string(),
                                                    });
                                            }
                                        }
                                    }
                                }
                                "content_block_stop" => {
                                    if !accumulated_text.is_empty() {
                                        let _ = event_tx.send(Event::Text {
                                            text: accumulated_text.clone(),
                                        });
                                        accumulated_text.clear();
                                    }
                                }
                                _ => {}
                            }
                        }
                    }
                    "assistant" => {
                        if let Some(msg) = parsed.get("message") {
                            if let Some(content) = msg.get("content").and_then(|v| v.as_array()) {
                                for block in content {
                                    let block_type = block
                                        .get("type")
                                        .and_then(|v| v.as_str())
                                        .unwrap_or("");
                                    if block_type == "tool_use" {
                                        let tool = block
                                            .get("name")
                                            .and_then(|v| v.as_str())
                                            .unwrap_or("unknown")
                                            .to_string();
                                        let id = block
                                            .get("id")
                                            .and_then(|v| v.as_str())
                                            .unwrap_or("")
                                            .to_string();
                                        let input = block
                                            .get("input")
                                            .cloned()
                                            .unwrap_or(Value::Null);
                                        let _ = event_tx.send(Event::ToolUse { tool, id, input });
                                    }
                                }
                            }
                        }
                    }
                    "tool_result" | "tool_use_result" => {
                        let tool = parsed
                            .get("tool")
                            .or_else(|| parsed.get("name"))
                            .and_then(|v| v.as_str())
                            .unwrap_or("unknown")
                            .to_string();
                        let id = parsed
                            .get("tool_use_id")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string();
                        let is_error = parsed
                            .get("is_error")
                            .and_then(|v| v.as_bool())
                            .unwrap_or(false);
                        let content_val = parsed
                            .get("content")
                            .or_else(|| parsed.get("output"));
                        let content = match content_val {
                            Some(Value::String(s)) => s.clone(),
                            Some(v) => v.to_string(),
                            None => String::new(),
                        };
                        let _ = event_tx.send(Event::ToolResult {
                            tool,
                            id,
                            success: !is_error,
                            content,
                        });
                    }
                    "result" => {
                        let total_cost = parsed
                            .get("total_cost_usd")
                            .and_then(|v| v.as_f64())
                            .unwrap_or(0.0);
                        let duration = parsed
                            .get("duration_ms")
                            .and_then(|v| v.as_u64())
                            .unwrap_or(0);
                        let usage = parsed.get("usage");
                        let input_tokens = usage
                            .and_then(|u| u.get("input_tokens"))
                            .and_then(|v| v.as_u64())
                            .unwrap_or(0);
                        let output_tokens = usage
                            .and_then(|u| u.get("output_tokens"))
                            .and_then(|v| v.as_u64())
                            .unwrap_or(0);
                        let cache_read = usage
                            .and_then(|u| u.get("cache_read_input_tokens"))
                            .and_then(|v| v.as_u64())
                            .unwrap_or(0);

                        let _ = event_tx.send(Event::Cost {
                            total_usd: total_cost,
                            duration_ms: duration,
                            input_tokens: input_tokens + cache_read,
                            output_tokens,
                        });

                        let is_error = parsed
                            .get("is_error")
                            .and_then(|v| v.as_bool())
                            .unwrap_or(false);
                        if is_error {
                            let msg = parsed
                                .get("result")
                                .and_then(|v| v.as_str())
                                .unwrap_or("Unknown error")
                                .to_string();
                            let _ = event_tx.send(Event::Error { message: msg });
                        }

                        sess.set_inactive().await;
                        let _ = event_tx.send(Event::Done);
                    }
                    _ => {}
                }
            }

            sess.set_inactive().await;
        });

        Ok(Self { child, session })
    }

    pub async fn abort(&mut self) -> Result<(), String> {
        self.child
            .kill()
            .await
            .map_err(|e| format!("Failed to kill claude process: {}", e))?;
        self.session.set_inactive().await;
        Ok(())
    }

    pub async fn wait(&mut self) -> Result<(), String> {
        self.child
            .wait()
            .await
            .map_err(|e| format!("Claude process error: {}", e))?;
        Ok(())
    }
}
