//! Core type definitions for Automation Nation

use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use uuid::Uuid;
use std::collections::HashMap;

/// System information collected by bash plugins
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemInfo {
    /// Detected system architecture
    pub detected_architecture: String,
    /// Collection metadata
    pub collection_metadata: CollectionMetadata,
    /// OS information
    pub os_info: Option<serde_json::Value>,
    /// Hardware information  
    pub hardware_info: Option<serde_json::Value>,
    /// Network information
    pub network_info: Option<serde_json::Value>,
    /// Package information
    pub package_info: Option<serde_json::Value>,
    /// Additional plugin data
    pub additional_data: HashMap<String, serde_json::Value>,
}

/// Metadata about the system information collection process
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CollectionMetadata {
    /// Collection timestamp
    pub timestamp: DateTime<Utc>,
    /// Number of plugins executed
    pub plugin_count: u32,
    /// Whether hashing was enabled
    pub hashing_enabled: bool,
    /// Whether sudo support was enabled
    pub sudo_support_enabled: bool,
    /// Whether sudo was available
    pub sudo_available: bool,
    /// Collection duration in milliseconds
    pub duration_ms: Option<u64>,
}

/// Performance metrics for the system
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceMetrics {
    /// Response time metrics
    pub response_times: ResponseTimeMetrics,
    /// Resource usage metrics
    pub resource_usage: ResourceUsageMetrics,
    /// System load metrics
    pub system_load: SystemLoadMetrics,
    /// Collection timestamp
    pub timestamp: DateTime<Utc>,
}

/// Response time tracking
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResponseTimeMetrics {
    /// Average response time (milliseconds)
    pub avg_response_time_ms: f64,
    /// Median response time (milliseconds)
    pub median_response_time_ms: f64,
    /// 95th percentile response time (milliseconds)
    pub p95_response_time_ms: f64,
    /// 99th percentile response time (milliseconds)
    pub p99_response_time_ms: f64,
    /// Minimum response time (milliseconds)
    pub min_response_time_ms: u64,
    /// Maximum response time (milliseconds)
    pub max_response_time_ms: u64,
    /// Total requests processed
    pub total_requests: u64,
}

/// Resource usage metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResourceUsageMetrics {
    /// CPU usage percentage
    pub cpu_usage_percent: f64,
    /// Memory usage in MB
    pub memory_usage_mb: u64,
    /// Memory usage percentage
    pub memory_usage_percent: f64,
    /// Disk I/O operations per second
    pub disk_iops: u64,
    /// Network bytes per second
    pub network_bytes_per_sec: u64,
}

/// System load metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemLoadMetrics {
    /// Load average (1 minute)
    pub load_avg_1min: f64,
    /// Load average (5 minutes)
    pub load_avg_5min: f64,
    /// Load average (15 minutes)
    pub load_avg_15min: f64,
    /// Number of active processes
    pub active_processes: u32,
    /// System uptime in seconds
    pub uptime_seconds: u64,
}

/// Configuration for performance optimization
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OptimizationConfig {
    /// Enable response caching
    pub enable_caching: bool,
    /// Cache TTL in seconds
    pub cache_ttl_seconds: u64,
    /// Maximum concurrent operations
    pub max_concurrent_ops: u32,
    /// Enable parallel plugin execution
    pub enable_parallel_execution: bool,
    /// Request timeout in seconds
    pub request_timeout_seconds: u64,
    /// Maximum memory usage in MB
    pub max_memory_usage_mb: u64,
}

impl Default for OptimizationConfig {
    fn default() -> Self {
        Self {
            enable_caching: true,
            cache_ttl_seconds: 300, // 5 minutes
            max_concurrent_ops: 10,
            enable_parallel_execution: true,
            request_timeout_seconds: 30,
            max_memory_usage_mb: 1024, // 1GB
        }
    }
}