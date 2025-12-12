# blink-infra Project Overview

## Purpose

Terraform/OpenTofu definitions for production-ready infrastructure to run the [Blink](https://github.com/blinkbitcoin/blink) Bitcoin Lightning stack. Provisions a private GKE cluster with bastion access, VPC networking, IAM roles, and optional PostgreSQL on GCP.

## Technology Stack

| Category | Technology | Version/Notes |
|----------|------------|---------------|
| IaC Tool | OpenTofu | 1.8.2 (Terraform fork) |
| Cloud (Primary) | GCP | GKE, Cloud SQL, VPC, IAM, NAT |
| Cloud (Partial) | Azure | AKS, VNet (bootstrap/inception/platform only) |
| Kubernetes | GKE | 1.32.9-gke.1010000, private cluster |
| Network Policy | Calico | Enabled via GKE |
| Dev Environment | Nix Flakes | direnv integration |
| CI/CD | Concourse CI | ytt templating |
| PR Checks | GitHub Actions | terraform fmt |

## Architecture Type

**Multi-phase sequential deployment** with 5 modules executed in order:

```
bootstrap → inception → platform → [postgresql] → [smoketest]
```

## Repository Structure

- **Type:** Monolith
- **Primary Language:** HCL (Terraform)
- **Module Pattern:** `modules/{module}/{cloud}/` (gcp, azure)

## Module Summary

| Module | Purpose | GCP | Azure |
|--------|---------|-----|-------|
| `bootstrap` | Initial APIs, inception SA, TF state bucket | Yes | Yes |
| `inception` | VPC, bastion, roles, service accounts | Yes | Yes |
| `platform` | GKE/AKS cluster provisioning | Yes | Yes |
| `postgresql` | Cloud SQL PostgreSQL with migration support | Yes | No |
| `smoketest` | CI testing infrastructure | Yes | No |

## Key Security Features

- Private GKE cluster (no public endpoint)
- Bastion host with OsLogin + 2FA
- Workload Identity for pod-to-GCP auth
- Binary Authorization enabled
- Shielded GKE nodes
- VPC-native networking

## Quick Links

- [Architecture Details](./architecture.md)
- [Source Tree Analysis](./source-tree-analysis.md)
- [Development Guide](./development-guide.md)
- [GCP Deployment Walkthrough](../examples/gcp/README.md)
- [PostgreSQL Migration Guide](./pg-migration-guide/README.md)
- [PostgreSQL Settings Reference](./pg-settings/README.md)
