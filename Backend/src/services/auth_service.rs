use std::sync::Arc;

use argon2::{
    Argon2,
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
};

use chrono::{Duration, Utc};
use jsonwebtoken::{EncodingKey, Header, encode};
use serde::Serialize;
use uuid::Uuid;

use crate::{
    dto::auth::{LoginRequest, LoginResponse, RegisterRequest, RegisterResponse},
    error::AppError,
    models::{
        base_response::BaseResponse,
        user::{Role, User},
    },
    repositories::user_repository::UserRepository,
};

#[derive(Clone)]
pub struct AuthService {
    user_repository: Arc<UserRepository>,
    jwt_secret: String,
}

#[derive(Serialize)]
struct Claims {
    sub: String,
    exp: usize,
}

impl AuthService {
    pub fn new(user_repository: Arc<UserRepository>, jwt_secret: String) -> Self {
        Self {
            user_repository,
            jwt_secret,
        }
    }

    pub async fn register(
        &self,
        request: RegisterRequest,
    ) -> Result<BaseResponse<RegisterResponse>, AppError> {
        if request.email.trim().is_empty() {
            return Err(AppError::BadRequest("email is empty".to_string()));
        }

        if request.password.len() < 8 {
            return Err(AppError::BadRequest(
                "password must be at least 8 characters".to_string(),
            ));
        }

        if self
            .user_repository
            .find_by_email(&request.email)
            .await
            .is_some()
        {
            return Err(AppError::Conflict("email already exists".to_string()));
        }

        let password_hash = hash_password(&request.password)?;

        let user = User {
            id: Uuid::new_v4(),
            email: request.email,
            full_name: request.full_name,
            password_hash,
            dob: request.dob,
            user_role: Role::User,
        };

        self.user_repository.create(user.clone()).await;

        let access_token = create_jwt(user.id, &self.jwt_secret)?;

        Ok(BaseResponse::success(
            "register success",
            RegisterResponse {
                id: user.id,
                email: user.email,
                full_name: user.full_name,
                access_token,
                user_role: user.user_role,
            },
        ))
    }

    pub async fn login(
        &self,
        request: LoginRequest,
    ) -> Result<BaseResponse<LoginResponse>, AppError> {
        if request.email.trim().is_empty() {
            return Err(AppError::BadRequest("email is required".to_string()));
        }

        if request.password.trim().is_empty() {
            return Err(AppError::BadRequest("password is required".to_string()));
        }

        let user = self
            .user_repository
            .find_by_email(&request.email)
            .await
            .ok_or(AppError::Unauthorized)?;

        let is_valid_password = verify_password(&request.password, &user.password_hash)?;

        if !is_valid_password {
            return Err(AppError::Unauthorized);
        }

        let access_token = create_jwt(user.id, &self.jwt_secret)?;

        Ok(BaseResponse::success(
            "login success",
            LoginResponse {
                id: user.id,
                email: user.email,
                full_name: user.full_name,
                access_token,
                user_role: user.user_role,
            },
        ))
    }
}

fn hash_password(password: &str) -> Result<String, AppError> {
    let salt_source = Uuid::new_v4();
    let salt = SaltString::encode_b64(salt_source.as_bytes())
        .map_err(|_| AppError::Internal("failed to create password salt".to_string()))?;
    let hash = Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map_err(|_| AppError::Internal("failed to hash password".to_string()))?
        .to_string();

    Ok(hash)
}

fn verify_password(password: &str, password_hash: &str) -> Result<bool, AppError> {
    let parsed_hash = PasswordHash::new(password_hash)
        .map_err(|_| AppError::Internal("invalid password hash".to_string()))?;

    Ok(Argon2::default()
        .verify_password(password.as_bytes(), &parsed_hash)
        .is_ok())
}

fn create_jwt(user_id: Uuid, secret: &str) -> Result<String, AppError> {
    let expiration = Utc::now() + Duration::hours(24);

    let claims = Claims {
        sub: user_id.to_string(),
        exp: expiration.timestamp() as usize,
    };

    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    )
    .map_err(|_| AppError::Internal("failed to create token".to_string()))
}
