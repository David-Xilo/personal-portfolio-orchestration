#!/bin/bash
set -e

echo "Checking required APIs..."
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
        echo "$api enabled"
    else
        echo "$api not enabled"
    fi
done

echo ""
echo "Checking Workload Identity Pool..."
if gcloud iam workload-identity-pools describe safehouse-github-pool --location="global" --quiet 2>/dev/null; then
    echo "Workload Identity Pool exists"
else
    echo "Workload Identity Pool not found"
fi

echo ""
echo "Checking Workload Identity Provider..."
if gcloud iam workload-identity-pools providers describe safehouse-github-provider \
    --location="global" \
    --workload-identity-pool=safehouse-github-pool --quiet 2>/dev/null; then
    echo "Workload Identity Provider exists"
else
    echo "Workload Identity Provider not found"
fi

echo ""
echo "Checking Service Account..."
if gcloud iam service-accounts describe safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com --quiet 2>/dev/null; then
    echo "Service Account exists"
else
    echo "Service Account not found"
fi

if gcloud projects get-iam-policy personal-portfolio-safehouse \
    --filter="bindings.members:serviceAccount:safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com" \
    --format="value(bindings.role)" | grep -q "roles/containeranalysis.admin"; then
    echo "roles/containeranalysis.admin assigned"
else
    echo "roles/containeranalysis.admin not assigned"
fi

echo ""
echo "Checking Service Account permissions..."
required_roles=(
    "roles/cloudsql.admin"
    "roles/run.admin"
    "roles/secretmanager.admin"
    "roles/compute.networkAdmin"
    "roles/servicenetworking.networkAdmin"
    "roles/storage.admin"
    "roles/logging.configWriter"
    "roles/serviceusage.serviceUsageAdmin"
)

for role in "${required_roles[@]}"; do
    if gcloud projects get-iam-policy personal-portfolio-safehouse \
        --filter="bindings.members:serviceAccount:safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com" \
        --format="value(bindings.role)" | grep -q "$role"; then
        echo "$role assigned"
    else
        echo "$role not assigned"
    fi
done

if gcloud secrets describe safehouse-latest-deployment --quiet 2>/dev/null; then
    echo "Deployment tracking secret exists"
else
    echo "Deployment tracking secret not found"
fi

if gcloud secrets describe github-actions-demo-secret --quiet 2>/dev/null; then
    echo "Demo secret exists"
else
    echo "Demo secret not found"
fi

echo ""
echo "Checking Cloud Run Service Account..."
if gcloud iam service-accounts describe portfolio-cloud-run@personal-portfolio-safehouse.iam.gserviceaccount.com --quiet 2>/dev/null; then
    echo "Cloud Run Service Account exists"
else
    echo "Cloud Run Service Account not found"
fi

echo ""
echo "Checking secrets..."
if gcloud secrets describe portfolio-safehouse-db-password --quiet 2>/dev/null; then
    echo "Database password secret exists"
else
    echo "Database password secret not found"
fi

if gcloud secrets describe safehouse-database-url --quiet 2>/dev/null; then
    echo "Database URL secret exists"
else
    echo "Database URL secret not found"
fi

if gcloud secrets describe personal-portfolio-terraform-key --quiet 2>/dev/null; then
    echo "Terraform key secret exists"
else
    echo "Terraform key secret not found (optional for Workload Identity)"
fi

echo ""
echo "Checking Secret Manager IAM permissions..."
# Check if Cloud Run service account has access to secrets
if gcloud secrets get-iam-policy portfolio-safehouse-db-password \
    --filter="bindings.members:serviceAccount:portfolio-cloud-run@personal-portfolio-safehouse.iam.gserviceaccount.com" \
    --format="value(bindings.role)" | grep -q "roles/secretmanager.secretAccessor"; then
    echo "Cloud Run has access to database password secret"
else
    echo "Cloud Run missing access to database password secret"
fi

if gcloud secrets get-iam-policy safehouse-database-url \
    --filter="bindings.members:serviceAccount:portfolio-cloud-run@personal-portfolio-safehouse.iam.gserviceaccount.com" \
    --format="value(bindings.role)" | grep -q "roles/secretmanager.secretAccessor"; then
    echo "Cloud Run has access to database URL secret"
else
    echo "Cloud Run missing access to database URL secret"
fi

echo ""
echo "Summary"
echo "Workload Identity Provider Path:"
echo "projects/942519139037/locations/global/workloadIdentityPools/safehouse-github-pool/providers/safehouse-github-provider"
echo ""
echo "Terraform Service Account:"
echo "safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com"
echo ""
echo "Cloud Run Service Account:"
echo "portfolio-cloud-run@personal-portfolio-safehouse.iam.gserviceaccount.com"
echo ""
echo "To bind a repository:"
echo "./bind-repository.sh <repository-name>"
echo ""
echo "Verification complete!"