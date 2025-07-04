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

resource "google_project_service" "cloud_run_api" {
  service = "run.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "cloud_sql_api" {
  service = "sqladmin.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "container_registry_api" {
  service = "containerregistry.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "secret_manager_api" {
  service = "secretmanager.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "vpcaccess_api" {
  service = "vpcaccess.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

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
  name          = "portfolio-connector"
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.name
  region        = var.region
  depends_on    = [google_project_service.vpcaccess_api]
}

# Cloud SQL PostgreSQL instance with PRIVATE IP
resource "google_sql_database_instance" "main" {
  name             = "portfolio-db-instance"
  database_version = "POSTGRES_13"
  region          = var.region

  settings {
    tier = "db-f1-micro"

    backup_configuration {
      enabled = false
    }

    ip_configuration {
      ipv4_enabled    = false  # No public IP
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
resource "google_sql_database" "portfolio_db" {
  name     = "portfolio"
  instance = google_sql_database_instance.main.name
}

# Create database user
resource "google_sql_user" "db_user" {
  name     = "portfolio_user"
  instance = google_sql_database_instance.main.name
  password = data.google_secret_manager_secret_version.db_password.secret_data
}

# Secret for database connection URL (more secure than env var)
resource "google_secret_manager_secret" "database_url" {
  secret_id = "portfolio-database-url"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secret_manager_api]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret = google_secret_manager_secret.database_url.id
  secret_data = "postgresql://${google_sql_user.db_user.name}:${data.google_secret_manager_secret_version.db_password.secret_data}@${google_sql_database_instance.main.private_ip_address}:5432/${google_sql_database.portfolio_db.name}"
}

# Cloud Run service
resource "google_cloud_run_service" "app" {
  name     = "portfolio-app"
  location = var.region

  template {
    metadata {
      annotations = {
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.name
      }
    }

    spec {
      containers {
        image = "gcr.io/cloudrun/hello"

        env {
          name  = "DB_HOST"
          value = google_sql_database_instance.main.private_ip_address
        }

        env {
          name  = "DB_NAME"
          value = google_sql_database.portfolio_db.name
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
      }
    }
  }

  depends_on = [google_project_service.cloud_run_api]
}

# Allow unauthenticated access to Cloud Run (for testing)
resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_service.app.location
  project  = google_cloud_run_service.app.project
  service  = google_cloud_run_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
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
      age = 90  # Delete logs after 90 days
    }
  }
}

# Logging sink for security audit
resource "google_logging_project_sink" "security_sink" {
  name        = "security-audit-sink"
  project     = var.project_id
  destination = "storage.googleapis.com/${google_storage_bucket.audit_logs.name}"

  filter = <<EOF
    protoPayload.methodName:"google.iam.admin.v1.CreateServiceAccount" OR
    protoPayload.methodName:"google.iam.admin.v1.DeleteServiceAccount" OR
    protoPayload.methodName:"google.sql.admin.v1.SqlInstancesService.Update" OR
    protoPayload.methodName:"google.sql.admin.v1.SqlUsersService.Insert"
  EOF
}
