#!/bin/bash
# Development setup script for Automation Nation

set -e

echo "🚀 Automation Nation - Development Setup"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker and Docker Compose are available
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Create .env file if it doesn't exist
setup_environment() {
    print_status "Setting up environment..."
    
    if [ ! -f .env ]; then
        print_status "Creating .env file from template..."
        cp .env.template .env
        print_warning "Please review and update the .env file with your preferred settings"
    else
        print_status ".env file already exists"
    fi
}

# Determine Docker Compose command
get_compose_cmd() {
    if command -v docker compose &> /dev/null; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        print_error "No Docker Compose command found"
        exit 1
    fi
}

# Build and start services
start_services() {
    local compose_cmd=$(get_compose_cmd)
    
    print_status "Building development environment..."
    $compose_cmd build python-dev
    
    print_status "Starting services..."
    $compose_cmd up -d postgres
    
    print_status "Waiting for PostgreSQL to be ready..."
    sleep 10
    
    print_status "Starting Python development container..."
    $compose_cmd up -d python-dev
    
    print_success "Services started successfully!"
}

# Setup Python virtual environment
setup_python_env() {
    local compose_cmd=$(get_compose_cmd)
    
    print_status "Setting up Python virtual environment inside container..."
    
    # Ensure the virtual environment is properly set up
    $compose_cmd exec python-dev bash -c "
        if [ ! -d .venv ]; then
            python -m venv .venv
        fi
        source .venv/bin/activate
        pip install --upgrade pip
        pip install -r requirements.txt
    "
    
    print_success "Python environment setup complete!"
}

# Show service status and helpful information
show_status() {
    local compose_cmd=$(get_compose_cmd)
    
    print_status "Service Status:"
    $compose_cmd ps
    
    echo ""
    print_success "Development environment is ready!"
    echo ""
    echo "🔗 Available services:"
    echo "   • PostgreSQL Database: localhost:5432"
    echo "   • Python API (when running): localhost:8000"
    echo "   • pgAdmin (optional): localhost:8080"
    echo ""
    echo "🐍 To work with Python:"
    echo "   $compose_cmd exec python-dev bash"
    echo "   source .venv/bin/activate"
    echo "   python src/main.py"
    echo ""
    echo "📊 To access pgAdmin (optional):"
    echo "   $compose_cmd --profile tools up -d pgadmin"
    echo "   Open http://localhost:8080"
    echo "   Email: admin@automation-nation.dev"
    echo "   Password: admin"
    echo ""
    echo "🗄️  Database connection details:"
    echo "   Host: localhost"
    echo "   Port: 5432"
    echo "   Database: automation_nation_dev"
    echo "   Username: automation_dev"
    echo "   Password: dev_password"
    echo ""
    echo "🛑 To stop services:"
    echo "   $compose_cmd down"
}

# Main execution
main() {
    case "${1:-start}" in
        "start")
            check_prerequisites
            setup_environment
            start_services
            setup_python_env
            show_status
            ;;
        "stop")
            print_status "Stopping services..."
            $(get_compose_cmd) down
            print_success "Services stopped"
            ;;
        "restart")
            print_status "Restarting services..."
            $(get_compose_cmd) down
            sleep 2
            $0 start
            ;;
        "status")
            $(get_compose_cmd) ps
            ;;
        "logs")
            $(get_compose_cmd) logs -f "${2:-python-dev}"
            ;;
        "shell")
            $(get_compose_cmd) exec python-dev bash
            ;;
        "help"|*)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  start    - Start development environment (default)"
            echo "  stop     - Stop all services"
            echo "  restart  - Restart all services"
            echo "  status   - Show service status"
            echo "  logs     - Show logs (optionally specify service name)"
            echo "  shell    - Open shell in Python development container"
            echo "  help     - Show this help message"
            ;;
    esac
}

main "$@"