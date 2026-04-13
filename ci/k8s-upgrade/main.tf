variable "version_prefix" {
  description = "Kubernetes major/minor prefix guard (for example: 1.33.)"
  type        = string
  default     = ""
}

locals {
  version_prefix = var.version_prefix
  project        = "infra-testflight"
  channel        = "STABLE"
}

data "google_container_engine_versions" "uscentral1" {
  provider = google-beta
  location = "us-central1"
  project  = local.project
}

data "google_container_engine_versions" "useast1" {
  provider = google-beta
  location = "us-east1"
  project  = local.project
}

locals {
  # Get the default version for the STABLE channel
  # see also here: https://cloud.google.com/kubernetes-engine/docs/release-notes
  default_version = data.google_container_engine_versions.uscentral1.release_channel_default_version[local.channel]
}

output "latest_version" {
  description = "The default version from the STABLE channel."
  value       = local.default_version

  precondition {
    condition     = local.default_version != null && can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+-gke\\.[0-9]+$", local.default_version)) && (local.version_prefix == "" || startswith(local.default_version, local.version_prefix))
    error_message = "The ${local.channel} channel returned an invalid default version: '${local.default_version}'. Expected format: X.Y.Z-gke.N and version prefix '${local.version_prefix}' (when configured)."
  }
}
