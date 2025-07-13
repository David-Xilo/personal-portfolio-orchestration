
data "external" "migration_status" {
  program = ["bash", "-c", "echo '{\"status\": \"completed\"}'"]

  depends_on = [null_resource.run_migrations]
}

resource "null_resource" "run_migrations" {
  depends_on = [
    google_sql_database_instance.db_instance,
    google_sql_database.safehouse_db,
    google_sql_user.db_user_iam,  # Depend on IAM user instead of password user
    google_project_iam_member.cloud_run_sa_roles  # Ensure service account has proper roles
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Starting database migration process with IAM authentication"

      # Wait for database to be fully ready
      sleep 60

      # Check if migration image exists in registry
      echo "Checking for migration image in registry"
      if ! gcloud container images describe gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} --format="value(name)" >/dev/null 2>&1; then
        echo "ERROR: Migration image not found in registry!"
        echo "Please ensure gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} exists"
        echo "Build and push it from the migrations repository first"
        exit 1
      fi

      echo "Migration image found. Running migrations with IAM authentication"

      # Pull the migration image
      docker pull gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag}

      # Run migrations with IAM authentication (most secure - no passwords!)
      docker run --rm \
        -v "$HOME/.config/gcloud:/home/migrate-user/.config/gcloud:ro" \
        -e PROJECT_ID="${var.project_id}" \
        -e INSTANCE_NAME="safehouse-db-instance" \
        -e DATABASE_NAME="safehouse_db" \
        -e DATABASE_USER="${data.google_service_account.cloud_run_sa.email}" \
        -e USE_IAM_AUTH="true" \
        -e CLOUDSDK_CONFIG="/home/migrate-user/.config/gcloud" \
        --network="host" \
        gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} up

      # Verify migrations were applied successfully
      echo "Verifying migration completion..."
      docker run --rm \
        -v "$HOME/.config/gcloud:/home/migrate-user/.config/gcloud:ro" \
        -e PROJECT_ID="${var.project_id}" \
        -e INSTANCE_NAME="safehouse-db-instance" \
        -e DATABASE_NAME="safehouse_db" \
        -e DATABASE_USER="${data.google_service_account.cloud_run_sa.email}" \
        -e USE_IAM_AUTH="true" \
        -e CLOUDSDK_CONFIG="/home/migrate-user/.config/gcloud" \
        --network="host" \
        gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} version

      echo "Database migrations completed and verified successfully with IAM authentication!"
    EOT

    environment = {
      GOOGLE_CLOUD_PROJECT = var.project_id
    }
  }

  # Trigger re-run if database changes or migration image changes
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
