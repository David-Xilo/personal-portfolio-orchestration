
resource "null_resource" "run_migrations" {
  depends_on = [
    google_sql_database_instance.db_instance,
    google_sql_database.safehouse_db,
    google_sql_user.db_user,
    google_secret_manager_secret_version.db_password
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Starting database migration process"
      
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
      
      echo "Migration image found. Running migrations"
      
      # Pull the migration image
      docker pull gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag}
      
      # Run migrations using Cloud SQL Proxy (as designed in your script)
      docker run --rm \
        -v "$HOME/.config/gcloud:/root/.config/gcloud:ro" \
        -e PROJECT_ID="${var.project_id}" \
        -e INSTANCE_NAME="safehouse-db-instance" \
        -e DATABASE_NAME="safehouse_db" \
        -e DATABASE_USER="safehouse_db_user" \
        -e PASSWORD_SECRET="safehouse-db-password" \
        --network="host" \
        gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} up
      
      echo "Database migrations completed successfully!"
    EOT

    environment = {
      GOOGLE_CLOUD_PROJECT = var.project_id
    }
  }

  # Trigger re-run if database changes or migration image changes
  triggers = {
    database_connection = google_sql_database_instance.db_instance.connection_name
    database_name      = google_sql_database.safehouse_db.name
    user_name         = google_sql_user.db_user.name
    migration_image   = var.migration_image_tag
    force_rerun       = var.force_migration_rerun
  }
}
