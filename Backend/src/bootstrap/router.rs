use axum::{
    Router,
    http::{HeaderValue, Method, header},
    routing::get,
};
use tower_http::{cors::CorsLayer, trace::TraceLayer};

use crate::{
    modules::{
        identity::presentation as identity_presentation,
        patients::presentation as patients_presentation,
    },
    shared::presentation::{ApiResponse, ApiResult},
};

use super::{AppState, Config};

pub fn build_router(state: AppState, config: &Config) -> Router {
    let origins: Vec<HeaderValue> = config
        .cors_allowed_origins
        .iter()
        .filter_map(|origin| origin.parse().ok())
        .collect();
    let cors = CorsLayer::new()
        .allow_origin(origins)
        .allow_methods([Method::GET, Method::POST, Method::PATCH, Method::DELETE])
        .allow_headers([header::AUTHORIZATION, header::CONTENT_TYPE, header::ACCEPT]);

    Router::new()
        .route("/health", get(health))
        .nest(
            "/api/v1",
            Router::new()
                .merge(identity_presentation::routes())
                .merge(patients_presentation::routes()),
        )
        .with_state(state)
        .layer(cors)
        .layer(TraceLayer::new_for_http())
}

async fn health() -> ApiResult<ApiResponse<serde_json::Value>> {
    Ok(ApiResponse::new(serde_json::json!({ "status": "ok" })))
}
