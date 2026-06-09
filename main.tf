###############################################################################
# Identity Bridge – Terraform root module
# Deployed via GCP Infrastructure Manager API
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

###############################################################################
# 1. Enable required APIs
###############################################################################
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "pubsub.googleapis.com",
    "bigquery.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "config.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false
}

data "google_project" "current" {}

###############################################################################
# 2. Service Accounts
# NOTE: infra-manager-deployer SA is pre-created by deploy.py bootstrap.
# We import it so Terraform manages it going forward without trying to create.
###############################################################################

resource "google_service_account" "bridge_runtime" {
  account_id   = "identity-bridge-runtime"
  display_name = "Identity Bridge Runtime SA"
  depends_on   = [google_project_service.apis]
}

# infra_deployer is imported (pre-exists) — see imports.tf
resource "google_service_account" "infra_deployer" {
  account_id   = "infra-manager-deployer"
  display_name = "Infrastructure Manager Deployer SA"
  depends_on   = [google_project_service.apis]
}

resource "google_project_iam_member" "deployer_roles" {
  for_each = toset([
    "roles/run.admin",
    "roles/secretmanager.admin",
    "roles/pubsub.admin",
    "roles/bigquery.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/artifactregistry.admin",
    "roles/storage.admin",
    "roles/logging.admin",
    "roles/config.agent",
    "roles/config.admin",
  ])
  project    = var.project_id
  role       = each.key
  member     = "serviceAccount:${google_service_account.infra_deployer.email}"
  depends_on = [google_service_account.infra_deployer]
}

###############################################################################
# 3. Artifact Registry
# Pre-created by deploy.py — imported so Terraform manages it.
###############################################################################
resource "google_artifact_registry_repository" "bridge_repo" {
  location      = var.region
  repository_id = "identity-bridge"
  description   = "Identity Bridge container images"
  format        = "DOCKER"
  depends_on    = [google_project_service.apis]
}

###############################################################################
# 4. Secret Manager
# Pre-created by deploy.py — imported so Terraform manages it.
###############################################################################
resource "google_secret_manager_secret" "signing_key" {
  secret_id = "bridge-signing-key"
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_iam_member" "bridge_secret_access" {
  secret_id  = google_secret_manager_secret.signing_key.secret_id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${google_service_account.bridge_runtime.email}"
  depends_on = [google_secret_manager_secret.signing_key]
}

###############################################################################
# 5. Pub/Sub
###############################################################################
resource "google_pubsub_topic" "audit" {
  name       = "identity-bridge-audit"
  depends_on = [google_project_service.apis]
  message_retention_duration = "86400s"
}

resource "google_pubsub_topic_iam_member" "bridge_pubsub_publish" {
  topic      = google_pubsub_topic.audit.name
  role       = "roles/pubsub.publisher"
  member     = "serviceAccount:${google_service_account.bridge_runtime.email}"
  depends_on = [google_pubsub_topic.audit]
}

###############################################################################
# 6. BigQuery
###############################################################################
resource "google_bigquery_dataset" "audit" {
  dataset_id    = "identity_bridge_audit"
  friendly_name = "Identity Bridge Audit Logs"
  location      = var.bq_location
  depends_on    = [google_project_service.apis]
}

resource "google_bigquery_table" "token_events" {
  dataset_id          = google_bigquery_dataset.audit.dataset_id
  table_id            = "token_events"
  deletion_protection = false

  schema = jsonencode([
    { name = "token_id",       type = "STRING",    mode = "REQUIRED" },
    { name = "issued_at",      type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "subject",        type = "STRING",    mode = "REQUIRED" },
    { name = "email",          type = "STRING",    mode = "NULLABLE" },
    { name = "department",     type = "STRING",    mode = "NULLABLE" },
    { name = "groups",         type = "STRING",    mode = "NULLABLE" },
    { name = "source_ip",      type = "STRING",    mode = "NULLABLE" },
    { name = "bridge_version", type = "STRING",    mode = "NULLABLE" },
  ])

  time_partitioning {
    type  = "DAY"
    field = "issued_at"
  }

  depends_on = [google_bigquery_dataset.audit]
}

# Grant Pub/Sub SA access to write to BigQuery
resource "google_project_iam_member" "pubsub_bq_writer" {
  project    = var.project_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "pubsub_bq_metadata" {
  project    = var.project_id
  role       = "roles/bigquery.metadataViewer"
  member     = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  depends_on = [google_project_service.apis]
}


###############################################################################
# 7. Workload Identity Federation
###############################################################################
resource "google_iam_workload_identity_pool" "legacy_idp" {
  workload_identity_pool_id = "legacy-idp-pool"
  display_name              = "Legacy IdP Pool"
  description               = "WIF pool for identity bridge OIDC tokens"
  depends_on                = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "bridge_oidc" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.legacy_idp.workload_identity_pool_id
  workload_identity_pool_provider_id = "bridge-oidc-provider"
  display_name                       = "Identity Bridge OIDC Provider"

  oidc {
    issuer_uri = var.bridge_issuer_uri
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.department" = "assertion.custom_dept"
    "attribute.email"      = "assertion.email"
  }

  attribute_condition = "assertion.iss == '${var.bridge_issuer_uri}'"
  depends_on          = [google_iam_workload_identity_pool.legacy_idp]
}

###############################################################################
# 8. Cloud Run
###############################################################################
resource "google_cloud_run_v2_service" "identity_bridge" {
  name     = "identity-bridge"
  location = var.region

  template {
    service_account = google_service_account.bridge_runtime.email

    scaling {
      min_instance_count = 1
      max_instance_count = 10
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/identity-bridge/bridge:${var.image_tag}"

      ports {
        container_port = 8080
      }

      env {
        name  = "GCP_PROJECT"
        value = var.project_id
      }
      env {
        name  = "BRIDGE_ISSUER_URI"
        value = var.bridge_issuer_uri
      }
      env {
        name  = "AUDIT_TOPIC"
        value = google_pubsub_topic.audit.name
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      startup_probe {
        http_get { path = "/health" }
        initial_delay_seconds = 5
        timeout_seconds       = 3
        period_seconds        = 5
        failure_threshold     = 3
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository.bridge_repo,
    google_secret_manager_secret_iam_member.bridge_secret_access,
    google_pubsub_topic_iam_member.bridge_pubsub_publish,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.identity_bridge.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
