#!/bin/bash
set -e

echo "🔐 Setting up Workload Identity..."

# Enable required APIs
echo "📋 Enabling required APIs..."
gcloud services enable compute.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable vpcaccess.googleapis.com
gcloud services enable iamcredentials.googleapis.com
gcloud services enable sts.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com

echo "🏊 Creating Workload Identity Pool..."
if ! gcloud iam workload-identity-pools describe safehouse-github-pool --location="global" --quiet 2>/dev/null; then
    gcloud iam workload-identity-pools create safehouse-github-pool \
        --location="global" \
        --display-name="GitHub Actions Pool"
    echo "✅ Workload Identity Pool created"
else
    echo "✅ Workload Identity Pool already exists"
fi

echo "🔗 Creating Workload Identity Provider..."
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

echo "👤 Creating Service Account..."
if ! gcloud iam service-accounts describe safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com --quiet 2>/dev/null; then
    gcloud iam service-accounts create safehouse-terraform-cicd \
        --display-name="Terraform CI/CD Service Account"
    echo "✅ Service Account created"
else
    echo "✅ Service Account already exists"
fi

echo "🔑 Granting permissions to Service Account..."

# Core permissions
gcloud projects add-iam-policy-binding personal-portfolio-safehouse \
    --member="serviceAccount:safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com" \
    --role="roles/editor"

# Specific service permissions
gcloud projects add-iam-policy-binding personal-portfolio-safehouse \
    --member="serviceAccount:safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com" \
    --role="roles/cloudsql.admin"

gcloud projects add-iam-policy-binding personal-portfolio-safehouse \
    --member="serviceAccount:safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com" \
    --role="roles/run.admin"

gcloud projects add-iam-policy-binding personal-portfolio-safehouse \
    --member="serviceAccount:safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

# Networking permissions (required for VPC and private networking)
gcloud projects add-iam-policy-binding personal-portfolio-safehouse \
    --member="serviceAccount:safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com" \
    --role="roles/compute.networkAdmin"

gcloud projects add-iam-policy-binding personal-portfolio-safehouse \
    --member="serviceAccount:safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com" \
    --role="roles/servicenetworking.networkAdmin"

echo "✅ Permissions granted"

echo ""
echo "🎉 Workload Identity setup complete!"
echo ""
echo "Next steps:"
echo "1. Run ./bind-repository.sh <repository-name> for each repository"
echo "2. Run ./verify-setup.sh to verify everything is configured correctly"
echo "3. Run ./setup-secrets.sh to create required secrets"
echo "4. Run ./deploy.sh to deploy your infrastructure"
