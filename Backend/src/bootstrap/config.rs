use std::{env, net::SocketAddr};

use crate::shared::presentation::ApiError;

#[derive(Clone, Debug)]
pub struct Config {
    pub bind_address: SocketAddr,
    pub database_url: String,
    pub database_max_connections: u32,
    pub jwt_secret: String,
    pub jwt_issuer: String,
    pub jwt_audience: String,
    pub access_token_ttl_seconds: i64,
    pub refresh_token_ttl_seconds: i64,
    pub cors_allowed_origins: Vec<String>,
}

impl Config {
    pub fn from_env() -> Result<Self, ApiError> {
        let bind_address = env::var("BIND_ADDRESS")
            .unwrap_or_else(|_| "0.0.0.0:8080".to_string())
            .parse()
            .map_err(|_| ApiError::config("BIND_ADDRESS must be a socket address"))?;
        let database_url = required("DATABASE_URL")?;
        let jwt_secret = required("JWT_SECRET")?;
        if jwt_secret.len() < 32 {
            return Err(ApiError::config(
                "JWT_SECRET must contain at least 32 bytes",
            ));
        }

        Ok(Self {
            bind_address,
            database_url,
            database_max_connections: parse_or("DATABASE_MAX_CONNECTIONS", 10)?,
            jwt_secret,
            jwt_issuer: env::var("JWT_ISSUER")
                .unwrap_or_else(|_| "exoskeleton-leg-api".to_string()),
            jwt_audience: env::var("JWT_AUDIENCE")
                .unwrap_or_else(|_| "exoskeleton-leg-mobile".to_string()),
            access_token_ttl_seconds: parse_or("ACCESS_TOKEN_TTL_SECONDS", 900)?,
            refresh_token_ttl_seconds: parse_or("REFRESH_TOKEN_TTL_SECONDS", 2_592_000)?,
            cors_allowed_origins: env::var("CORS_ALLOWED_ORIGINS")
                .unwrap_or_else(|_| "http://localhost:3000".to_string())
                .split(',')
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(str::to_string)
                .collect(),
        })
    }
}

fn required(name: &'static str) -> Result<String, ApiError> {
    env::var(name).map_err(|_| ApiError::config(format!("{name} is required")))
}

fn parse_or<T>(name: &'static str, default: T) -> Result<T, ApiError>
where
    T: std::str::FromStr,
{
    match env::var(name) {
        Ok(value) => value
            .parse()
            .map_err(|_| ApiError::config(format!("{name} has an invalid value"))),
        Err(_) => Ok(default),
    }
}
