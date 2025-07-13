
data "google_service_account" "cloud_run_sa" {
  account_id = "safehouse-cloud-run"
  project    = var.project_id
}

data "google_service_account" "terraform_cicd" {
  account_id = "safehouse-terraform-cicd"
  project    = var.project_id
}

resource "google_service_account" "migration_runner" {
  account_id   = "safehouse-migration-runner"
  display_name = "Safehouse Migration Runner"
  description  = "Service account for running database migrations only"
}

