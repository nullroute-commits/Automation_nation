//! Web server binary for Automation Nation
//! 
//! This binary provides a high-performance web API for system information collection
//! and user management with RBAC authentication.

use automation_nation::{RbacManager, SystemProfiler, PerformanceOptimizer};
use axum::{
    extract::{State, Query},
    http::{StatusCode, HeaderMap},
    response::Json,
    routing::{get, post},
    Router,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use tower::ServiceBuilder;
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;
use clap::Parser;
use std::net::SocketAddr;
use log::{info, error};

/// Web server state
#[derive(Clone)]
struct AppState {
    rbac_manager: Arc<RwLock<RbacManager>>,
    system_profiler: Arc<RwLock<SystemProfiler>>,
    performance_optimizer: Arc<PerformanceOptimizer>,
}

/// Command line arguments
#[derive(Parser, Debug)]
#[command(name = "automation_nation_server")]
#[command(about = "Automation Nation Web Server")]
struct Args {
    /// Port to bind to
    #[arg(short, long, default_value = "3000")]
    port: u16,
    
    /// Host to bind to
    #[arg(long, default_value = "127.0.0.1")]
    host: String,
    
    /// JWT secret key
    #[arg(long, default_value = "your-secret-key-change-in-production")]
    jwt_secret: String,
    
    /// Enable debug logging
    #[arg(short, long)]
    debug: bool,
}

/// Health check response
#[derive(Serialize)]
struct HealthResponse {
    status: String,
    version: String,
    timestamp: chrono::DateTime<chrono::Utc>,
}

/// System information query parameters
#[derive(Deserialize)]
struct SystemInfoQuery {
    /// Use minimal collection for faster response
    minimal: Option<bool>,
    /// Force refresh cache
    refresh: Option<bool>,
}

/// Login request
#[derive(Deserialize)]
struct LoginRequest {
    username: String,
    password: String,
}

/// Login response
#[derive(Serialize)]
struct LoginResponse {
    token: String,
    user_id: String,
    username: String,
    roles: Vec<String>,
    expires_at: chrono::DateTime<chrono::Utc>,
}

/// User creation request
#[derive(Deserialize)]
struct CreateUserRequest {
    username: String,
    email: String,
    display_name: String,
    password: String,
    roles: Vec<String>,
}

/// Error response
#[derive(Serialize)]
struct ErrorResponse {
    error: String,
    message: String,
}

#[tokio::main]
async fn main() {
    let args = Args::parse();
    
    // Initialize logging
    if args.debug {
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("debug")).init();
    } else {
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    }
    
    info!("Starting Automation Nation Web Server");
    
    // Initialize application state
    let state = AppState {
        rbac_manager: Arc::new(RwLock::new(RbacManager::new(args.jwt_secret.clone()))),
        system_profiler: Arc::new(RwLock::new(SystemProfiler::new())),
        performance_optimizer: Arc::new(PerformanceOptimizer::new()),
    };
    
    // Create default admin user
    {
        let mut rbac = state.rbac_manager.write().await;
        if let Err(e) = rbac.create_user(
            "admin".to_string(),
            "admin@automation-nation.local".to_string(),
            "Administrator".to_string(),
            "admin123".to_string(),
            vec!["admin".to_string()],
        ) {
            info!("Admin user already exists or creation failed: {}", e);
        } else {
            info!("Created default admin user (username: admin, password: admin123)");
        }
    }
    
    // Build router
    let app = Router::new()
        .route("/health", get(health_check))
        .route("/api/auth/login", post(login))
        .route("/api/users", post(create_user))
        .route("/api/system-info", get(get_system_info))
        .route("/api/performance", get(get_performance_metrics))
        .route("/api/cache/clear", post(clear_cache))
        .with_state(state)
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(CorsLayer::permissive())
        );
    
    // Start server
    let addr = SocketAddr::new(args.host.parse().expect("Invalid host"), args.port);
    info!("Server listening on http://{}", addr);
    
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

/// Health check endpoint
async fn health_check() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "healthy".to_string(),
        version: env!("CARGO_PKG_VERSION").to_string(),
        timestamp: chrono::Utc::now(),
    })
}

