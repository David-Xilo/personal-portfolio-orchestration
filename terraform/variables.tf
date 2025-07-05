variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
  default     = "personal-portfolio-safehouse"
}

variable "region" {
  description = "The Google Cloud region"
  type        = string
  default     = "us-central1"  # Good for free tier
}

variable "authorized_user_email" {
  description = "Email address of the authorized user for Cloud Run access"
  type        = string
  default     = "david.dbmoura@gmail.com"
}
