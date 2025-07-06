#!/bin/bash
set -e

PROJECT_ID="personal-portfolio-safehouse"

SERVICE_ACCOUNT_CICD="safehouse-terraform-cicd"
SERVICE_ACCOUNT_CICD_FULL="${SERVICE_ACCOUNT_CICD}@${PROJECT_ID}.iam.gserviceaccount.com"

SERVICE_ACCOUNT_CLOUD_RUN="safehouse-cloud-run"
SERVICE_ACCOUNT_CLOUD_RUN_FULL="${SERVICE_ACCOUNT_CLOUD_RUN}@${PROJECT_ID}.iam.gserviceaccount.com"

# secrets to verify
DB_PASSWORD_SECRET_NAME="safehouse-db-password"
JWT_SECRET_NAME="safehouse-jwt-signing-key"
FRONTEND_AUTH_SECRET_NAME="safehouse-frontend-auth-key"

gcloud config set project "$PROJECT_ID"

echo "Checking required APIs"
required_apis=(
    "compute.googleapis.com"
    "servicenetworking.googleapis.com" 
    "run.googleapis.com"
    "sqladmin.googleapis.com"
    "containerregistry.googleapis.com"
    "secretmanager.googleapis.com"
    "vpcaccess.googleapis.com"
)

workload_identity_apis=(
    "iamcredentials.googleapis.com"
    "sts.googleapis.com"
    "cloudresourcemanager.googleapis.com"
)

echo "Core APIs (enabled by Terraform)"
for api in "${required_apis[@]}"; do
    if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
        echo "$api enabled"
    else
        echo "$api not enabled"
    fi
done

echo ""
echo "Workload Identity APIs"
for api in "${workload_identity_apis[@]}"; do
    if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
        echo "$api enabled"
    else
        echo "$api not enabled"
    fi
done

echo ""
echo "Checking Workload Identity Pool"
if gcloud iam workload-identity-pools describe safehouse-github-pool --location="global" --quiet 2>/dev/null; then
    echo "Workload Identity Pool exists"
else
    echo "Workload Identity Pool not found"
fi

echo ""
echo "Checking Workload Identity Provider"
if gcloud iam workload-identity-pools providers describe safehouse-github-provider \
    --location="global" \
    --workload-identity-pool=safehouse-github-pool --quiet 2>/dev/null; then
    echo "Workload Identity Provider exists"
else
    echo "Workload Identity Provider not found"
fi

echo ""
echo "Checking Service Accounts"
if gcloud iam service-accounts describe "${SERVICE_ACCOUNT_CICD_FULL}" --quiet 2>/dev/null; then
    echo "CI/CD Service Account exists"
else
    echo "CI/CD Service Account not found"
fi


if gcloud iam service-accounts describe "${SERVICE_ACCOUNT_CLOUD_RUN_FULL}" --quiet 2>/dev/null; then
    echo "Cloud Run Service Account exists"
else
    echo "Cloud Run Service Account not found"
fi


echo ""
echo "=== Service Account Permissions ==="
required_roles=(
    "roles/cloudsql.editor"
    "roles/run.developer"
    "roles/secretmanager.secretAccessor"
    "roles/compute.networkAdmin"
    "roles/servicenetworking.networksAdmin"
    "roles/storage.objectAdmin"
    "roles/logging.configWriter"
    "roles/serviceusage.serviceUsageAdmin"
    "roles/containeranalysis.admin"
)

for role in "${required_roles[@]}"; do
    if gcloud projects get-iam-policy ${PROJECT_ID} \
        --filter="bindings.members:serviceAccount:${SERVICE_ACCOUNT_CICD_FULL}" \
        --format="value(bindings.role)" | grep -q "$role"; then
        echo "$role assigned"
    else
        echo "$role not assigned"
    fi
done


echo ""
echo "Checking secrets"

if gcloud secrets describe "${DB_PASSWORD_SECRET_NAME}" --quiet 2>/dev/null; then
    echo "Database password secret exists"
else
    echo "Database password secret not found"
fi

if gcloud secrets describe "${JWT_SECRET_NAME}" --quiet 2>/dev/null; then
    echo "JWT secret exists"
else
    echo "JWT secret not found"
fi

if gcloud secrets describe "${FRONTEND_AUTH_SECRET_NAME}" --quiet 2>/dev/null; then
    echo "Frontend auth key secret exists"
else
    echo "Frontend auth key secret not found (optional for Workload Identity)"
fi

echo ""
echo "Checking Secret Manager IAM permissions"

if gcloud secrets get-iam-policy "${DB_PASSWORD_SECRET_NAME}" \
    --filter="bindings.members:serviceAccount:portfolio-cloud-run@${PROJECT_ID}.iam.gserviceaccount.com" \
    --format="value(bindings.role)" | grep -q "roles/secretmanager.secretAccessor"; then
    echo "Cloud Run has access to database password secret"
else
    echo "Cloud Run missing access to database password secret"
fi

if gcloud secrets get-iam-policy "${JWT_SECRET_NAME}" \
    --filter="bindings.members:serviceAccount:portfolio-cloud-run@${PROJECT_ID}.iam.gserviceaccount.com" \
    --format="value(bindings.role)" | grep -q "roles/secretmanager.secretAccessor"; then
    echo "Cloud Run has access to JWT secret"
else
    echo "Cloud Run missing access to JWT secret"
fi

if gcloud secrets get-iam-policy "${FRONTEND_AUTH_SECRET_NAME}" \
    --filter="bindings.members:serviceAccount:portfolio-cloud-run@${PROJECT_ID}.iam.gserviceaccount.com" \
    --format="value(bindings.role)" | grep -q "roles/secretmanager.secretAccessor"; then
    echo "Cloud Run has access to Frontend auth secret"
else
    echo "Cloud Run missing access to Frontend auth secret"
fi

echo ""
echo "Summary"
echo "Workload Identity Provider Path:"
echo "projects/942519139037/locations/global/workloadIdentityPools/safehouse-github-pool/providers/safehouse-github-provider"
echo ""
echo "Terraform Service Account:"
echo "safehouse-terraform-cicd@${PROJECT_ID}.iam.gserviceaccount.com"
echo ""
echo "Cloud Run Service Account:"
echo "portfolio-cloud-run@${PROJECT_ID}.iam.gserviceaccount.com"
echo ""
echo "Verification complete!"