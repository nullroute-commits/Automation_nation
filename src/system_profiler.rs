//! System profiler for interfacing with bash-based system information collection
//!
//! This module provides high-level Rust interface to the bash collection scripts,
//! optimizing for performance and minimal dependencies.

use serde::{Deserialize, Serialize};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};
use tokio::process::Command as TokioCommand;
use tokio::time::timeout;
use crate::types::*;
use crate::error::{Result, AutomationError};
use crate::performance_optimizer::PerformanceOptimizer;
use log::{info, warn, error, debug};
use uuid::Uuid;

/// System profiler configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProfilerConfig {
    /// Path to collect_info.sh script
    pub script_path: String,
    /// Execution timeout in seconds
    pub timeout_seconds: u64,
    /// Enable parallel plugin execution
    pub enable_parallel: bool,
    /// Enable sudo support for privileged information
    pub enable_sudo: bool,
    /// Enable CRC32 hashing for integrity verification
    pub enable_hashing: bool,
    /// Maximum number of packages to collect
    pub max_packages: u32,
    /// Maximum number of executables to collect
    pub max_executables: u32,
    /// Custom environment variables
    pub env_vars: std::collections::HashMap<String, String>,
}

impl Default for ProfilerConfig {
    fn default() -> Self {
        Self {
            script_path: "./collect_info.sh".to_string(),
            timeout_seconds: 30,
            enable_parallel: true,
            enable_sudo: false,
            enable_hashing: true,
            max_packages: 30,
            max_executables: 20,
            env_vars: std::collections::HashMap::new(),
        }
    }
}

/// System profiler for collecting system information
pub struct SystemProfiler {
    /// Configuration
    config: ProfilerConfig,
    /// Performance optimizer
    optimizer: PerformanceOptimizer,
    /// Collection statistics
    stats: CollectionStats,
}

/// Statistics about collection operations
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CollectionStats {
    /// Total collections performed
    pub total_collections: u64,
    /// Successful collections
    pub successful_collections: u64,
    /// Failed collections
    pub failed_collections: u64,
    /// Average collection time (ms)
    pub avg_collection_time_ms: f64,
    /// Last collection timestamp
    pub last_collection_at: Option<chrono::DateTime<chrono::Utc>>,
    /// Cache hit rate
    pub cache_hit_rate: f64,
}

/// Collection result with metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CollectionResult {
    /// Unique collection ID
    pub id: Uuid,
    /// Collected system information
    pub system_info: SystemInfo,
    /// Collection duration in milliseconds
    pub duration_ms: u64,
    /// Whether collection was successful
    pub success: bool,
    /// Error message if collection failed
    pub error_message: Option<String>,
    /// Whether result was served from cache
    pub from_cache: bool,
    /// Collection timestamp
    pub timestamp: chrono::DateTime<chrono::Utc>,
}

impl SystemProfiler {
    /// Create a new system profiler
    pub fn new() -> Self {
        Self::with_config(ProfilerConfig::default())
    }
    
    /// Create a new system profiler with custom configuration
    pub fn with_config(config: ProfilerConfig) -> Self {
        Self {
            config,
            optimizer: PerformanceOptimizer::new(),
            stats: CollectionStats::default(),
        }
    }
    
