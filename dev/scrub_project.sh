#!/bin/bash
# scrub_project.sh - Script to clean up GCP resources
#
# This script removes all resources from a GCP project to return it to a clean state.
# It's particularly useful when Terraform state doesn't match actual resources.
#
# Usage: ./scrub_project.sh PROJECT_ID [--dry-run] [--no-ask]
#   --dry-run: Show what would be deleted without actually deleting
#   --no-ask: Skip confirmation prompts (use with caution!)

set -e

# Default values
DRY_RUN=false
NO_ASK=false
PROJECT_ID=""

# Text formatting
BOLD='\033[1m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-ask)
      NO_ASK=true
      shift
      ;;
    *)
      if [[ -z "$PROJECT_ID" ]]; then
        PROJECT_ID="$1"
      else
        echo -e "${RED}Error: Unknown parameter $1${NC}"
        echo "Usage: ./scrub_project.sh PROJECT_ID [--dry-run] [--no-ask]"
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate project ID
if [[ -z "$PROJECT_ID" ]]; then
  echo -e "${RED}Error: PROJECT_ID is required${NC}"
  echo "Usage: ./scrub_project.sh PROJECT_ID [--dry-run] [--no-ask]"
  exit 1
fi

# Check if project exists
if ! gcloud projects describe "$PROJECT_ID" &>/dev/null; then
  echo -e "${RED}Error: Project $PROJECT_ID does not exist or you don't have access to it${NC}"
  exit 1
fi

# Function to execute or echo command based on dry run flag
execute() {
  local suppress_output=false
  if [[ "$1" == "--suppress-output" ]]; then
    suppress_output=true
    shift
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}Would execute:${NC} $*"
    return 0
  else
    echo -e "${GREEN}Executing:${NC} $*"
    eval "$*"
    return $?
  fi
}

# Function to ask for confirmation
confirm() {
  if [[ "$NO_ASK" == true ]]; then
    return 0
  fi

  read -p "$1 (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    return 0
  fi
  return 1
}

# Function to check and delete resources
check_and_delete_resources() {
  local resource_type=$1
  local list_command=$2
  local delete_command=$3
  local resource_name_field=${4:-"name"}
  local resource_location_field=${5:-""}
  local resource_location_type=${6:-""}
  local skip_pattern=${7:-"^$"}  # Default to a pattern that won't match anything
  local is_peering=${8:-false}   # Special handling for peering connections
  
  echo -e "\n${BOLD}Checking for ${resource_type}...${NC}"
  local resources
  resources=$(eval "$list_command" 2>/dev/null || echo "")
  
  if [[ -n "$resources" ]]; then
    echo "Found ${resource_type}:"
    
    # Filter out resources to skip
    local filtered_resources=""
    while read -r line; do
      if [[ -n "$line" ]]; then
        local name=$(echo "$line" | awk "{print \$$resource_name_field}")
        if [[ ! "$name" =~ $skip_pattern ]]; then
          filtered_resources+="$line"$'\n'
          
          # Display resource info
          if [[ -n "$resource_location_field" ]]; then
            local location=$(echo "$line" | awk "{print \$$resource_location_field}")
            if [[ "$is_peering" == true && -n "$location" ]]; then
              # Extract just the network name for peering connections
              local network_name=$(echo "$location" | sed -E 's/.*\/([^\/]+)$/\1/')
              echo "- $name (${resource_location_type}: $network_name)"
            else
              echo "- $name (${resource_location_type}: $location)"
            fi
          else
            echo "- $name"
          fi
        fi
      fi
    done <<< "$resources"
    
    # Trim trailing newline
    filtered_resources=$(echo "$filtered_resources" | sed '/^$/d')
    
    if [[ -n "$filtered_resources" ]]; then
      if confirm "Delete these ${resource_type}?"; then
        while read -r line; do
          if [[ -n "$line" ]]; then
            local name=$(echo "$line" | awk "{print \$$resource_name_field}")
            local delete_cmd="$delete_command"
            
            if [[ -n "$resource_location_field" ]]; then
              local location=$(echo "$line" | awk "{print \$$resource_location_field}")
              
              if [[ "$is_peering" == true && -n "$location" ]]; then
                # Extract just the network name for peering connections
                local network_name=$(echo "$location" | sed -E 's/.*\/([^\/]+)$/\1/')
                delete_cmd="${delete_cmd//%LOCATION%/$network_name}"
              else
                delete_cmd="${delete_cmd//%LOCATION%/$location}"
              fi
            fi
            
            delete_cmd="${delete_cmd//%NAME%/$name}"
            execute "$delete_cmd"
          fi
        done <<< "$filtered_resources"
      fi
    else
      echo "No custom ${resource_type} found (excluding skipped patterns)."
    fi
  else
    echo "No ${resource_type} found."
  fi
}

