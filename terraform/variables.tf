variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region (Mumbai)"
  type        = string
  default     = "asia-south1"
}

variable "cluster_name" {
  description = "GKE Autopilot cluster name"
  type        = string
  default     = "self-healing-demo"
}

variable "github_repo" {
  description = "GitHub repo allowed to authenticate via WIF, format: owner/repo"
  type        = string
}
