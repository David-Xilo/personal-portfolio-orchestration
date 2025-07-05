output "cloud_run_url" {
  description = "The URL of the Cloud Run service"
  value       = google_cloud_run_service.safehouse_app.status[0].url
}

output "database_private_ip" {
  description = "The private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.main.private_ip_address
}

output "database_connection_name" {
  description = "The connection name for the Cloud SQL instance"
  value       = google_sql_database_instance.main.connection_name
}

output "database_url_secret" {
  description = "The Secret Manager secret containing the database URL"
  value       = google_secret_manager_secret.database_url.secret_id
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
  value       = google_sql_database_instance.main.name
}

# Not necessary for now - don't add for cost reduction
# output "terraform_state_bucket" {
#   description = "Name of the Terraform state bucket"
#   value       = google_storage_bucket.terraform_state.name
# }
