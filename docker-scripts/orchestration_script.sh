#!/bin/bash


set -e

NETWORK_NAME="personal-portfolio_dev_network"

FRONTEND_URL=http://localhost,https://localhost
BACKEND_PORT=4000
FRONTEND_PORT=80

POSTGRES_IMAGE="personal-portfolio_postgres_dev_image"
MIGRATION_IMAGE="personal-portfolio_migrations_image"
BACKEND_IMAGE="personal-portfolio_backend_image"
FRONTEND_IMAGE="personal-portfolio_frontend_image"

POSTGRES_CONTAINER="personal-portfolio_postgres_dev"
MIGRATION_CONTAINER="personal-portfolio_migrations"
BACKEND_CONTAINER="personal-portfolio_backend"
FRONTEND_CONTAINER="personal-portfolio_frontend"

POSTGRES_DOCKERFILE="../../personal-portfolio-db-schema/postgresql"
MIGRATION_DOCKERFILE="../../personal-portfolio-db-schema/schema/dev/Dockerfile"
BACKEND_DOCKERFILE="../../personal-portfolio-main-back"
FRONTEND_DOCKERFILE="../../personal-portfolio-main-front"

MIGRATION_CONTEXT="../../personal-portfolio-db-schema/schema"

POSTGRES_HOST="postgres-dev"
POSTGRES_PORT="5432"
POSTGRES_USER="dev_user"
POSTGRES_PASSWORD="mypassword"
POSTGRES_DB="dev_db"

# "postgres://dev_user:mypassword@postgres-dev:5432/dev_db?sslmode=disable"
DATABASE_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=disable"

POSTGRES_VOLUME=personal-portfolio_postgres_volume

NETWORK_ALIAS=${POSTGRES_HOST}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^$1$"
}

container_running() {
    docker ps --format '{{.Names}}' | grep -q "^$1$"
}

create_network() {
    if docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
        print_status "Network ${NETWORK_NAME} already exists"
    else
        print_status "Creating development network: ${NETWORK_NAME}"
        docker network create ${NETWORK_NAME}
    fi
}

wait_for_postgres() {
    print_status "Waiting for PostgreSQL to be ready"
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if docker exec ${POSTGRES_CONTAINER} pg_isready -h localhost -p ${POSTGRES_PORT} -U ${POSTGRES_USER} > /dev/null 2>&1; then
            print_status "PostgreSQL is ready!"
            return 0
        fi

        print_status "Attempt $attempt/$max_attempts - PostgreSQL not ready yet, waiting 2 seconds"
        sleep 2
        attempt=$((attempt + 1))
    done

    print_error "PostgreSQL failed to start within expected time"
    return 1
}

start_postgres() {
    print_section "Starting PostgreSQL Development Database"

    if container_running ${POSTGRES_CONTAINER}; then
        print_status "PostgreSQL container already running"
        return 0
    fi

    print_status "Building and starting new PostgreSQL container"
    docker build -t ${POSTGRES_IMAGE} ${POSTGRES_DOCKERFILE}
    print_status "PostgreSQL Built"
    docker run -d \
        --name ${POSTGRES_CONTAINER} \
        --network ${NETWORK_NAME} \
        --network-alias ${NETWORK_ALIAS} \
        -p ${POSTGRES_PORT}:${POSTGRES_PORT} \
        -e POSTGRES_DB=${POSTGRES_DB} \
        -e POSTGRES_USER=${POSTGRES_USER} \
        -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
        -e POSTGRES_LISTEN_ADDRESSES='*' \
        -v ${POSTGRES_VOLUME}:/var/lib/postgresql/data \
        ${POSTGRES_IMAGE}

    wait_for_postgres
}

run_migrations() {
    print_section "Running Database Migrations"

    local original_dir
    original_dir=$(pwd)

    print_status "Building migration container"
    docker build -f ${MIGRATION_DOCKERFILE} -t "${MIGRATION_IMAGE}" ${MIGRATION_CONTEXT}

    print_status "Applying database migrations"
    print_status "changing to migrations directory"
    pwd
    print_status "applying migrations"
    docker run --rm \
        --network ${NETWORK_NAME} \
        -e DATABASE_URL="${DATABASE_URL}" \
        -e POSTGRES_HOST=${POSTGRES_HOST} \
        -e POSTGRES_PORT=${POSTGRES_PORT} \
        -e POSTGRES_USER=${POSTGRES_USER} \
        -e POSTGRES_DB=${POSTGRES_DB} \
        ${MIGRATION_IMAGE} up

    cd "${original_dir}"

    sleep 5

    print_status "Migrations completed successfully"
}

