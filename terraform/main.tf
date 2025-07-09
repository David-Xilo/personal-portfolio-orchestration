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

# Create database user
resource "google_sql_user" "db_user" {
  name     = "safehouse_db_user"
  instance = google_sql_database_instance.db_instance.name
  password = data.google_secret_manager_secret_version.db_password.secret_data

  lifecycle {
    ignore_changes       = [password]
    replace_triggered_by = [time_rotating.pw_trigger.id]
  }
}


resource "google_iam_workload_identity_pool" "github_pool" {
  project                   = var.project_id
  workload_identity_pool_id = "safehouse-github-pool"
  display_name              = "GitHub Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "safehouse-github-provider"
  display_name                       = "GitHub Actions Provider"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  attribute_condition = "assertion.repository_owner == 'David-Xilo'"
}

# Roles for CI/CD

resource "google_cloud_run_service" "safehouse_backend" {
  name     = "safehouse-backend"
  location = var.region

  template {
    metadata {
      annotations = {
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.name
      }
    }

    spec {
      service_account_name = google_service_account.cloud_run_sa.email

      containers {
        image = "gcr.io/cloudrun/hello"

        env {
          name  = "DB_HOST"
          value = google_sql_database_instance.db_instance.private_ip_address
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

        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }

        # Add security headers and settings
        env {
          name  = "SECURITY_HEADERS_ENABLED"
          value = "true"
        }

        # Resource limits for security
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

