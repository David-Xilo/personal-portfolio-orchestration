

resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "safehouse-db-password"

  replication {
    user_managed {
      replicas {
        location = var.region # Only one region
      }
    }
  }

  depends_on = [google_project_service.secret_manager_api]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

resource "random_password" "jwt_secret" {
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "jwt_signing_key" {
  secret_id = "safehouse-jwt-signing-key"

  replication {
    user_managed {
      replicas {
        location = var.region # Only one region
      }
    }
  }

  depends_on = [google_project_service.secret_manager_api]
}

resource "google_secret_manager_secret_version" "jwt_signing_key" {
  secret      = google_secret_manager_secret.jwt_signing_key.id
  secret_data = random_password.jwt_secret.result
}

# Grant Cloud Run SA access to secrets
resource "google_secret_manager_secret_iam_member" "cloud_run_db_password_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_service_account.cloud_run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "cloud_run_jwt_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.jwt_signing_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_service_account.cloud_run_sa.email}"
}


data "google_secret_manager_secret_version" "db_password" {
  secret     = google_secret_manager_secret.db_password.secret_id
  depends_on = [google_secret_manager_secret_version.db_password]
}
