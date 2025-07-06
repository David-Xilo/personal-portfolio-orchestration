
locals {
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

resource "google_project_iam_member" "terraform_cicd_roles" {
  for_each = toset(local.cicd_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.terraform_cicd.email}"
}


