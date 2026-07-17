use std::sync::Arc;

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use serde::Serialize;
use uuid::Uuid;

use super::domain::{NewRefreshSession, NewUser, Role, User, UserStatus};

#[derive(Debug, thiserror::Error)]
pub enum IdentityError {
    #[error("invalid identity input")]
    Validation {
        field: &'static str,
        message: &'static str,
    },
    #[error("email already exists")]
    EmailAlreadyExists,
    #[error("invalid credentials")]
    InvalidCredentials,
    #[error("invalid access token")]
    InvalidAccessToken,
    #[error("invalid refresh token")]
    InvalidRefreshToken,
    #[error("refresh token reuse detected")]
    RefreshTokenReused,
    #[error("account is not active")]
    AccountUnavailable,
    #[error("identity dependency failed")]
    Dependency,
    #[error("identity operation failed")]
    Internal,
}

#[derive(Debug)]
pub enum RepositoryError {
    EmailAlreadyExists,
    InvalidRefreshToken,
    RefreshTokenReused,
    Internal,
}

#[async_trait]
pub trait IdentityRepository: Send + Sync {
    async fn create_patient(&self, user: NewUser) -> Result<User, RepositoryError>;
    async fn find_by_email(&self, email_normalized: &str) -> Result<Option<User>, RepositoryError>;
    async fn find_by_id(&self, user_id: Uuid) -> Result<Option<User>, RepositoryError>;
    async fn create_refresh_session(
        &self,
        user_id: Uuid,
        session: NewRefreshSession,
    ) -> Result<(), RepositoryError>;
    async fn rotate_refresh_session(
        &self,
        current_token_hash: &[u8],
        replacement: NewRefreshSession,
        now: DateTime<Utc>,
    ) -> Result<User, RepositoryError>;
    async fn revoke_refresh_session(
        &self,
        user_id: Uuid,
        token_hash: &[u8],
        now: DateTime<Utc>,
    ) -> Result<(), RepositoryError>;
}

pub struct IssuedRefreshToken {
    pub raw: String,
    pub session: NewRefreshSession,
}

#[async_trait]
pub trait TokenProvider: Send + Sync {
    fn hash_password(&self, password: &str) -> Result<String, IdentityError>;
    fn verify_password(&self, password: &str, password_hash: &str) -> Result<bool, IdentityError>;
    fn issue_access_token(&self, user: &User) -> Result<String, IdentityError>;
    fn validate_access_token(&self, token: &str) -> Result<Uuid, IdentityError>;
    fn issue_refresh_token(
        &self,
        device_label: Option<String>,
    ) -> Result<IssuedRefreshToken, IdentityError>;
    fn hash_refresh_token(&self, token: &str) -> Vec<u8>;
    fn access_token_ttl_seconds(&self) -> i64;
    fn refresh_token_ttl_seconds(&self) -> i64;
}

#[derive(Clone, Debug)]
pub struct RegisterCommand {
    pub email: String,
    pub password: String,
    pub display_name: String,
    pub locale: String,
    pub timezone: String,
    pub accepted_terms_version: String,
    pub device_label: Option<String>,
}

#[derive(Clone, Debug)]
pub struct LoginCommand {
    pub email: String,
    pub password: String,
    pub device_label: Option<String>,
}

#[derive(Clone, Debug, Serialize)]
pub struct PublicUser {
    pub id: Uuid,
    pub display_name: String,
    pub roles: Vec<Role>,
}

#[derive(Clone, Debug, Serialize)]
pub struct MeOutput {
    pub id: Uuid,
    pub email: String,
    pub display_name: String,
    pub locale: String,
    pub timezone: String,
    pub roles: Vec<Role>,
}

#[derive(Clone, Debug, Serialize)]
pub struct AuthOutput {
    pub access_token: String,
    pub access_token_expires_in: i64,
    pub refresh_token: String,
    pub refresh_token_expires_in: i64,
    pub user: PublicUser,
}

pub struct AuthService {
    repository: Arc<dyn IdentityRepository>,
    tokens: Arc<dyn TokenProvider>,
}

impl AuthService {
    pub fn new(repository: Arc<dyn IdentityRepository>, tokens: Arc<dyn TokenProvider>) -> Self {
        Self { repository, tokens }
    }

    pub async fn register(&self, command: RegisterCommand) -> Result<AuthOutput, IdentityError> {
        let email = normalize_and_validate_email(&command.email)?;
        validate_password(&command.password)?;
        let display_name = trimmed_required("display_name", &command.display_name, 2, 100)?;
        let timezone = trimmed_required("timezone", &command.timezone, 1, 100)?;
        let terms = trimmed_required(
            "accepted_terms_version",
            &command.accepted_terms_version,
            1,
            50,
        )?;
        let locale = match command.locale.trim() {
            "vi" => "vi",
            "en" => "en",
            _ => {
                return Err(IdentityError::Validation {
                    field: "locale",
                    message: "Ngôn ngữ chỉ hỗ trợ vi hoặc en.",
                });
            }
        };
        let password_hash = self.tokens.hash_password(&command.password)?;
        let user = self
            .repository
            .create_patient(NewUser {
                id: Uuid::new_v4(),
                email_normalized: email,
                password_hash,
                display_name,
                locale: locale.to_string(),
                timezone,
                accepted_terms_version: terms,
            })
            .await
            .map_err(map_repository_error)?;

        self.create_session(user, command.device_label).await
    }

