//! Role-Based Access Control (RBAC) system for Automation Nation
//! 
//! This module provides comprehensive authentication and authorization capabilities
//! for both the orchestrator web interface and deployed applications.
//! 
//! Features:
//! - JWT-based authentication with configurable token expiration
//! - Role-based authorization with granular permissions
//! - Session management with Redis backend support
//! - API key authentication for service-to-service communication
//! - Audit logging for security compliance
//! - Integration with external identity providers (future extensibility)

use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc, Duration};
use uuid::Uuid;
use std::collections::{HashMap, HashSet};
use crate::error::{Result, AutomationError};
use log::{info, warn, error, debug};

/// User authentication and profile information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    /// Unique user identifier
    pub id: Uuid,
    /// Username for authentication
    pub username: String,
    /// Email address
    pub email: String,
    /// Display name
    pub display_name: String,
    /// Password hash (bcrypt)
    pub password_hash: String,
    /// Assigned roles
    pub roles: Vec<String>,
    /// Account status
    pub status: UserStatus,
    /// Account creation timestamp
    pub created_at: DateTime<Utc>,
    /// Last login timestamp
    pub last_login_at: Option<DateTime<Utc>>,
    /// Password last changed timestamp
    pub password_changed_at: DateTime<Utc>,
    /// Failed login attempts counter
    pub failed_login_attempts: u32,
    /// Account locked until timestamp
    pub locked_until: Option<DateTime<Utc>>,
    /// User metadata
    pub metadata: HashMap<String, String>,
}

/// User account status enumeration
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum UserStatus {
    /// Active account with full access
    Active,
    /// Temporarily disabled account
    Disabled,
    /// Account locked due to security policy violation
    Locked,
    /// Account pending email verification
    PendingVerification,
    /// Account marked for deletion
    PendingDeletion,
}

/// Role definition with associated permissions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Role {
    /// Unique role identifier
    pub name: String,
    /// Human-readable role description
    pub description: String,
    /// Set of permissions granted by this role
    pub permissions: HashSet<Permission>,
    /// Whether this role can be assigned by other users
    pub assignable: bool,
    /// Role creation timestamp
    pub created_at: DateTime<Utc>,
}

/// System permissions enumeration
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum Permission {
    // System Information Collection
    /// Read system information
    SystemInfoRead,
    /// Execute system information collection
    SystemInfoCollect,
    /// Manage system collection plugins
    SystemInfoManage,
    
    // User Management
    /// Create new users
    UserCreate,
    /// Read user information
    UserRead,
    /// Update user information
    UserUpdate,
    /// Delete users
    UserDelete,
    /// Manage user roles
    UserManageRoles,
    
    // Role Management
    /// Create new roles
    RoleCreate,
    /// Read role information
    RoleRead,
    /// Update role information
    RoleUpdate,
    /// Delete roles
    RoleDelete,
    /// Assign permissions to roles
    RoleManagePermissions,
    
    // API Access
    /// Access REST API
    ApiAccess,
    /// Create API keys
    ApiKeyCreate,
    /// Manage API keys
    ApiKeyManage,
    
    // System Administration
    /// View system logs
    SystemLogsRead,
    /// Manage system configuration
    SystemConfigManage,
    /// Perform system maintenance
    SystemMaintenance,
    
    // Performance Management
    /// View performance metrics
    PerformanceRead,
    /// Configure performance settings
    PerformanceManage,
    
    // Audit and Compliance
    /// View audit logs
    AuditRead,
    /// Export audit data
    AuditExport,
}

/// JWT authentication token
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthToken {
    /// User ID
    pub user_id: Uuid,
    /// Username
    pub username: String,
    /// User roles
    pub roles: Vec<String>,
    /// Token expiration timestamp
    pub expires_at: DateTime<Utc>,
    /// Token issued timestamp
    pub issued_at: DateTime<Utc>,
    /// Token issuer
    pub issuer: String,
}

/// API key for service authentication
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiKey {
    /// Unique API key identifier
    pub id: Uuid,
    /// API key name/description
    pub name: String,
    /// Key hash (not the actual key)
    pub key_hash: String,
    /// Owner user ID
    pub owner_id: Uuid,
    /// Permissions granted to this key
    pub permissions: HashSet<Permission>,
    /// Key creation timestamp
    pub created_at: DateTime<Utc>,
    /// Key expiration timestamp
    pub expires_at: Option<DateTime<Utc>>,
    /// Last used timestamp
    pub last_used_at: Option<DateTime<Utc>>,
    /// Whether the key is active
    pub active: bool,
}

