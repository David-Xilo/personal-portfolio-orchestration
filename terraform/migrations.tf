
resource "google_sql_user" "migration_iam_user" {
  name     = data.google_service_account.cloud_run_sa.email
  instance = google_sql_database_instance.db_instance.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

resource "google_cloud_run_service" "migrations" {
  name     = "safehouse-migrations"
  location = var.region

  template {
    metadata {
      annotations = {
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.name
        "run.googleapis.com/execution-environment" = "gen2"
      }
    }

    spec {
      service_account_name = data.google_service_account.cloud_run_sa.email

      containers {
        image = "gcr.io/${var.project_id}/safehouse-migrations:latest"

        # Use your existing database configuration
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

        # Securely inject the password from Secret Manager
        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.db_password.secret_id
              version = "latest"
            }
          }
        }

        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }
      }

      timeout_seconds = 3600
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [google_project_service.cloud_run_api]
}

resource "google_sql_user" "migration_user" {
  name     = "migration_user"  # Short name that fits in 63 chars
  instance = google_sql_database_instance.db_instance.name
  password = data.google_secret_manager_secret_version.db_password.secret_data
}

resource "google_project_iam_member" "cloud_run_cloudsql_access" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${data.google_service_account.cloud_run_sa.email}"
}

resource "google_sql_user" "migration_iam_user" {
  name     = "sa-migration"
  instance = google_sql_database_instance.db_instance.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"

  # This maps the short name to your actual service account
  depends_on = [google_project_iam_member.cloud_run_cloudsql_access]
}

# Create a null_resource to execute the permission grants automatically
resource "null_resource" "setup_migration_permissions" {
  depends_on = [
    google_sql_user.migration_user,
    google_sql_database.safehouse_db
  ]

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for database to be ready
      sleep 30

      # Get the database password
      DB_PASSWORD=$(gcloud secrets versions access latest --secret="${google_secret_manager_secret.db_password.secret_id}" --project="${var.project_id}")

      # Set up permissions using the existing db_user (which should have admin rights)
      PGPASSWORD="$DB_PASSWORD" psql \
        -h ${google_sql_database_instance.db_instance.private_ip_address} \
        -U ${google_sql_user.db_user.name} \
        -d ${google_sql_database.safehouse_db.name} \
        -c "
        GRANT ALL PRIVILEGES ON DATABASE ${google_sql_database.safehouse_db.name} TO migration_user;
        GRANT ALL PRIVILEGES ON SCHEMA public TO migration_user;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO migration_user;
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO migration_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO migration_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO migration_user;

        -- Create migrations table if it doesn't exist
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version bigint NOT NULL PRIMARY KEY,
            dirty boolean NOT NULL
        );

        -- Grant access to migrations table
        GRANT ALL PRIVILEGES ON TABLE schema_migrations TO migration_user;
        "
    EOT

    environment = {
      PGPASSWORD = ""  # Will be set by the script
    }
  }

  # Re-run permissions if database user changes
  triggers = {
    user_id = google_sql_user.migration_user.name
    db_id   = google_sql_database.safehouse_db.name
  }
}

resource "google_cloudbuild_trigger" "run_migrations" {
  name        = "safehouse-run-migrations"
  description = "Manually trigger database migrations"

  # Manual trigger (can be invoked via API/gcloud)
  manual_trigger {}

  build {
    # Use the migration image we build and push
    step {
      name = "gcr.io/${var.project_id}/safehouse-migrations:latest"

      # Set environment variables for the migration
      env = [
        "DB_HOST=${google_sql_database_instance.db_instance.private_ip_address}",
        "DB_PORT=5432",
        "DB_NAME=${google_sql_database.safehouse_db.name}",
        "DB_USER=${google_sql_user.db_user.name}",
        "GOOGLE_CLOUD_PROJECT=${var.project_id}"
      ]

      # Get the password from Secret Manager
      secret_env = ["DB_PASSWORD"]

      # The args will be passed when triggering the build
      args = ["$_MIGRATION_COMMAND"]
    }

    # Grant access to the secret
    available_secrets {
      secret_manager {
        version_name = "${google_secret_manager_secret.db_password.secret_id}/versions/latest"
        env          = "DB_PASSWORD"
      }
    }

    options {
      # Use the VPC for database connectivity
      worker_pool = google_cloudbuild_worker_pool.migration_pool.id
    }
  }

  depends_on = [google_project_service.cloudbuild_api]
}

# Create a private worker pool that can access your VPC
resource "google_cloudbuild_worker_pool" "migration_pool" {
  name     = "safehouse-migration-pool"
  location = var.region

  worker_config {
    disk_size_gb   = 10
    machine_type   = "e2-standard-2"
    no_external_ip = false  # Set to true if you want no external IP
  }

  network_config {
    peered_network          = google_compute_network.vpc.id
    peered_network_ip_range = "10.10.0.0/16"  # Different from your existing ranges
  }

  depends_on = [google_project_service.cloudbuild_api]
}

# Grant Cloud Build access to the secret
resource "google_secret_manager_secret_iam_member" "cloudbuild_secret_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Grant Cloud Build access to pull images
resource "google_project_iam_member" "cloudbuild_gcr_access" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}
