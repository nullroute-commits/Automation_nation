//! User management CLI for Automation Nation
//!
//! This binary provides command-line user management capabilities

use automation_nation::{RbacManager, Permission};
use clap::{Parser, Subcommand};
use uuid::Uuid;
use std::collections::HashSet;
use log::info;

#[derive(Parser)]
#[command(name = "user_manager")]
#[command(about = "Automation Nation User Management CLI")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
    
    /// JWT secret key
    #[arg(long, default_value = "your-secret-key-change-in-production")]
    jwt_secret: String,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a new user
    CreateUser {
        /// Username
        #[arg(short, long)]
        username: String,
        /// Email address
        #[arg(short, long)]
        email: String,
        /// Display name
        #[arg(short, long)]
        display_name: String,
        /// Password
        #[arg(short, long)]
        password: String,
        /// Roles (comma-separated)
        #[arg(short, long, default_value = "user")]
        roles: String,
    },
    /// List all users
    ListUsers,
    /// List all roles
    ListRoles,
    /// Create an API key
    CreateApiKey {
        /// User ID to create key for
        #[arg(short, long)]
        user_id: String,
        /// Key name/description
        #[arg(short, long)]
        name: String,
        /// Permissions (comma-separated)
        #[arg(short, long, default_value = "SystemInfoRead,ApiAccess")]
        permissions: String,
    },
    /// Authenticate user
    Auth {
        /// Username
        #[arg(short, long)]
        username: String,
        /// Password
        #[arg(short, long)]
        password: String,
    },
}

#[tokio::main]
async fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    
    let cli = Cli::parse();
    let mut rbac_manager = RbacManager::new(cli.jwt_secret);
    
    match cli.command {
        Commands::CreateUser { username, email, display_name, password, roles } => {
            let roles_vec: Vec<String> = roles.split(',').map(|s| s.trim().to_string()).collect();
            
            match rbac_manager.create_user(username.clone(), email, display_name, password, roles_vec) {
                Ok(user_id) => {
                    println!("✅ User created successfully!");
                    println!("   User ID: {}", user_id);
                    println!("   Username: {}", username);
                }
                Err(e) => {
                    eprintln!("❌ Failed to create user: {}", e);
                    std::process::exit(1);
                }
            }
        }
        
        Commands::ListUsers => {
            let users = rbac_manager.list_users();
            
            if users.is_empty() {
                println!("No users found.");
                return;
            }
            
            println!("📋 Users:");
            println!("{:<36} {:<20} {:<30} {:<15} {:<20}", "ID", "Username", "Email", "Status", "Roles");
            println!("{}", "─".repeat(130));
            
            for user in users {
                println!(
                    "{:<36} {:<20} {:<30} {:<15} {:<20}",
                    user.id,
                    user.username,
                    user.email,
                    format!("{:?}", user.status),
                    user.roles.join(", ")
                );
            }
        }
        
        Commands::ListRoles => {
            let roles = rbac_manager.list_roles();
            
            if roles.is_empty() {
                println!("No roles found.");
                return;
            }
            
            println!("🔐 Roles:");
            
            for role in roles {
                println!("\n📝 Role: {}", role.name);
                println!("   Description: {}", role.description);
                println!("   Assignable: {}", role.assignable);
                println!("   Permissions:");
                for permission in &role.permissions {
                    println!("     • {:?}", permission);
                }
            }
        }
        
        Commands::CreateApiKey { user_id, name, permissions } => {
            let user_uuid = Uuid::parse_str(&user_id)
                .unwrap_or_else(|_| {
                    eprintln!("❌ Invalid user ID format");
                    std::process::exit(1);
                });
            
            let permissions_set: HashSet<Permission> = permissions
                .split(',')
                .filter_map(|s| {
                    let perm_str = s.trim();
                    match perm_str {
                        "SystemInfoRead" => Some(Permission::SystemInfoRead),
                        "SystemInfoCollect" => Some(Permission::SystemInfoCollect),
                        "SystemInfoManage" => Some(Permission::SystemInfoManage),
                        "ApiAccess" => Some(Permission::ApiAccess),
                        "UserRead" => Some(Permission::UserRead),
                        "PerformanceRead" => Some(Permission::PerformanceRead),
                        _ => {
                            eprintln!("⚠️  Unknown permission: {}", perm_str);
                            None
                        }
                    }
                })
                .collect();
            
            if permissions_set.is_empty() {
                eprintln!("❌ No valid permissions provided");
                std::process::exit(1);
            }
            
            match rbac_manager.create_api_key(user_uuid, name.clone(), permissions_set) {
                Ok((key_id, api_key)) => {
                    println!("✅ API Key created successfully!");
                    println!("   Key ID: {}", key_id);
                    println!("   Key Name: {}", name);
                    println!("   API Key: {}", api_key);
                    println!("\n⚠️  IMPORTANT: Save this API key securely. It will not be shown again.");
                }
                Err(e) => {
                    eprintln!("❌ Failed to create API key: {}", e);
                    std::process::exit(1);
                }
            }
        }
        
        Commands::Auth { username, password } => {
            match rbac_manager.authenticate(&username, &password, "127.0.0.1".to_string()) {
                Ok(token) => {
                    println!("✅ Authentication successful!");
                    println!("   User ID: {}", token.user_id);
                    println!("   Username: {}", token.username);
                    println!("   Roles: {}", token.roles.join(", "));
                    println!("   Expires at: {}", token.expires_at);
                }
                Err(e) => {
                    eprintln!("❌ Authentication failed: {}", e);
                    std::process::exit(1);
                }
            }
        }
    }
}