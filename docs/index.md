# blink-infra Documentation Index

## Project Overview

- **Type:** Monolith (Infrastructure as Code)
- **Primary Technology:** OpenTofu/Terraform
- **Cloud Providers:** GCP (primary), Azure (partial)
- **Architecture:** Multi-phase sequential deployment

## Quick Reference

| Attribute | Value |
|-----------|-------|
| IaC Tool | OpenTofu 1.8.2 |
| Kubernetes | GKE 1.32.9-gke.1010000 |
| Deployment Phases | bootstrap → inception → platform → postgresql |
| CI/CD | Concourse CI (ytt templating) |
| Dev Environment | Nix Flakes |

## Generated Documentation

- [Project Overview](./project-overview.md) - Purpose, tech stack, module summary
- [Architecture](./architecture.md) - Module details, network design, CI/CD flow
- [Source Tree Analysis](./source-tree-analysis.md) - Directory structure, critical files
- [Development Guide](./development-guide.md) - Setup, commands, CI/CD, recovery

## Existing Documentation

- [GCP Deployment Walkthrough](../examples/gcp/README.md) - Step-by-step deployment guide
- [PostgreSQL Migration Guide](./pg-migration-guide/README.md) - PG14→PG15 upgrade via DMS
- [PostgreSQL Settings Reference](./pg-settings/README.md) - Cloud SQL config parameters
- [Dev Scripts README](../dev/README.md) - Recovery and cleanup procedures

## Getting Started

### For New Deployments

1. Review [Architecture](./architecture.md) to understand the module sequence
2. Follow [GCP Deployment Walkthrough](../examples/gcp/README.md) for step-by-step setup
3. Consult [Development Guide](./development-guide.md) for environment setup

### For Existing Deployments

- **K8s upgrades:** Handled automatically by CI (`check-and-upgrade-k8s` job)
- **PostgreSQL upgrades:** See [Migration Guide](./pg-migration-guide/README.md)
- **Config tuning:** See [PostgreSQL Settings](./pg-settings/README.md)

### For Development

1. Set up Nix environment: `nix develop`
2. Run `make fmt` before commits
3. CI tests all changes in `infra-testflight` project

---

*Generated: 2025-12-10 | Scan Level: deep | Mode: initial_scan*
