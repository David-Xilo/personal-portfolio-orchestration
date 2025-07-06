
resource "google_service_account" "cloud_run_sa" {
  account_id   = "safehouse-cloud-run"
  display_name = "Safehouse Cloud Run Service Account"
  description  = "Service account for Cloud Run with minimal permissions"
}

resource "google_service_account" "terraform_cicd" {
  account_id   = "safehouse-terraform-cicd"
  display_name = "Terraform CI/CD Service Account"
  description  = "Service account for CI/CD"
}

