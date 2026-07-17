use argon2::{
    Argon2,
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
};
use async_trait::async_trait;
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use chrono::{DateTime, Duration, Utc};
use jsonwebtoken::{Algorithm, DecodingKey, EncodingKey, Header, Validation, decode, encode};
use rand_core::{OsRng, TryRngCore};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use sqlx::{FromRow, PgPool, Postgres, Transaction};
use uuid::Uuid;

use super::{
    application::{
        IdentityError, IdentityRepository, IssuedRefreshToken, RepositoryError, TokenProvider,
    },
    domain::{NewRefreshSession, NewUser, Role, User, UserStatus},
};
use crate::shared::presentation::ApiError;

pub struct JwtTokenService {
    encoding_key: EncodingKey,
    decoding_key: DecodingKey,
    issuer: String,
    audience: String,
    access_ttl_seconds: i64,
    refresh_ttl_seconds: i64,
}

#[derive(Debug, Deserialize, Serialize)]
struct AccessClaims {
    sub: Uuid,
    iss: String,
    aud: String,
    exp: usize,
    iat: usize,
    jti: Uuid,
    roles: Vec<Role>,
}

impl JwtTokenService {
    pub fn new(
        secret: &[u8],
        issuer: String,
        audience: String,
        access_ttl_seconds: i64,
        refresh_ttl_seconds: i64,
    ) -> Result<Self, ApiError> {
        if access_ttl_seconds <= 0 || refresh_ttl_seconds <= access_ttl_seconds {
            return Err(ApiError::config("token TTL configuration is invalid"));
        }
        Ok(Self {
            encoding_key: EncodingKey::from_secret(secret),
            decoding_key: DecodingKey::from_secret(secret),
            issuer,
            audience,
            access_ttl_seconds,
            refresh_ttl_seconds,
        })
    }
}

#[async_trait]
impl TokenProvider for JwtTokenService {
    fn hash_password(&self, password: &str) -> Result<String, IdentityError> {
        let mut random_salt = [0_u8; 16];
        OsRng
            .try_fill_bytes(&mut random_salt)
            .map_err(|_| IdentityError::Internal)?;
        let salt = SaltString::encode_b64(&random_salt).map_err(|_| IdentityError::Internal)?;
        Argon2::default()
            .hash_password(password.as_bytes(), &salt)
            .map(|hash| hash.to_string())
            .map_err(|_| IdentityError::Internal)
    }

    fn verify_password(&self, password: &str, password_hash: &str) -> Result<bool, IdentityError> {
        let parsed = PasswordHash::new(password_hash).map_err(|_| IdentityError::Internal)?;
        Ok(Argon2::default()
            .verify_password(password.as_bytes(), &parsed)
            .is_ok())
    }

    fn issue_access_token(&self, user: &User) -> Result<String, IdentityError> {
        let now = Utc::now();
        let claims = AccessClaims {
            sub: user.id,
            iss: self.issuer.clone(),
            aud: self.audience.clone(),
            exp: (now + Duration::seconds(self.access_ttl_seconds)).timestamp() as usize,
            iat: now.timestamp() as usize,
            jti: Uuid::new_v4(),
            roles: user.roles.clone(),
        };
        encode(&Header::new(Algorithm::HS256), &claims, &self.encoding_key)
            .map_err(|_| IdentityError::Internal)
    }

    fn validate_access_token(&self, token: &str) -> Result<Uuid, IdentityError> {
        let mut validation = Validation::new(Algorithm::HS256);
        validation.set_issuer(&[self.issuer.as_str()]);
        validation.set_audience(&[self.audience.as_str()]);
        decode::<AccessClaims>(token, &self.decoding_key, &validation)
            .map(|data| data.claims.sub)
            .map_err(|_| IdentityError::InvalidAccessToken)
    }

