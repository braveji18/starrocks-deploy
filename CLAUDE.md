# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**StarRocks Kubernetes Deployment** - GitOps-based infrastructure-as-code for deploying and managing StarRocks (a columnar database) on Kubernetes using Helm, Kustomize, and ArgoCD.

This repository provides:
- Automated deployment configuration using Kustomize + Helm
- Environment-specific overlays (dev, staging, production)
- ArgoCD integration for GitOps-based deployments
- Support for internal Nexus-based Helm repository management

## Architecture

```
starrocks-deploy/
├── chart/                      # Reference to Helm charts (managed via Nexus)
├── kustomize/                  # Environment-specific settings (ConfigMap, etc)
│   └── overlays/               # Environment configurations
│       ├── dev/                # Development settings
│       ├── staging/            # Staging settings
│       └── prod/               # Production settings
├── argocd/                     # ArgoCD ApplicationSet manifests
│   └── applications.yaml       # ApplicationSet (generates dev/staging/prod Applications)
├── bin/                        # Deployment and utility scripts
├── docs/                       # Documentation
└── Configuration files         # Setup guides and checklists
```

## Key Workflows

### Deployment

**Quick start:**
```bash
./bin/deploy.sh dev       # Deploy to development
./bin/deploy.sh staging   # Deploy to staging
./bin/deploy.sh prod      # Deploy to production
```

**Manual deployment:**
```bash
# Via kubectl
kubectl apply -f argocd/applications.yaml

# Via ArgoCD CLI
argocd app sync kube-starrocks-operator-dev
```

### Status Monitoring

```bash
./bin/check-status.sh     # Check all environments
kubectl get applications -n argocd | grep kube-starrocks
kubectl get pods -n starrocks-[env]
```

### Rollback

```bash
./bin/rollback.sh [env] [revision]
# or manually via ArgoCD
argocd app rollback kube-starrocks-operator-[env] <revision>
```

## Configuration Management

### Environment Variables
- **Nexus URL**: Helm chart repository location
- **Git Repository**: Source of truth for infrastructure configuration
- **Kubernetes Namespace**: `starrocks-dev`, `starrocks-staging`, `starrocks-prod`

### Key Configuration Files

**Helm Repository Setting** - `kustomize/base/helm-release.yaml`:
```yaml
source:
  repoURL: https://your-nexus.com/repository/helm-hosted/  # Update this
```

**Git Repository** - `argocd/overlays/*/application.yaml`:
```yaml
source:
  repoURL: https://your-git-repo.com/starrocks-deploy.git  # Update this
```

### Environment-Specific Values

- **Dev**: 1 replica, minimal resources, DEBUG logging, auto-sync enabled
- **Staging**: 2 replicas, moderate resources, INFO logging, pod anti-affinity preferred
- **Prod**: 3 replicas, high resources, WARN logging, pod anti-affinity required, manual sync

Modify `kustomize/overlays/[env]/values.yaml` for environment customization.

## Documentation

- **Quick Start** → [QUICKSTART.md](QUICKSTART.md) - Get running in 5 minutes
- **Setup Guide** → [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) - Detailed setup instructions
- **Environment Config** → [docs/ENVIRONMENT_CONFIG.md](docs/ENVIRONMENT_CONFIG.md) - Environment-specific settings
- **Troubleshooting** → [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues and solutions
- **Deployment Checklist** → [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - Pre/post deployment checks

## Helm Chart Management

StarRocks Operator charts are managed via internal Nexus repository:

1. Extract charts from [GitHub](https://github.com/StarRocks/starrocks-kubernetes-operator/tree/main/helm-charts)
2. Upload to Nexus helm-hosted repository
3. Configure chart version in `kustomize/base/helm-release.yaml`

## External References

- **StarRocks Operator**: https://github.com/StarRocks/starrocks-kubernetes-operator
- **ArgoCD Docs**: https://argo-cd.readthedocs.io/
- **Kustomize Docs**: https://kustomize.io/
- **Helm Docs**: https://helm.sh/docs/

## Development Considerations

- All infrastructure is defined as code (IaC)
- Changes require Git commits and should be reviewed before production deployment
- Each environment has isolated namespace: `starrocks-[env]`
- Production uses manual sync policy for safety
- Monitoring, backup, and disaster recovery must be configured separately
- Pod Disruption Budgets (PDB) enabled in production for high availability
