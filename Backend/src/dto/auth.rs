use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::NaiveDate;

#[derive(Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
    pub full_name: String,
    pub dob: NaiveDate
}

#[derive(Deserialize)]
pub struct RegisterResponse {
    pub id: Uuid,
    pub email: String,
    pub full_name: String
}