    fn issue_refresh_token(
        &self,
        device_label: Option<String>,
    ) -> Result<IssuedRefreshToken, IdentityError> {
        let mut random = [0_u8; 32];
        OsRng
            .try_fill_bytes(&mut random)
            .map_err(|_| IdentityError::Internal)?;
        let raw = URL_SAFE_NO_PAD.encode(random);
        Ok(IssuedRefreshToken {
            session: NewRefreshSession {
                id: Uuid::new_v4(),
                token_hash: self.hash_refresh_token(&raw),
                device_label: device_label
                    .map(|value| value.trim().chars().take(100).collect())
                    .filter(|value: &String| !value.is_empty()),
                expires_at: Utc::now() + Duration::seconds(self.refresh_ttl_seconds),
            },
            raw,
        })
    }

    fn hash_refresh_token(&self, token: &str) -> Vec<u8> {
        Sha256::digest(token.as_bytes()).to_vec()
    }

    fn access_token_ttl_seconds(&self) -> i64 {
        self.access_ttl_seconds
    }

    fn refresh_token_ttl_seconds(&self) -> i64 {
        self.refresh_ttl_seconds
    }
}

pub struct PostgresIdentityRepository {
    pool: PgPool,
}

impl PostgresIdentityRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[derive(FromRow)]
struct UserRow {
    id: Uuid,
    email_normalized: String,
    password_hash: String,
    display_name: String,
    status: String,
    locale: String,
    timezone: String,
    roles: Vec<String>,
}

impl TryFrom<UserRow> for User {
    type Error = RepositoryError;

    fn try_from(row: UserRow) -> Result<Self, Self::Error> {
        let status = UserStatus::parse(&row.status).ok_or(RepositoryError::Internal)?;
        let roles = row
            .roles
            .iter()
            .map(|role| Role::parse(role).ok_or(RepositoryError::Internal))
            .collect::<Result<Vec<_>, _>>()?;
        Ok(Self {
            id: row.id,
            email_normalized: row.email_normalized,
            password_hash: row.password_hash,
            display_name: row.display_name,
            status,
            locale: row.locale,
            timezone: row.timezone,
            roles,
        })
    }
}

#[derive(FromRow)]
struct RefreshSessionRow {
    id: Uuid,
    user_id: Uuid,
    family_id: Uuid,
    expires_at: DateTime<Utc>,
    revoked_at: Option<DateTime<Utc>>,
}

#[async_trait]
impl IdentityRepository for PostgresIdentityRepository {
    async fn create_patient(&self, user: NewUser) -> Result<User, RepositoryError> {
        let mut transaction = self.pool.begin().await.map_err(db_error)?;
        let result = sqlx::query(
            r#"INSERT INTO users (
                id, email_normalized, password_hash, display_name, locale, timezone,
                accepted_terms_version
            ) VALUES ($1, $2, $3, $4, $5, $6, $7)"#,
        )
        .bind(user.id)
        .bind(&user.email_normalized)
        .bind(&user.password_hash)
        .bind(&user.display_name)
        .bind(&user.locale)
        .bind(&user.timezone)
        .bind(&user.accepted_terms_version)
        .execute(&mut *transaction)
        .await;

        if let Err(error) = result {
            if error
                .as_database_error()
                .and_then(|value| value.code())
                .as_deref()
                == Some("23505")
            {
                return Err(RepositoryError::EmailAlreadyExists);
            }
            return Err(db_error(error));
        }

        sqlx::query("INSERT INTO user_roles (user_id, role) VALUES ($1, 'patient')")
            .bind(user.id)
            .execute(&mut *transaction)
            .await
            .map_err(db_error)?;
        transaction.commit().await.map_err(db_error)?;

