terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
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


resource "google_sql_database_instance" "db_instance" {
  name             = "safehouse-db-instance"
  database_version = "POSTGRES_13"
  region           = var.region

  settings {
    tier = "db-f1-micro"

    # no need for backup for now
    backup_configuration {
      enabled = false
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
      require_ssl     = true
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
  }

  depends_on = [
    google_project_service.cloud_sql_api,
    google_service_networking_connection.private_vpc_connection
  ]
}

# Create database
resource "google_sql_database" "safehouse_db" {
  name     = "safehouse_db"
  instance = google_sql_database_instance.db_instance.name
}

resource "time_rotating" "pw_trigger" {
  rotation_minutes = 1440 # 24h
}

resource "google_sql_user" "db_user" {
  name     = "safehouse_db_user"
  instance = google_sql_database_instance.db_instance.name
  password = data.google_secret_manager_secret_version.db_password.secret_data

  lifecycle {
    ignore_changes       = [password]
    replace_triggered_by = [time_rotating.pw_trigger.id]
  }
}

resource "google_cloud_run_service" "safehouse_backend" {
  name     = "safehouse-backend"
  location = var.region

  template {
    metadata {
      annotations = {
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.name
        "run.googleapis.com/cloudsql-instances"   = google_sql_database_instance.db_instance.connection_name
      }
    }

    spec {
      service_account_name = data.google_service_account.cloud_run_sa.email

      containers {
        image = "gcr.io/${var.project_id}/safehouse-backend-main:${var.backend_image_tag}"

        env {
          name  = "ENV"
          value = "production"
        }

        env {
          name  = "DB_HOST"
          value = "/cloudsql/${google_sql_database_instance.db_instance.connection_name}"
        }

        env {
          name  = "DB_PORT"
          value = "5432"
        }

        env {
          name  = "DB_NAME"
          value = google_sql_database.safehouse_db.name
        }

        env {
          name  = "DB_USER"
          value = google_sql_user.db_user.name
        }

        # env {
        #   name  = "DB_USER"
        #   value = "safehouse-cloud-run"
        # }
        #
        # env {
        #   name  = "USE_IAM_DB_AUTH"
        #   value = "true"
        # }

        env {
          name  = "DATABASE_TIMEOUT"
          value = "10s"
        }

        env {
          name  = "READ_TIMEOUT"
          value = "10s"
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
          value = "https://safehouse-frontend-942519139037.us-central1.run.app"
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
      }
    }
  }

  depends_on = [
    google_project_service.cloud_run_api,
    null_resource.run_migrations,
    data.external.migration_status
  ]
}

resource "google_cloud_run_service" "safehouse_frontend" {
  name     = "safehouse-frontend"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/safehouse-frontend-main:${var.frontend_image_tag}"

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

