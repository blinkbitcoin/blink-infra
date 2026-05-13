variable "version_prefix" {
  description = "Kubernetes major/minor prefix guard (for example: 1.33.)"
  type        = string
  default     = "1.33."
}

locals {
  version_prefix = var.version_prefix
  project        = "infra-testflight"
  channel        = "STABLE"
}

data "google_container_engine_versions" "uscentral1" {
  provider       = google-beta
  location       = "us-central1"
  project        = local.project
  version_prefix = local.version_prefix
}

data "google_container_engine_versions" "useast1" {
  provider       = google-beta
  location       = "us-east1"
  project        = local.project
  version_prefix = local.version_prefix
}

locals {
  # Get the latest version matching the pinned prefix for the STABLE channel.
  # see also here: https://cloud.google.com/kubernetes-engine/docs/release-notes
  latest_version = lookup(data.google_container_engine_versions.uscentral1.release_channel_latest_version, local.channel, null)
}

output "latest_version" {
  description = "The latest pinned-prefix version from the STABLE channel."
  value       = local.latest_version

  precondition {
    condition     = local.latest_version != null && can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+-gke\\.[0-9]+$", local.latest_version)) && (local.version_prefix == "" || startswith(local.latest_version, local.version_prefix))
    error_message = "The ${local.channel} channel returned no valid latest version for prefix '${local.version_prefix}' (when configured). Got: '${local.latest_version}'. Expected format: X.Y.Z-gke.N."
  }
}
