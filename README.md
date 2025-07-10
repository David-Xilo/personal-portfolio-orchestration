# safehouse-orchestration
safehouse orchestration

# Setup commands

#### To run locally

gcloud auth login

gcloud config set project personal-portfolio-safehouse

gcloud auth application-default login

terraform init

# Permissions added manually

gcloud projects add-iam-policy-binding personal-portfolio-safehouse \
--member="serviceAccount:safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com" \
--role="roles/iam.serviceAccountViewer"

### Grant IAM admin permission manually
gcloud projects add-iam-policy-binding personal-portfolio-safehouse \
--member="serviceAccount:safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com" \
--role="roles/resourcemanager.projectIamAdmin"

### Also grant basic project editor permissions
gcloud projects add-iam-policy-binding personal-portfolio-safehouse \
--member="serviceAccount:safehouse-terraform-cicd@personal-portfolio-safehouse.iam.gserviceaccount.com" \
--role="roles/editor"
