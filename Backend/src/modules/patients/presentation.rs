use axum::{
    Json, Router,
    extract::{Path, State},
    http::{HeaderMap, header},
    routing::get,
};
use chrono::Utc;
use serde::Serialize;
use uuid::Uuid;

use crate::{
    bootstrap::AppState,
    modules::identity::application::{IdentityError, MeOutput},
    shared::presentation::{ApiError, ApiResponse, ApiResult},
};

pub fn routes() -> Router<AppState> {
    Router::new().route("/patients/{patient_id}/home", get(patient_home))
}

async fn patient_home(
    State(state): State<AppState>,
    Path(patient_id): Path<Uuid>,
    headers: HeaderMap,
) -> ApiResult<Json<ApiResponse<PatientHomeOutput>>> {
    let token = bearer_token(&headers)?;
    let me = state.auth.me(token).await.map_err(map_identity_error)?;
    if me.id != patient_id {
        return Err(ApiError::forbidden("Bạn không có quyền xem hồ sơ này."));
    }

    Ok(Json(ApiResponse::new(PatientHomeOutput::for_patient(me))))
}

#[derive(Debug, Serialize)]
struct PatientHomeOutput {
    patient: PatientSummary,
    device: Option<HomeDevice>,
    next_plan_item: Option<NextPlanItem>,
    today_metrics: TodayMetrics,
    open_alerts: Vec<HomeAlert>,
    recent_session: Option<RecentSession>,
}

impl PatientHomeOutput {
    fn for_patient(me: MeOutput) -> Self {
        Self {
            patient: PatientSummary {
                id: me.id,
                display_name: me.display_name,
                timezone: me.timezone,
            },
            device: Some(HomeDevice {
                id: Uuid::new_v4(),
                serial_number: "EXO-2026-000123",
                online: true,
                battery_percent: 78,
                last_seen_at: Utc::now(),
                readiness: Readiness {
                    state: "ready",
                    blocking_reasons: Vec::new(),
                },
            }),
            next_plan_item: Some(NextPlanItem {
                id: Uuid::new_v4(),
                exercise_id: Uuid::new_v4(),
                exercise_name: "Đứng lên và ngồi xuống",
                target: ExerciseTarget {
                    kind: "repetitions",
                    sets: 2,
                    repetitions_per_set: 8,
                },
                assistance_level: "low",
                estimated_duration_seconds: 600,
            }),
            today_metrics: TodayMetrics {
                planned_count: 2,
                completed_count: 1,
                active_seconds: 420,
                correctness_ratio: Some(0.82),
            },
            open_alerts: vec![HomeAlert {
                id: Uuid::new_v4(),
                severity: "warning",
                title: "Hiệu chỉnh sẽ hết hạn trong 3 ngày.",
                occurred_at: Utc::now(),
            }],
            recent_session: None,
        }
    }
}

#[derive(Debug, Serialize)]
struct PatientSummary {
    id: Uuid,
    display_name: String,
    timezone: String,
}

#[derive(Debug, Serialize)]
struct HomeDevice {
    id: Uuid,
    serial_number: &'static str,
    online: bool,
    battery_percent: u8,
    last_seen_at: chrono::DateTime<Utc>,
    readiness: Readiness,
}

#[derive(Debug, Serialize)]
struct Readiness {
    state: &'static str,
    blocking_reasons: Vec<&'static str>,
}

#[derive(Debug, Serialize)]
struct NextPlanItem {
    id: Uuid,
    exercise_id: Uuid,
    exercise_name: &'static str,
    target: ExerciseTarget,
    assistance_level: &'static str,
    estimated_duration_seconds: u32,
}

#[derive(Debug, Serialize)]
struct ExerciseTarget {
    kind: &'static str,
    sets: u8,
    repetitions_per_set: u8,
}

#[derive(Debug, Serialize)]
struct TodayMetrics {
    planned_count: u8,
    completed_count: u8,
    active_seconds: u32,
    correctness_ratio: Option<f32>,
}

#[derive(Debug, Serialize)]
struct HomeAlert {
    id: Uuid,
    severity: &'static str,
    title: &'static str,
    occurred_at: chrono::DateTime<Utc>,
}

#[derive(Debug, Serialize)]
struct RecentSession {}

fn bearer_token(headers: &HeaderMap) -> ApiResult<&str> {
    let value = headers
        .get(header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .ok_or_else(|| {
            ApiError::unauthorized("auth.invalid_token", "Phiên đăng nhập không hợp lệ.")
        })?;
    value
        .strip_prefix("Bearer ")
        .filter(|token| !token.is_empty())
        .ok_or_else(|| {
            ApiError::unauthorized("auth.invalid_token", "Phiên đăng nhập không hợp lệ.")
        })
}

fn map_identity_error(error: IdentityError) -> ApiError {
    match error {
        IdentityError::InvalidAccessToken => ApiError::unauthorized(
            "auth.invalid_token",
            "Phiên đăng nhập không hợp lệ hoặc đã hết hạn.",
        ),
        IdentityError::AccountUnavailable => {
            ApiError::forbidden("Tài khoản hiện không thể sử dụng.")
        }
        _ => ApiError::internal("identity service"),
    }
}
