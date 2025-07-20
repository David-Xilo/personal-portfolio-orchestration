#!/bin/bash

# deployment-helper.sh - Helper scripts for managing deployments

set -e

PROJECT_ID="personal-portfolio-safehouse"

function show_help() {
    echo "Safehouse Deployment Helper"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  latest-image     Show the latest built image tag"
    echo "  deploy-info      Show full deployment information"
    echo "  update-terraform Update terraform with latest image"
    echo "  create-secret    Create a new secret in Secret Manager"
    echo "  get-secret       Get a secret from Secret Manager"
    echo "  list-images      List all available images"
    echo ""
    echo "Examples:"
    echo "  $0 latest-image"
    echo "  $0 create-secret my-secret-name"
    echo "  $0 get-secret database-password"
}

function get_latest_image() {
    echo "🔍 Getting latest deployment info"

    DEPLOYMENT_INFO=$(gcloud secrets versions access latest \
        --secret="safehouse-latest-deployment" \
        --project="$PROJECT_ID" 2>/dev/null || echo "{}")

    if [ "$DEPLOYMENT_INFO" = "{}" ]; then
        echo "No deployment info found. Run a build first."
        return 1
    fi

    IMAGE=$(echo "$DEPLOYMENT_INFO" | jq -r '.image // "not found"')
    echo "Latest image: $IMAGE"
}

function show_deploy_info() {
    echo "Full deployment information:"

    DEPLOYMENT_INFO=$(gcloud secrets versions access latest \
        --secret="safehouse-latest-deployment" \
        --project="$PROJECT_ID" 2>/dev/null || echo "{}")

    if [ "$DEPLOYMENT_INFO" = "{}" ]; then
        echo "No deployment info found. Run a build first."
        return 1
    fi

    echo "$DEPLOYMENT_INFO" | jq .
}

function update_terraform() {
    echo "Updating Terraform configuration"

    # Get latest image
    DEPLOYMENT_INFO=$(gcloud secrets versions access latest \
        --secret="safehouse-latest-deployment" \
        --project="$PROJECT_ID" 2>/dev/null || echo "{}")

    if [ "$DEPLOYMENT_INFO" = "{}" ]; then
        echo "No deployment info found. Run a build first."
        return 1
    fi

    IMAGE=$(echo "$DEPLOYMENT_INFO" | jq -r '.image')

    if [ ! -f "main.tf" ]; then
        echo "main.tf not found in current directory"
        return 1
    fi

    # Create backup
    cp main.tf main.tf.backup

    # Update the image in main.tf
    sed -i.tmp "s|image = \"gcr.io/[^\"]*\"|image = \"$IMAGE\"|g" main.tf
    rm -f main.tf.tmp

    echo "Updated main.tf with image: $IMAGE"
    echo "Backup saved as: main.tf.backup"
    echo ""
    echo "To deploy:"
    echo "   terraform plan"
    echo "   terraform apply"
}

function create_secret() {
    local secret_name="$1"

    if [ -z "$secret_name" ]; then
        echo "Please provide a secret name"
        echo "Usage: $0 create-secret <secret-name>"
        return 1
    fi

    echo "Creating secret: $secret_name"
    echo "Enter the secret value (input will be hidden):"
    read -s secret_value

    echo "$secret_value" | gcloud secrets create "$secret_name" \
        --data-file=- \
        --replication-policy="automatic" \
        --project="$PROJECT_ID"

    echo "Secret '$secret_name' created successfully"
}

function get_secret() {
    local secret_name="$1"

    if [ -z "$secret_name" ]; then
        echo "Please provide a secret name"
        echo "Usage: $0 get-secret <secret-name>"
        return 1
    fi

    echo "🔍 Getting secret: $secret_name"

    gcloud secrets versions access latest \
        --secret="$secret_name" \
        --project="$PROJECT_ID"
}

function list_images() {
    echo "Available images in Container Registry:"
    echo ""

    gcloud container images list \
        --repository="gcr.io/$PROJECT_ID" \
        --project="$PROJECT_ID"

    echo ""
    echo "Tags for safehouse-app:"
    gcloud container images list-tags \
        "gcr.io/$PROJECT_ID/safehouse-app" \
        --project="$PROJECT_ID" \
        --limit=10 \
        --sort-by="~timestamp"
}

# Main script logic
case "${1:-help}" in
    "latest-image")
        get_latest_image
        ;;
    "deploy-info")
        show_deploy_info
        ;;
    "update-terraform")
        update_terraform
        ;;
    "create-secret")
        create_secret "$2"
        ;;
    "get-secret")
        get_secret "$2"
        ;;
    "list-images")
        list_images
        ;;
    "help"|*)
        show_help
        ;;
esac