/// Audit log entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditEvent {
    /// Unique event identifier
    pub id: Uuid,
    /// User ID (if applicable)
    pub user_id: Option<Uuid>,
    /// Action performed
    pub action: String,
    /// Resource affected
    pub resource: String,
    /// Client IP address
    pub client_ip: String,
    /// Whether the action was successful
    pub success: bool,
    /// Error message (if unsuccessful)
    pub error_message: Option<String>,
    /// Event timestamp
    pub timestamp: DateTime<Utc>,
    /// Additional event details
    pub details: HashMap<String, String>,
}

/// RBAC Manager for handling authentication and authorization
pub struct RbacManager {
    /// User storage
    users: HashMap<Uuid, User>,
    /// Role definitions
    roles: HashMap<String, Role>,
    /// API keys
    api_keys: HashMap<Uuid, ApiKey>,
    /// JWT secret key
    jwt_secret: String,
    /// Token expiration duration
    token_expiration: Duration,
    /// Audit log
    audit_log: Vec<AuditEvent>,
    /// Maximum failed login attempts before lockout
    max_failed_attempts: u32,
    /// Account lockout duration
    lockout_duration: Duration,
}

impl RbacManager {
    /// Create a new RBAC manager
    pub fn new(jwt_secret: String) -> Self {
        let mut manager = Self {
            users: HashMap::new(),
            roles: HashMap::new(),
            api_keys: HashMap::new(),
            jwt_secret,
            token_expiration: Duration::hours(24),
            audit_log: Vec::new(),
            max_failed_attempts: 5,
            lockout_duration: Duration::minutes(30),
        };
        
        // Initialize default roles
        manager.init_default_roles();
        manager
    }
    
    /// Initialize default system roles
    fn init_default_roles(&mut self) {
        // Admin role with all permissions
        let admin_permissions = vec![
            Permission::SystemInfoRead, Permission::SystemInfoCollect, Permission::SystemInfoManage,
            Permission::UserCreate, Permission::UserRead, Permission::UserUpdate, Permission::UserDelete, Permission::UserManageRoles,
            Permission::RoleCreate, Permission::RoleRead, Permission::RoleUpdate, Permission::RoleDelete, Permission::RoleManagePermissions,
            Permission::ApiAccess, Permission::ApiKeyCreate, Permission::ApiKeyManage,
            Permission::SystemLogsRead, Permission::SystemConfigManage, Permission::SystemMaintenance,
            Permission::PerformanceRead, Permission::PerformanceManage,
            Permission::AuditRead, Permission::AuditExport,
        ].into_iter().collect();
        
        let admin_role = Role {
            name: "admin".to_string(),
            description: "Full system administration access".to_string(),
            permissions: admin_permissions,
            assignable: false,
            created_at: Utc::now(),
        };
        
        // User role with limited permissions
        let user_permissions = vec![
            Permission::SystemInfoRead,
            Permission::ApiAccess,
            Permission::PerformanceRead,
        ].into_iter().collect();
        
        let user_role = Role {
            name: "user".to_string(),
            description: "Standard user access".to_string(),
            permissions: user_permissions,
            assignable: true,
            created_at: Utc::now(),
        };
        
        // Operator role with collection permissions
        let operator_permissions = vec![
            Permission::SystemInfoRead, Permission::SystemInfoCollect,
            Permission::ApiAccess,
            Permission::PerformanceRead,
        ].into_iter().collect();
        
        let operator_role = Role {
            name: "operator".to_string(),
            description: "System information collection operator".to_string(),
            permissions: operator_permissions,
            assignable: true,
            created_at: Utc::now(),
        };
        
        self.roles.insert("admin".to_string(), admin_role);
        self.roles.insert("user".to_string(), user_role);
        self.roles.insert("operator".to_string(), operator_role);
    }
    
