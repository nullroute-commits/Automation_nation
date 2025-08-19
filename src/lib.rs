//! Automation Nation - Enterprise-grade automation platform
//!
//! This library provides comprehensive automation capabilities including:
//! - Role-based access control (RBAC) with user management
//! - High-performance system information collection
//! - Container orchestration and deployment
//! - Real-time performance monitoring and optimization

pub mod rbac;
pub mod performance_optimizer;
pub mod system_profiler;
pub mod types;
pub mod error;

// Re-export commonly used types
pub use rbac::{RbacManager, User, Role, Permission};
pub use performance_optimizer::PerformanceOptimizer;
pub use system_profiler::SystemProfiler;
pub use types::*;
pub use error::{Result, AutomationError};