        Ok(User {
            id: user.id,
            email_normalized: user.email_normalized,
            password_hash: user.password_hash,
            display_name: user.display_name,
            status: UserStatus::Active,
            locale: user.locale,
            timezone: user.timezone,
            roles: vec![Role::Patient],
        })
    }

    async fn find_by_email(&self, email_normalized: &str) -> Result<Option<User>, RepositoryError> {
        find_user(&self.pool, "u.email_normalized = $1", email_normalized).await
    }

    async fn find_by_id(&self, user_id: Uuid) -> Result<Option<User>, RepositoryError> {
        let row = sqlx::query_as::<_, UserRow>(USER_BY_ID_QUERY)
            .bind(user_id)
            .fetch_optional(&self.pool)
            .await
            .map_err(db_error)?;
        row.map(TryInto::try_into).transpose()
    }

    async fn create_refresh_session(
        &self,
        user_id: Uuid,
        session: NewRefreshSession,
    ) -> Result<(), RepositoryError> {
        sqlx::query(
            r#"INSERT INTO refresh_sessions
               (id, user_id, family_id, token_hash, device_label, expires_at)
               VALUES ($1, $2, $1, $3, $4, $5)"#,
        )
        .bind(session.id)
        .bind(user_id)
        .bind(session.token_hash)
        .bind(session.device_label)
        .bind(session.expires_at)
        .execute(&self.pool)
        .await
        .map_err(db_error)?;
        Ok(())
    }

    async fn rotate_refresh_session(
        &self,
        current_token_hash: &[u8],
        replacement: NewRefreshSession,
        now: DateTime<Utc>,
    ) -> Result<User, RepositoryError> {
        let mut transaction = self.pool.begin().await.map_err(db_error)?;
        let current = sqlx::query_as::<_, RefreshSessionRow>(
            r#"SELECT id, user_id, family_id, expires_at, revoked_at
               FROM refresh_sessions WHERE token_hash = $1 FOR UPDATE"#,
        )
        .bind(current_token_hash)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(db_error)?
        .ok_or(RepositoryError::InvalidRefreshToken)?;

        if current.revoked_at.is_some() {
            revoke_family(&mut transaction, current.family_id, now).await?;
            transaction.commit().await.map_err(db_error)?;
            return Err(RepositoryError::RefreshTokenReused);
        }
        if current.expires_at <= now {
            sqlx::query(
                "UPDATE refresh_sessions SET revoked_at = $2, last_used_at = $2 WHERE id = $1",
            )
            .bind(current.id)
            .bind(now)
            .execute(&mut *transaction)
            .await
            .map_err(db_error)?;
            transaction.commit().await.map_err(db_error)?;
            return Err(RepositoryError::InvalidRefreshToken);
        }

        sqlx::query(
            r#"INSERT INTO refresh_sessions
               (id, user_id, family_id, token_hash, device_label, expires_at, rotated_from_id)
               VALUES ($1, $2, $3, $4, $5, $6, $7)"#,
        )
        .bind(replacement.id)
        .bind(current.user_id)
        .bind(current.family_id)
        .bind(replacement.token_hash)
        .bind(replacement.device_label)
        .bind(replacement.expires_at)
        .bind(current.id)
        .execute(&mut *transaction)
        .await
        .map_err(db_error)?;
        sqlx::query("UPDATE refresh_sessions SET revoked_at = $2, last_used_at = $2 WHERE id = $1")
            .bind(current.id)
            .bind(now)
            .execute(&mut *transaction)
            .await
            .map_err(db_error)?;
        let user = fetch_user_by_id(&mut transaction, current.user_id).await?;
        transaction.commit().await.map_err(db_error)?;
        Ok(user)
    }

    async fn revoke_refresh_session(
        &self,
        user_id: Uuid,
        token_hash: &[u8],
        now: DateTime<Utc>,
    ) -> Result<(), RepositoryError> {
        let result = sqlx::query(
            r#"UPDATE refresh_sessions SET revoked_at = $3, last_used_at = $3
               WHERE user_id = $1 AND token_hash = $2 AND revoked_at IS NULL"#,
        )
        .bind(user_id)
        .bind(token_hash)
        .bind(now)
        .execute(&self.pool)
        .await
        .map_err(db_error)?;
        if result.rows_affected() == 0 {
            return Err(RepositoryError::InvalidRefreshToken);
        }
        Ok(())
    }
}

