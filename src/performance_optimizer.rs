//! Performance optimization module for Automation Nation
//!
//! This module provides high-performance system monitoring and optimization
//! capabilities including response time tracking, resource usage monitoring,
//! and intelligent caching for maximum runtime execution speed.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use chrono::{DateTime, Utc, Duration};
use crate::types::*;
use crate::error::{Result, AutomationError};
use log::{info, warn, debug};

/// Cache entry for response data
#[derive(Debug, Clone, Serialize, Deserialize)]
struct CacheEntry {
    /// Cached data
    data: serde_json::Value,
    /// Cache timestamp
    created_at: DateTime<Utc>,
    /// Time-to-live in seconds
    ttl_seconds: u64,
    /// Number of cache hits
    hit_count: u64,
}

impl CacheEntry {
    /// Check if cache entry is still valid
    fn is_valid(&self) -> bool {
        Utc::now() < self.created_at + Duration::seconds(self.ttl_seconds as i64)
    }
}

/// Response cache for frequently requested data
#[derive(Debug, Default)]
struct ResponseCache {
    /// Cache storage
    entries: HashMap<String, CacheEntry>,
    /// Cache statistics
    total_hits: u64,
    total_misses: u64,
}

/// Query cache for expensive operations
#[derive(Debug, Default)]
struct QueryCache {
    /// System info cache
    system_info_cache: HashMap<String, CacheEntry>,
    /// Performance metrics cache
    metrics_cache: HashMap<String, CacheEntry>,
}

/// Cache configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheConfig {
    /// Default TTL for responses (seconds)
    pub default_ttl: u64,
    /// Maximum cache size (number of entries)
    pub max_entries: usize,
    /// Enable automatic cache cleanup
    pub auto_cleanup: bool,
    /// Cleanup interval (seconds)
    pub cleanup_interval: u64,
}

impl Default for CacheConfig {
    fn default() -> Self {
        Self {
            default_ttl: 300, // 5 minutes
            max_entries: 1000,
            auto_cleanup: true,
            cleanup_interval: 600, // 10 minutes
        }
    }
}

/// Endpoint-specific performance metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EndpointMetrics {
    /// Total request count
    pub request_count: u64,
    /// Total error count
    pub error_count: u64,
    /// Average response time (milliseconds)
    pub avg_response_time_ms: f64,
    /// Last request timestamp
    pub last_request_at: DateTime<Utc>,
    /// Recent response times for calculation
    response_times: Vec<u64>,
}

impl Default for EndpointMetrics {
    fn default() -> Self {
        Self {
            request_count: 0,
            error_count: 0,
            avg_response_time_ms: 0.0,
            last_request_at: Utc::now(),
            response_times: Vec::new(),
        }
    }
}

/// Complete performance metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComprehensiveMetrics {
    /// Overall response time metrics
    pub response_times: ResponseTimeMetrics,
    /// Resource usage metrics
    pub resource_usage: ResourceUsageMetrics,
    /// System load metrics
    pub system_load: SystemLoadMetrics,
    /// Per-endpoint metrics
    pub endpoint_metrics: HashMap<String, EndpointMetrics>,
    /// Cache performance metrics
    pub cache_metrics: CacheMetrics,
    /// Collection timestamp
    pub timestamp: DateTime<Utc>,
}

/// Cache performance metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheMetrics {
    /// Total cache hits
    pub total_hits: u64,
    /// Total cache misses
    pub total_misses: u64,
    /// Cache hit ratio
    pub hit_ratio: f64,
    /// Current cache size
    pub cache_size: usize,
    /// Memory used by cache (estimated MB)
    pub memory_usage_mb: f64,
}

/// Performance optimization manager
pub struct PerformanceOptimizer {
    /// Response cache
    response_cache: Arc<RwLock<ResponseCache>>,
    /// Query cache
    query_cache: Arc<RwLock<QueryCache>>,
    /// Performance metrics
    metrics: Arc<RwLock<ComprehensiveMetrics>>,
    /// Configuration
    config: CacheConfig,
}

impl PerformanceOptimizer {
    /// Create a new performance optimizer
    pub fn new() -> Self {
        Self::with_config(CacheConfig::default())
    }
    
