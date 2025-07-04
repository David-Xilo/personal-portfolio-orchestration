#!/bin/bash
set -e

echo "🔍 Checking required APIs..."
required_apis=(
    "compute.googleapis.com"
    "servicenetworking.googleapis.com"
    "vpcaccess.googleapis.com"
    "iamcredentials.googleapis.com"
    "sts.googleapis.com"
    "cloudresourcemanager.googleapis.com"
    "secretmanager.googleapis.com"
    "run.googleapis.com"
    "sqladmin.googleapis.com"
    "containerregistry.googleapis.com"
)

for api in "${required_apis[@]}"; do
    if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
        echo "✅ $api enabled"
    else
        echo "❌ $api not enabled"
    fi
done

echo ""
echo "🔍 Checking Workload Identity Pool..."
if gcloud iam workload-identity-pools describe safehouse-github-pool --location="global" --quiet 2>/dev/null; then
    echo "✅ Workload Identity Pool exists"
else
    echo "❌ Workload Identity Pool not found"
fi

echo ""
echo "🔍 Checking Workload Identity Provider..."
if gcloud iam workload-identity-pools providers describe safehouse-github-provider \
    --location="global" \
    --workload-identity-pool=safehouse-github-pool --quiet 2>/dev/null; then
    echo "✅ Workload Identity Provider exists"
else
    echo "❌ Workload Identity Provider not found"
fi

echo ""
echo "🔍 Checking Service Account..."
if gcloud iam service-accounts describe safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com --quiet 2>/dev/null; then
    echo "✅ Service Account exists"
else
    echo "❌ Service Account not found"
fi

echo ""
echo "🔍 Checking Service Account permissions..."
required_roles=(
    "roles/editor"
    "roles/cloudsql.admin"
    "roles/run.admin"
    "roles/secretmanager.secretAccessor"
    "roles/compute.networkAdmin"
    "roles/servicenetworking.networkAdmin"
)

for role in "${required_roles[@]}"; do
    if gcloud projects get-iam-policy personal-portfolio-safehouse \
        --filter="bindings.members:serviceAccount:safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com" \
        --format="value(bindings.role)" | grep -q "$role"; then
        echo "✅ $role assigned"
    else
        echo "❌ $role not assigned"
    fi
done

echo ""
echo "🔍 Checking secrets..."
if gcloud secrets describe portfolio-safehouse-db-password --quiet 2>/dev/null; then
    echo "✅ Database password secret exists"
else
    echo "❌ Database password secret not found"
fi

if gcloud secrets describe personal-portfolio-terraform-key --quiet 2>/dev/null; then
    echo "✅ Terraform key secret exists"
else
    echo "ℹ️  Terraform key secret not found (optional for Workload Identity)"
fi

echo ""
echo "📋 Summary"
echo "Workload Identity Provider Path:"
echo "projects/942519139037/locations/global/workloadIdentityPools/safehouse-github-pool/providers/safehouse-github-provider"
echo ""
echo "Service Account:"
echo "safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com"
echo ""
echo "To bind a repository:"
echo "./bind-repository.sh <repository-name>"
echo ""
echo "🎉 Verification complete!"