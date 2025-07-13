
resource "google_sql_user" "db_user_iam_short" {
  name     = "db-acc@personal-portfolio-safehouse.iam"
  instance = google_sql_database_instance.db_instance.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"

  depends_on = [
    google_service_account.db_access,
    google_sql_database_instance.db_instance
  ]
}

data "external" "migration_status" {
  program = ["bash", "-c", "echo '{\"status\": \"completed\"}'"]

  depends_on = [null_resource.run_migrations]
}

resource "null_resource" "run_migrations" {
  depends_on = [
    google_sql_database_instance.db_instance,
    google_sql_database.safehouse_db,
    google_sql_user.db_user_iam_short,
    google_service_account.db_access,
    google_service_account_iam_member.cloud_run_impersonate_db_sa
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Starting database migration with dedicated database service account"

      sleep 60

      if ! gcloud container images describe gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} --format="value(name)" >/dev/null 2>&1; then
        echo "ERROR: Migration image not found in registry!"
        exit 1
      fi

      docker pull gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag}

      # Use the dedicated service account for database access
      docker run --rm \
        -v "$HOME/.config/gcloud:/home/migrate-user/.config/gcloud:ro" \
        -e PROJECT_ID="${var.project_id}" \
        -e INSTANCE_NAME="safehouse-db-instance" \
        -e DATABASE_NAME="safehouse_db" \
        -e DATABASE_USER="${google_service_account.db_access.account_id}" \
        -e USE_IAM_AUTH="true" \
        -e DB_SERVICE_ACCOUNT="${google_service_account.db_access.email}" \
        -e CLOUDSDK_CONFIG="/home/migrate-user/.config/gcloud" \
        --network="host" \
        gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} up

      echo "Database migrations completed with dedicated service account!"
    EOT

    environment = {
      GOOGLE_CLOUD_PROJECT = var.project_id
    }
  }

  triggers = {
    database_connection = google_sql_database_instance.db_instance.connection_name
    database_name       = google_sql_database.safehouse_db.name
    user_name           = google_sql_user.db_user_iam_short.name
    service_account     = google_service_account.db_access.email
    migration_image     = var.migration_image_tag
    force_rerun         = var.force_migration_rerun
  }
}

resource "null_resource" "verify_migration_completion" {
  depends_on = [null_resource.run_migrations]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Verifying migration completion..."

      # Verify migration was successful by checking database schema
      docker run --rm \
        -v "$HOME/.config/gcloud:/root/.config/gcloud:ro" \
        -e PROJECT_ID="${var.project_id}" \
        -e INSTANCE_NAME="safehouse-db-instance" \
        -e DATABASE_NAME="safehouse_db" \
        -e DATABASE_USER="safehouse_db_user" \
        -e PASSWORD_SECRET="safehouse-db-password" \
        --network="host" \
        gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} version

      echo "Migration verification completed!"
    EOT
  }

  triggers = {
    migration_run = null_resource.run_migrations.id
  }
}
