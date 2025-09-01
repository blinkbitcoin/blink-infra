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



  # Get the version that is the STABLE channel default in both regions AND available in both regions
  # This will be null if the conditions aren't met (which will cause the validation check to fail)
  stable_version = (
    local.uscentral1_default_version == local.useast1_default_version &&
    contains(local.common_all_versions, local.uscentral1_default_version)
  ) ? local.uscentral1_default_version : null


}

# Validation: Fail if no stable version is available
check "stable_version_available" {
  assert {
    condition     = local.stable_version != null
    error_message = "No stable version found. Either the ${local.channel} channel defaults don't match between regions (us-central1: ${local.uscentral1_default_version}, us-east1: ${local.useast1_default_version}) or the default version is not available in both regions."
  }
}

output "uscentral1_default_version" {
  value = local.uscentral1_default_version
}

output "useast1_default_version" {
  value = local.useast1_default_version
}

output "latest_version" {
  description = "The version from the selected channel in both regions and available in both regions"
  # This should never be null due to the validation check above, but adding extra safety
  value = local.stable_version != null ? local.stable_version : ""
}
