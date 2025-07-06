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

output "audit_logs_bucket" {
  description = "The audit logs storage bucket"
  value       = google_storage_bucket.audit_logs.name
}

output "vpc_network_name" {
  description = "The VPC network name"
  value       = google_compute_network.vpc.name
}

output "database_instance_name" {
  description = "The Cloud SQL instance name"
  value       = google_sql_database_instance.db_instance.name
}

output "secret_names" {
  description = "Names of created secrets"
  value = {
    db_password      = google_secret_manager_secret.db_password.secret_id
    jwt_signing_key  = google_secret_manager_secret.jwt_signing_key.secret_id
    frontend_auth    = google_secret_manager_secret.frontend_auth_key.secret_id
  }
}

output "service_account_emails" {
  description = "Service account email addresses"
  value = {
    cloud_run = google_service_account.cloud_run_sa.email
    cicd      = google_service_account.terraform_cicd.email
  }
}

output "workload_identity_provider" {
  description = "Workload Identity Provider path for GitHub Actions"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "project_number" {
  description = "Project number for Workload Identity configuration"
  value       = data.google_project.project.number
}