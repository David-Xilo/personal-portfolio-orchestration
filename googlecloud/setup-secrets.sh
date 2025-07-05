#!/bin/bash
set -e

PROJECT_ID="personal-portfolio-safehouse"

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

echo "Creating database password secret..."
if ! gcloud secrets describe portfolio-safehouse-db-password --quiet 2>/dev/null; then
    DB_PASSWORD=$(openssl rand -base64 32)
    echo -n "$DB_PASSWORD" | gcloud secrets create portfolio-safehouse-db-password --data-file=-
    echo "Database password secret created with generated password"
else
    echo "Database password secret already exists"
fi

echo "Creating terraform service account key secret"
if ! gcloud secrets describe personal-portfolio-terraform-key --quiet 2>/dev/null; then
    echo "Terraform service account key secret not found."
else
    echo "Terraform service account key secret already exists"
fi

echo "Creating deployment tracking secret..."
if ! gcloud secrets describe safehouse-latest-deployment --quiet 2>/dev/null; then
    echo '{"image":"none","timestamp":"initial"}' | gcloud secrets create safehouse-latest-deployment --data-file=-
    echo "Deployment tracking secret created"
else
    echo "Deployment tracking secret already exists"
fi

echo "Creating GitHub Actions demo secret..."
if ! gcloud secrets describe github-actions-demo-secret --quiet 2>/dev/null; then
    echo "demo-value" | gcloud secrets create github-actions-demo-secret --data-file=-
    echo "Demo secret created (you can delete this later)"
else
    echo "Demo secret already exists"
fi

echo "Secret setup complete!"
