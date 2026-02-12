mod claude;
mod protocol;
mod session;

use protocol::{Event, Request};
use session::SessionManager;
use tokio::io::{self, AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::sync::mpsc;
use std::sync::Arc;
use tokio::sync::Mutex;
use tokio::task::JoinHandle;

fn spawn_event_forwarder(
    mut rx: mpsc::UnboundedReceiver<Event>,
    active_process: Arc<Mutex<Option<claude::ClaudeProcess>>>,
) -> JoinHandle<()> {
    tokio::spawn(async move {
        while let Some(event) = rx.recv().await {
            let line = event.to_json_line();
            let mut out = io::stdout();
            let _ = out.write_all(line.as_bytes()).await;
            let _ = out.flush().await;

            if matches!(event, Event::Done) {
                let mut proc = active_process.lock().await;
                if let Some(ref mut p) = *proc {
                    let _ = p.wait().await;
                }
                *proc = None;
                break;
            }
        }
    })
}

#[tokio::main]
async fn main() {
    let session = SessionManager::new();
    let active_process: Arc<Mutex<Option<claude::ClaudeProcess>>> = Arc::new(Mutex::new(None));
    let active_forwarder: Arc<Mutex<Option<JoinHandle<()>>>> = Arc::new(Mutex::new(None));

    let stdin = io::stdin();
    let mut stdout = io::stdout();
    let reader = BufReader::new(stdin);
    let mut lines = reader.lines();

    while let Ok(Some(line)) = lines.next_line().await {
        if line.is_empty() {
            continue;
        }

        let request: Request = match serde_json::from_str(&line) {
            Ok(r) => r,
            Err(e) => {
                let err = Event::Error {
                    message: format!("Invalid request: {}", e),
                };
                let _ = stdout.write_all(err.to_json_line().as_bytes()).await;
                let _ = stdout.flush().await;
                continue;
            }
        };

        match request {
            Request::Chat(params) => {
                {
                    let mut proc = active_process.lock().await;
                    if let Some(ref mut p) = *proc {
                        let _ = p.abort().await;
                    }
                    *proc = None;
                }

                let (tx, rx) = mpsc::unbounded_channel::<Event>();

                let proc_result =
                    claude::ClaudeProcess::spawn(&params, None, session.clone(), tx).await;

                match proc_result {
                    Ok(process) => {
                        *active_process.lock().await = Some(process);
                        let handle = spawn_event_forwarder(rx, active_process.clone());
                        *active_forwarder.lock().await = Some(handle);
                    }
                    Err(e) => {
                        let err = Event::Error { message: e };
                        let _ = stdout.write_all(err.to_json_line().as_bytes()).await;
                        let _ = stdout.flush().await;
                    }
                }
            }

            Request::Resume(params) => {
                {
                    let mut proc = active_process.lock().await;
                    if let Some(ref mut p) = *proc {
                        let _ = p.abort().await;
                    }
                    *proc = None;
                }

                let chat_params = protocol::ChatParams {
                    prompt: String::new(),
                    cwd: params.cwd,
                    context: None,
                    model: None,
                    allowed_tools: None,
                    append_system_prompt: None,
                    permission_mode: None,
                };

                let (tx, rx) = mpsc::unbounded_channel::<Event>();
                let proc_result = claude::ClaudeProcess::spawn(
                    &chat_params,
                    Some(params.session_id),
                    session.clone(),
                    tx,
                )
                .await;

                match proc_result {
                    Ok(process) => {
                        *active_process.lock().await = Some(process);
                        let handle = spawn_event_forwarder(rx, active_process.clone());
                        *active_forwarder.lock().await = Some(handle);
                    }
                    Err(e) => {
                        let err = Event::Error { message: e };
                        let _ = stdout.write_all(err.to_json_line().as_bytes()).await;
                        let _ = stdout.flush().await;
                    }
                }
            }

            Request::Continue(params) => {
                let sid = session.get_session_id().await;
                if let Some(session_id) = sid {
                    let chat_params = protocol::ChatParams {
                        prompt: params.prompt,
                        cwd: None,
                        context: params.context,
                        model: None,
                        allowed_tools: None,
                        append_system_prompt: None,
                        permission_mode: None,
                    };

                    let (tx, rx) = mpsc::unbounded_channel::<Event>();
                    let proc_result = claude::ClaudeProcess::spawn(
                        &chat_params,
                        Some(session_id),
                        session.clone(),
                        tx,
                    )
                    .await;

                    match proc_result {
                        Ok(process) => {
                            *active_process.lock().await = Some(process);
                            let handle = spawn_event_forwarder(rx, active_process.clone());
                            *active_forwarder.lock().await = Some(handle);
                        }
                        Err(e) => {
                            let err = Event::Error { message: e };
                            let _ = stdout.write_all(err.to_json_line().as_bytes()).await;
                            let _ = stdout.flush().await;
                        }
                    }
                } else {
                    let err = Event::Error {
                        message: "No active session to continue".to_string(),
                    };
                    let _ = stdout.write_all(err.to_json_line().as_bytes()).await;
                    let _ = stdout.flush().await;
                }
            }

            Request::Abort => {
                let mut proc = active_process.lock().await;
                if let Some(ref mut p) = *proc {
                    let _ = p.abort().await;
                    let done = Event::Done;
                    let _ = stdout.write_all(done.to_json_line().as_bytes()).await;
                    let _ = stdout.flush().await;
                }
                *proc = None;
            }

            Request::Status => {
                let state = session.get_state().await;
                let evt = Event::Status {
                    active: state.active,
                    session_id: state.session_id,
                };
                let _ = stdout.write_all(evt.to_json_line().as_bytes()).await;
                let _ = stdout.flush().await;
            }
        }
    }

    let handle = active_forwarder.lock().await.take();
    if let Some(h) = handle {
        let _ = h.await;
    }
}
