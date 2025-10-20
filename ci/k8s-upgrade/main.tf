locals {
  version_prefix = "1.33."
  project        = "infra-testflight"
  channel        = "STABLE"
}

data "google_container_engine_versions" "uscentral1" {
  provider       = google-beta
  location       = "us-central1"
  version_prefix = local.version_prefix
  project        = local.project
}

data "google_container_engine_versions" "useast1" {
  provider       = google-beta
  location       = "us-east1"
  version_prefix = local.version_prefix
  project        = local.project
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
    condition     = startswith(local.default_version, local.version_prefix)
    error_message = "The ${local.channel} channel default version '${local.default_version}' does not match the configured version prefix '${local.version_prefix}'."
  }
}
