###############################################################################
# Outputs — consumed by deploy.py after successful deployment
###############################################################################

output "bridge_url" {
  description = "Cloud Run service URL for the identity bridge"
  value       = google_cloud_run_v2_service.identity_bridge.uri
}

output "artifact_registry" {
  description = "Full Artifact Registry path for image pushes"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/identity-bridge"
}

output "workload_identity_pool" {
  description = "Full resource name of the WIF pool"
  value       = google_iam_workload_identity_pool.legacy_idp.name
}

output "wif_provider" {
  description = "Full resource name of the OIDC provider"
  value       = google_iam_workload_identity_pool_provider.bridge_oidc.name
}

output "audit_topic" {
  description = "Pub/Sub audit topic name"
  value       = google_pubsub_topic.audit.name
}

output "bq_table" {
  description = "Full BigQuery table reference"
  value       = "${var.project_id}.${google_bigquery_dataset.audit.dataset_id}.token_events"
}

output "bridge_runtime_sa" {
  description = "Bridge runtime service account email"
  value       = google_service_account.bridge_runtime.email
}

output "infra_deployer_sa" {
  description = "Infra Manager deployer service account email"
  value       = google_service_account.infra_deployer.email
}
