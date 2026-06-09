###############################################################################
# Variables
###############################################################################

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Primary GCP region for Cloud Run + Artifact Registry"
  type        = string
  default     = "us-central1"
}

variable "bq_location" {
  description = "BigQuery dataset location"
  type        = string
  default     = "US"
}

variable "bridge_issuer_uri" {
  description = "OIDC issuer URI — must match iss claim in minted JWTs"
  type        = string
  default     = "https://identity-bridge.corp.internal"
}

variable "image_tag" {
  description = "Container image tag to deploy (injected by deploy.py)"
  type        = string
  default     = "latest"
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
  default     = "demo"
}
