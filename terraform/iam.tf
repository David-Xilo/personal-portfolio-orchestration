data "google_project" "project" {}

locals {
  cloud_run_sa_email      = "safehouse-cloud-run@${var.project_id}.iam.gserviceaccount.com"
  terraform_cicd_sa_email = "safehouse-terraform-cicd@${var.project_id}.iam.gserviceaccount.com"

  cloud_run_roles = [
    "roles/cloudsql.client",
    "roles/cloudsql.instanceUser",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter"
  ]
  cicd_roles = [
    "roles/cloudsql.editor",
    "roles/run.developer",
    "roles/compute.networkAdmin",
    "roles/servicenetworking.networksAdmin",
    "roles/logging.configWriter",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/containeranalysis.admin",

    "roles/iam.workloadIdentityPoolAdmin",
    "roles/storage.admin",
    "roles/vpcaccess.admin",
    "roles/secretmanager.admin",
    "roles/iam.serviceAccountAdmin",

    "roles/resourcemanager.projectIamAdmin",

    "roles/cloudsql.admin",
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
  member   = "serviceAccount:${local.cloud_run_sa_email}"
}

resource "google_project_iam_member" "terraform_cicd_roles" {
  for_each = toset(local.cicd_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${local.terraform_cicd_sa_email}"
}

resource "google_service_account_iam_member" "github_workload_identity" {
  for_each = toset(local.allowed_repositories)

  service_account_id = "projects/${var.project_id}/serviceAccounts/${local.terraform_cicd_sa_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/safehouse-github-pool/attribute.repository/${var.github_user}/${each.value}"
}

resource "google_sql_user" "db_user_iam" {
  name     = "safehouse-cloud-run"
  instance = google_sql_database_instance.db_instance.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"

  depends_on = [
    data.google_service_account.cloud_run_sa,
    google_sql_database_instance.db_instance
  ]
}

resource "google_project_iam_member" "db_sa_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.db_access.email}"
}

resource "google_project_iam_member" "db_sa_instance_user" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.db_access.email}"
}

resource "google_service_account_iam_member" "cloud_run_impersonate_db_sa" {
  service_account_id = google_service_account.db_access.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${data.google_service_account.cloud_run_sa.email}"
}
