
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

  filter = <<EOF
    protoPayload.methodName:"google.iam.admin.v1.CreateServiceAccount" OR
    protoPayload.methodName:"google.iam.admin.v1.DeleteServiceAccount" OR
    protoPayload.methodName:"google.sql.admin.v1.SqlInstancesService.Update" OR
    protoPayload.methodName:"google.sql.admin.v1.SqlUsersService.Insert" OR
    protoPayload.methodName:"SetIamPolicy" OR
    protoPayload.methodName:"google.secretmanager" OR
    (resource.type="cloud_run_revision" AND httpRequest.status>=400)
  EOF
}


resource "google_monitoring_alert_policy" "unauthorized_access" {
  display_name = "Unauthorized Access Attempts"
  combiner     = "OR"

  conditions {
    display_name = "High 4xx Error Rate"

    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${google_cloud_run_service.safehouse_backend.name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [] # Add notification channels here

  alert_strategy {
    auto_close = "1800s"
  }
}

# Not necessary for now - don't add for cost reduction
# resource "google_storage_bucket" "terraform_state" {
#   name          = "${var.project_id}-terraform-state"
#   location      = var.region
#   force_destroy = true
#
#   versioning {
#     enabled = false
#   }
#
#   public_access_prevention = "enforced"
#
#   lifecycle_rule {
#     action {
#       type = "Delete"
#     }
#     condition {
#       age = 15
#       with_state = "ARCHIVED"
#     }
#   }
#
#   lifecycle_rule {
#     action {
#       type = "SetStorageClass"
#       storage_class = "ARCHIVE"
#     }
#     condition {
#       age = 7
#     }
#   }
# }