    pub async fn login(&self, command: LoginCommand) -> Result<AuthOutput, IdentityError> {
        let email = normalize_and_validate_email(&command.email)?;
        if command.password.is_empty() {
            return Err(IdentityError::InvalidCredentials);
        }
        let user = self
            .repository
            .find_by_email(&email)
            .await
            .map_err(map_repository_error)?
            .ok_or(IdentityError::InvalidCredentials)?;
        ensure_active(&user)?;
        if !self
            .tokens
            .verify_password(&command.password, &user.password_hash)?
        {
            return Err(IdentityError::InvalidCredentials);
        }

        self.create_session(user, command.device_label).await
    }

    pub async fn refresh(
        &self,
        refresh_token: &str,
        device_label: Option<String>,
    ) -> Result<AuthOutput, IdentityError> {
        if refresh_token.is_empty() {
            return Err(IdentityError::InvalidRefreshToken);
        }
        let current_hash = self.tokens.hash_refresh_token(refresh_token);
        let replacement = self.tokens.issue_refresh_token(device_label)?;
        let user = self
            .repository
            .rotate_refresh_session(&current_hash, replacement.session, Utc::now())
            .await
            .map_err(map_repository_error)?;
        ensure_active(&user)?;
        self.auth_output(user, replacement.raw)
    }

    pub async fn logout(
        &self,
        access_token: &str,
        refresh_token: &str,
    ) -> Result<(), IdentityError> {
        let user_id = self.tokens.validate_access_token(access_token)?;
        let refresh_hash = self.tokens.hash_refresh_token(refresh_token);
        self.repository
            .revoke_refresh_session(user_id, &refresh_hash, Utc::now())
            .await
            .map_err(map_repository_error)
    }

    pub async fn me(&self, access_token: &str) -> Result<MeOutput, IdentityError> {
        let user_id = self.tokens.validate_access_token(access_token)?;
        let user = self
            .repository
            .find_by_id(user_id)
            .await
            .map_err(map_repository_error)?
            .ok_or(IdentityError::InvalidAccessToken)?;
        ensure_active(&user)?;
        Ok(MeOutput {
            id: user.id,
            email: user.email_normalized,
            display_name: user.display_name,
            locale: user.locale,
            timezone: user.timezone,
            roles: user.roles,
        })
    }

    async fn create_session(
        &self,
        user: User,
        device_label: Option<String>,
    ) -> Result<AuthOutput, IdentityError> {
        ensure_active(&user)?;
        let refresh = self.tokens.issue_refresh_token(device_label)?;
        self.repository
            .create_refresh_session(user.id, refresh.session)
            .await
            .map_err(map_repository_error)?;
        self.auth_output(user, refresh.raw)
    }

    fn auth_output(&self, user: User, refresh_token: String) -> Result<AuthOutput, IdentityError> {
        let access_token = self.tokens.issue_access_token(&user)?;
        Ok(AuthOutput {
            access_token,
            access_token_expires_in: self.tokens.access_token_ttl_seconds(),
            refresh_token,
            refresh_token_expires_in: self.tokens.refresh_token_ttl_seconds(),
            user: PublicUser {
                id: user.id,
                display_name: user.display_name,
                roles: user.roles,
            },
        })
    }
}

fn normalize_and_validate_email(value: &str) -> Result<String, IdentityError> {
    let email = value.trim().to_lowercase();
    let mut parts = email.split('@');
    let local = parts.next().unwrap_or_default();
    let domain = parts.next().unwrap_or_default();
    if email.len() > 254
        || local.is_empty()
        || domain.is_empty()
        || !domain.contains('.')
        || parts.next().is_some()
    {
        return Err(IdentityError::Validation {
            field: "email",
            message: "Email không hợp lệ.",
        });
    }
    Ok(email)
}

fn validate_password(value: &str) -> Result<(), IdentityError> {
    if !(8..=128).contains(&value.chars().count()) {
        return Err(IdentityError::Validation {
            field: "password",
            message: "Mật khẩu cần từ 8 đến 128 ký tự.",
        });
    }
    Ok(())
}

fn trimmed_required(
    field: &'static str,
    value: &str,
    min: usize,
    max: usize,
) -> Result<String, IdentityError> {
    let value = value.trim();
    if !(min..=max).contains(&value.chars().count()) {
        return Err(IdentityError::Validation {
            field,
            message: "Giá trị không hợp lệ.",
        });
    }
    Ok(value.to_string())
}

fn ensure_active(user: &User) -> Result<(), IdentityError> {
    if user.status == UserStatus::Active {
        Ok(())
    } else {
        Err(IdentityError::AccountUnavailable)
    }
}

fn map_repository_error(error: RepositoryError) -> IdentityError {
    match error {
        RepositoryError::EmailAlreadyExists => IdentityError::EmailAlreadyExists,
        RepositoryError::InvalidRefreshToken => IdentityError::InvalidRefreshToken,
        RepositoryError::RefreshTokenReused => IdentityError::RefreshTokenReused,
        RepositoryError::Internal => IdentityError::Dependency,
    }
}

#[cfg(test)]
mod tests {
    use super::{normalize_and_validate_email, validate_password};

    #[test]
    fn normalizes_email_before_identity_lookup() {
        let email = normalize_and_validate_email("  USER@Example.COM ").unwrap();
        assert_eq!(email, "user@example.com");
    }

    #[test]
    fn rejects_invalid_email_and_short_password() {
        assert!(normalize_and_validate_email("not-an-email").is_err());
        assert!(validate_password("short").is_err());
        assert!(validate_password("strong-password").is_ok());
    }
}
