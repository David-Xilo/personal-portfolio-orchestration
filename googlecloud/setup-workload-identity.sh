#!/bin/bash
set -e

SERVICE_ACCOUNT="safehouse-terraform-cicd"
SERVICE_ACCOUNT_FULL="safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com"
PROJECT_ID="personal-portfolio-safehouse"

echo "Setting up Workload Identity..."
gcloud config set project "${PROJECT_ID}"

echo "Enabling required APIs..."
gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable vpcaccess.googleapis.com
gcloud services enable iamcredentials.googleapis.com
gcloud services enable sts.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com

echo "Creating Workload Identity Pool..."
if ! gcloud iam workload-identity-pools describe safehouse-github-pool --location="global" --quiet 2>/dev/null; then
    gcloud iam workload-identity-pools create safehouse-github-pool \
        --location="global" \
        --display-name="GitHub Actions Pool"
    echo "Workload Identity Pool created"
else
    echo "Workload Identity Pool already exists"
fi

echo "Creating Workload Identity Provider..."
if ! gcloud iam workload-identity-pools providers describe safehouse-github-provider \
    --location="global" \
    --workload-identity-pool=safehouse-github-pool --quiet 2>/dev/null; then

    gcloud iam workload-identity-pools providers create-oidc safehouse-github-provider \
        --location="global" \
        --workload-identity-pool=safehouse-github-pool \
        --display-name="GitHub Actions Provider" \
        --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
        --attribute-condition="assertion.repository_owner == 'David-Xilo'" \
        --issuer-uri="https://token.actions.githubusercontent.com"
    echo "✅ Workload Identity Provider created"
else
    echo "✅ Workload Identity Provider already exists"
fi

echo "Creating Service Account..."
if ! gcloud iam service-accounts describe ${SERVICE_ACCOUNT_FULL} --quiet 2>/dev/null; then
    gcloud iam service-accounts create ${SERVICE_ACCOUNT} \
        --display-name="Terraform CI/CD Service Account"
    echo "Service Account created"
else
    echo "Service Account already exists"
fi

echo "🔑 Granting permissions to Service Account..."

# Specific service permissions
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_FULL}" \
    --role="roles/cloudsql.editor"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_FULL}" \
    --role="roles/run.developer"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_FULL}" \
    --role="roles/secretmanager.secretAccessor"

# Networking permissions - TODO: Consider reducing these if VPC creation/API enabling works
# roles/compute.networkAdmin may be reducible to roles/compute.networkUser + roles/servicenetworking.serviceAgent
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_FULL}" \
    --role="roles/compute.networkAdmin"

# roles/servicenetworking.networkAdmin may be reducible to roles/servicenetworking.serviceAgent  
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_FULL}" \
    --role="roles/servicenetworking.networkAdmin"

# Storage for audit logs
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_FULL}" \
    --role="roles/storage.objectAdmin"

# Logging configuration
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_FULL}" \
    --role="roles/logging.configWriter"

# Service usage (for API management) - TODO: Consider reducing to roles/serviceusage.serviceUsageConsumer if API enabling works
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_FULL}" \
    --role="roles/serviceusage.serviceUsageAdmin"

# Container Registry and analysis permissions for Go backend CI/CD
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_FULL}" \
    --role="roles/containeranalysis.admin"

echo "Container permissions granted"

echo "Permissions granted"

echo "Workload Identity setup complete!"
