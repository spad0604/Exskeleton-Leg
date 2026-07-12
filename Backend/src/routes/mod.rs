use axum::{Json, Router, routing::get};

use crate::{
    app_state::AppState,
    models::base_response::{BaseResponse, ResponseStatus},
};

pub(crate) mod auth;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/health", get(health))
        .nest("/auth", auth::routes())
}

async fn health() -> Json<BaseResponse<()>> {
    Json(BaseResponse {
        status: ResponseStatus::Success,
        message: "ok".to_string(),
        data: None,
    })
}
