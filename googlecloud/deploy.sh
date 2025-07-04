#!/bin/bash
set -e

PROJECT_ID="personal-portfolio-safehouse"
TERRAFORM_DIR="../terraform"

echo "🚀 Starting deployment for project: $PROJECT_ID"

is_ci_cd() {
    [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ] || [ -n "$GITLAB_CI" ] || [ -n "$JENKINS_URL" ]
}

setup_auth() {
    if is_ci_cd; then
        echo "🔐 CI/CD detected - using Workload Identity or service account"
        # In CI/CD, authentication should be handled by the CI/CD platform
        # via Workload Identity (recommended) or service account keys

        # If using service account keys in CI/CD (not recommended but sometimes necessary)

    else
        echo "Local development detected"
        echo "Checking authentication..."

        if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
            echo "No active authentication found. Running gcloud auth login..."
            gcloud auth login
        fi

        if ! gcloud auth application-default print-access-token &>/dev/null; then
            echo "Setting up application default credentials..."
            gcloud auth application-default login
        fi
    fi
}

run_terraform() {
    cd "$TERRAFORM_DIR"

    echo "Initializing Terraform..."
    terraform init

    echo "Planning Terraform changes..."
    terraform plan -out=tfplan

    echo "Applying Terraform changes..."
    terraform apply tfplan

    echo "Terraform outputs:"
    terraform output

    rm -f tfplan

    if [ -f "/tmp/terraform-key.json" ]; then
        rm -f /tmp/terraform-key.json
    fi
}

main() {
    setup_auth
    run_terraform
    echo "Deployment completed successfully"
}

main "$@"
