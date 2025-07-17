#!/bin/bash

# GCP Infrastructure Bootstrap Script
# This script sets up the necessary service accounts, IAM roles, and workload identity
# for Terraform CI/CD and GitHub Actions integration

set -e  # Exit on any error

# Configuration variables
PROJECT_ID="personal-portfolio-safehouse"
PROJECT_NUMBER="942519139037"
GITHUB_USER="David-Xilo"
TERRAFORM_SA="safehouse-terraform-cicd"
CLOUD_RUN_SA="crun-sa"
WI_POOL_ID="safehouse-github-pool"
WI_PROVIDER_ID="safehouse-github-provider"

# Repository names
REPOS=(
    "safehouse-orchestration"
    "safehouse-db-schema"
    "safehouse-main-back"
    "safehouse-main-front"
)


# Set the active project
echo "Setting active project"
gcloud config set project $PROJECT_ID

# Create service accounts
echo "Creating Terraform CI/CD service account"
gcloud iam service-accounts create $TERRAFORM_SA \
    --display-name="Terraform CI/CD Service Account" \
    --project=$PROJECT_ID || true

echo "Creating Cloud Run service account"
gcloud iam service-accounts create $CLOUD_RUN_SA \
    --display-name="Cloud Run Service Account" \
    --project=$PROJECT_ID || true

# Grant IAM permissions to Terraform service account
gcloud projects add-iam-policy-binding personal-portfolio-safehouse \
    --member="serviceAccount:$TERRAFORM_SA@personal-portfolio-safehouse.iam.gserviceaccount.com" \
    --role="roles/run.admin"

echo "Granting service account viewer role"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$TERRAFORM_SA@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountViewer"

echo "Granting project IAM admin role"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$TERRAFORM_SA@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/resourcemanager.projectIamAdmin"

echo "Granting editor role"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$TERRAFORM_SA@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/editor"

echo "Granting storage admin role"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$TERRAFORM_SA@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

# Create workload identity pool and provider
echo "Creating workload identity pool"
gcloud iam workload-identity-pools create $WI_POOL_ID \
    --location="global" \
    --display-name="GitHub Actions Pool" \
    --project=$PROJECT_ID || true

echo "Creating workload identity provider"
gcloud iam workload-identity-pools providers create-oidc $WI_PROVIDER_ID \
    --location="global" \
    --workload-identity-pool="$WI_POOL_ID" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
    --project=$PROJECT_ID || true

# Grant workload identity user role for each repository
echo "Granting workload identity user roles"
for repo in "${REPOS[@]}"; do
    echo "Granting access for repository: $GITHUB_USER/$repo"
    gcloud iam service-accounts add-iam-policy-binding $TERRAFORM_SA@$PROJECT_ID.iam.gserviceaccount.com \
        --role="roles/iam.workloadIdentityUser" \
        --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$WI_POOL_ID/attribute.repository/$GITHUB_USER/$repo"
done


