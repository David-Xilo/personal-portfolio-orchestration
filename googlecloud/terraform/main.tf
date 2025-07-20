terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "personal-portfolio-safehouse-terraform-state"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_cloud_run_service" "safehouse_backend" {
  name     = "safehouse-backend"
  location = var.region

  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "1"
      }
    }

    spec {
      service_account_name = data.google_service_account.cloud_run_sa.email

      containers {
        image = "xilo/safehouse-backend-main:${var.backend_image_tag}"

        env {
          name  = "ENV"
          value = "production"
        }

        env {
          name  = "DB_HOST"
          value = google_cloud_run_service.postgres_db.status[0].url
        }

        env {
          name  = "DB_PORT"
          value = "5432"
        }

        env {
          name  = "DB_NAME"
          value = "safehouse_db"
        }

        env {
          name  = "DB_USER"
          value = "safehouse_user"
        }

        env {
          name  = "DB_PASSWORD"
          value = data.google_secret_manager_secret_version.db_password.secret_data
        }

        # env {
        #   name  = "DB_PASSWORD_SECRET"
        #   value = google_secret_manager_secret.db_password.secret_id
        # }

        # Option 2: Uncomment these for IAM authentication instead
        # env {
        #   name  = "DB_USER"
        #   value = "safehouse-cloud-run@${var.project_id}.iam"
        # }
        #
        # env {
        #   name  = "USE_IAM_DB_AUTH"
        #   value = "true"
        # }

        env {
          name  = "DATABASE_TIMEOUT"
          value = "30s"
        }

        env {
          name  = "READ_TIMEOUT"
          value = "30s"
        }

        env {
          name  = "WRITE_TIMEOUT"
          value = "1s"
        }

        env {
          name  = "JWT_EXPIRATION_MINUTES"
          value = "30"
        }

        env {
          name  = "GCP_PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "FRONTEND_URL"
          value = google_cloud_run_service.safehouse_frontend.status[0].url
        }

        env {
          name  = "SECURITY_HEADERS_ENABLED"
          value = "true"
        }

        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }

        # Add startup and liveness probes
        startup_probe {
          http_get {
            path = "/health"
          }
          initial_delay_seconds = 60
          timeout_seconds       = 10
          period_seconds        = 10
          failure_threshold     = 10
        }

        liveness_probe {
          http_get {
            path = "/health"
          }
          initial_delay_seconds = 30
          timeout_seconds       = 5
          period_seconds        = 30
        }
      }
    }
  }

  depends_on = [
    google_project_service.cloud_run_api,
    google_cloud_run_service.postgres_db,
    google_cloud_run_v2_job.migrations
  ]

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service" "safehouse_frontend" {
  name     = "safehouse-frontend"
  location = var.region

  template {
    spec {
      containers {
        image = "xilo/safehouse-frontend-main:${var.frontend_image_tag}"

        ports {
          container_port = 80
        }
        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
    }
  }

  depends_on = [google_project_service.cloud_run_api]
}

resource "google_cloud_run_service" "postgres_db" {
  name     = "postgres-db"
  location = var.region

  template {
    spec {
      containers {
        image = "xilo/safehouse-postgres:${var.postgres_image_tag}"

        ports {
          container_port = 5432
        }

        env {
          name  = "POSTGRES_DB"
          value = "safehouse_db"
        }
        env {
          name  = "POSTGRES_USER"
          value = "safehouse_user"
        }
        env {
          name  = "POSTGRES_PASSWORD"
          value = data.google_secret_manager_secret_version.db_password.secret_data
        }
      }
    }
  }
}

resource "google_cloud_run_service_iam_member" "postgres_public_access" {
  location = google_cloud_run_service.postgres_db.location
  project  = google_cloud_run_service.postgres_db.project
  service  = google_cloud_run_service.postgres_db.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_job" "migrations" {
  name     = "run-migrations"
  location = var.region

  template {
    template {
      containers {
        image = "xilo/safehouse-migrations:${var.migration_image_tag}"
        env {
          name  = "POSTGRES_HOST"
          value = google_cloud_run_service.postgres_db.status[0].url
        }
        env {
          name  = "POSTGRES_USER"
          value = "safehouse_user"
        }
        env {
          name  = "POSTGRES_PASSWORD"
          value = data.google_secret_manager_secret_version.db_password.secret_data
        }
        env {
          name  = "POSTGRES_DB"
          value = "safehouse_db"
        }
      }
    }
  }
}


resource "google_cloud_run_service_iam_member" "authenticated_access" {
  location = google_cloud_run_service.safehouse_backend.location
  project  = google_cloud_run_service.safehouse_backend.project
  service  = google_cloud_run_service.safehouse_backend.name
  role     = "roles/run.invoker"
  member   = "user:${var.authorized_user_email}"
}

resource "google_cloud_run_service_iam_member" "frontend_public_access" {
  location = google_cloud_run_service.safehouse_frontend.location
  project  = google_cloud_run_service.safehouse_frontend.project
  service  = google_cloud_run_service.safehouse_frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

