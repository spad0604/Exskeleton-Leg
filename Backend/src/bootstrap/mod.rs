pub mod config;
mod router;
mod state;

use axum::Router;
use sqlx::postgres::PgPoolOptions;

use crate::shared::presentation::ApiError;

pub use config::Config;
pub use state::AppState;

pub async fn build_app(config: Config) -> Result<Router, ApiError> {
    let pool = PgPoolOptions::new()
        .max_connections(config.database_max_connections)
        .connect(&config.database_url)
        .await
        .map_err(ApiError::dependency)?;

    sqlx::migrate!()
        .run(&pool)
        .await
        .map_err(ApiError::dependency)?;

    let state = state::build_state(pool, &config)?;
    Ok(router::build_router(state, &config))
}
