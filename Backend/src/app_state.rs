use crate::services::auth_service::AuthService;

#[derive(Clone)]
pub struct AppState {
    pub auth_service: AuthService,
}
