
# for secrets
resource "google_project_service" "secret_manager_api" {
  service = "secretmanager.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_secret_manager_secret_iam_member" "cloud_run_db_password_access" {
  secret_id = "safehouse-db-password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "cloud_run_jwt_access" {
  secret_id = "safehouse-jwt-signing-key"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "cloud_run_frontend_auth_access" {
  secret_id = "safehouse-frontend-auth-key"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# getting db password from secret store
data "google_secret_manager_secret_version" "db_password" {
  secret = "safehouse-db-password"
  depends_on = [google_project_service.secret_manager_api]
}
