###############################################################################
# Import pre-existing resources into Terraform state.
# IDs must be hardcoded — variables are not allowed in import blocks.
###############################################################################

import {
  id = "projects/gcp-nav-project/serviceAccounts/infra-manager-deployer@gcp-nav-project.iam.gserviceaccount.com"
  to = google_service_account.infra_deployer
}

import {
  id = "projects/gcp-nav-project/locations/us-central1/repositories/identity-bridge"
  to = google_artifact_registry_repository.bridge_repo
}

import {
  id = "projects/gcp-nav-project/secrets/bridge-signing-key"
  to = google_secret_manager_secret.signing_key
}