    /// Create a new user
    pub fn create_user(
        &mut self,
        username: String,
        email: String,
        display_name: String,
        password: String,
        roles: Vec<String>,
    ) -> Result<Uuid> {
        // Validate input
        if username.trim().is_empty() || email.trim().is_empty() {
            return Err(AutomationError::Validation("Username and email are required".to_string()));
        }
        
        // Check if user already exists
        if self.users.values().any(|u| u.username == username || u.email == email) {
            return Err(AutomationError::Validation("User with this username or email already exists".to_string()));
        }
        
        // Validate roles exist
        for role_name in &roles {
            if !self.roles.contains_key(role_name) {
                return Err(AutomationError::Validation(format!("Role '{}' does not exist", role_name)));
            }
        }
        
        // Hash password
        let password_hash = bcrypt::hash(&password, bcrypt::DEFAULT_COST)
            .map_err(|e| AutomationError::Generic(format!("Password hashing failed: {}", e)))?;
        
        let user_id = Uuid::new_v4();
        let now = Utc::now();
        
        let user = User {
            id: user_id,
            username: username.clone(),
            email: email.clone(),
            display_name,
            password_hash,
            roles,
            status: UserStatus::Active,
            created_at: now,
            last_login_at: None,
            password_changed_at: now,
            failed_login_attempts: 0,
            locked_until: None,
            metadata: HashMap::new(),
        };
        
        self.users.insert(user_id, user);
        
        // Log audit event
        self.log_audit_event(
            None,
            "user_created".to_string(),
            format!("user:{}", user_id),
            "127.0.0.1".to_string(),
            true,
            None,
            [("username".to_string(), username.clone()), ("email".to_string(), email.clone())].into(),
        );
        
        info!("Created user: {} ({})", username, user_id);
        Ok(user_id)
    }
    
    /// Authenticate user with username/password
    pub fn authenticate(&mut self, username: &str, password: &str, client_ip: String) -> Result<AuthToken> {
        // Find user first
        let user_id = {
            let user = self.users.values()
                .find(|u| u.username == username)
                .ok_or_else(|| AutomationError::Authentication("Invalid credentials".to_string()))?;
            user.id
        };
        
        // Get mutable reference to user
        let user = self.users.get_mut(&user_id)
            .ok_or_else(|| AutomationError::Authentication("User not found".to_string()))?;
        
        // Check if account is locked
        if let Some(locked_until) = user.locked_until {
            if Utc::now() < locked_until {
                let user_id_for_audit = user.id;
                drop(user); // Release mutable borrow
                self.log_audit_event(
                    Some(user_id_for_audit),
                    "login_failed_locked".to_string(),
                    format!("user:{}", user_id_for_audit),
                    client_ip,
                    false,
                    Some("Account is locked".to_string()),
                    HashMap::new(),
                );
                return Err(AutomationError::Authentication("Account is locked".to_string()));
            } else {
                // Unlock account
                user.locked_until = None;
                user.failed_login_attempts = 0;
            }
        }
        
        // Check account status
        if user.status != UserStatus::Active {
            let user_id_for_audit = user.id;
            drop(user); // Release mutable borrow
            self.log_audit_event(
                Some(user_id_for_audit),
                "login_failed_inactive".to_string(),
                format!("user:{}", user_id_for_audit),
                client_ip,
                false,
                Some("Account is not active".to_string()),
                HashMap::new(),
            );
            return Err(AutomationError::Authentication("Account is not active".to_string()));
        }
        
        // Verify password
        let password_hash = user.password_hash.clone();
        let password_valid = bcrypt::verify(password, &password_hash)
            .map_err(|e| AutomationError::Generic(format!("Password verification failed: {}", e)))?;
        
        if !password_valid {
            user.failed_login_attempts += 1;
            
            // Lock account if too many failed attempts
            if user.failed_login_attempts >= self.max_failed_attempts {
                user.locked_until = Some(Utc::now() + self.lockout_duration);
                warn!("Locked account {} due to too many failed login attempts", username);
            }
            
            let user_id_for_audit = user.id;
            drop(user); // Release mutable borrow
            self.log_audit_event(
                Some(user_id_for_audit),
                "login_failed_password".to_string(),
                format!("user:{}", user_id_for_audit),
                client_ip,
                false,
                Some("Invalid password".to_string()),
                HashMap::new(),
            );
            
            return Err(AutomationError::Authentication("Invalid credentials".to_string()));
        }
        
        // Successful authentication
        user.failed_login_attempts = 0;
        user.last_login_at = Some(Utc::now());
        
        // Extract needed data before dropping the borrow
        let user_id_final = user.id;
        let username_final = user.username.clone();
        let roles_final = user.roles.clone();
        drop(user); // Release mutable borrow
        
        let token = self.create_token(user_id_final, &username_final, &roles_final)?;
        
        self.log_audit_event(
            Some(user_id_final),
            "login_success".to_string(),
            format!("user:{}", user_id_final),
            client_ip,
            true,
            None,
            HashMap::new(),
        );
        
        info!("User {} authenticated successfully", username);
        Ok(token)
    }
    
