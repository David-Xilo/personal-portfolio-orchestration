
locals {
  cloud_run_roles = [
    "roles/cloudsql.client",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter"
  ]

  cicd_roles = [
    "roles/cloudsql.editor",
    "roles/run.developer",
    "roles/secretmanager.secretAccessor",
    "roles/compute.networkAdmin",
    "roles/servicenetworking.networksAdmin",
    "roles/storage.objectAdmin",
    "roles/logging.configWriter",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/containeranalysis.admin",
  ]
}

# Cloud Run service account permissions
resource "google_project_iam_member" "cloud_run_sa_roles" {
  for_each = toset(local.cloud_run_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# CI/CD service account permissions (already exists, but moved to locals)
resource "google_project_iam_member" "terraform_cicd_roles" {
  for_each = toset(local.cicd_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.terraform_cicd.email}"
}


data "google_project" "project" {}

resource "google_service_account_iam_member" "backend_repo_binding" {
  service_account_id = google_service_account.terraform_cicd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/attribute.repository/${var.github_user}/${var.backend_github_repository}"
}


resource "google_service_account_iam_member" "frontend_repo_binding" {
  service_account_id = google_service_account.terraform_cicd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/attribute.repository/${var.github_user}/${var.frontend_github_repository}"
}

resource "google_service_account_iam_member" "orchestration_repo_binding" {
  service_account_id = google_service_account.terraform_cicd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/attribute.repository/${var.github_user}/${var.orchestration_github_repository}"
}

resource "google_service_account_iam_member" "migrations_repo_binding" {
  service_account_id = google_service_account.terraform_cicd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/attribute.repository/${var.github_user}/${var.migrations_github_repository}"
}