const USER_SELECT: &str = r#"SELECT u.id, u.email_normalized, u.password_hash,
    u.display_name, u.status, u.locale, u.timezone,
    COALESCE(array_agg(ur.role ORDER BY ur.role) FILTER (WHERE ur.role IS NOT NULL), ARRAY[]::text[]) AS roles
    FROM users u LEFT JOIN user_roles ur ON ur.user_id = u.id"#;

const USER_BY_ID_QUERY: &str = r#"SELECT u.id, u.email_normalized, u.password_hash,
    u.display_name, u.status, u.locale, u.timezone,
    COALESCE(array_agg(ur.role ORDER BY ur.role) FILTER (WHERE ur.role IS NOT NULL), ARRAY[]::text[]) AS roles
    FROM users u LEFT JOIN user_roles ur ON ur.user_id = u.id
    WHERE u.id = $1 GROUP BY u.id"#;

async fn find_user(
    pool: &PgPool,
    _condition: &str,
    email: &str,
) -> Result<Option<User>, RepositoryError> {
    let query = format!("{USER_SELECT} WHERE u.email_normalized = $1 GROUP BY u.id");
    let row = sqlx::query_as::<_, UserRow>(&query)
        .bind(email)
        .fetch_optional(pool)
        .await
        .map_err(db_error)?;
    row.map(TryInto::try_into).transpose()
}

async fn fetch_user_by_id(
    transaction: &mut Transaction<'_, Postgres>,
    user_id: Uuid,
) -> Result<User, RepositoryError> {
    let row = sqlx::query_as::<_, UserRow>(USER_BY_ID_QUERY)
        .bind(user_id)
        .fetch_optional(&mut **transaction)
        .await
        .map_err(db_error)?
        .ok_or(RepositoryError::Internal)?;
    row.try_into()
}

async fn revoke_family(
    transaction: &mut Transaction<'_, Postgres>,
    family_id: Uuid,
    now: DateTime<Utc>,
) -> Result<(), RepositoryError> {
    sqlx::query(
        "UPDATE refresh_sessions SET revoked_at = COALESCE(revoked_at, $2) WHERE family_id = $1",
    )
    .bind(family_id)
    .bind(now)
    .execute(&mut **transaction)
    .await
    .map_err(db_error)?;
    Ok(())
}

fn db_error(_error: sqlx::Error) -> RepositoryError {
    RepositoryError::Internal
}

#[cfg(test)]
mod tests {
    use super::{JwtTokenService, TokenProvider};
    use crate::modules::identity::domain::{Role, User, UserStatus};
    use uuid::Uuid;

    fn token_service() -> JwtTokenService {
        JwtTokenService::new(
            b"a-development-secret-with-more-than-32-bytes",
            "test-issuer".to_string(),
            "test-audience".to_string(),
            900,
            2_592_000,
        )
        .unwrap()
    }

    #[test]
    fn hashes_password_with_argon2id_and_verifies_it() {
        let tokens = token_service();
        let hash = tokens.hash_password("strong-password").unwrap();

        assert!(hash.starts_with("$argon2id$"));
        assert!(tokens.verify_password("strong-password", &hash).unwrap());
        assert!(!tokens.verify_password("wrong-password", &hash).unwrap());
    }

    #[test]
    fn access_token_round_trips_subject_and_refresh_token_is_opaque() {
        let tokens = token_service();
        let user_id = Uuid::new_v4();
        let user = User {
            id: user_id,
            email_normalized: "user@example.com".to_string(),
            password_hash: "not-used".to_string(),
            display_name: "Nguyễn An".to_string(),
            status: UserStatus::Active,
            locale: "vi".to_string(),
            timezone: "Asia/Ho_Chi_Minh".to_string(),
            roles: vec![Role::Patient],
        };

        let access_token = tokens.issue_access_token(&user).unwrap();
        assert_eq!(
            tokens.validate_access_token(&access_token).unwrap(),
            user_id
        );

        let refresh = tokens.issue_refresh_token(None).unwrap();
        assert_ne!(
            refresh.raw.as_bytes(),
            refresh.session.token_hash.as_slice()
        );
        assert_eq!(refresh.session.token_hash.len(), 32);
    }
}
