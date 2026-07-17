use std::sync::Arc;

use sqlx::PgPool;

use crate::{
    modules::identity::{
        application::{AuthService, IdentityRepository},
        infrastructure::{JwtTokenService, PostgresIdentityRepository},
    },
    shared::presentation::ApiError,
};

use super::Config;

#[derive(Clone)]
pub struct AppState {
    pub auth: Arc<AuthService>,
}

pub fn build_state(pool: PgPool, config: &Config) -> Result<AppState, ApiError> {
    let repository: Arc<dyn IdentityRepository> = Arc::new(PostgresIdentityRepository::new(pool));
    let tokens = Arc::new(JwtTokenService::new(
        config.jwt_secret.as_bytes(),
        config.jwt_issuer.clone(),
        config.jwt_audience.clone(),
        config.access_token_ttl_seconds,
        config.refresh_token_ttl_seconds,
    )?);

    Ok(AppState {
        auth: Arc::new(AuthService::new(repository, tokens)),
    })
}
