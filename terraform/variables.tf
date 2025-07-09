variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
  default     = "personal-portfolio-safehouse"
}

variable "region" {
  description = "The Google Cloud region"
  type        = string
  default     = "us-central1" # Good for free tier
}

variable "authorized_user_email" {
  description = "Email address of the authorized user for Cloud Run access"
  type        = string
  default     = "david.dbmoura@gmail.com"
}

variable "backend_github_repository" {
  description = "GitHub backend repository name for Workload Identity binding"
  type        = string
  default     = "safehouse-main-back"
}

variable "frontend_github_repository" {
  description = "GitHub frontend repository name for Workload Identity binding"
  type        = string
  default     = "safehouse-main-front"
}

variable "migrations_github_repository" {
  description = "GitHub migrations repository name for Workload Identity binding"
  type        = string
  default     = "safehouse-db-schema"
}

variable "orchestration_github_repository" {
  description = "GitHub orchestration repository name for Workload Identity binding"
  type        = string
  default     = "safehouse-orchestration"
}

variable "github_user" {
  description = "GitHub username"
  type        = string
  default     = "David-Xilo"
}