# Function to handle VPC networks and their dependencies
delete_vpc_networks() {
  echo -e "\n${BOLD}Checking for VPC networks...${NC}"
  NETWORKS=$(gcloud compute networks list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null || echo "")
  
  if [[ -n "$NETWORKS" ]]; then
    # Check if there are any non-default networks
    local has_custom_networks=false
    local custom_networks=()
    
    for NETWORK in $NETWORKS; do
      if [[ "$NETWORK" != "default" ]]; then
        has_custom_networks=true
        custom_networks+=("$NETWORK")
      fi
    done
    
    if [[ "$has_custom_networks" == true ]]; then
      echo "Found VPC networks:"
      for NETWORK in "${custom_networks[@]}"; do
        echo "- $NETWORK"
        
        # List subnets for this network
        SUBNETS=$(gcloud compute networks subnets list --network="$NETWORK" --project="$PROJECT_ID" --format="value(name,region)" 2>/dev/null || echo "")
        if [[ -n "$SUBNETS" ]]; then
          echo "  Subnets:"
          echo "$SUBNETS" | while read -r NAME REGION; do
            echo "  - $NAME (region: $REGION)"
          done
        fi
      done
      
      if confirm "Delete these VPC networks and their subnets?"; then
        for NETWORK in "${custom_networks[@]}"; do
          # Delete subnets first
          SUBNETS=$(gcloud compute networks subnets list --network="$NETWORK" --project="$PROJECT_ID" --format="value(name,region)" 2>/dev/null || echo "")
          if [[ -n "$SUBNETS" ]]; then
            echo "$SUBNETS" | while read -r NAME REGION; do
              execute "gcloud compute networks subnets delete $NAME --region=$REGION --quiet --project=$PROJECT_ID"
            done
          fi
          
          # Then delete the network
          execute "gcloud compute networks delete $NETWORK --quiet --project=$PROJECT_ID"
        done
      fi
    else
      echo "No custom VPC networks found (excluding default network)."
    fi
  else
    echo "No VPC networks found."
  fi
}

# Print script mode
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${BOLD}Running in DRY RUN mode. No resources will be deleted.${NC}"
else
  echo -e "${BOLD}${RED}WARNING: This will DELETE resources in project: $PROJECT_ID${NC}"
  if ! confirm "Are you sure you want to continue?"; then
    echo "Operation cancelled."
    exit 0
  fi
fi

# Main script execution flow
echo -e "${BOLD}Starting cleanup of resources in project: $PROJECT_ID${NC}"

# 1. GKE Clusters
check_and_delete_resources \
  "GKE clusters" \
  "gcloud container clusters list --project=\"$PROJECT_ID\" --format=\"value(name,zone)\"" \
  "gcloud container clusters delete %NAME% --zone=%LOCATION% --quiet --project=$PROJECT_ID" \
  "1" "2" "zone"

# 2. Cloud SQL Instances
check_and_delete_resources \
  "Cloud SQL instances" \
  "gcloud sql instances list --project=\"$PROJECT_ID\" --format=\"value(name)\"" \
  "gcloud sql instances delete %NAME% --quiet --project=$PROJECT_ID"

# 3. Compute Instances
check_and_delete_resources \
  "Compute instances" \
  "gcloud compute instances list --project=\"$PROJECT_ID\" --format=\"value(name,zone)\"" \
  "gcloud compute instances delete %NAME% --zone=%LOCATION% --quiet --project=$PROJECT_ID" \
  "1" "2" "zone"

