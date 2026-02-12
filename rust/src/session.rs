use std::sync::Arc;
use tokio::sync::Mutex;

#[derive(Debug, Clone)]
pub struct SessionState {
    pub session_id: Option<String>,
    pub active: bool,
    pub model: Option<String>,
}

impl SessionState {
    pub fn new() -> Self {
        Self {
            session_id: None,
            active: false,
            model: None,
        }
    }
}

#[derive(Clone)]
pub struct SessionManager {
    state: Arc<Mutex<SessionState>>,
}

impl SessionManager {
    pub fn new() -> Self {
        Self {
            state: Arc::new(Mutex::new(SessionState::new())),
        }
    }

    pub async fn set_active(&self, session_id: String, model: String) {
        let mut state = self.state.lock().await;
        state.session_id = Some(session_id);
        state.model = Some(model);
        state.active = true;
    }

    pub async fn set_inactive(&self) {
        let mut state = self.state.lock().await;
        state.active = false;
    }

    pub async fn get_state(&self) -> SessionState {
        self.state.lock().await.clone()
    }

    pub async fn get_session_id(&self) -> Option<String> {
        self.state.lock().await.session_id.clone()
    }
}
