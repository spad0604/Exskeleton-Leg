use std::collections::HashMap;
use tokio::sync::RwLock;

use crate::models::user::User;

pub struct UserRepository {
    users: RwLock<HashMap<String, User>>,
}

impl UserRepository {
    pub fn new() -> Self {
        Self {
            users: RwLock::new(HashMap::new()),
        }
    }

    pub async fn find_by_email(&self, email: &str) -> Option<User> {
        let users = self.users.read().await;
        users.get(email).cloned()
    }

    pub async fn create(&self, user: User) {
        let mut users = self.users.write().await;
        users.insert(user.email.clone(), user);
    }
}
