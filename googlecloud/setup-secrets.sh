#!/bin/bash
set -e

PROJECT_ID="personal-portfolio-safehouse"

# secrets to create
DB_PASSWORD_SECRET_NAME="safehouse-db-password"
JWT_SECRET_NAME="safehouse-jwt-signing-key"
FRONTEND_AUTH_SECRET_NAME="safehouse-frontend-auth-key"

echo "Setting up secrets for project: $PROJECT_ID"

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "No active gcloud authentication found. Please run:"
    echo "gcloud auth login"
    echo "gcloud auth application-default login"
    exit 1
fi

gcloud config set project $PROJECT_ID

echo "Enabling Secret Manager API"
gcloud services enable secretmanager.googleapis.com

echo "Creating database password secret"
if ! gcloud secrets describe "${DB_PASSWORD_SECRET_NAME}" --quiet 2>/dev/null; then
    DB_PASSWORD=$(openssl rand -base64 32)
    echo -n "${DB_PASSWORD}" | gcloud secrets create "${DB_PASSWORD_SECRET_NAME}" --data-file=-
    echo "Database password secret created with generated password"
else
    echo "Database password secret already exists"
fi

echo "Creating JWT secret"
if ! gcloud secrets describe "${JWT_SECRET_NAME}" --quiet 2>/dev/null; then
    JWT_SECRET=$(openssl rand -base64 32)
    echo -n "${JWT_SECRET}" | gcloud secrets create "${JWT_SECRET_NAME}" --data-file=-
    echo "JWT secret created with generated password"
else
    echo "JWT secret already exists"
fi

echo "Creating frontend auth secret"
if ! gcloud secrets describe "${FRONTEND_AUTH_SECRET_NAME}" --quiet 2>/dev/null; then
    FE_AUTH_SECRET=$(openssl rand -base64 32)
    echo -n "${FE_AUTH_SECRET}" | gcloud secrets create "${FRONTEND_AUTH_SECRET_NAME}" --data-file=-
    echo "Frontend auth secret created with generated password"
else
    echo "Frontend auth secret already exists"
fi

echo "Secret setup complete!"