    /// Create a new performance optimizer with custom configuration
    pub fn with_config(config: CacheConfig) -> Self {
        let initial_metrics = ComprehensiveMetrics {
            response_times: ResponseTimeMetrics {
                avg_response_time_ms: 0.0,
                median_response_time_ms: 0.0,
                p95_response_time_ms: 0.0,
                p99_response_time_ms: 0.0,
                min_response_time_ms: 0,
                max_response_time_ms: 0,
                total_requests: 0,
            },
            resource_usage: ResourceUsageMetrics {
                cpu_usage_percent: 0.0,
                memory_usage_mb: 0,
                memory_usage_percent: 0.0,
                disk_iops: 0,
                network_bytes_per_sec: 0,
            },
            system_load: SystemLoadMetrics {
                load_avg_1min: 0.0,
                load_avg_5min: 0.0,
                load_avg_15min: 0.0,
                active_processes: 0,
                uptime_seconds: 0,
            },
            endpoint_metrics: HashMap::new(),
            cache_metrics: CacheMetrics {
                total_hits: 0,
                total_misses: 0,
                hit_ratio: 0.0,
                cache_size: 0,
                memory_usage_mb: 0.0,
            },
            timestamp: Utc::now(),
        };
        
        Self {
            response_cache: Arc::new(RwLock::new(ResponseCache::default())),
            query_cache: Arc::new(RwLock::new(QueryCache::default())),
            metrics: Arc::new(RwLock::new(initial_metrics)),
            config,
        }
    }
    
    /// Get cached response if available
    pub async fn get_cached_response(&self, key: &str) -> Option<serde_json::Value> {
        let cache = self.response_cache.read().await;
        
        if let Some(entry) = cache.entries.get(key) {
            if entry.is_valid() {
                debug!("Cache hit for key: {}", key);
                return Some(entry.data.clone());
            } else {
                debug!("Cache expired for key: {}", key);
            }
        }
        
        debug!("Cache miss for key: {}", key);
        None
    }
    
    /// Store response in cache
    pub async fn cache_response(&self, key: String, data: serde_json::Value) {
        let mut cache = self.response_cache.write().await;
        
        // Check cache size limits
        if cache.entries.len() >= self.config.max_entries {
            self.cleanup_cache(&mut cache).await;
        }
        
        let entry = CacheEntry {
            data,
            created_at: Utc::now(),
            ttl_seconds: self.config.default_ttl,
            hit_count: 0,
        };
        
        cache.entries.insert(key.clone(), entry);
        debug!("Cached response for key: {}", key);
    }
    
    /// Clean up expired cache entries
    async fn cleanup_cache(&self, cache: &mut ResponseCache) {
        let now = Utc::now();
        let mut expired_keys = Vec::new();
        
        for (key, entry) in &cache.entries {
            if !entry.is_valid() {
                expired_keys.push(key.clone());
            }
        }
        
        for key in expired_keys {
            cache.entries.remove(&key);
        }
        
        debug!("Cleaned up {} expired cache entries", cache.entries.len());
    }
    
    /// Record request performance metrics
    pub async fn record_request_metrics(
        &self,
        endpoint: &str,
        method: &str,
        response_time_ms: u64,
        success: bool,
    ) {
        let mut metrics = self.metrics.write().await;
        
        // Update overall metrics
        metrics.response_times.total_requests += 1;
        
        // Update min/max response times
        if metrics.response_times.total_requests == 1 {
            metrics.response_times.min_response_time_ms = response_time_ms;
            metrics.response_times.max_response_time_ms = response_time_ms;
        } else {
            metrics.response_times.min_response_time_ms = metrics.response_times.min_response_time_ms.min(response_time_ms);
            metrics.response_times.max_response_time_ms = metrics.response_times.max_response_time_ms.max(response_time_ms);
        }
        
        // Add to response times for average calculation
        let response_times = &mut metrics.response_times;
        if response_times.total_requests <= 1000 {
            // Keep last 1000 response times for accurate calculations
            if response_times.total_requests == 1 {
                response_times.avg_response_time_ms = response_time_ms as f64;
            } else {
                let total_time = response_times.avg_response_time_ms * (response_times.total_requests - 1) as f64 + response_time_ms as f64;
                response_times.avg_response_time_ms = total_time / response_times.total_requests as f64;
            }
        }
        
        // Update endpoint-specific metrics
        let endpoint_key = format!("{} {}", method, endpoint);
        let endpoint_metrics = metrics.endpoint_metrics.entry(endpoint_key).or_default();
        endpoint_metrics.request_count += 1;
        endpoint_metrics.last_request_at = Utc::now();
        
        if !success {
            endpoint_metrics.error_count += 1;
        }
        
        // Update endpoint response times
        endpoint_metrics.response_times.push(response_time_ms);
        if endpoint_metrics.response_times.len() > 100 {
            endpoint_metrics.response_times.remove(0); // Keep only last 100
        }
        
        // Calculate endpoint average
        if !endpoint_metrics.response_times.is_empty() {
            endpoint_metrics.avg_response_time_ms = endpoint_metrics.response_times.iter().sum::<u64>() as f64 / endpoint_metrics.response_times.len() as f64;
        }
        
        metrics.timestamp = Utc::now();
    }
    