    /// Collect system information with performance optimization
    pub async fn collect_system_info(&mut self) -> Result<CollectionResult> {
        let start_time = Instant::now();
        let collection_id = Uuid::new_v4();
        let timestamp = chrono::Utc::now();
        
        info!("Starting system information collection {}", collection_id);
        
        // Check cache first
        let cache_key = self.generate_cache_key();
        if let Some(cached_data) = self.optimizer.get_cached_response(&cache_key).await {
            debug!("Serving system info from cache");
            self.stats.cache_hit_rate = (self.stats.cache_hit_rate + 1.0) / 2.0; // Simple moving average
            
            let system_info: SystemInfo = serde_json::from_value(cached_data)
                .map_err(|e| AutomationError::Validation(format!("Cache deserialization error: {}", e)))?;
                
            return Ok(CollectionResult {
                id: collection_id,
                system_info,
                duration_ms: start_time.elapsed().as_millis() as u64,
                success: true,
                error_message: None,
                from_cache: true,
                timestamp,
            });
        }
        
        // Perform actual collection
        let result = self.execute_collection().await;
        let duration_ms = start_time.elapsed().as_millis() as u64;
        
        // Update statistics
        self.stats.total_collections += 1;
        self.stats.last_collection_at = Some(timestamp);
        
        // Update average collection time
        if self.stats.total_collections == 1 {
            self.stats.avg_collection_time_ms = duration_ms as f64;
        } else {
            self.stats.avg_collection_time_ms = 
                (self.stats.avg_collection_time_ms * (self.stats.total_collections - 1) as f64 + duration_ms as f64) 
                / self.stats.total_collections as f64;
        }
        
        // Record performance metrics
        self.optimizer.record_request_metrics(
            "/api/system-info",
            "GET",
            duration_ms,
            result.is_ok(),
        ).await;
        
        match result {
            Ok(system_info) => {
                self.stats.successful_collections += 1;
                
                // Cache the result
                let cache_data = serde_json::to_value(&system_info)?;
                self.optimizer.cache_response(cache_key, cache_data).await;
                
                info!("System information collection {} completed successfully in {}ms", collection_id, duration_ms);
                
                Ok(CollectionResult {
                    id: collection_id,
                    system_info,
                    duration_ms,
                    success: true,
                    error_message: None,
                    from_cache: false,
                    timestamp,
                })
            }
            Err(e) => {
                self.stats.failed_collections += 1;
                error!("System information collection {} failed: {}", collection_id, e);
                
                Ok(CollectionResult {
                    id: collection_id,
                    system_info: SystemInfo {
                        detected_architecture: "unknown".to_string(),
                        collection_metadata: CollectionMetadata {
                            timestamp,
                            plugin_count: 0,
                            hashing_enabled: self.config.enable_hashing,
                            sudo_support_enabled: self.config.enable_sudo,
                            sudo_available: false,
                            duration_ms: Some(duration_ms),
                        },
                        os_info: None,
                        hardware_info: None,
                        network_info: None,
                        package_info: None,
                        additional_data: std::collections::HashMap::new(),
                    },
                    duration_ms,
                    success: false,
                    error_message: Some(e.to_string()),
                    from_cache: false,
                    timestamp,
                })
            }
        }
    }
    
    /// Execute the actual system information collection
    async fn execute_collection(&self) -> Result<SystemInfo> {
        // Prepare environment variables for optimization
        let mut env_vars = self.config.env_vars.clone();
        env_vars.insert("MAX_PACKAGES".to_string(), self.config.max_packages.to_string());
        env_vars.insert("MAX_EXECUTABLES".to_string(), self.config.max_executables.to_string());
        env_vars.insert("ENABLE_HASHING".to_string(), if self.config.enable_hashing { "1" } else { "0" }.to_string());
        env_vars.insert("ENABLE_SUDO_SUPPORT".to_string(), if self.config.enable_sudo { "1" } else { "0" }.to_string());
        env_vars.insert("ENABLE_PARALLEL".to_string(), if self.config.enable_parallel { "1" } else { "0" }.to_string());
        
        // Choose optimal script based on configuration
        let script_path = if self.config.enable_parallel {
            "./collect_info_optimized.sh"
        } else {
            &self.config.script_path
        };
        
        debug!("Executing collection script: {}", script_path);
        debug!("Environment variables: {:?}", env_vars);
        
        // Execute collection script with timeout
        let mut cmd = TokioCommand::new(script_path);
        cmd.stdout(Stdio::piped())
           .stderr(Stdio::piped());
           
        // Set environment variables
        for (key, value) in &env_vars {
            cmd.env(key, value);
        }
        
        let output = timeout(
            Duration::from_secs(self.config.timeout_seconds),
            cmd.output()
        ).await
        .map_err(|_| AutomationError::System("Collection script timed out".to_string()))?
        .map_err(|e| AutomationError::System(format!("Failed to execute collection script: {}", e)))?;
        
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(AutomationError::System(format!("Collection script failed: {}", stderr)));
        }
        
        let stdout = String::from_utf8_lossy(&output.stdout);
        debug!("Collection script output length: {} bytes", stdout.len());
        
        // Parse JSON output
        let raw_data: serde_json::Value = serde_json::from_str(&stdout)
            .map_err(|e| AutomationError::Validation(format!("Invalid JSON output from collection script: {}", e)))?;
        
