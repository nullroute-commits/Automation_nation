//! System profiler CLI for Automation Nation
//!
//! This binary provides command-line system information collection capabilities

use automation_nation::SystemProfiler;
use clap::{Parser, Subcommand};
use log::info;

#[derive(Parser)]
#[command(name = "system_profiler")]
#[command(about = "Automation Nation System Profiler CLI")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
    
    /// Enable debug logging
    #[arg(short, long)]
    debug: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// Collect full system information
    Collect {
        /// Output file (JSON format)
        #[arg(short, long)]
        output: Option<String>,
        /// Use minimal collection for faster response
        #[arg(short, long)]
        minimal: bool,
        /// Pretty-print JSON output
        #[arg(short, long)]
        pretty: bool,
    },
    /// Test system collection capabilities
    Test,
    /// Show collection statistics
    Stats,
    /// Show performance metrics
    Performance,
    /// Clear performance cache
    ClearCache,
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();
    
    // Initialize logging
    if cli.debug {
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("debug")).init();
    } else {
        env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    }
    
    let mut profiler = SystemProfiler::new();
    
    match cli.command {
        Commands::Collect { output, minimal, pretty } => {
            println!("🔍 Collecting system information...");
            
            let start_time = std::time::Instant::now();
            
            let result = if minimal {
                profiler.collect_minimal().await
            } else {
                profiler.collect_system_info().await
            };
            
            match result {
                Ok(collection_result) => {
                    let duration = start_time.elapsed();
                    
                    println!("✅ Collection completed successfully!");
                    println!("   Collection ID: {}", collection_result.id);
                    println!("   Duration: {:?}", duration);
                    println!("   From cache: {}", collection_result.from_cache);
                    println!("   Architecture: {}", collection_result.system_info.detected_architecture);
                    println!("   Plugin count: {}", collection_result.system_info.collection_metadata.plugin_count);
                    
                    // Serialize to JSON
                    let json_output = if pretty {
                        serde_json::to_string_pretty(&collection_result.system_info)
                    } else {
                        serde_json::to_string(&collection_result.system_info)
                    };
                    
                    match json_output {
                        Ok(json) => {
                            if let Some(output_file) = output {
                                // Write to file
                                match tokio::fs::write(&output_file, &json).await {
                                    Ok(_) => println!("📁 Output written to: {}", output_file),
                                    Err(e) => eprintln!("❌ Failed to write output file: {}", e),
                                }
                            } else {
                                // Print to stdout
                                println!("\n📊 System Information:");
                                println!("{}", json);
                            }
                        }
                        Err(e) => {
                            eprintln!("❌ Failed to serialize JSON: {}", e);
                            std::process::exit(1);
                        }
                    }
                }
                Err(e) => {
                    eprintln!("❌ Collection failed: {}", e);
                    std::process::exit(1);
                }
            }
        }
        
        Commands::Test => {
            println!("🧪 Testing system collection capabilities...");
            
            match profiler.test_collection().await {
                Ok(test_results) => {
                    println!("📋 Test Results:");
                    for result in test_results {
                        println!("   • {}", result);
                    }
                }
                Err(e) => {
                    eprintln!("❌ Test failed: {}", e);
                    std::process::exit(1);
                }
            }
        }
        
        Commands::Stats => {
            let stats = profiler.get_stats();
            
            println!("📈 Collection Statistics:");
            println!("   Total collections: {}", stats.total_collections);
            println!("   Successful: {}", stats.successful_collections);
            println!("   Failed: {}", stats.failed_collections);
            println!("   Average duration: {:.2}ms", stats.avg_collection_time_ms);
            println!("   Cache hit rate: {:.1}%", stats.cache_hit_rate * 100.0);
            
            if let Some(last_collection) = stats.last_collection_at {
                println!("   Last collection: {}", last_collection);
            }
            
            if stats.total_collections > 0 {
                let success_rate = (stats.successful_collections as f64 / stats.total_collections as f64) * 100.0;
                println!("   Success rate: {:.1}%", success_rate);
            }
        }
        
        Commands::Performance => {
            println!("⚡ Collecting performance metrics...");
            
            let metrics = profiler.get_performance_metrics().await;
            
            println!("📊 Performance Metrics:");
            println!("   Response Times:");
            println!("     • Average: {:.2}ms", metrics.response_times.avg_response_time_ms);
            println!("     • Median: {:.2}ms", metrics.response_times.median_response_time_ms);
            println!("     • 95th percentile: {:.2}ms", metrics.response_times.p95_response_time_ms);
            println!("     • 99th percentile: {:.2}ms", metrics.response_times.p99_response_time_ms);
            println!("     • Min: {}ms", metrics.response_times.min_response_time_ms);
            println!("     • Max: {}ms", metrics.response_times.max_response_time_ms);
            println!("     • Total requests: {}", metrics.response_times.total_requests);
            
            println!("   Resource Usage:");
            println!("     • CPU usage: {:.1}%", metrics.resource_usage.cpu_usage_percent);
            println!("     • Memory usage: {} MB ({:.1}%)", 
                     metrics.resource_usage.memory_usage_mb, 
                     metrics.resource_usage.memory_usage_percent);
            println!("     • Disk IOPS: {}", metrics.resource_usage.disk_iops);
            println!("     • Network bytes/sec: {}", metrics.resource_usage.network_bytes_per_sec);
            
            println!("   System Load:");
            println!("     • Load avg (1m): {:.2}", metrics.system_load.load_avg_1min);
            println!("     • Load avg (5m): {:.2}", metrics.system_load.load_avg_5min);
            println!("     • Load avg (15m): {:.2}", metrics.system_load.load_avg_15min);
            println!("     • Active processes: {}", metrics.system_load.active_processes);
            println!("     • Uptime: {}s", metrics.system_load.uptime_seconds);
        }
        
        Commands::ClearCache => {
            println!("🗑️  Clearing performance cache...");
            profiler.clear_cache().await;
            println!("✅ Cache cleared successfully!");
        }
    }
}