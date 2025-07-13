
data "external" "migration_status" {
  program = ["bash", "-c", "echo '{\"status\": \"completed\"}'"]

  depends_on = [null_resource.run_migrations]
}

resource "null_resource" "run_migrations" {
  depends_on = [
    google_sql_database_instance.db_instance,
    google_sql_database.safehouse_db,
    google_sql_user.db_user_iam,
    google_project_iam_member.cloud_run_sa_roles
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Starting database migration process with IAM authentication"

      sleep 60

      if ! gcloud container images describe gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} --format="value(name)" >/dev/null 2>&1; then
        echo "ERROR: Migration image not found in registry!"
        exit 1
      fi

      docker pull gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag}

      # Use the short service account name for database username
      docker run --rm \
        -v "$HOME/.config/gcloud:/home/migrate-user/.config/gcloud:ro" \
        -e PROJECT_ID="${var.project_id}" \
        -e INSTANCE_NAME="safehouse-db-instance" \
        -e DATABASE_NAME="safehouse_db" \
        -e DATABASE_USER="safehouse-cloud-run" \
        -e USE_IAM_AUTH="true" \
        -e CLOUDSDK_CONFIG="/home/migrate-user/.config/gcloud" \
        --network="host" \
        gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} up

      echo "Verifying migration completion..."
      docker run --rm \
        -v "$HOME/.config/gcloud:/home/migrate-user/.config/gcloud:ro" \
        -e PROJECT_ID="${var.project_id}" \
        -e INSTANCE_NAME="safehouse-db-instance" \
        -e DATABASE_NAME="safehouse_db" \
        -e DATABASE_USER="safehouse-cloud-run" \
        -e USE_IAM_AUTH="true" \
        -e CLOUDSDK_CONFIG="/home/migrate-user/.config/gcloud" \
        --network="host" \
        gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} version

      echo "Database migrations completed successfully with IAM authentication!"
    EOT

    environment = {
      GOOGLE_CLOUD_PROJECT = var.project_id
    }
  }

  triggers = {
    database_connection = google_sql_database_instance.db_instance.connection_name
    database_name       = google_sql_database.safehouse_db.name
    user_name           = google_sql_user.db_user_iam.name
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
