# Automation Nation - Development Environment

This guide explains how to set up and use the Docker Compose-based development environment for Automation Nation with PostgreSQL database and Python virtual environment support.

## Quick Start

1. **Clone the repository** (if not already done):
   ```bash
   git clone <repository-url>
   cd Automation_nation
   ```

2. **Start the development environment**:
   ```bash
   ./dev-setup.sh start
   ```

3. **Access the Python development container**:
   ```bash
   ./dev-setup.sh shell
   source .venv/bin/activate
   ```

4. **Run the Python API** (inside the container):
   ```bash
   python src/main.py
   ```

## Architecture

The development environment consists of:

- **PostgreSQL Database** (`postgres`): Primary database for storing system information
- **Python Development Container** (`python-dev`): Python 3.11 environment with virtual environment
- **pgAdmin** (optional): Web-based PostgreSQL administration tool

## Services and Ports

| Service | Port | Description |
|---------|------|-------------|
| PostgreSQL | 5432 | Database server |
| Python API | 8000 | FastAPI application |
| Python Debugger | 5678 | debugpy remote debugging |
| pgAdmin | 8080 | Database administration (optional) |

## Docker Compose Configuration

### Core Services

```yaml
services:
  postgres:        # PostgreSQL 15 with alpine
  python-dev:      # Python 3.11 development environment
  pgadmin:         # Optional database administration
```

### Key Features

- **Volume Mounting**: Current directory mounted read-write at `/app`
- **Virtual Environment**: Python venv created and managed inside container
- **Database Integration**: Pre-configured PostgreSQL connection
- **Development Tools**: Includes debugging, testing, and linting tools

## Development Workflow

### 1. Environment Setup

```bash
# Start all services
./dev-setup.sh start

# Check service status
./dev-setup.sh status

# View logs
./dev-setup.sh logs
./dev-setup.sh logs postgres
```

### 2. Python Development

```bash
# Enter development container
./dev-setup.sh shell

# Activate virtual environment
source .venv/bin/activate

# Install additional packages
pip install package-name

# Run the application
python src/main.py

# Run tests
pytest

# Format code
black src/
isort src/

# Lint code
flake8 src/
```

### 3. Database Operations

```bash
# Connect to PostgreSQL (from host)
psql -h localhost -p 5432 -U automation_dev -d automation_nation_dev

# Connect to PostgreSQL (from container)
docker compose exec postgres psql -U automation_dev -d automation_nation_dev

# Access pgAdmin (optional)
docker compose --profile tools up -d pgadmin
# Open http://localhost:8080
```

### 4. Integration with Bash Scripts

The existing Bash scripts are available in the Python container:

```bash
# Inside the container
./collect_info.sh                    # Run system info collection
./collect_info.sh -o output.json     # Save to file
./dependency_manager.sh check        # Check dependencies
```

The Python API provides endpoints to trigger these scripts:

```bash
# Test the API
curl http://localhost:8000/
curl -X POST http://localhost:8000/collect/system-info
curl http://localhost:8000/plugins
```

## Environment Variables

The `.env` file contains configuration for the development environment:

```bash
# Database
DATABASE_URL=postgresql://automation_dev:dev_password@postgres:5432/automation_nation_dev

# Application
DEBUG=True
ENVIRONMENT=development
SECRET_KEY=your-secret-key-here

# API
API_HOST=0.0.0.0
API_PORT=8000
```

## Database Schema

The PostgreSQL database includes tables for:

- `system_info`: System information collection results
- `collection_runs`: Metadata about collection runs
- `plugin_results`: Individual plugin execution results

See `init.sql` for the complete schema.

## File Structure

```
.
├── docker-compose.yml          # Main compose configuration
├── Dockerfile.dev              # Development container definition
├── dev-setup.sh               # Development setup script
├── requirements.txt           # Python dependencies
├── .env.template             # Environment variables template
├── init.sql                  # Database initialization
├── src/
│   ├── main.py              # FastAPI application
│   └── models.py            # Database models
└── [existing bash scripts]   # Original automation tools
```

## Common Commands

```bash
# Development lifecycle
./dev-setup.sh start          # Start environment
./dev-setup.sh stop           # Stop all services
./dev-setup.sh restart        # Restart services
./dev-setup.sh shell          # Enter Python container
./dev-setup.sh logs           # View logs

# Docker Compose direct commands
docker compose up -d           # Start services
docker compose down            # Stop services
docker compose ps             # Show status
docker compose logs -f        # Follow logs
docker compose exec python-dev bash  # Enter container
```

## Troubleshooting

### PostgreSQL Connection Issues

```bash
# Check if PostgreSQL is running
docker compose ps postgres

# Check PostgreSQL logs
docker compose logs postgres

# Test connection
docker compose exec postgres psql -U automation_dev -d automation_nation_dev -c "SELECT 1;"
```

### Python Environment Issues

```bash
# Rebuild Python container
docker compose build python-dev

# Recreate virtual environment
docker compose exec python-dev bash -c "rm -rf .venv && python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt"
```

### Volume and Permission Issues

```bash
# Check volume mounts
docker compose exec python-dev ls -la /app

# Fix permissions (if needed)
docker compose exec python-dev chown -R appuser:appuser /app
```

## Production Considerations

This development environment is optimized for local development. For production deployment:

1. Use production-grade PostgreSQL configuration
2. Implement proper secrets management
3. Configure appropriate security settings
4. Use production WSGI server (gunicorn/uvicorn)
5. Implement monitoring and logging
6. Set up backup and recovery procedures

## Security Notes

- Default passwords are used for development convenience
- Change all passwords before production use
- The `.env` file contains sensitive information - keep it secure
- PostgreSQL is accessible without SSL in development mode