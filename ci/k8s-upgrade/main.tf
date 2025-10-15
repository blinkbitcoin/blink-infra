locals {
  version_prefix = "1.32."
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
  # Get the default version for the selected channel
  # see also here: https://cloud.google.com/kubernetes-engine/docs/release-notes
  uscentral1_default_version = data.google_container_engine_versions.uscentral1.release_channel_default_version[local.channel]
  useast1_default_version    = data.google_container_engine_versions.useast1.release_channel_default_version[local.channel]

  # Get the latest version in the STABLE channel for the given version_prefix
  # This ensures we only get versions that are actually in the STABLE channel, not RAPID
  uscentral1_latest_version = data.google_container_engine_versions.uscentral1.release_channel_latest_version[local.channel]
  useast1_latest_version    = data.google_container_engine_versions.useast1.release_channel_latest_version[local.channel]

  # Use the latest version from the STABLE channel if it matches our version_prefix and is consistent across regions
  stable_version = (
    local.uscentral1_latest_version == local.useast1_latest_version &&
    startswith(local.uscentral1_latest_version, local.version_prefix)
  ) ? local.uscentral1_latest_version : null


}

# Validation: Fail if no stable version is available
check "stable_version_available" {
  assert {
    condition     = local.stable_version != null
    error_message = "No ${local.channel} channel version found with prefix ${local.version_prefix} that is consistent across both regions. ${local.channel} channel latest: us-central1=${local.uscentral1_latest_version}, us-east1=${local.useast1_latest_version}. ${local.channel} channel default: us-central1=${local.uscentral1_default_version}, us-east1=${local.useast1_default_version}."
  }
}

output "uscentral1_default_version" {
  value = local.uscentral1_default_version
}

output "useast1_default_version" {
  value = local.useast1_default_version
}

output "uscentral1_latest_version" {
  value = local.uscentral1_latest_version
}

output "useast1_latest_version" {
  value = local.useast1_latest_version
}

output "latest_version" {
  description = "The latest version from the STABLE channel with the configured prefix available in both regions."
  # This should never be null due to the validation check above, but adding extra safety
  value = local.stable_version != null ? local.stable_version : ""
}
