use serde::Serialize;
use serde_repr::Serialize_repr;

#[derive(Serialize_repr, Debug, Clone, Copy)]
#[repr(u8)]
pub enum ResponseStatus {
    Failure = 0,
    Success = 1,
}

#[derive(Serialize, Debug, Clone)]
pub struct BaseResponse<T> {
    pub status: ResponseStatus,
    pub message: String,
    pub data: Option<T>,
}

impl<T> BaseResponse<T> {
    pub fn success(message: impl Into<String>, data: T) -> Self {
        Self {
            status: ResponseStatus::Success,
            message: message.into(),
            data: Some(data),
        }
    }

    pub fn failure(message: impl Into<String>) -> Self {
        Self {
            status: ResponseStatus::Failure,
            message: message.into(),
            data: None,
        }
    }
}
