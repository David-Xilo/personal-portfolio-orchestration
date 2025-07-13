
resource "google_service_account" "cloud_run_sa" {
  account_id   = "safehouse-cloud-run"
  display_name = "Safehouse Cloud Run"
  description  = "Service account for Cloud Run services"
}

data "google_service_account" "terraform_cicd" {
  account_id = "safehouse-terraform-cicd"
  project    = var.project_id
}


resource "google_service_account" "db_access" {
  account_id   = "safehouse-db"
  display_name = "Safehouse Database Access"
  description  = "Service account for database access with IAM authentication"
}

