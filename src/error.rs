//! Error types for Automation Nation

use std::fmt;

/// Main error type for Automation Nation
#[derive(Debug)]
pub enum AutomationError {
    /// Authentication/authorization errors
    Authentication(String),
    /// Permission denied errors
    Permission(String),
    /// Database operation errors
    Database(String),
    /// System operation errors
    System(String),
    /// Configuration errors
    Configuration(String),
    /// Validation errors
    Validation(String),
    /// Generic errors
    Generic(String),
}

impl fmt::Display for AutomationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AutomationError::Authentication(msg) => write!(f, "Authentication error: {}", msg),
            AutomationError::Permission(msg) => write!(f, "Permission denied: {}", msg),
            AutomationError::Database(msg) => write!(f, "Database error: {}", msg),
            AutomationError::System(msg) => write!(f, "System error: {}", msg),
            AutomationError::Configuration(msg) => write!(f, "Configuration error: {}", msg),
            AutomationError::Validation(msg) => write!(f, "Validation error: {}", msg),
            AutomationError::Generic(msg) => write!(f, "Error: {}", msg),
        }
    }
}

impl std::error::Error for AutomationError {}

/// Result type alias for convenience
pub type Result<T> = std::result::Result<T, AutomationError>;

impl From<anyhow::Error> for AutomationError {
    fn from(err: anyhow::Error) -> Self {
        AutomationError::Generic(err.to_string())
    }
}

impl From<serde_json::Error> for AutomationError {
    fn from(err: serde_json::Error) -> Self {
        AutomationError::Validation(format!("JSON error: {}", err))
    }
}