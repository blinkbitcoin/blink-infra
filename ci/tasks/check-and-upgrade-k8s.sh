#!/bin/bash

set -eu

source pipeline-tasks/ci/tasks/helpers.sh
pushd repo

CURRENT_VERSION=$(hcledit -f modules/platform/gcp/variables.tf attribute get variable.kube_version.default | tr -d '"')

# Fallback only: when CURRENT_VERSION is null/empty, use a pinned minor guard to avoid
# unexpected STABLE cross-minor upgrades during bootstrap/self-heal.
VERSION_PREFIX="1.33."
if [[ -n "${CURRENT_VERSION}" && "${CURRENT_VERSION}" != "null" ]]; then
  if [[ "${CURRENT_VERSION}" =~ ^([0-9]+\.[0-9]+)\.[0-9]+-gke\.[0-9]+$ ]]; then
    VERSION_PREFIX="${BASH_REMATCH[1]}."
  else
    echo "CURRENT_VERSION has unexpected format: '${CURRENT_VERSION}'"
    exit 1
  fi
fi

popd

pushd pipeline-tasks/ci/k8s-upgrade

tofu init && tofu apply -auto-approve -var="version_prefix=${VERSION_PREFIX}"
LATEST_VERSION="$(tofu output -json | jq -r .latest_version.value)"

if [[ -z "${LATEST_VERSION}" || "${LATEST_VERSION}" == "null" ]]; then
  echo "Failed to get latest version (got: '${LATEST_VERSION}')"
  exit 1
fi

popd

pushd repo

if [[ -z "${CURRENT_VERSION}" || "${CURRENT_VERSION}" == "null" ]]; then
  echo "CURRENT_VERSION is null/empty — setting to LATEST_VERSION (${LATEST_VERSION}) unconditionally"
  hcledit -u -f modules/platform/gcp/variables.tf attribute set variable.kube_version.default \"$LATEST_VERSION\"
  make_commit "fix: set kubernetes version to '${LATEST_VERSION}' (was null)"
  exit 0
fi

echo "    --> CURRENT_VERSION: ${CURRENT_VERSION}"
echo "    --> LATEST_VERSION:  ${LATEST_VERSION}" 

if [[ "$(echo -e "$CURRENT_VERSION\n$LATEST_VERSION" | sort -V | head -n1)" != "$LATEST_VERSION" ]]; then
  echo "K8s upgrade from ${CURRENT_VERSION} to ${LATEST_VERSION} is available"
  hcledit -u -f modules/platform/gcp/variables.tf attribute set variable.kube_version.default \"$LATEST_VERSION\"
else
  echo "No upgrade available"

  exit 0
fi

make_commit "chore: bump kubernetes to '${LATEST_VERSION}'"
