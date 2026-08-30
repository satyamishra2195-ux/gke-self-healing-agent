terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ---------------------------------------------------------------
# 1. Enable required APIs
# ---------------------------------------------------------------
resource "google_project_service" "apis" {
  for_each = toset([
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false
}

# ---------------------------------------------------------------
# 2. Artifact Registry - Docker images yahan push honge
# ---------------------------------------------------------------
resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = "apps"
  format        = "DOCKER"
  depends_on    = [google_project_service.apis]
}

# ---------------------------------------------------------------
# 3. GKE Autopilot cluster
#    Autopilot = Google manages nodes; you only pay for pod resources.
#    deletion_protection=false so terraform destroy works raat ko.
# ---------------------------------------------------------------
resource "google_container_cluster" "autopilot" {
  name                = var.cluster_name
  location            = var.region
  enable_autopilot    = true
  deletion_protection = false

  release_channel {
    channel = "REGULAR"
  }

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------
# 4. Service account jo GitHub Actions use karega
# ---------------------------------------------------------------
resource "google_service_account" "github_actions" {
  account_id   = "github-actions-deployer"
  display_name = "GitHub Actions deployer"
}

# Cluster pe deploy karne ki permission
resource "google_project_iam_member" "gke_dev" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Artifact Registry pe image push karne ki permission
resource "google_project_iam_member" "ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# ---------------------------------------------------------------
# 5. Workload Identity Federation
#    GitHub ka OIDC token -> GCP service account, bina kisi JSON key ke.
#    attribute_condition ensures SIRF tumhara repo hi auth kar sake.
# ---------------------------------------------------------------
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions pool"
  depends_on                = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "attribute.repository == \"${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Pool ke identities ko service account impersonate karne do
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}
