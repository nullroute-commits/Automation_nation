-- Initialization script for Automation Nation Development Database

-- Create additional database user for development
CREATE USER automation_readonly WITH PASSWORD 'readonly_password';

-- Grant appropriate permissions
GRANT CONNECT ON DATABASE automation_nation_dev TO automation_readonly;
GRANT USAGE ON SCHEMA public TO automation_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO automation_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO automation_readonly;

-- Create sample tables for system information collection
CREATE TABLE IF NOT EXISTS system_info (
    id SERIAL PRIMARY KEY,
    collected_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    hostname VARCHAR(255),
    architecture VARCHAR(50),
    os_name VARCHAR(255),
    os_version VARCHAR(255),
    kernel_version VARCHAR(255),
    data JSONB,
    checksum VARCHAR(64)
);

CREATE TABLE IF NOT EXISTS collection_runs (
    id SERIAL PRIMARY KEY,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'running',
    plugin_count INTEGER,
    duration_ms INTEGER,
    error_message TEXT
);

CREATE TABLE IF NOT EXISTS plugin_results (
    id SERIAL PRIMARY KEY,
    collection_run_id INTEGER REFERENCES collection_runs(id),
    plugin_name VARCHAR(100),
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    success BOOLEAN DEFAULT TRUE,
    execution_time_ms INTEGER,
    data JSONB,
    error_message TEXT
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_system_info_collected_at ON system_info(collected_at);
CREATE INDEX IF NOT EXISTS idx_system_info_hostname ON system_info(hostname);
CREATE INDEX IF NOT EXISTS idx_system_info_architecture ON system_info(architecture);
CREATE INDEX IF NOT EXISTS idx_collection_runs_started_at ON collection_runs(started_at);
CREATE INDEX IF NOT EXISTS idx_plugin_results_collection_run_id ON plugin_results(collection_run_id);
CREATE INDEX IF NOT EXISTS idx_plugin_results_plugin_name ON plugin_results(plugin_name);

-- Insert sample data
INSERT INTO system_info (hostname, architecture, os_name, os_version, kernel_version, data) 
VALUES (
    'development-host',
    'x86_64',
    'Ubuntu',
    '22.04 LTS',
    '5.15.0',
    '{"sample": true, "environment": "development"}'::jsonb
);

-- Grant permissions on new tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO automation_readonly;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO automation_dev;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO automation_dev;