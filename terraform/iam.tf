data "google_project" "project" {}

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

    "roles/iam.workloadIdentityPoolAdmin",
    "roles/storage.admin",
    "roles/vpcaccess.admin",
    "roles/secretmanager.admin",
    "roles/iam.serviceAccountAdmin",
  ]
  allowed_repositories = [
    var.backend_github_repository,
    var.frontend_github_repository,
    var.migrations_github_repository,
    var.orchestration_github_repository
  ]
}

resource "google_project_iam_member" "cloud_run_sa_roles" {
  for_each = toset(local.cloud_run_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "terraform_cicd_roles" {
  for_each = toset(local.cicd_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.terraform_cicd.email}"
}

resource "google_service_account_iam_member" "github_workload_identity" {
  for_each = toset(local.allowed_repositories)

  service_account_id = google_service_account.terraform_cicd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/attribute.repository/${var.github_user}/${each.value}"
}

