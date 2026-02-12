use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
#[serde(tag = "method", content = "params")]
#[serde(rename_all = "snake_case")]
pub enum Request {
    Chat(ChatParams),
    Resume(ResumeParams),
    Continue(ContinueParams),
    Abort,
    Status,
}

#[derive(Debug, Deserialize)]
pub struct ChatParams {
    pub prompt: String,
    #[serde(default)]
    pub cwd: Option<String>,
    #[serde(default)]
    pub context: Option<String>,
    #[serde(default)]
    pub model: Option<String>,
    #[serde(default)]
    pub allowed_tools: Option<Vec<String>>,
    #[serde(default)]
    pub append_system_prompt: Option<String>,
    #[serde(default)]
    pub permission_mode: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ResumeParams {
    pub session_id: String,
    #[serde(default)]
    pub cwd: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ContinueParams {
    pub prompt: String,
    #[serde(default)]
    pub context: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(tag = "event")]
#[serde(rename_all = "snake_case")]
pub enum Event {
    Init {
        session_id: String,
        model: String,
        tools: Vec<String>,
    },
    TextChunk {
        text: String,
    },
    Text {
        text: String,
    },
    ToolUse {
        tool: String,
        id: String,
        input: serde_json::Value,
    },
    ToolResult {
        tool: String,
        id: String,
        success: bool,
        content: String,
    },
    Cost {
        total_usd: f64,
        duration_ms: u64,
        input_tokens: u64,
        output_tokens: u64,
    },
    Done,
    Error {
        message: String,
    },
    Status {
        active: bool,
        session_id: Option<String>,
    },
}

impl Event {
    pub fn to_json_line(&self) -> String {
        let mut s = serde_json::to_string(self).unwrap_or_else(|e| {
            format!(r#"{{"event":"error","message":"serialize error: {}"}}"#, e)
        });
        s.push('\n');
        s
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_deserialize_chat_request() {
        let json = r#"{"method":"chat","params":{"prompt":"hello","cwd":"/tmp"}}"#;
        let req: Request = serde_json::from_str(json).unwrap();
        match req {
            Request::Chat(params) => {
                assert_eq!(params.prompt, "hello");
                assert_eq!(params.cwd, Some("/tmp".to_string()));
                assert!(params.model.is_none());
            }
            _ => panic!("expected Chat variant"),
        }
    }

    #[test]
    fn test_deserialize_chat_with_all_fields() {
        let json = r#"{"method":"chat","params":{"prompt":"hi","cwd":"/home","context":"some ctx","model":"claude-sonnet-4-5-20250514","allowed_tools":["Read","Write"],"append_system_prompt":"be nice","permission_mode":"auto"}}"#;
        let req: Request = serde_json::from_str(json).unwrap();
        match req {
            Request::Chat(params) => {
                assert_eq!(params.prompt, "hi");
                assert_eq!(params.context, Some("some ctx".to_string()));
                assert_eq!(params.model, Some("claude-sonnet-4-5-20250514".to_string()));
                assert_eq!(params.allowed_tools, Some(vec!["Read".to_string(), "Write".to_string()]));
                assert_eq!(params.append_system_prompt, Some("be nice".to_string()));
                assert_eq!(params.permission_mode, Some("auto".to_string()));
            }
            _ => panic!("expected Chat variant"),
        }
    }

    #[test]
    fn test_deserialize_resume_request() {
        let json = r#"{"method":"resume","params":{"session_id":"abc-123","cwd":"/tmp"}}"#;
        let req: Request = serde_json::from_str(json).unwrap();
        match req {
            Request::Resume(params) => {
                assert_eq!(params.session_id, "abc-123");
                assert_eq!(params.cwd, Some("/tmp".to_string()));
            }
            _ => panic!("expected Resume variant"),
        }
    }

    #[test]
    fn test_deserialize_continue_request() {
        let json = r#"{"method":"continue","params":{"prompt":"next"}}"#;
        let req: Request = serde_json::from_str(json).unwrap();
        match req {
            Request::Continue(params) => {
                assert_eq!(params.prompt, "next");
            }
            _ => panic!("expected Continue variant"),
        }
    }

    #[test]
    fn test_deserialize_abort_request() {
        let json = r#"{"method":"abort"}"#;
        let req: Request = serde_json::from_str(json).unwrap();
        assert!(matches!(req, Request::Abort));
    }

    #[test]
    fn test_deserialize_status_request() {
        let json = r#"{"method":"status"}"#;
        let req: Request = serde_json::from_str(json).unwrap();
        assert!(matches!(req, Request::Status));
    }

    #[test]
    fn test_serialize_init_event() {
        let evt = Event::Init {
            session_id: "s1".to_string(),
            model: "claude-sonnet-4-5-20250514".to_string(),
            tools: vec!["Read".to_string()],
        };
        let json = evt.to_json_line();
        assert!(json.ends_with('\n'));
        let parsed: serde_json::Value = serde_json::from_str(json.trim()).unwrap();
        assert_eq!(parsed["event"], "init");
        assert_eq!(parsed["session_id"], "s1");
        assert_eq!(parsed["model"], "claude-sonnet-4-5-20250514");
    }

    #[test]
    fn test_serialize_text_chunk_event() {
        let evt = Event::TextChunk {
            text: "hello".to_string(),
        };
        let json = evt.to_json_line();
        let parsed: serde_json::Value = serde_json::from_str(json.trim()).unwrap();
        assert_eq!(parsed["event"], "text_chunk");
        assert_eq!(parsed["text"], "hello");
    }

    #[test]
    fn test_serialize_tool_use_event() {
        let evt = Event::ToolUse {
            tool: "Edit".to_string(),
            id: "t1".to_string(),
            input: serde_json::json!({"file_path": "/tmp/x.lua"}),
        };
        let json = evt.to_json_line();
        let parsed: serde_json::Value = serde_json::from_str(json.trim()).unwrap();
        assert_eq!(parsed["event"], "tool_use");
        assert_eq!(parsed["tool"], "Edit");
        assert_eq!(parsed["input"]["file_path"], "/tmp/x.lua");
    }

    #[test]
    fn test_serialize_tool_result_event() {
        let evt = Event::ToolResult {
            tool: "Edit".to_string(),
            id: "t1".to_string(),
            success: true,
            content: "ok".to_string(),
        };
        let json = evt.to_json_line();
        let parsed: serde_json::Value = serde_json::from_str(json.trim()).unwrap();
        assert_eq!(parsed["event"], "tool_result");
        assert_eq!(parsed["success"], true);
    }

    #[test]
    fn test_serialize_cost_event() {
        let evt = Event::Cost {
            total_usd: 0.005,
            duration_ms: 1200,
            input_tokens: 500,
            output_tokens: 100,
        };
        let json = evt.to_json_line();
        let parsed: serde_json::Value = serde_json::from_str(json.trim()).unwrap();
        assert_eq!(parsed["event"], "cost");
        assert_eq!(parsed["duration_ms"], 1200);
    }

    #[test]
    fn test_serialize_done_event() {
        let evt = Event::Done;
        let json = evt.to_json_line();
        let parsed: serde_json::Value = serde_json::from_str(json.trim()).unwrap();
        assert_eq!(parsed["event"], "done");
    }

    #[test]
    fn test_serialize_error_event() {
        let evt = Event::Error {
            message: "bad thing".to_string(),
        };
        let json = evt.to_json_line();
        let parsed: serde_json::Value = serde_json::from_str(json.trim()).unwrap();
        assert_eq!(parsed["event"], "error");
        assert_eq!(parsed["message"], "bad thing");
    }

    #[test]
    fn test_serialize_status_event() {
        let evt = Event::Status {
            active: true,
            session_id: Some("s1".to_string()),
        };
        let json = evt.to_json_line();
        let parsed: serde_json::Value = serde_json::from_str(json.trim()).unwrap();
        assert_eq!(parsed["event"], "status");
        assert_eq!(parsed["active"], true);
        assert_eq!(parsed["session_id"], "s1");
    }

    #[test]
    fn test_to_json_line_ends_with_newline() {
        let events = vec![
            Event::Done,
            Event::Error { message: "x".to_string() },
            Event::TextChunk { text: "y".to_string() },
        ];
        for evt in events {
            let line = evt.to_json_line();
            assert!(line.ends_with('\n'), "line must end with newline");
            assert_eq!(line.matches('\n').count(), 1, "exactly one newline");
        }
    }
}
