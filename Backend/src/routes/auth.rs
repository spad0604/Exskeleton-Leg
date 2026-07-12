use axum::{Json, Router, extract::State, routing::post};

use crate::{
    app_state::AppState,
    dto::auth::{LoginRequest, LoginResponse, RegisterRequest, RegisterResponse},
    error::AppError,
    models::base_response::BaseResponse,
};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/register", post(register))
        .route("/login", post(login))
}

async fn register(
    State(state): State<AppState>,
    Json(request): Json<RegisterRequest>,
) -> Result<Json<BaseResponse<RegisterResponse>>, AppError> {
    let response = state.auth_service.register(request).await?;
    Ok(Json(response))
}

async fn login(
    State(state): State<AppState>,
    Json(request): Json<LoginRequest>,
) -> Result<Json<BaseResponse<LoginResponse>>, AppError> {
    let response = state.auth_service.login(request).await?;
    Ok(Json(response))
}
