#!/bin/bash
# scripts/run-migration.sh
# Usage: ./run-migration.sh <migration_version> <project_id>

set -e

MIGRATION_VERSION=${1:-latest}
PROJECT_ID=${2:-03936bb2-d116-4765-beeb-c29074266234}
TIMESTAMP=$(date +%s)
SERVICE_NAME="safehouse-migration-${TIMESTAMP}"

echo "🚀 Starting database migration deployment..."
echo "Migration version: ${MIGRATION_VERSION}"
echo "Project ID: ${PROJECT_ID}"
echo "Service name: ${SERVICE_NAME}"

# Check if Railway token is set
if [ -z "$RAILWAY_TOKEN" ]; then
    echo "❌ ERROR: RAILWAY_TOKEN environment variable not set"
    exit 1
fi

# Function to cleanup migration service
cleanup_migration_service() {
    echo "🧹 Cleaning up migration service: ${SERVICE_NAME}"
    railway service delete ${SERVICE_NAME} --yes 2>/dev/null || echo "Service already deleted or not found"
    echo "💰 Migration service cleaned up to avoid ongoing costs"
}

# Set up cleanup trap
trap cleanup_migration_service EXIT

# Authenticate with Railway
echo "🔐 Authenticating with Railway..."
railway login --token $RAILWAY_TOKEN 2>/dev/null || {
    echo "❌ Railway authentication failed"
    exit 1
}

# Link to project
echo "🔗 Linking to project ${PROJECT_ID}..."
railway link ${PROJECT_ID}

# Create temporary migration service
echo "📦 Creating migration service: ${SERVICE_NAME}"
railway service create ${SERVICE_NAME} --image "xilo/safehouse-db-schema:${MIGRATION_VERSION}"

# Link to the new service
railway link --service ${SERVICE_NAME}

# Set up environment variables for the migration service
echo "⚙️  Configuring migration service..."
railway variables set MIGRATION_TIMEOUT=300
railway variables set MIGRATION_VERBOSE=true
railway variables set RAILWAY_ENVIRONMENT=production

# Connect to PostgreSQL database (get DATABASE_URL from postgres service)
echo "🔌 Connecting to database..."
POSTGRES_DATABASE_URL=$(railway variables get DATABASE_URL --service postgres)
railway variables set DATABASE_URL="${POSTGRES_DATABASE_URL}"

# Deploy the migration service
echo "🚀 Deploying migration service..."
railway up --service ${SERVICE_NAME}

# Monitor deployment with timeout
echo "📋 Monitoring migration progress..."
TIMEOUT=300  # 5 minutes
COUNTER=0
MIGRATION_SUCCESS=false

while [ $COUNTER -lt $TIMEOUT ]; do
    # Check if migration completed successfully
    if railway logs --service ${SERVICE_NAME} | grep -q "✅ Migrations completed successfully"; then
        echo "✅ Database migrations completed successfully!"
        MIGRATION_SUCCESS=true
        break
    fi

    # Check if migration failed
    if railway logs --service ${SERVICE_NAME} | grep -q "❌ Migration failed"; then
        echo "❌ Migration failed! Check logs:"
        railway logs --service ${SERVICE_NAME} --tail 20
        exit 1
    fi

    # Wait and increment counter
    sleep 5
    COUNTER=$((COUNTER + 5))

    if [ $((COUNTER % 30)) -eq 0 ]; then
        echo "⏳ Still waiting for migration... ($COUNTER/${TIMEOUT}s)"
    fi
done

if [ "$MIGRATION_SUCCESS" = false ]; then
    echo "⏰ Migration timed out after ${TIMEOUT} seconds"
    echo "📋 Final logs:"
    railway logs --service ${SERVICE_NAME} --tail 20
    exit 1
fi

# Show final migration status
echo "📋 Final migration logs:"
railway logs --service ${SERVICE_NAME} --tail 10

echo "🎉 Migration deployment completed successfully!"
echo "💰 Service will be cleaned up automatically..."
