output "cluster_name" {
  value = google_container_cluster.autopilot.name
}

output "region" {
  value = var.region
}

output "registry_url" {
  description = "Prefix for docker image tags"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

output "wif_provider" {
  description = "Paste into GitHub secret GCP_WIF_PROVIDER"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_email" {
  description = "Paste into GitHub secret GCP_SA_EMAIL"
  value       = google_service_account.github_actions.email
}