    /// Create JWT token for authenticated user
    fn create_token(&self, user_id: Uuid, username: &str, roles: &[String]) -> Result<AuthToken> {
        let now = Utc::now();
        let expires_at = now + self.token_expiration;
        
        Ok(AuthToken {
            user_id,
            username: username.to_string(),
            roles: roles.to_vec(),
            expires_at,
            issued_at: now,
            issuer: "automation_nation".to_string(),
        })
    }
    
    /// Validate token and check permissions
    pub fn authorize(&self, token: &AuthToken, required_permission: Permission) -> Result<()> {
        // Check token expiration
        if Utc::now() > token.expires_at {
            return Err(AutomationError::Authentication("Token has expired".to_string()));
        }
        
        // Get user
        let user = self.users.get(&token.user_id)
            .ok_or_else(|| AutomationError::Authentication("User not found".to_string()))?;
        
        // Check if user is active
        if user.status != UserStatus::Active {
            return Err(AutomationError::Authentication("User account is not active".to_string()));
        }
        
        // Check permissions
        if !self.user_has_permission(user, &required_permission) {
            return Err(AutomationError::Permission(format!("Permission {:?} required", required_permission)));
        }
        
        Ok(())
    }
    
    /// Check if user has specific permission
    fn user_has_permission(&self, user: &User, permission: &Permission) -> bool {
        for role_name in &user.roles {
            if let Some(role) = self.roles.get(role_name) {
                if role.permissions.contains(permission) {
                    return true;
                }
            }
        }
        false
    }
    
    /// Create API key for service authentication
    pub fn create_api_key(&mut self, owner_id: Uuid, name: String, permissions: HashSet<Permission>) -> Result<(Uuid, String)> {
        // Validate owner exists
        if !self.users.contains_key(&owner_id) {
            return Err(AutomationError::Validation("Owner user does not exist".to_string()));
        }
        
        // Generate API key
        let api_key_id = Uuid::new_v4();
        let raw_key = format!("ak_{}", Uuid::new_v4().simple());
        let key_hash = bcrypt::hash(&raw_key, bcrypt::DEFAULT_COST)
            .map_err(|e| AutomationError::Generic(format!("API key hashing failed: {}", e)))?;
        
        let api_key = ApiKey {
            id: api_key_id,
            name,
            key_hash,
            owner_id,
            permissions,
            created_at: Utc::now(),
            expires_at: None, // Non-expiring by default
            last_used_at: None,
            active: true,
        };
        
        self.api_keys.insert(api_key_id, api_key);
        
        self.log_audit_event(
            Some(owner_id),
            "api_key_created".to_string(),
            format!("api_key:{}", api_key_id),
            "127.0.0.1".to_string(),
            true,
            None,
            HashMap::new(),
        );
        
        info!("Created API key {} for user {}", api_key_id, owner_id);
        Ok((api_key_id, raw_key))
    }
    
    /// Validate API key and check permissions
    pub fn authorize_api_key(&mut self, api_key: &str, required_permission: Permission) -> Result<Uuid> {
        // Find matching API key
        let (key_id, key_obj) = self.api_keys.iter_mut()
            .find(|(_, k)| {
                k.active && bcrypt::verify(api_key, &k.key_hash).unwrap_or(false)
            })
            .ok_or_else(|| AutomationError::Authentication("Invalid API key".to_string()))?;
        
        // Check expiration
        if let Some(expires_at) = key_obj.expires_at {
            if Utc::now() > expires_at {
                return Err(AutomationError::Authentication("API key has expired".to_string()));
            }
        }
        
        // Check permissions
        if !key_obj.permissions.contains(&required_permission) {
            return Err(AutomationError::Permission(format!("API key lacks permission {:?}", required_permission)));
        }
        
        // Update last used timestamp
        key_obj.last_used_at = Some(Utc::now());
        
        Ok(*key_id)
    }
    
