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

output "deployment_images" {
  description = "Docker images used in this deployment"
  value = {
    migration = "gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag}"
    backend   = "gcr.io/${var.project_id}/safehouse-backend-main:${var.backend_image_tag}"
    frontend  = "gcr.io/${var.project_id}/safehouse-frontend-main:${var.frontend_image_tag}"
  }
}

output "image_tags" {
  description = "Image tags used in this deployment"
  value = {
    migration = var.migration_image_tag
    backend   = var.backend_image_tag
    frontend  = var.frontend_image_tag
  }
}

output "manual_migration_commands" {
  description = "Commands to run migrations manually"
  value = {
    pull_image  = "docker pull gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag}"
    run_up      = "docker run --rm -v $HOME/.config/gcloud:/root/.config/gcloud:ro -e PROJECT_ID=${var.project_id} -e INSTANCE_NAME=safehouse-db-instance -e DATABASE_NAME=safehouse_db -e DATABASE_USER=safehouse_db_user -e PASSWORD_SECRET=safehouse-db-password --network=host gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} up"
    run_version = "docker run --rm -v $HOME/.config/gcloud:/root/.config/gcloud:ro -e PROJECT_ID=${var.project_id} -e INSTANCE_NAME=safehouse-db-instance -e DATABASE_NAME=safehouse_db -e DATABASE_USER=safehouse_db_user -e PASSWORD_SECRET=safehouse-db-password --network=host gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} version"
    run_down    = "docker run --rm -v $HOME/.config/gcloud:/root/.config/gcloud:ro -e PROJECT_ID=${var.project_id} -e INSTANCE_NAME=safehouse-db-instance -e DATABASE_NAME=safehouse_db -e DATABASE_USER=safehouse_db_user -e PASSWORD_SECRET=safehouse-db-password --network=host gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag} down"
    current_tag = "Currently using migration image: gcr.io/${var.project_id}/safehouse-migrations:${var.migration_image_tag}"
  }
}
