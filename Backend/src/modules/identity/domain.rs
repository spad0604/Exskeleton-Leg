use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Role {
    Patient,
    Caregiver,
    Clinician,
    Admin,
}

impl Role {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Patient => "patient",
            Self::Caregiver => "caregiver",
            Self::Clinician => "clinician",
            Self::Admin => "admin",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "patient" => Some(Self::Patient),
            "caregiver" => Some(Self::Caregiver),
            "clinician" => Some(Self::Clinician),
            "admin" => Some(Self::Admin),
            _ => None,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum UserStatus {
    Active,
    Locked,
    Deactivated,
}

impl UserStatus {
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "active" => Some(Self::Active),
            "locked" => Some(Self::Locked),
            "deactivated" => Some(Self::Deactivated),
            _ => None,
        }
    }
}

#[derive(Clone, Debug)]
pub struct User {
    pub id: Uuid,
    pub email_normalized: String,
    pub password_hash: String,
    pub display_name: String,
    pub status: UserStatus,
    pub locale: String,
    pub timezone: String,
    pub roles: Vec<Role>,
}

#[derive(Clone, Debug)]
pub struct NewUser {
    pub id: Uuid,
    pub email_normalized: String,
    pub password_hash: String,
    pub display_name: String,
    pub locale: String,
    pub timezone: String,
    pub accepted_terms_version: String,
}

#[derive(Clone, Debug)]
pub struct NewRefreshSession {
    pub id: Uuid,
    pub token_hash: Vec<u8>,
    pub device_label: Option<String>,
    pub expires_at: DateTime<Utc>,
}