    /// Record system resource usage
    pub async fn record_system_metrics(&self, resource_usage: ResourceUsageMetrics, system_load: SystemLoadMetrics) {
        let mut metrics = self.metrics.write().await;
        metrics.resource_usage = resource_usage;
        metrics.system_load = system_load;
        metrics.timestamp = Utc::now();
    }
    
    /// Get current performance metrics
    pub async fn get_performance_metrics(&self) -> ComprehensiveMetrics {
        let mut metrics = self.metrics.read().await.clone();
        
        // Update cache metrics
        let response_cache = self.response_cache.read().await;
        metrics.cache_metrics = CacheMetrics {
            total_hits: response_cache.total_hits,
            total_misses: response_cache.total_misses,
            hit_ratio: if response_cache.total_hits + response_cache.total_misses > 0 {
                response_cache.total_hits as f64 / (response_cache.total_hits + response_cache.total_misses) as f64
            } else {
                0.0
            },
            cache_size: response_cache.entries.len(),
            memory_usage_mb: (response_cache.entries.len() * 1024) as f64 / 1024.0 / 1024.0, // Rough estimate
        };
        
        metrics
    }
    
    /// Get optimization recommendations based on current metrics
    pub async fn get_optimization_recommendations(&self) -> Vec<String> {
        let metrics = self.get_performance_metrics().await;
        let mut recommendations = Vec::new();
        
        // Check response times
        if metrics.response_times.avg_response_time_ms > 1000.0 {
            recommendations.push("Consider optimizing slow endpoints - average response time is over 1 second".to_string());
        }
        
        if metrics.response_times.p95_response_time_ms > 2000.0 {
            recommendations.push("95th percentile response time is over 2 seconds - investigate performance bottlenecks".to_string());
        }
        
        // Check cache performance
        if metrics.cache_metrics.hit_ratio < 0.5 && metrics.cache_metrics.total_hits + metrics.cache_metrics.total_misses > 100 {
            recommendations.push("Cache hit ratio is low - consider increasing cache TTL or improving cache keys".to_string());
        }
        
        // Check resource usage
        if metrics.resource_usage.cpu_usage_percent > 80.0 {
            recommendations.push("High CPU usage detected - consider scaling or optimizing CPU-intensive operations".to_string());
        }
        
        if metrics.resource_usage.memory_usage_percent > 85.0 {
            recommendations.push("High memory usage detected - consider optimizing memory usage or increasing available memory".to_string());
        }
        
        // Check system load
        if metrics.system_load.load_avg_5min > 2.0 {
            recommendations.push("System load is high - consider distributing load or optimizing resource usage".to_string());
        }
        
        // Check endpoint error rates
        for (endpoint, endpoint_metrics) in &metrics.endpoint_metrics {
            let error_rate = endpoint_metrics.error_count as f64 / endpoint_metrics.request_count as f64;
            if error_rate > 0.1 {
                recommendations.push(format!("High error rate ({:.1}%) for endpoint {} - investigate error causes", error_rate * 100.0, endpoint));
            }
        }
        
        if recommendations.is_empty() {
            recommendations.push("System performance looks good - no immediate optimizations needed".to_string());
        }
        
        recommendations
    }
    
    /// Clear all caches
    pub async fn clear_caches(&self) {
        let mut response_cache = self.response_cache.write().await;
        let mut query_cache = self.query_cache.write().await;
        
        response_cache.entries.clear();
        query_cache.system_info_cache.clear();
        query_cache.metrics_cache.clear();
        
        info!("Cleared all caches");
    }
    
    /// Get cache statistics
    pub async fn get_cache_stats(&self) -> CacheMetrics {
        let cache = self.response_cache.read().await;
        
        CacheMetrics {
            total_hits: cache.total_hits,
            total_misses: cache.total_misses,
            hit_ratio: if cache.total_hits + cache.total_misses > 0 {
                cache.total_hits as f64 / (cache.total_hits + cache.total_misses) as f64
            } else {
                0.0
            },
            cache_size: cache.entries.len(),
            memory_usage_mb: (cache.entries.len() * 1024) as f64 / 1024.0 / 1024.0,
        }
    }
    