start_backend() {
    print_section "Starting Backend Services"

    if container_running $BACKEND_CONTAINER; then
        print_status "Backend container already running"
        return 0
    fi

    print_status "Building backend container"
    docker build -t ${BACKEND_IMAGE} ${BACKEND_DOCKERFILE}

    docker run \
        -e ENV=development \
        -e DATABASE_URL="${DATABASE_URL}" \
        -e ALLOWED_ORIGINS=${FRONTEND_URL} \
        -e PORT=${BACKEND_PORT} \
        --network ${NETWORK_NAME} \
        --name ${BACKEND_CONTAINER} \
        -p ${BACKEND_PORT}:${BACKEND_PORT} \
        -d ${BACKEND_IMAGE}

    sleep 2

    if container_running $BACKEND_CONTAINER; then
        print_status "Backend container started successfully"
    else
        print_error "Backend container failed to start"
        docker logs ${BACKEND_CONTAINER}
        return 1
    fi
}

start_frontend() {
    print_section "Starting Frontend Services"

    if container_running $FRONTEND_CONTAINER; then
        print_status "Frontend container already running"
        return 0
    fi

    print_status "Build frontend container"
    docker build --build-arg NODE_ENV=development --build-arg REACT_APP_API_URL=http://localhost:4000 -t ${FRONTEND_IMAGE} ${FRONTEND_DOCKERFILE}

    print_status "Starting frontend container"
    docker run \
      --name ${FRONTEND_CONTAINER} \
      -p ${FRONTEND_PORT}:${FRONTEND_PORT} \
      -d ${FRONTEND_IMAGE}

    print_status "Frontend container started"

}

stop_services() {
    print_section "Stopping Development Environment"

    docker stop ${FRONTEND_CONTAINER} || true
    docker stop ${BACKEND_CONTAINER} || true
    docker stop ${POSTGRES_CONTAINER} || true
    docker stop ${MIGRATION_CONTAINER} || true

    docker rm ${FRONTEND_CONTAINER} || true
    docker rm ${BACKEND_CONTAINER} || true
    docker rm ${POSTGRES_CONTAINER} || true
    docker rm ${MIGRATION_CONTAINER} || true

    docker network rm ${NETWORK_NAME} || true

    print_status "Network and containers have been removed successfully."
}

cleanup() {
    print_section "Cleaning Up Development Environment"

    stop_services

    docker volume rm ${POSTGRES_VOLUME} || true

    # Clean up local secrets
    if [ -d "./dev-secrets" ]; then
        print_status "Removing local development secrets"
        rm -rf ./dev-secrets
    fi

    print_status "Cleanup completed"
}

migration_command() {
    if [ -z "$1" ]; then
        print_error "Usage: $0 migrate <command>"
        echo "Available commands: up, down, status, create <name>"
        exit 1
    fi

    if ! container_running ${POSTGRES_CONTAINER}; then
        print_error "PostgreSQL container is not running. Start the environment first."
        exit 1
    fi

    print_status "Running migration command: $1"
    docker run --rm \
        --network $NETWORK_NAME \
        -e POSTGRES_HOST=${POSTGRES_HOST} \
        -e POSTGRES_PORT=${POSTGRES_PORT} \
        -e POSTGRES_USER=${POSTGRES_USER} \
        -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
        -e POSTGRES_DB=${POSTGRES_DB} \
        ${MIGRATION_IMAGE} "$@"
}

case "${1:-start}" in
    "start")
        print_section "Starting Complete Development Environment"
        print_status "Cleanup first"
        stop_services
        cleanup
        print_status "Starting now"
        create_network
        start_postgres
        run_migrations
        start_backend
        start_frontend
        print_status "Development environment is ready!"
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        stop_services
        sleep 2
        create_network
        start_postgres
        run_migrations
        start_backend
        start_frontend
        ;;
    "clean")
        stop_services
        cleanup
        ;;
    "migrate")
        shift
        migration_command "$@"
        ;;
    "help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  start          Start the complete development environment (default)"
        echo "  stop           Stop all running services"
        echo "  restart        Stop and restart all services"
        echo "  clean          Stop and remove all containers and networks"
        echo "  migrate <cmd>  Run migration commands (up, down, status, create <name>)"
        echo "  help           Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                           # Start everything"
        echo "  $0 migrate status            # Check migration status"
        echo "  $0 migrate create add_users  # Create a new migration"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