        // Convert to structured system info
        self.parse_system_info(raw_data)
    }
    
    /// Parse raw JSON output into structured SystemInfo
    fn parse_system_info(&self, raw_data: serde_json::Value) -> Result<SystemInfo> {
        let obj = raw_data.as_object()
            .ok_or_else(|| AutomationError::Validation("Expected JSON object at root level".to_string()))?;
        
        // Extract detected architecture
        let detected_architecture = obj.get("detected_architecture")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown")
            .to_string();
        
        // Extract collection metadata
        let collection_metadata = if let Some(meta) = obj.get("collection_metadata") {
            serde_json::from_value(meta.clone())
                .unwrap_or_else(|_| CollectionMetadata {
                    timestamp: chrono::Utc::now(),
                    plugin_count: 0,
                    hashing_enabled: self.config.enable_hashing,
                    sudo_support_enabled: self.config.enable_sudo,
                    sudo_available: false,
                    duration_ms: None,
                })
        } else {
            CollectionMetadata {
                timestamp: chrono::Utc::now(),
                plugin_count: 0,
                hashing_enabled: self.config.enable_hashing,
                sudo_support_enabled: self.config.enable_sudo,
                sudo_available: false,
                duration_ms: None,
            }
        };
        
        // Extract specific plugin data
        let os_info = self.extract_plugin_data(obj, "get_os_info");
        let hardware_info = self.extract_plugin_data(obj, "get_hardware_info");
        let network_info = self.extract_network_info(obj);
        let package_info = self.extract_plugin_data(obj, "get_packages_and_executables");
        
        // Extract additional plugin data
        let mut additional_data = std::collections::HashMap::new();
        for (key, value) in obj {
            if !["detected_architecture", "collection_metadata"].contains(&key.as_str()) &&
               !key.starts_with("get_") {
                additional_data.insert(key.clone(), value.clone());
            }
        }
        
        Ok(SystemInfo {
            detected_architecture,
            collection_metadata,
            os_info,
            hardware_info,
            network_info,
            package_info,
            additional_data,
        })
    }
    
    /// Extract plugin data from raw JSON
    fn extract_plugin_data(&self, obj: &serde_json::Map<String, serde_json::Value>, plugin_name: &str) -> Option<serde_json::Value> {
        obj.get(plugin_name)
           .and_then(|plugin| plugin.get("data"))
           .cloned()
    }
    
    /// Extract and combine network information from multiple plugins
    fn extract_network_info(&self, obj: &serde_json::Map<String, serde_json::Value>) -> Option<serde_json::Value> {
        let mut network_data = serde_json::Map::new();
        
        // Combine IP info, network stats, and LLDP neighbors
        if let Some(ip_data) = self.extract_plugin_data(obj, "get_ip_info") {
            network_data.insert("interfaces".to_string(), ip_data);
        }
        
        if let Some(stats_data) = self.extract_plugin_data(obj, "get_network_stats") {
            network_data.insert("statistics".to_string(), stats_data);
        }
        
        if let Some(lldp_data) = self.extract_plugin_data(obj, "get_lldp_neighbors") {
            network_data.insert("neighbors".to_string(), lldp_data);
        }
        
        if network_data.is_empty() {
            None
        } else {
            Some(serde_json::Value::Object(network_data))
        }
    }
    
    /// Generate cache key for current configuration
    fn generate_cache_key(&self) -> String {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};
        
        let mut hasher = DefaultHasher::new();
        self.config.max_packages.hash(&mut hasher);
        self.config.max_executables.hash(&mut hasher);
        self.config.enable_sudo.hash(&mut hasher);
        self.config.enable_hashing.hash(&mut hasher);
        
        format!("system_info_{:x}", hasher.finish())
    }
    
    /// Collect system information with minimal dependencies (optimized for speed)
    pub async fn collect_minimal(&mut self) -> Result<CollectionResult> {
        let start_time = Instant::now();
        let collection_id = Uuid::new_v4();
        let timestamp = chrono::Utc::now();
        
        info!("Starting minimal system information collection {}", collection_id);
        
        // Use fast collection script with minimal dependencies
        let output = TokioCommand::new("./collect_info_fast.sh")
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .env("MAX_PACKAGES", "10") // Reduced for speed
            .env("MAX_EXECUTABLES", "5") // Reduced for speed
            .env("ENABLE_HASHING", "0") // Disabled for speed
            .env("ENABLE_SUDO_SUPPORT", "0") // Disabled for speed
            .output()
            .await
            .map_err(|e| AutomationError::System(format!("Failed to execute fast collection script: {}", e)))?;
        
        let duration_ms = start_time.elapsed().as_millis() as u64;
        
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            error!("Fast collection script failed: {}", stderr);
            
            return Ok(CollectionResult {
                id: collection_id,
                system_info: SystemInfo {
                    detected_architecture: "unknown".to_string(),
                    collection_metadata: CollectionMetadata {
                        timestamp,
                        plugin_count: 0,
                        hashing_enabled: false,
                        sudo_support_enabled: false,
                        sudo_available: false,
                        duration_ms: Some(duration_ms),
                    },
                    os_info: None,
                    hardware_info: None,
                    network_info: None,
                    package_info: None,
                    additional_data: std::collections::HashMap::new(),
                },
                duration_ms,
                success: false,
                error_message: Some(String::from_utf8_lossy(&output.stderr).to_string()),
                from_cache: false,
                timestamp,
            });
        }
        
        let stdout = String::from_utf8_lossy(&output.stdout);
        let raw_data: serde_json::Value = serde_json::from_str(&stdout)
            .map_err(|e| AutomationError::Validation(format!("Invalid JSON output: {}", e)))?;
        
        let system_info = self.parse_system_info(raw_data)?;
        
        // Update statistics
        self.stats.total_collections += 1;
        self.stats.successful_collections += 1;
        self.stats.last_collection_at = Some(timestamp);
        
        info!("Minimal system information collection {} completed in {}ms", collection_id, duration_ms);
        
        Ok(CollectionResult {
            id: collection_id,
            system_info,
            duration_ms,
            success: true,
            error_message: None,
            from_cache: false,
            timestamp,
        })
    }
    
    /// Get collection statistics
    pub fn get_stats(&self) -> &CollectionStats {
        &self.stats
    }
    
    /// Get performance metrics
    pub async fn get_performance_metrics(&self) -> crate::types::PerformanceMetrics {
        let optimizer_metrics = self.optimizer.get_performance_metrics().await;
        
        PerformanceMetrics {
            response_times: optimizer_metrics.response_times,
            resource_usage: optimizer_metrics.resource_usage,
            system_load: optimizer_metrics.system_load,
            timestamp: chrono::Utc::now(),
        }
    }
    
    /// Clear performance cache
    pub async fn clear_cache(&self) {
        self.optimizer.clear_caches().await;
    }
    
    /// Update configuration
    pub fn update_config(&mut self, config: ProfilerConfig) {
        self.config = config;
    }
    
    /// Test system collection capabilities
    pub async fn test_collection(&self) -> Result<Vec<String>> {
        let mut results = Vec::new();
        
        // Test script availability
        let script_exists = tokio::fs::metadata(&self.config.script_path).await.is_ok();
        results.push(format!("Script exists ({}): {}", self.config.script_path, script_exists));
        
        // Test script executability
        if script_exists {
            let output = TokioCommand::new(&self.config.script_path)
                .arg("--help")
                .output()
                .await;
            
            match output {
                Ok(output) => {
                    results.push(format!("Script executable: {}", output.status.success()));
                }
                Err(e) => {
                    results.push(format!("Script execution test failed: {}", e));
                }
            }
        }
        
        // Test plugin availability
        let plugins_dir = tokio::fs::read_dir("./plugins").await;
        match plugins_dir {
            Ok(mut entries) => {
                let mut plugin_count = 0;
                while let Ok(Some(_)) = entries.next_entry().await {
                    plugin_count += 1;
                }
                results.push(format!("Plugins available: {}", plugin_count));
            }
            Err(e) => {
                results.push(format!("Plugin directory check failed: {}", e));
            }
        }
        
        Ok(results)
    }
}

impl Default for SystemProfiler {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_profiler_creation() {
        let profiler = SystemProfiler::new();
        assert_eq!(profiler.config.timeout_seconds, 30);
        assert!(profiler.config.enable_parallel);
    }
    
    #[tokio::test]
    async fn test_cache_key_generation() {
        let profiler = SystemProfiler::new();
        let key1 = profiler.generate_cache_key();
        let key2 = profiler.generate_cache_key();
        assert_eq!(key1, key2); // Should be identical for same config
    }
    
    #[tokio::test]
    async fn test_config_update() {
        let mut profiler = SystemProfiler::new();
        
        let mut new_config = ProfilerConfig::default();
        new_config.timeout_seconds = 60;
        new_config.max_packages = 50;
        
        profiler.update_config(new_config);
        assert_eq!(profiler.config.timeout_seconds, 60);
        assert_eq!(profiler.config.max_packages, 50);
    }
}