# 4. Firewall Rules
check_and_delete_resources \
  "Firewall rules" \
  "gcloud compute firewall-rules list --project=\"$PROJECT_ID\" --format=\"value(name)\"" \
  "gcloud compute firewall-rules delete %NAME% --quiet --project=$PROJECT_ID" \
  "1" "" "" "default-allow-"

# 5. Service Networking Connections (Peering)
echo -e "\n${BOLD}Checking for VPC Peering connections...${NC}"
PEERINGS=$(gcloud compute networks peerings list --project="$PROJECT_ID" --format="csv(name,network)" 2>/dev/null | tail -n +2 || echo "")

if [[ -n "$PEERINGS" ]]; then
  echo "Found VPC Peering connections:"
  
  while IFS=, read -r NAME NETWORK; do
    # Extract just the network name from the full path
    NETWORK_NAME=$(echo "$NETWORK" | sed -E 's/.*\/([^\/]+)$/\1/')
    echo "- $NAME (network: $NETWORK_NAME)"
  done <<< "$PEERINGS"
  
  if confirm "Delete these VPC Peering connections?"; then
    while IFS=, read -r NAME NETWORK; do
      # Extract just the network name from the full path
      NETWORK_NAME=$(echo "$NETWORK" | sed -E 's/.*\/([^\/]+)$/\1/')
      if [[ -n "$NETWORK_NAME" ]]; then
        execute "gcloud compute networks peerings delete $NAME --network=$NETWORK_NAME --quiet --project=$PROJECT_ID"
      else
        echo -e "${YELLOW}Skipping peering $NAME due to missing network name${NC}"
      fi
    done <<< "$PEERINGS"
  fi
else
  echo "No VPC Peering connections found."
fi

# Special handling for servicenetworking connections
echo -e "\n${BOLD}Checking for Service Networking connections...${NC}"
NETWORKS=$(gcloud compute networks list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null || echo "")
for NETWORK in $NETWORKS; do
  if [[ "$NETWORK" != "default" ]]; then
    if confirm "Check for servicenetworking connections in network $NETWORK?"; then
      execute "gcloud compute networks peerings delete servicenetworking-googleapis-com --network=$NETWORK --quiet --project=$PROJECT_ID" || true
    fi
  fi
done

# 6. Global Addresses (used for peering)
check_and_delete_resources \
  "Global Addresses used for peering" \
  "gcloud compute addresses list --project=\"$PROJECT_ID\" --global --filter=\"purpose=VPC_PEERING\" --format=\"value(name)\"" \
  "gcloud compute addresses delete %NAME% --global --quiet --project=$PROJECT_ID"

# 7. Cloud Routers
check_and_delete_resources \
  "Cloud Routers" \
  "gcloud compute routers list --project=\"$PROJECT_ID\" --format=\"value(name,region)\"" \
  "gcloud compute routers delete %NAME% --region=%LOCATION% --quiet --project=$PROJECT_ID" \
  "1" "2" "region"

# 8. VPC Networks and Subnets
delete_vpc_networks

# 9. Cloud Storage Buckets
check_and_delete_resources \
  "Storage buckets" \
  "gsutil ls -p \"$PROJECT_ID\"" \
  "gsutil -m rm -r %NAME%"

# 10. Service Accounts
check_and_delete_resources \
  "Service accounts" \
  "gcloud iam service-accounts list --project=\"$PROJECT_ID\" --format=\"value(email)\"" \
  "gcloud iam service-accounts delete %NAME% --quiet --project=$PROJECT_ID" \
  "1" "" "" "compute@developer.gserviceaccount.com\\|cloudbuild@"

# 11. Pub/Sub Topics
check_and_delete_resources \
  "Pub/Sub topics" \
  "gcloud pubsub topics list --project=\"$PROJECT_ID\" --format=\"value(name)\"" \
  "gcloud pubsub topics delete %NAME% --project=$PROJECT_ID"

