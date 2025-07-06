#!/bin/bash
set -e

PROJECT_ID=personal-portfolio-safehouse
PROJECT_ID_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
GITHUB_POOL=safehouse-github-pool
GITHUB_USER=David-Xilo

bind_repository() {
    local repo_name="$1"

    if [ -z "$repo_name" ]; then
        echo "Usage: $0 <repository-name>"
        echo "Example: $0 my-portfolio-frontend"
        exit 1
    fi

    echo "Binding repository: ${GITHUB_USER}/$repo_name"

    gcloud iam service-accounts add-iam-policy-binding \
        safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com \
        --role="roles/iam.workloadIdentityUser" \
        --member="principalSet://iam.googleapis.com/projects/${PROJECT_ID_NUMBER}/locations/global/workloadIdentityPools/${GITHUB_POOL}/attribute.repository/${GITHUB_USER}/$repo_name"

    echo "Repository $repo_name bound successfully!"
}

if [ $# -eq 0 ]; then
    echo "This script binds GitHub repositories to your Workload Identity setup."
    echo "Usage: $0 <repository-name>"
    exit 1
fi

bind_repository "$1"
