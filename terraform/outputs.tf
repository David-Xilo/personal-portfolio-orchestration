output "cloud_run_url" {
  description = "The URL of the Cloud Run service"
  value       = google_cloud_run_service.safehouse_backend.status[0].url
}

output "database_private_ip" {
  description = "The private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.db_instance.private_ip_address
}

output "database_connection_name" {
  description = "The connection name for the Cloud SQL instance"
  value       = google_sql_database_instance.db_instance.connection_name
}

output "vpc_connector_name" {
  description = "The VPC Access Connector name"
  value       = google_vpc_access_connector.connector.name
}

output "vpc_network_name" {
  description = "The VPC network name"
  value       = google_compute_network.vpc.name
}

output "database_instance_name" {
  description = "The Cloud SQL instance name"
  value       = google_sql_database_instance.db_instance.name
}

output "service_account_emails" {
  description = "Service account email addresses"
  value = {
    cloud_run = data.google_service_account.cloud_run_sa.email
    cicd      = data.google_service_account.terraform_cicd.email
  }
}

output "project_number" {
  description = "Project number for Workload Identity configuration"
  value       = data.google_project.project.number
}

output "repository_configuration" {
  description = "GitHub repository configuration"
  value = {
    backend       = var.backend_github_repository
    frontend      = var.frontend_github_repository
    migrations    = var.migrations_github_repository
    orchestration = var.orchestration_github_repository
    github_user   = var.github_user
  }
}

output "frontend_url" {
  description = "The URL of the frontend Cloud Run service"
  value       = google_cloud_run_service.safehouse_frontend.status[0].url
}

output "environment_info" {
  description = "Environment and project information"
  value = {
    project_id  = var.project_id
    region      = var.region
    environment = "production"
  }
}

output "migration_trigger_name" {
  description = "Cloud Build trigger name for migrations"
  value       = google_cloudbuild_trigger.run_migrations.name
}

output "migration_commands" {
  description = "Commands to run database migrations"
  value = {
    # Run migrations up (default)
    run_up = "gcloud builds run --source=. --config=cloudbuild-migration.yaml --substitutions=_MIGRATION_COMMAND=up"

    # Or trigger the existing trigger
    trigger_up      = "gcloud builds triggers run ${google_cloudbuild_trigger.run_migrations.name} --substitutions=_MIGRATION_COMMAND=up"
    trigger_down    = "gcloud builds triggers run ${google_cloudbuild_trigger.run_migrations.name} --substitutions=_MIGRATION_COMMAND=down"
    trigger_version = "gcloud builds triggers run ${google_cloudbuild_trigger.run_migrations.name} --substitutions=_MIGRATION_COMMAND=version"

    # Check logs
    check_logs = "gcloud logging read 'resource.type=\"build\" AND protoPayload.methodName=\"google.devtools.cloudbuild.v1.CloudBuild.CreateBuild\"' --limit=10"
  }
}

output "build_worker_pool" {
  description = "Cloud Build worker pool for migrations"
  value = {
    name     = google_cloudbuild_worker_pool.migration_pool.name
    location = google_cloudbuild_worker_pool.migration_pool.location
  }
}
