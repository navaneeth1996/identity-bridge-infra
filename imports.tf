###############################################################################
# Import pre-existing resources created by deploy.py bootstrap steps.
# These were created before Terraform ran — without import blocks Terraform
# would try to create them again and fail with 409 Already Exists.
###############################################################################

import {
  id = "projects/${var.project_id}/serviceAccounts/infra-manager-deployer@${var.project_id}.iam.gserviceaccount.com"
  to = google_service_account.infra_deployer
}

import {
  id = "projects/${var.project_id}/locations/${var.region}/repositories/identity-bridge"
  to = google_artifact_registry_repository.bridge_repo
}

import {
  id = "projects/${var.project_id}/secrets/bridge-signing-key"
  to = google_secret_manager_secret.signing_key
}
