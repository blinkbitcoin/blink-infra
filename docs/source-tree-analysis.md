# blink-infra Source Tree Analysis

## Directory Structure

```
blink-infra/
├── modules/                    # Core Terraform modules
│   ├── bootstrap/              # Phase 1: Initial setup
│   │   ├── gcp/               # GCP implementation
│   │   │   ├── variables.tf   # Input variables
│   │   │   ├── outputs.tf     # Module outputs
│   │   │   ├── services.tf    # API enablement
│   │   │   ├── inception-account.tf  # SA creation
│   │   │   ├── tf-state-bucket.tf    # State storage
│   │   │   └── external-users.tf     # External access
│   │   └── azure/             # Azure implementation
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       ├── resource-group.tf
│   │       ├── service-principal.tf
│   │       └── tf-state-storage.tf
│   │
│   ├── inception/              # Phase 2: Security resources
│   │   ├── gcp/
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   ├── network.tf          # VPC, subnets
│   │   │   ├── nat.tf              # Cloud NAT
│   │   │   ├── bastion.tf          # Bastion host
│   │   │   ├── bastion-startup.tmpl # Bastion init script
│   │   │   ├── bastion-access-role.tf
│   │   │   ├── bastion-service-account.tf
│   │   │   ├── inception-roles.tf  # IAM roles
│   │   │   ├── platform-roles.tf
│   │   │   ├── platform-users.tf
│   │   │   ├── node-account.tf     # GKE node SA
│   │   │   ├── grafana-account.tf
│   │   │   ├── logs-viewer.tf
│   │   │   ├── backups-bucket.tf
│   │   │   └── tf-state-bucket.tf
│   │   └── azure/
│   │       ├── variables.tf
│   │       ├── output.tf
│   │       ├── provider.tf
│   │       ├── data.tf
│   │       ├── network.tf
│   │       ├── bastion.tf
│   │       └── bastion-access-role.tf
│   │
│   ├── platform/               # Phase 3: Kubernetes cluster
│   │   ├── gcp/
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   ├── kube.tf             # GKE cluster + node pool
│   │   │   ├── network.tf          # Cluster subnet
│   │   │   ├── firewall.tf         # Network policies
│   │   │   └── lnd-ip.tf           # Optional static IPs
│   │   └── azure/
│   │       ├── variables.tf
│   │       ├── output.tf
│   │       ├── providers.tf
│   │       ├── data.tf
│   │       ├── network.tf
│   │       └── kube.tf
│   │
│   ├── postgresql/             # Phase 4: Database (GCP only)
│   │   └── gcp/
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       ├── main.tf             # Cloud SQL instance
│   │       ├── read-replica.tf     # Read replica
│   │       ├── database/           # Database creation
│   │       │   └── main.tf
│   │       └── migration/          # DMS support
│   │           └── main.tf
│   │
│   └── smoketest/              # CI testing (GCP only)
│       └── gcp/
│           ├── variables.tf
│           ├── output.tf
│           ├── main.tf
│           └── concourse-k8s-access.tf
│
├── examples/                   # Usage examples
│   └── gcp/
│       ├── README.md           # Deployment walkthrough
│       ├── Makefile            # Deployment targets
│       ├── bin/                # Helper scripts
│       │   ├── prep-inception.sh
│       │   ├── prep-platform.sh
│       │   ├── prep-postgresql.sh
│       │   └── prep-smoketest.sh
│       ├── bootstrap/
│       │   └── main.tf
│       ├── inception/
│       │   ├── main.tf
│       │   └── import.tf
│       ├── platform/
│       │   └── main.tf
│       ├── postgresql/
│       │   └── main.tf
│       └── smoketest/
│           └── main.tf
│
├── ci/                         # CI/CD pipeline
│   ├── pipeline.yml            # Main Concourse pipeline
│   ├── commons.lib.yml         # Shared YTT definitions
│   ├── gcp.lib.yml            # GCP-specific jobs
│   ├── values.yml             # Pipeline variables
│   ├── repipe                  # Pipeline update script
│   ├── image/                  # CI container images
│   │   ├── gcp/Dockerfile
│   │   └── azure/Dockerfile
│   ├── tasks/                  # CI task scripts
│   │   ├── helpers.sh
│   │   ├── check-and-upgrade-k8s.sh
│   │   └── gcp/
│   │       ├── bootstrap.sh
│   │       ├── inception.sh
│   │       ├── platform.sh
│   │       ├── postgresql.sh
│   │       ├── smoketest.sh
│   │       ├── teardown.sh
│   │       ├── teardown-postgresql.sh
│   │       └── bump-repos.sh
│   ├── k8s-upgrade/           # K8s version management
│   │   └── main.tf
│   └── build/
│       └── pipeline.yml
│
├── dev/                        # Development helper scripts
│   ├── README.md
│   ├── scrub_project.sh       # Clean GCP project resources
│   ├── scrub_tfstate.sh       # Clean TF state
│   ├── scrub_locks.sh         # Remove state locks
│   └── bump_version.sh        # Version bump utility
│
├── docs/                       # Documentation
│   ├── pg-migration-guide/    # PostgreSQL upgrade guide
│   │   ├── README.md
│   │   └── assets/
│   └── pg-settings/           # PostgreSQL config reference
│       └── README.md
│
├── .github/
│   └── workflows/
│       └── fmt.yml            # Terraform fmt check
│
├── flake.nix                  # Nix dev environment
├── flake.lock
├── .envrc                     # direnv config
├── Makefile                   # `make fmt`
├── README.md                  # Project overview
└── LICENSE                    # MIT
```

## Critical Files by Purpose

### Entry Points
| File | Purpose |
|------|---------|
| `examples/gcp/*/main.tf` | Example module invocations |
| `modules/*/gcp/variables.tf` | Module input definitions |

### Core Infrastructure
| File | Purpose |
|------|---------|
| `modules/inception/gcp/network.tf` | VPC and subnet creation |
| `modules/inception/gcp/bastion.tf` | Bastion host provisioning |
| `modules/platform/gcp/kube.tf` | GKE cluster definition |
| `modules/postgresql/gcp/main.tf` | Cloud SQL instance |

### Security Configuration
| File | Purpose |
|------|---------|
| `modules/bootstrap/gcp/inception-account.tf` | Inception service account |
| `modules/inception/gcp/inception-roles.tf` | IAM role definitions |
| `modules/inception/gcp/platform-roles.tf` | Platform phase permissions |
| `modules/inception/gcp/node-account.tf` | GKE node service account |

### CI/CD
| File | Purpose |
|------|---------|
| `ci/pipeline.yml` | Main Concourse pipeline |
| `ci/gcp.lib.yml` | GCP job definitions (ytt) |
| `ci/tasks/gcp/*.sh` | CI task implementations |

### Development
| File | Purpose |
|------|---------|
| `flake.nix` | Nix dev shell definition |
| `dev/scrub_project.sh` | Project cleanup utility |