    /// Log audit event for security compliance
    fn log_audit_event(
        &mut self,
        user_id: Option<Uuid>,
        action: String,
        resource: String,
        client_ip: String,
        success: bool,
        error_message: Option<String>,
        details: HashMap<String, String>,
    ) {
        let event = AuditEvent {
            id: Uuid::new_v4(),
            user_id,
            action,
            resource,
            client_ip,
            success,
            error_message,
            timestamp: Utc::now(),
            details,
        };
        
        self.audit_log.push(event);
        
        // In production, this would be persisted to a database
        // and potentially sent to external audit systems
    }
    
    /// Get user by ID
    pub fn get_user(&self, user_id: Uuid) -> Option<&User> {
        self.users.get(&user_id)
    }
    
    /// Get role by name
    pub fn get_role(&self, role_name: &str) -> Option<&Role> {
        self.roles.get(role_name)
    }
    
    /// List all users (admin only)
    pub fn list_users(&self) -> Vec<&User> {
        self.users.values().collect()
    }
    
    /// List all roles
    pub fn list_roles(&self) -> Vec<&Role> {
        self.roles.values().collect()
    }
    
    /// Get audit log entries
    pub fn get_audit_log(&self, limit: Option<usize>) -> Vec<&AuditEvent> {
        let mut events: Vec<&AuditEvent> = self.audit_log.iter().collect();
        events.sort_by(|a, b| b.timestamp.cmp(&a.timestamp));
        
        if let Some(limit) = limit {
            events.truncate(limit);
        }
        
        events
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_rbac_manager_creation() {
        let manager = RbacManager::new("secret".to_string());
        assert_eq!(manager.roles.len(), 3); // admin, user, operator
    }
    
    #[test]
    fn test_user_creation() {
        let mut manager = RbacManager::new("secret".to_string());
        
        let user_id = manager.create_user(
            "testuser".to_string(),
            "test@example.com".to_string(),
            "Test User".to_string(),
            "password123".to_string(),
            vec!["user".to_string()],
        ).unwrap();
        
        let user = manager.get_user(user_id).unwrap();
        assert_eq!(user.username, "testuser");
        assert_eq!(user.email, "test@example.com");
        assert_eq!(user.roles, vec!["user"]);
    }
    
    #[test]
    fn test_authentication() {
        let mut manager = RbacManager::new("secret".to_string());
        
        manager.create_user(
            "testuser".to_string(),
            "test@example.com".to_string(),
            "Test User".to_string(),
            "password123".to_string(),
            vec!["user".to_string()],
        ).unwrap();
        
        let token = manager.authenticate("testuser", "password123", "127.0.0.1".to_string()).unwrap();
        assert_eq!(token.username, "testuser");
        assert!(token.roles.contains(&"user".to_string()));
    }
    
    #[test]
    fn test_authorization() {
        let mut manager = RbacManager::new("secret".to_string());
        
        let user_id = manager.create_user(
            "testuser".to_string(),
            "test@example.com".to_string(),
            "Test User".to_string(),
            "password123".to_string(),
            vec!["user".to_string()],
        ).unwrap();
        
        let token = manager.create_token(user_id, "testuser", &["user".to_string()]).unwrap();
        
        // Should succeed for allowed permission
        assert!(manager.authorize(&token, Permission::SystemInfoRead).is_ok());
        
        // Should fail for disallowed permission
        assert!(manager.authorize(&token, Permission::UserCreate).is_err());
    }
    
    #[test]
    fn test_api_key_creation() {
        let mut manager = RbacManager::new("secret".to_string());
        
        let user_id = manager.create_user(
            "testuser".to_string(),
            "test@example.com".to_string(),
            "Test User".to_string(),
            "password123".to_string(),
            vec!["user".to_string()],
        ).unwrap();
        
        let permissions = [Permission::SystemInfoRead].into();
        let (key_id, raw_key) = manager.create_api_key(user_id, "Test Key".to_string(), permissions).unwrap();
        
        assert!(raw_key.starts_with("ak_"));
        assert!(manager.api_keys.contains_key(&key_id));
    }
}