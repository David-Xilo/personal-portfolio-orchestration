terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "compute_api" {
  service = "compute.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "servicenetworking_api" {
  service = "servicenetworking.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

# for app containers
resource "google_project_service" "cloud_run_api" {
  service = "run.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

# for postgres
resource "google_project_service" "cloud_sql_api" {
  service = "sqladmin.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

# for docker images
resource "google_project_service" "container_registry_api" {
  service = "containerregistry.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

# for secrets
resource "google_project_service" "secret_manager_api" {
  service = "secretmanager.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

# so cloud run can access private networks
resource "google_project_service" "vpcaccess_api" {
  service = "vpcaccess.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

# getting db password from secret store
data "google_secret_manager_secret_version" "db_password" {
  secret = "portfolio-safehouse-db-password"
  depends_on = [google_project_service.secret_manager_api]
}

resource "google_compute_network" "vpc" {
  name                    = "portfolio-vpc"
  auto_create_subnetworks = false
  depends_on             = [google_project_service.compute_api]
}

resource "google_compute_subnetwork" "subnet" {
  name          = "portfolio-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Private service connection for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  depends_on             = [google_project_service.servicenetworking_api]
}

# VPC Access Connector for Cloud Run to reach private resources
resource "google_vpc_access_connector" "connector" {
  name          = "safehouse-connector"
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.name
  region        = var.region
  depends_on    = [google_project_service.vpcaccess_api]
}

resource "google_sql_database_instance" "main" {
  name             = "safehouse-db-instance"
  database_version = "POSTGRES_13"
  region          = var.region

  settings {
    tier = "db-f1-micro"

    backup_configuration {
      enabled = false
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
      require_ssl     = true
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
  instance = google_sql_database_instance.main.name
}

# Create database user
resource "google_sql_user" "db_user" {
  name     = "safehouse_db_user"
  instance = google_sql_database_instance.main.name
  password = data.google_secret_manager_secret_version.db_password.secret_data
}

# Secret for database connection URL (more secure than env var)
resource "google_secret_manager_secret" "database_url" {
  secret_id = "safehouse-database-url"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secret_manager_api]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret = google_secret_manager_secret.database_url.id
  secret_data = "postgresql://${google_sql_user.db_user.name}:${data.google_secret_manager_secret_version.db_password.secret_data}@${google_sql_database_instance.main.private_ip_address}:5432/${google_sql_database.safehouse_db.name}"
}

# Storage bucket for audit logs
resource "google_storage_bucket" "audit_logs" {
  name          = "${var.project_id}-audit-logs"
  location      = var.region
  force_destroy = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 15
    }
  }
}

resource "google_service_account" "cloud_run_sa" {
  account_id   = "portfolio-cloud-run"
  display_name = "Portfolio Cloud Run Service Account"
  description  = "Service account for Cloud Run with minimal permissions"
}

# Grant Cloud Run service account access to secrets
resource "google_secret_manager_secret_iam_member" "cloud_run_db_secret_access" {
  secret_id = google_secret_manager_secret.database_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "cloud_run_db_password_access" {
  secret_id = "portfolio-safehouse-db-password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Update Cloud Run service to use dedicated service account
resource "google_cloud_run_service" "safehouse_app" {
  name     = "safehouse-app"
  location = var.region

  template {
    metadata {
      annotations = {
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.name
      }
    }

    spec {
      # Use dedicated service account
      service_account_name = google_service_account.cloud_run_sa.email

      containers {
        image = "gcr.io/cloudrun/hello"

        env {
          name  = "DB_HOST"
          value = google_sql_database_instance.main.private_ip_address
        }

        env {
          name  = "DB_NAME"
          value = google_sql_database.safehouse_db.name
        }

        env {
          name  = "DB_USER"
          value = google_sql_user.db_user.name
        }

        # Reference the database URL secret - app will read from Secret Manager
        env {
          name  = "DATABASE_URL_SECRET"
          value = google_secret_manager_secret.database_url.secret_id
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

# Optional: More restrictive Cloud Run access (for production)
# Uncomment this and remove the "allUsers" version for production
resource "google_cloud_run_service_iam_member" "authenticated_access" {
  location = google_cloud_run_service.safehouse_app.location
  project  = google_cloud_run_service.safehouse_app.project
  service  = google_cloud_run_service.safehouse_app.name
  role     = "roles/run.invoker"
  member   = "user:david.dbmoura@gmail.com"  # Replace with your email
}


resource "google_monitoring_alert_policy" "unauthorized_access" {
  display_name = "Unauthorized Access Attempts"
  combiner     = "OR"

  conditions {
    display_name = "High 4xx Error Rate"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${google_cloud_run_service.safehouse_app.name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = []  # Add notification channels here

  alert_strategy {
    auto_close = "1800s"
  }
}

# Enhanced audit logging with more security events
resource "google_logging_project_sink" "security_sink" {
  name        = "security-audit-sink"
  project     = var.project_id
  destination = "storage.googleapis.com/${google_storage_bucket.audit_logs.name}"

  filter = <<EOF
    protoPayload.methodName:"google.iam.admin.v1.CreateServiceAccount" OR
    protoPayload.methodName:"google.iam.admin.v1.DeleteServiceAccount" OR
    protoPayload.methodName:"google.sql.admin.v1.SqlInstancesService.Update" OR
    protoPayload.methodName:"google.sql.admin.v1.SqlUsersService.Insert" OR
    protoPayload.methodName:"SetIamPolicy" OR
    protoPayload.methodName:"google.secretmanager" OR
    (resource.type="cloud_run_revision" AND httpRequest.status>=400)
  EOF
}
