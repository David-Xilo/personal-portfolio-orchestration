
data "google_service_account" "cloud_run_sa" {
  account_id = "safehouse-cloud-run"
  project    = var.project_id
}

data "google_service_account" "terraform_cicd" {
  account_id = "safehouse-terraform-cicd"
  project    = var.project_id
}