    /// Optimize system information collection based on performance data
    pub async fn optimize_collection_strategy(&self) -> OptimizationConfig {
        let metrics = self.get_performance_metrics().await;
        let mut config = OptimizationConfig::default();
        
        // Adjust based on system load
        if metrics.system_load.load_avg_5min > 2.0 {
            config.max_concurrent_ops = (config.max_concurrent_ops / 2).max(1);
            config.enable_parallel_execution = false;
            info!("Reduced concurrency due to high system load");
        } else if metrics.system_load.load_avg_5min < 0.5 {
            config.max_concurrent_ops = config.max_concurrent_ops * 2;
            config.enable_parallel_execution = true;
        }
        
        // Adjust cache settings based on hit ratio
        if metrics.cache_metrics.hit_ratio > 0.8 {
            config.cache_ttl_seconds = config.cache_ttl_seconds * 2; // Increase TTL for good hit ratio
        } else if metrics.cache_metrics.hit_ratio < 0.3 {
            config.cache_ttl_seconds = config.cache_ttl_seconds / 2; // Decrease TTL for poor hit ratio
        }
        
        // Adjust timeout based on response times
        if metrics.response_times.avg_response_time_ms > 5000.0 {
            config.request_timeout_seconds = config.request_timeout_seconds * 2;
        }
        
        // Memory-based adjustments
        if metrics.resource_usage.memory_usage_percent > 80.0 {
            config.max_memory_usage_mb = config.max_memory_usage_mb / 2;
            config.enable_caching = false;
            warn!("Disabled caching due to high memory usage");
        }
        
        config
    }
}

impl Default for PerformanceOptimizer {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::test;
    
    #[tokio::test]
    async fn test_cache_operations() {
        let optimizer = PerformanceOptimizer::new();
        let key = "test_key".to_string();
        let data = serde_json::json!({"test": "data"});
        
        // Test cache miss
        assert!(optimizer.get_cached_response(&key).await.is_none());
        
        // Cache data
        optimizer.cache_response(key.clone(), data.clone()).await;
        
        // Test cache hit
        let cached = optimizer.get_cached_response(&key).await;
        assert!(cached.is_some());
        assert_eq!(cached.unwrap(), data);
    }
    
    #[tokio::test]
    async fn test_performance_metrics() {
        let optimizer = PerformanceOptimizer::new();
        
        // Record some metrics
        optimizer.record_request_metrics("/api/test", "GET", 100, true).await;
        optimizer.record_request_metrics("/api/test", "GET", 200, true).await;
        optimizer.record_request_metrics("/api/test", "GET", 150, false).await;

        let metrics = optimizer.get_performance_metrics().await;
        assert_eq!(metrics.response_times.total_requests, 3);
        assert_eq!(metrics.response_times.min_response_time_ms, 100);
        assert_eq!(metrics.response_times.max_response_time_ms, 200);
        
        let endpoint_key = "GET /api/test";
        let endpoint_metrics = metrics.endpoint_metrics.get(endpoint_key).unwrap();
        assert_eq!(endpoint_metrics.request_count, 3);
        assert_eq!(endpoint_metrics.error_count, 1);
    }
    
    #[tokio::test]
    async fn test_optimization_recommendations() {
        let optimizer = PerformanceOptimizer::new();
        
        // Record high response times
        optimizer.record_request_metrics("/api/slow", "GET", 3000, true).await;
        
        let recommendations = optimizer.get_optimization_recommendations().await;
        assert!(!recommendations.is_empty());
        assert!(recommendations.iter().any(|r| r.contains("average response time")));
    }
    
    #[tokio::test]
    async fn test_cache_cleanup() {
        let mut config = CacheConfig::default();
        config.default_ttl = 1; // 1 second TTL
        
        let optimizer = PerformanceOptimizer::with_config(config);
        let key = "test_key".to_string();
        let data = serde_json::json!({"test": "data"});
        
        // Cache data
        optimizer.cache_response(key.clone(), data.clone()).await;
        
        // Should be available immediately
        assert!(optimizer.get_cached_response(&key).await.is_some());
        
        // Wait for expiration
        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
        
        // Should be expired
        assert!(optimizer.get_cached_response(&key).await.is_none());
    }
}