# 12. Load Balancers and Forwarding Rules
check_and_delete_resources \
  "Forwarding Rules" \
  "gcloud compute forwarding-rules list --project=\"$PROJECT_ID\" --format=\"value(name,region)\"" \
  "gcloud compute forwarding-rules delete %NAME% --region=%LOCATION% --quiet --project=$PROJECT_ID" \
  "1" "2" "region"

# 13. Custom IAM Roles
echo -e "\n${BOLD}Checking for Custom IAM Roles...${NC}"
CUSTOM_ROLES=$(gcloud iam roles list --project="$PROJECT_ID" --format="value(name)" 2>/dev/null || echo "")
if [[ -n "$CUSTOM_ROLES" ]]; then
  echo "Found Active Custom IAM Roles:"
  ACTIVE_ROLES=()
  PREFIX_FILTER="testflight"
  
  while read -r ROLE_PATH; do
    ROLE_NAME=${ROLE_PATH#"projects/$PROJECT_ID/roles/"}
    
    # Only include roles that start with our prefix
    if [[ "$ROLE_NAME" == "$PREFIX_FILTER"* ]]; then
      # Skip the testflightBootstrap role
      if [[ "$ROLE_NAME" == "testflightBootstrap" ]]; then
        echo -e "${YELLOW}Skipping protected role: $ROLE_NAME${NC}"
        continue
      fi
      
      echo -e "- ${ROLE_NAME}"
      ACTIVE_ROLES+=("$ROLE_NAME")
    fi
  done <<< "$CUSTOM_ROLES"

  if [[ ${#ACTIVE_ROLES[@]} -gt 0 ]]; then
    if confirm "Delete these ${#ACTIVE_ROLES[@]} active Custom IAM Roles starting with '$PREFIX_FILTER'?"; then
      for ROLE_NAME in "${ACTIVE_ROLES[@]}"; do
        # Delete the role (--force flag is not supported)
        execute --suppress-output "gcloud iam roles delete \"$ROLE_NAME\" --project=\"$PROJECT_ID\""
        echo -e "${GREEN}Deleted role:${NC} $ROLE_NAME"
      done
    fi
  else
    echo "No active Custom IAM Roles starting with '$PREFIX_FILTER' found (excluding protected roles)."
  fi
else
  echo "No Custom IAM Roles found."
fi

# 14. Skip handling of Soft-Deleted IAM Roles
echo -e "\n${BOLD}Note:${NC} Soft-deleted roles will be automatically purged after 7 days."
echo "This script will not attempt to recover or modify soft-deleted roles."

# 15. Check for any roles that couldn't be fully purged
if [[ "$DRY_RUN" == false ]]; then
  echo -e "\n${BOLD}Checking for any roles that couldn't be fully purged...${NC}"
  REMAINING_ROLES=$(gcloud iam roles list --project="$PROJECT_ID" --show-deleted --format="json" | \
    jq -r '.[] | "\(.name) \(.deleted)"' 2>/dev/null || echo "")

  if [[ -n "$REMAINING_ROLES" ]]; then
    echo "Found roles that may still exist (either active or soft-deleted):"
    echo "$REMAINING_ROLES" | while read -r ROLE_PATH DELETED; do
      ROLE_NAME=${ROLE_PATH#"projects/$PROJECT_ID/roles/"}
      
      if [[ "$DELETED" == "true" ]]; then
        echo -e "  - ${YELLOW}${ROLE_NAME}${NC} (soft-deleted, will be purged after 7 days)"
      else
        echo -e "  - ${GREEN}${ROLE_NAME}${NC} (active)"
      fi
    done

    echo -e "\n${YELLOW}Note: Soft-deleted roles will be automatically purged after 7 days.${NC}"
    echo "If you need to use the same role name immediately, you'll need to wait for the purge or use a different name."
  else
    echo "No remaining roles found."
  fi
fi

echo -e "\n${BOLD}Project cleanup process completed.${NC}"
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}This was a dry run. No resources were actually deleted.${NC}"
  echo "To actually delete resources, run without the --dry-run flag."
fi
