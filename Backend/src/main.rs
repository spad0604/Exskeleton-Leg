use std::sync::Arc;

use app_state::AppState;
use repositories::user_repository::UserRepository;
use services::auth_service::AuthService;
use tower_http::{cors::CorsLayer, trace::TraceLayer};

mod app_state;
mod dto;
mod error;
mod models;
mod repositories;
mod routes;
mod services;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let user_repository = Arc::new(UserRepository::new());
    let auth_service = AuthService::new(user_repository, "dev-secret-change-me".to_string());
    let state = AppState { auth_service };

    let app = routes::routes()
        .with_state(state)
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http());

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080")
        .await
        .expect("failed to bind server");

    println!("Backend running at http://0.0.0.0:8080");

    axum::serve(listener, app).await.expect("server failed");
}
