# blink-infra Architecture

## Deployment Model

Sequential multi-phase infrastructure deployment where each module builds on the previous:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  bootstrap  │ ──▶ │  inception  │ ──▶ │  platform   │ ──▶ │ postgresql  │
│  (1x only)  │     │  (security) │     │   (GKE)     │     │  (optional) │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

## Module Details

### 1. Bootstrap (`modules/bootstrap/gcp/`)

**Purpose:** One-time initial setup on a blank GCP project with owner access.

**Resources Created:**
- Enable required GCP APIs
- `inception` service account for subsequent phases
- GCS bucket for Terraform state storage

**Key Variables:**
- `name_prefix` - Resource naming prefix
- `gcp_project` - Target GCP project
- `tf_state_bucket_location` - State bucket region (default: US-EAST1)

**Files:**
- `services.tf` - API enablement
- `inception-account.tf` - Service account creation
- `tf-state-bucket.tf` - State storage
- `external-users.tf` - Optional external user access

---

### 2. Inception (`modules/inception/gcp/`)

**Purpose:** Security-sensitive foundational resources.

**Resources Created:**
- VPC network with DMZ subnet
- Cloud NAT for outbound connectivity
- Bastion host (Ubuntu 24.04, e2-micro) with:
  - OsLogin + 2FA enabled
  - Pre-installed tools: kubectl, k9s, opentofu, helm, bria, lnd, bitcoin-cli
- IAM roles and service accounts for platform phase
- GCS backup bucket
- VPC peering for private services

**Key Variables:**
- `users` - List of users with role assignments (bastion, inception, platform, logs)
- `region` - Deployment region (default: us-east1)
- `bastion_machine_type` - Bastion VM size (default: e2-micro)
- `network_prefix` - VPC CIDR prefix (default: 10.0)

**Network Layout:**
```
VPC: {name_prefix}-vpc
├── DMZ Subnet: {network_prefix}.0.0/24
│   └── Bastion host (OsLogin + 2FA)
└── Peering: /16 for private services (Cloud SQL)
```

---

### 3. Platform (`modules/platform/gcp/`)

**Purpose:** Kubernetes cluster provisioning.

**Resources Created:**
- Private GKE cluster with:
  - VPC-native networking
  - Calico network policies
  - Workload Identity
  - Binary Authorization
  - Shielded nodes
- Cluster subnet with pod/service secondary ranges
- Default node pool (autoscaling)
- Optional LND static IPs

**Key Variables:**
- `kube_version` - GKE version (default: 1.32.9-gke.1010000)
- `node_default_machine_type` - Node VM type (default: n2-standard-4)
- `min/max_default_node_count` - Autoscaling bounds (1-3)
- `destroyable_cluster` - Deletion protection toggle

**Cluster Configuration:**
- Master CIDR: 172.16.0.0/28
- Private endpoint only (no public access)
- Master authorized from DMZ subnet
- Release channel: UNSPECIFIED (manual upgrades)
- Maintenance window: 05:00 UTC daily

---

### 4. PostgreSQL (`modules/postgresql/gcp/`)

**Purpose:** Cloud SQL PostgreSQL with migration support.

**Resources Created:**
- Cloud SQL PostgreSQL instance
- Optional read replica
- BigQuery connection (for analytics)
- Database Migration Service support (PG14→PG15)

**Key Variables:**
- `database_version` - PostgreSQL version (default: POSTGRES_14)
- `tier` - Instance size (default: db-custom-1-3840)
- `highly_available` - HA failover (default: true)
- `replication` - Logical replication toggle
- `prep_upgrade_as_source_db` - DMS migration source config

**Performance Tuning:**
- `work_mem`, `checkpoint_timeout`, `random_page_cost`
- `auto_explain_*` for query logging
- See [pg-settings/README.md](./pg-settings/README.md) for details

---

### 5. Smoketest (`modules/smoketest/gcp/`)

**Purpose:** CI/CD testing infrastructure validation.

---

## Network Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│                    GCP Project                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │              VPC: {prefix}-vpc                   │   │
│  │                                                  │   │
│  │  ┌──────────────┐      ┌──────────────────────┐ │   │
│  │  │  DMZ Subnet  │      │   Cluster Subnet     │ │   │
│  │  │  10.0.0.0/24 │      │   10.1.0.0/16        │ │   │
│  │  │              │      │                      │ │   │
│  │  │  [Bastion]◄──┼──IAP─┼── Operators          │ │   │
│  │  │      │       │      │                      │ │   │
│  │  │      ▼       │      │  ┌────────────────┐  │ │   │
│  │  │   Cloud NAT  │      │  │  GKE Cluster   │  │ │   │
│  │  │      │       │      │  │  (private)     │  │ │   │
│  │  └──────┼───────┘      │  │                │  │ │   │
│  │         │              │  │  Pods: /14     │  │ │   │
│  │         ▼              │  │  Svcs: /20     │  │ │   │
│  │    [Internet]          │  └────────────────┘  │ │   │
│  │                        └──────────────────────┘ │   │
│  │                                                  │   │
│  │  ┌─────────────────────────────────────────┐    │   │
│  │  │  Private Services (VPC Peering)         │    │   │
│  │  │  - Cloud SQL PostgreSQL                 │    │   │
│  │  └─────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Access Model

1. **Operators** → IAP tunnel → Bastion (OsLogin + 2FA)
2. **Bastion** → kubectl → GKE private endpoint
3. **GKE Pods** → Workload Identity → GCP APIs
4. **GKE Pods** → VPC peering → Cloud SQL

## CI/CD Pipeline

**Tool:** Concourse CI with ytt templating

**Pipeline Flow:**
```
gcp-modules change
    │
    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  bootstrap  │ ──▶ │  inception  │ ──▶ │  platform   │
│   testflight│     │   testflight│     │   testflight│
└─────────────┘     └─────────────┘     └─────────────┘
                                              │
                    ┌─────────────┐           │
                    │  smoketest  │ ◀─────────┘
                    │   testflight│
                    └─────────────┘
                          │
                          ▼
                    ┌─────────────┐
                    │  cleanup    │
                    │  (teardown) │
                    └─────────────┘
                          │
                          ▼
                    ┌─────────────┐
                    │ bump-repos  │
                    │ (update ex.)│
                    └─────────────┘
```

**Additional Jobs:**
- `check-and-upgrade-k8s` - Daily K8s version check (STABLE channel)
- `build-pipeline-image` - CI container image build

## State Management

- **Backend:** GCS bucket (`{prefix}-tf-state`)
- **Per-module state:** Separate state files per phase
- **Locking:** GCS native locking
