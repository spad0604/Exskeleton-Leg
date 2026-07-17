use axum::{
    Json, Router,
    extract::State,
    http::{HeaderMap, StatusCode, header},
    routing::{get, post},
};
use serde::Deserialize;
use serde_json::json;

use super::application::{AuthOutput, IdentityError, LoginCommand, MeOutput, RegisterCommand};
use crate::{
    bootstrap::AppState,
    shared::presentation::{ApiError, ApiResponse, ApiResult},
};

pub fn routes() -> Router<AppState> {
    Router::new()
        .nest(
            "/auth",
            Router::new()
                .route("/register", post(register))
                .route("/login", post(login))
                .route("/refresh", post(refresh))
                .route("/logout", post(logout)),
        )
        .route("/me", get(me))
}

#[derive(Debug, Deserialize)]
struct RegisterRequest {
    email: String,
    password: String,
    display_name: String,
    #[serde(default = "default_locale")]
    locale: String,
    timezone: String,
    accepted_terms_version: String,
    device_label: Option<String>,
}

#[derive(Debug, Deserialize)]
struct LoginRequest {
    email: String,
    password: String,
    device_label: Option<String>,
}

#[derive(Debug, Deserialize)]
struct RefreshRequest {
    refresh_token: String,
    device_label: Option<String>,
}

#[derive(Debug, Deserialize)]
struct LogoutRequest {
    refresh_token: String,
}

async fn register(
    State(state): State<AppState>,
    Json(request): Json<RegisterRequest>,
) -> ApiResult<(StatusCode, Json<ApiResponse<AuthOutput>>)> {
    let output = state
        .auth
        .register(RegisterCommand {
            email: request.email,
            password: request.password,
            display_name: request.display_name,
            locale: request.locale,
            timezone: request.timezone,
            accepted_terms_version: request.accepted_terms_version,
            device_label: request.device_label,
        })
        .await
        .map_err(map_identity_error)?;
    Ok((StatusCode::CREATED, Json(ApiResponse::new(output))))
}

async fn login(
    State(state): State<AppState>,
    Json(request): Json<LoginRequest>,
) -> ApiResult<ApiResponse<AuthOutput>> {
    let output = state
        .auth
        .login(LoginCommand {
            email: request.email,
            password: request.password,
            device_label: request.device_label,
        })
        .await
        .map_err(map_identity_error)?;
    Ok(ApiResponse::new(output))
}

async fn refresh(
    State(state): State<AppState>,
    Json(request): Json<RefreshRequest>,
) -> ApiResult<ApiResponse<AuthOutput>> {
    let output = state
        .auth
        .refresh(&request.refresh_token, request.device_label)
        .await
        .map_err(map_identity_error)?;
    Ok(ApiResponse::new(output))
}

async fn logout(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(request): Json<LogoutRequest>,
) -> ApiResult<ApiResponse<serde_json::Value>> {
    let token = bearer_token(&headers)?;
    state
        .auth
        .logout(token, &request.refresh_token)
        .await
        .map_err(map_identity_error)?;
    Ok(ApiResponse::new(json!({ "logged_out": true })))
}

async fn me(State(state): State<AppState>, headers: HeaderMap) -> ApiResult<ApiResponse<MeOutput>> {
    let token = bearer_token(&headers)?;
    let output = state.auth.me(token).await.map_err(map_identity_error)?;
    Ok(ApiResponse::new(output))
}

fn bearer_token(headers: &HeaderMap) -> ApiResult<&str> {
    let value = headers
        .get(header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .ok_or_else(|| {
            ApiError::unauthorized("auth.invalid_token", "Phiên đăng nhập không hợp lệ.")
        })?;
    value
        .strip_prefix("Bearer ")
        .filter(|token| !token.is_empty())
        .ok_or_else(|| {
            ApiError::unauthorized("auth.invalid_token", "Phiên đăng nhập không hợp lệ.")
        })
}

fn default_locale() -> String {
    "vi".to_string()
}

fn map_identity_error(error: IdentityError) -> ApiError {
    match error {
        IdentityError::Validation { field, message } => {
            ApiError::validation(message).with_details(json!({ "field": field }))
        }
        IdentityError::EmailAlreadyExists => ApiError::conflict(
            "identity.email_already_exists",
            "Email này đã được sử dụng.",
        ),
        IdentityError::InvalidCredentials => ApiError::unauthorized(
            "auth.invalid_credentials",
            "Email hoặc mật khẩu không đúng.",
        ),
        IdentityError::InvalidAccessToken => ApiError::unauthorized(
            "auth.invalid_token",
            "Phiên đăng nhập không hợp lệ hoặc đã hết hạn.",
        ),
        IdentityError::InvalidRefreshToken => ApiError::unauthorized(
            "auth.invalid_refresh_token",
            "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.",
        ),
        IdentityError::RefreshTokenReused => ApiError::unauthorized(
            "auth.refresh_token_reused",
            "Phát hiện phiên đăng nhập không an toàn. Vui lòng đăng nhập lại.",
        ),
        IdentityError::AccountUnavailable => {
            ApiError::forbidden("Tài khoản hiện không thể sử dụng.")
        }
        IdentityError::Dependency => ApiError::dependency("identity repository"),
        IdentityError::Internal => ApiError::internal("identity service"),
    }
}
