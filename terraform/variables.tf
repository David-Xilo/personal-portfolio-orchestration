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