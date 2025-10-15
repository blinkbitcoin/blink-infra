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
  # Convert outputs to sets
  uscentral1_versions = data.google_container_engine_versions.uscentral1.valid_master_versions
  useast1_versions    = data.google_container_engine_versions.useast1.valid_master_versions

  # Find the intersection of all sets, i.e., common versions
  common_all_versions = [for version in local.useast1_versions : version if contains(local.uscentral1_versions, version)]

  # Get the default version for the selected channel
  # see also here: https://cloud.google.com/kubernetes-engine/docs/release-notes
  uscentral1_default_version = data.google_container_engine_versions.uscentral1.release_channel_default_version[local.channel]
  useast1_default_version    = data.google_container_engine_versions.useast1.release_channel_default_version[local.channel]

  # Check if the STABLE channel default matches the version_prefix and is available in both regions
  # If the default is outside our version_prefix (e.g., default is 1.33 but we want 1.32),
  # fall back to the latest version from version_prefix that's available in both regions
  stable_version = (
    local.uscentral1_default_version == local.useast1_default_version &&
    startswith(local.uscentral1_default_version, local.version_prefix) &&
    contains(local.common_all_versions, local.uscentral1_default_version)
  ) ? local.uscentral1_default_version : (length(local.common_all_versions) > 0 ? local.common_all_versions[0] : null)


}

# Validation: Fail if no stable version is available
check "stable_version_available" {
  assert {
    condition     = local.stable_version != null
    error_message = "No stable version found with prefix ${local.version_prefix} that is available in both regions (us-central1 and us-east1). Note: ${local.channel} channel default is ${local.uscentral1_default_version} in us-central1 and ${local.useast1_default_version} in us-east1."
  }
}

output "uscentral1_default_version" {
  value = local.uscentral1_default_version
}

output "useast1_default_version" {
  value = local.useast1_default_version
}

output "latest_version" {
  description = "The latest version with the configured prefix available in both regions. Prefers STABLE channel default if it matches the prefix."
  # This should never be null due to the validation check above, but adding extra safety
  value = local.stable_version != null ? local.stable_version : ""
}
