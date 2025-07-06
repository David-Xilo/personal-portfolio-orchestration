#!/bin/bash
set -e

PROJECT_ID="personal-portfolio-safehouse"
TERRAFORM_DIR="../terraform"


run_terraform() {
  echo "🚀 Starting deployment for project: $PROJECT_ID"
  cd "$TERRAFORM_DIR"

  echo "Initializing Terraform"
  terraform init

  echo "Planning Terraform changes"
  terraform plan -out=tfplan

  echo "Applying Terraform changes"
  terraform apply tfplan

  echo "Terraform outputs:"
  terraform output

  rm -f tfplan

}

main() {
    setup_auth
    run_terraform
    echo "Deployment completed successfully"
}

main "$@"