/// User authentication endpoint
async fn login(
    State(state): State<AppState>,
    Json(request): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, (StatusCode, Json<ErrorResponse>)> {
    let start_time = std::time::Instant::now();
    
    let mut rbac = state.rbac_manager.write().await;
    
    match rbac.authenticate(&request.username, &request.password, "127.0.0.1".to_string()) {
        Ok(token) => {
            let response = LoginResponse {
                token: format!("jwt_{}", token.user_id), // Simplified token for demo
                user_id: token.user_id.to_string(),
                username: token.username,
                roles: token.roles,
                expires_at: token.expires_at,
            };
            
            // Record performance metrics
            state.performance_optimizer.record_request_metrics(
                "/api/auth/login",
                "POST",
                start_time.elapsed().as_millis() as u64,
                true,
            ).await;
            
            Ok(Json(response))
        }
        Err(e) => {
            state.performance_optimizer.record_request_metrics(
                "/api/auth/login",
                "POST",
                start_time.elapsed().as_millis() as u64,
                false,
            ).await;
            
            Err((
                StatusCode::UNAUTHORIZED,
                Json(ErrorResponse {
                    error: "authentication_failed".to_string(),
                    message: e.to_string(),
                }),
            ))
        }
    }
}

/// Create user endpoint
async fn create_user(
    State(state): State<AppState>,
    Json(request): Json<CreateUserRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ErrorResponse>)> {
    let start_time = std::time::Instant::now();
    
    let mut rbac = state.rbac_manager.write().await;
    
    match rbac.create_user(
        request.username,
        request.email,
        request.display_name,
        request.password,
        request.roles,
    ) {
        Ok(user_id) => {
            state.performance_optimizer.record_request_metrics(
                "/api/users",
                "POST",
                start_time.elapsed().as_millis() as u64,
                true,
            ).await;
            
            Ok(Json(serde_json::json!({
                "user_id": user_id,
                "message": "User created successfully"
            })))
        }
        Err(e) => {
            state.performance_optimizer.record_request_metrics(
                "/api/users",
                "POST",
                start_time.elapsed().as_millis() as u64,
                false,
            ).await;
            
            Err((
                StatusCode::BAD_REQUEST,
                Json(ErrorResponse {
                    error: "user_creation_failed".to_string(),
                    message: e.to_string(),
                }),
            ))
        }
    }
}

/// Get system information endpoint
async fn get_system_info(
    State(state): State<AppState>,
    Query(params): Query<SystemInfoQuery>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<ErrorResponse>)> {
    let start_time = std::time::Instant::now();
    
    // Clear cache if refresh requested
    if params.refresh.unwrap_or(false) {
        state.performance_optimizer.clear_caches().await;
    }
    
    let mut profiler = state.system_profiler.write().await;
    
    let result = if params.minimal.unwrap_or(false) {
        profiler.collect_minimal().await
    } else {
        profiler.collect_system_info().await
    };
    
    match result {
        Ok(collection_result) => {
            state.performance_optimizer.record_request_metrics(
                "/api/system-info",
                "GET",
                start_time.elapsed().as_millis() as u64,
                collection_result.success,
            ).await;
            
            Ok(Json(serde_json::to_value(collection_result).unwrap()))
        }
        Err(e) => {
            state.performance_optimizer.record_request_metrics(
                "/api/system-info",
                "GET",
                start_time.elapsed().as_millis() as u64,
                false,
            ).await;
            
            Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: "collection_failed".to_string(),
                    message: e.to_string(),
                }),
            ))
        }
    }
}

/// Get performance metrics endpoint
async fn get_performance_metrics(
    State(state): State<AppState>,
) -> Json<serde_json::Value> {
    let start_time = std::time::Instant::now();
    
    let metrics = state.performance_optimizer.get_performance_metrics().await;
    let recommendations = state.performance_optimizer.get_optimization_recommendations().await;
    
    state.performance_optimizer.record_request_metrics(
        "/api/performance",
        "GET",
        start_time.elapsed().as_millis() as u64,
        true,
    ).await;
    
    Json(serde_json::json!({
        "metrics": metrics,
        "recommendations": recommendations,
        "timestamp": chrono::Utc::now()
    }))
}

/// Clear cache endpoint
async fn clear_cache(
    State(state): State<AppState>,
) -> Json<serde_json::Value> {
    let start_time = std::time::Instant::now();
    
    state.performance_optimizer.clear_caches().await;
    
    state.performance_optimizer.record_request_metrics(
        "/api/cache/clear",
        "POST",
        start_time.elapsed().as_millis() as u64,
        true,
    ).await;
    
    Json(serde_json::json!({
        "message": "Cache cleared successfully",
        "timestamp": chrono::Utc::now()
    }))
}