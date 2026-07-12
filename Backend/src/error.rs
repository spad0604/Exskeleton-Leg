use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};

use crate::models::base_response::BaseResponse;

#[derive(Debug)]
pub enum AppError {
    BadRequest(String),
    Conflict(String),
    Unauthorized,
    Internal(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            AppError::BadRequest(message) => (StatusCode::BAD_REQUEST, message),
            AppError::Conflict(message) => (StatusCode::CONFLICT, message),
            AppError::Unauthorized => (
                StatusCode::UNAUTHORIZED,
                "invalid email or password".to_string(),
            ),
            AppError::Internal(message) => (StatusCode::INTERNAL_SERVER_ERROR, message),
        };

        (status, Json(BaseResponse::<()>::failure(message))).into_response()
    }
}
