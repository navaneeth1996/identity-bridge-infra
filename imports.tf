###############################################################################
# Import ALL pre-existing resources into Terraform state.
# Variables not allowed in import block IDs — must be hardcoded.
###############################################################################

import {
  id = "projects/gcp-nav-project/serviceAccounts/infra-manager-deployer@gcp-nav-project.iam.gserviceaccount.com"
  to = google_service_account.infra_deployer
}

import {
  id = "projects/gcp-nav-project/serviceAccounts/identity-bridge-runtime@gcp-nav-project.iam.gserviceaccount.com"
  to = google_service_account.bridge_runtime
}

import {
  id = "projects/gcp-nav-project/locations/us-central1/repositories/identity-bridge"
  to = google_artifact_registry_repository.bridge_repo
}

import {
  id = "projects/gcp-nav-project/secrets/bridge-signing-key"
  to = google_secret_manager_secret.signing_key
}

import {
  id = "projects/gcp-nav-project/topics/identity-bridge-audit"
  to = google_pubsub_topic.audit
}

import {
  id = "projects/gcp-nav-project/datasets/identity_bridge_audit"
  to = google_bigquery_dataset.audit
}

import {
  id = "projects/gcp-nav-project/locations/global/workloadIdentityPools/legacy-idp-pool"
  to = google_iam_workload_identity_pool.legacy_idp
}

import {
  id = "projects/gcp-nav-project/locations/global/workloadIdentityPools/legacy-idp-pool/providers/bridge-oidc-provider"
  to = google_iam_workload_identity_pool_provider.bridge_oidc
}


import {
  id = "projects/gcp-nav-project/locations/us-central1/services/identity-bridge"
  to = google_cloud_run_v2_service.identity_bridge
}
