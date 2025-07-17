
##
# ALL this was removed to keep gcloud in its free tier
##

# resource "google_sql_user" "migration_access" {
#   name     = "db-acc@personal-portfolio-safehouse.iam"
#   instance = google_sql_database_instance.db_instance.name
#   type     = "CLOUD_IAM_SERVICE_ACCOUNT"
#
#   depends_on = [
#     google_service_account.db_access,
#     google_sql_database_instance.db_instance
#   ]
# }
#
# data "external" "migration_status" {
#   program = ["bash", "-c", "echo '{\"status\": \"completed\"}'"]
#
#   depends_on = [null_resource.run_migrations]
# }
#
# resource "null_resource" "run_migrations" {
#   depends_on = [
#     google_sql_database_instance.db_instance,
#     google_sql_database.safehouse_db,
#     google_sql_user.migration_access,
#     google_service_account.db_access,
#     google_service_account_iam_member.terraform_cicd_impersonate_db_sa
#   ]
#
#   provisioner "local-exec" {
#     interpreter = ["bash", "-c"]
#     command     = <<-EOT
# echo "Starting database migration with dedicated database service account"
# sleep 60
#
# # Ensure the migration image exists
# if ! gcloud container images describe gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} \
#     --format="value(name)" >/dev/null 2>&1; then
#   echo "ERROR: Migration image not found!"
#   exit 1
# fi
#
# docker pull gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag}
#
# # Generate a fresh access token by impersonating the db_access service account
# export GOOGLE_ACCESS_TOKEN=$(
#   gcloud auth print-access-token \
#     --impersonate-service-account="${google_service_account.db_access.email}"
# )
#
# # Run migration container with the token
# docker run --rm \
#   --user root \
#   -e PROJECT_ID="${var.project_id}" \
#   -e INSTANCE_NAME="safehouse-db-instance" \
#   -e DATABASE_NAME="safehouse_db" \
#   -e DATABASE_USER="${google_sql_user.migration_access.name}" \
#   -e USE_IAM_AUTH="true" \
#   -e GOOGLE_ACCESS_TOKEN="$GOOGLE_ACCESS_TOKEN" \
#   -e DB_SERVICE_ACCOUNT="${google_service_account.db_access.email}" \
#   -e CONNECTION_NAME="${google_sql_database_instance.db_instance.connection_name}" \
#   --network="host" \
#   gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} up
#
# echo "Database migrations completed!"
# EOT
#
#     environment = {
#       GOOGLE_CLOUD_PROJECT = var.project_id
#     }
#   }
#
#   triggers = {
#     database_connection = google_sql_database_instance.db_instance.connection_name
#     database_name       = google_sql_database.safehouse_db.name
#     user_name           = google_service_account.db_access.email
#     service_account     = google_service_account.db_access.email
#     migration_image     = var.migration_image_tag
#     force_rerun         = var.force_migration_rerun
#   }
# }
#
# resource "null_resource" "verify_migration_completion" {
#   depends_on = [null_resource.run_migrations]
#
#   provisioner "local-exec" {
#     interpreter = ["bash", "-c"]
#     command     = <<-EOT
# echo "Verifying migration completion..."
# sleep 5
#
# # Generate a fresh IAM access token at runtime
# export GOOGLE_ACCESS_TOKEN=$(
#   gcloud auth print-access-token \
#     --impersonate-service-account="${google_service_account.db_access.email}"
# )
#
# # Run the migration container with the token, using 'version' command
# docker run --rm \
#   --user root \
#   -e PROJECT_ID="${var.project_id}" \
#   -e INSTANCE_NAME="safehouse-db-instance" \
#   -e DATABASE_NAME="safehouse_db" \
#   -e DATABASE_USER="${google_sql_user.migration_access.name}" \
#   -e USE_IAM_AUTH="true" \
#   -e GOOGLE_ACCESS_TOKEN="$GOOGLE_ACCESS_TOKEN" \
#   -e DB_SERVICE_ACCOUNT="${google_service_account.db_access.email}" \
#   -e CONNECTION_NAME="${google_sql_database_instance.db_instance.connection_name}" \
#   --network="host" \
#   gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} version
#
# echo "Migration verification completed!"
# EOT
#   }
#
#   triggers = {
#     migration_run = null_resource.run_migrations.id
#   }
# }


# data "google_service_account_access_token" "db_token" {
#   provider               = google.impersonate_db
#   target_service_account = google_service_account.db_access.email
#   scopes                 = ["https://www.googleapis.com/auth/cloud-platform"]
#   lifetime               = "3600s"
# }

# resource "google_sql_database_instance" "db_instance" {
#   name             = "safehouse-db-instance"
#   database_version = "POSTGRES_13"
#   region           = var.region
#
#   settings {
#     tier = "db-f1-micro"
#
#     # no need for backup for now
#     backup_configuration {
#       enabled = false
#     }
#
#     ip_configuration {
#       ipv4_enabled    = false
#       private_network = google_compute_network.vpc.id
#       require_ssl     = true
#     }
#
#     database_flags {
#       name  = "cloudsql.iam_authentication"
#       value = "on"
#     }
#
#     database_flags {
#       name  = "log_connections"
#       value = "on"
#     }
#
#     database_flags {
#       name  = "log_disconnections"
#       value = "on"
#     }
#   }
#
#   depends_on = [
#     google_project_service.cloud_sql_api,
#     google_service_networking_connection.private_vpc_connection
#   ]
# }

# Create database
# resource "google_sql_database" "safehouse_db" {
#   name     = "safehouse_db"
#   instance = google_sql_database_instance.db_instance.name
# }
#
# resource "time_rotating" "pw_trigger" {
#   rotation_minutes = 1440 # 24h
# }
#
# resource "google_sql_user" "db_user" {
#   name     = "safehouse_db_user"
#   instance = google_sql_database_instance.db_instance.name
#   password = data.google_secret_manager_secret_version.db_password.secret_data
#
#   lifecycle {
#     ignore_changes       = [password]
#     replace_triggered_by = [time_rotating.pw_trigger.id]
#   }
# }
