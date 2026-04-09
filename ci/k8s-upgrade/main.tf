locals {
  project = "infra-testflight"
  channel = "STABLE"
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
    condition     = local.default_version != null && can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+-gke\\.[0-9]+$", local.default_version))
    error_message = "The ${local.channel} channel returned an invalid default version: '${local.default_version}'. Expected format: X.Y.Z-gke.N"
  }
}
