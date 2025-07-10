
resource "google_storage_bucket" "audit_logs" {
  name          = "${var.project_id}-audit-logs"
  location      = var.region
  force_destroy = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 15
    }
  }
}

# Enhanced audit logging with more security events
resource "google_logging_project_sink" "security_sink" {
  name        = "security-audit-sink"
  project     = var.project_id
  destination = "storage.googleapis.com/${google_storage_bucket.audit_logs.name}"

  filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"safehouse-backend\" AND httpRequest.status>=400"
}


