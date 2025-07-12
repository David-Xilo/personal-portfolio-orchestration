
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
        "run.googleapis.com/vpc-access-connector"  = google_vpc_access_connector.connector.name
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
  name     = "migration_user" # Short name that fits in 63 chars
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
resource "null_resource" "run_migrations" {
  # This runs after database is created but before backend service
  depends_on = [
    google_sql_database_instance.db_instance,
    google_sql_database.safehouse_db,
    google_sql_user.db_user,
    google_vpc_access_connector.connector,
    google_cloudbuild_trigger.run_migrations,
    google_cloudbuild_worker_pool.migration_pool,
    google_secret_manager_secret_version.db_password
  ]

  # Trigger migrations using local-exec
  provisioner "local-exec" {
    command = <<-EOT
      echo "Running database migrations..."

      # Wait for database to be fully ready
      sleep 30

      # Check if migration image exists, build if not
      if ! gcloud container images describe gcr.io/${var.project_id}/safehouse-migrations:latest >/dev/null 2>&1; then
        echo "Building migration image..."
        docker build -f ${path.module}/../Dockerfile -t gcr.io/${var.project_id}/safehouse-migrations:latest ${path.module}/..
        gcloud auth configure-docker
        docker push gcr.io/${var.project_id}/safehouse-migrations:latest
      fi

      # Run migrations
      BUILD_ID=$(gcloud builds triggers run safehouse-run-migrations \
        --substitutions=_MIGRATION_COMMAND=up \
        --format="value(metadata.build.id)")

      echo "Migration build started: $BUILD_ID"

      # Wait for completion
      gcloud builds log --stream $BUILD_ID

      # Check if successful
      BUILD_STATUS=$(gcloud builds describe $BUILD_ID --format="value(status)")
      if [ "$BUILD_STATUS" != "SUCCESS" ]; then
        echo "Migration failed with status: $BUILD_STATUS"
        exit 1
      fi

      echo "Migrations completed successfully"
    EOT

    environment = {
      GOOGLE_CLOUD_PROJECT = var.project_id
    }
  }

  # Re-run migrations if database instance changes
  triggers = {
    database_instance = google_sql_database_instance.db_instance.connection_name
    database_name     = google_sql_database.safehouse_db.name
    # Add a trigger for when migration files change
    migration_hash = filemd5("${path.module}/../run-migrations-prod.sh")
  }
}


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
      PGPASSWORD = "" # Will be set by the script
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
  description = "Run database migrations"

  manual_trigger {}

  build {
    step {
      name = "gcr.io/${var.project_id}/safehouse-migrations:latest"

      env = [
        "DB_HOST=${google_sql_database_instance.db_instance.private_ip_address}",
        "DB_PORT=5432",
        "DB_NAME=${google_sql_database.safehouse_db.name}",
        "DB_USER=${google_sql_user.db_user.name}",
        "GOOGLE_CLOUD_PROJECT=${var.project_id}"
      ]

      secret_env = ["DB_PASSWORD"]
      args       = ["$_MIGRATION_COMMAND"]
    }

    available_secrets {
      secret_manager {
        version_name = "${google_secret_manager_secret.db_password.secret_id}/versions/latest"
        env          = "DB_PASSWORD"
      }
    }

    options {
      worker_pool = google_cloudbuild_worker_pool.migration_pool.id
    }
  }

  depends_on = [google_project_service.cloudbuild_api]
}

resource "google_cloudbuild_worker_pool" "migration_pool" {
  name     = "safehouse-migration-pool"
  location = var.region

  worker_config {
    disk_size_gb   = 10
    machine_type   = "e2-standard-2"
    no_external_ip = false
  }

  network_config {
    peered_network          = google_compute_network.vpc.id
    peered_network_ip_range = "10.10.0.0/16"
  }

  depends_on = [google_project_service.cloudbuild_api]
}

resource "google_secret_manager_secret_iam_member" "cloudbuild_secret_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_gcr_access" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}
