# blink-infra Development Guide

## Prerequisites

- Nix with flakes enabled (recommended) OR manually installed:
  - OpenTofu 1.8.2+
  - ytt (Carvel)
  - jq
  - gcloud CLI (for GCP)
  - az CLI with ssh extension (for Azure)
- GCP project with owner access
- direnv (optional, for automatic env loading)

## Development Environment Setup

### Using Nix (Recommended)

```bash
# Enter dev shell (auto-loads via direnv if .envrc present)
nix develop

# Or manually
nix develop .#default
```

This provides: `opentofu`, `ytt`, `jq`, `azure-cli` (with ssh), `alejandra` (Nix formatter)

### Manual Setup

Install tools matching versions in `ci/image/gcp/Dockerfile`:
- OpenTofu 1.8.2
- kubectl v1.24.12
- yq v4.21.1
- gcloud CLI
- helm 3.x

## Common Commands

### Formatting

```bash
# Format all Terraform files
make fmt
# or
tofu fmt -recursive
```

### GCP Deployment (from examples/gcp/)

```bash
cd examples/gcp

# 1. Bootstrap (one-time)
cat <<EOF > bootstrap/terraform.tfvars
name_prefix = "myprefix"
gcp_project = "my-gcp-project"
EOF
make bootstrap

# 2. Configure users
cat <<EOF > inception/users.auto.tfvars
users = [
  {
    id        = "user:you@example.com"
    bastion   = true
    inception = true
    platform  = true
    logs      = true
  }
]
EOF

# 3. Inception
make inception

# 4. Platform
bin/prep-platform.sh
make platform

# 5. PostgreSQL (optional)
bin/prep-postgresql.sh
make postgresql
```

### Bastion Access

```bash
# Upload SSH key (one-time)
gcloud compute os-login ssh-keys add --key-file=~/.ssh/id_rsa.pub

# SSH to bastion
gcloud compute ssh <bastion-name> --zone=<zone> --project=<project>
# Requires 2FA
```

## CI/CD Development

### Pipeline Structure

Pipelines use [ytt](https://carvel.dev/ytt/) templating:

```
ci/
├── pipeline.yml      # Main pipeline (imports libs)
├── commons.lib.yml   # Shared definitions
├── gcp.lib.yml       # GCP-specific jobs
└── values.yml        # Variable definitions
```

### Regenerating Pipeline

```bash
cd ci
./repipe
```

### CI Image

Build the CI container:

```bash
cd ci/image/gcp
docker build -t gcp-infra-pipeline .
```

## Recovery Procedures

When CI breaks mid-run or you need to start fresh:

```bash
# 1. Clean GCP project resources
./dev/scrub_project.sh <project-name>

# 2. Clean Terraform state
./dev/scrub_tfstate.sh

# 3. Bump version (for clean CI run)
./dev/bump_version.sh

# 4. Remove stale locks
./dev/scrub_locks.sh
```

## Testing Changes

CI automatically tests on push via Concourse:
1. Creates resources in `infra-testflight` project
2. Runs through bootstrap → inception → platform → smoketest
3. Tears down and bumps example refs on success

## Kubernetes Version Management

K8s versions are auto-checked daily via `check-and-upgrade-k8s` job:

- Queries GKE STABLE channel for latest 1.32.x
- Updates `modules/platform/gcp/variables.tf` if newer
- Creates commit with updated version

Manual override: Edit `kube_version` in platform variables.

## PR Guidelines

1. Run `make fmt` before committing
2. GitHub Actions will verify formatting
3. Concourse runs full testflight on module changes
4. Examples are auto-updated on successful CI
