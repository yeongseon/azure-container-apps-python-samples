# Azure Container Apps Python Sample

This repository contains a minimal FastAPI application and helper scripts to build and push the image to Azure Container Registry (ACR) and deploy it to Azure Container Apps (ACA) using a safe two‑phase pattern (placeholder image first, then switch to the real image after Managed Identity and AcrPull role assignment propagate).

## Structure

```
infra/
	scripts/
		00_prepare.sh             # Install extension / register provider
		01_create_infra.sh        # Create RG, ACR, ACA environment (env vars)
		10_acr_build_push.sh      # Build & push image (local + remote fallback)
		20_deploy_containerapp.sh # Deploy container app (MI + AcrPull + update)
samples/
	quickstart-fastapi/
		app/main.py               # FastAPI sample endpoints
		Dockerfile
		requirements.txt
```

## Prerequisites
- Azure subscription and `az login`
- Azure CLI (latest) + `containerapp` extension (handled by `00_prepare.sh`)
- Bash shell (Linux / WSL / macOS recommended)

## Quick Start

### 1. Prepare (Provider & Extension)
```bash
./infra/scripts/00_prepare.sh
```

### 2. Provision Infrastructure (Resource Group, ACR, ACA Environment)
```bash
export RG=my-rg
export ACR=acraps20141   # must be globally unique
export ENV=my-env2        # ACA environment name
export LOCATION=koreacentral

./infra/scripts/01_create_infra.sh
```

### 3. Build & Push Image
Use `auto` tag to automatically substitute the current git short SHA:
```bash
./infra/scripts/10_acr_build_push.sh "$ACR" quickstart-fastapi auto
# Example output: acraps20141.azurecr.io/quickstart-fastapi:<gitsha>
```
Record the full image reference for the next step.

### 4. Deploy Container App
```
./infra/scripts/20_deploy_containerapp.sh <RG> <ENV_NAME> <APP_NAME> <ACR_NAME> <IMAGE> <LOCATION>
```
Example:
```bash
IMAGE="acraps20141.azurecr.io/quickstart-fastapi:abcdef1"  # replace with real sha
./infra/scripts/20_deploy_containerapp.sh "$RG" "$ENV" my-app "$ACR" "$IMAGE" "$LOCATION"
```
Script flow:
1. Create app with a public placeholder image (`nginx:latest`) – attempts to attach system identity immediately
2. Retry assigning system-assigned Managed Identity if not present
3. Poll for `principalId`
4. Assign `AcrPull` role and wait for propagation
5. Update revision to the real ACR image (forces re-pull using MI)
6. Print final summary (FQDN, image, identity)

### 5. Verify
```bash
curl https://my-app.<random>.<region>.azurecontainerapps.io/health
```

## Script Details

### 00_prepare.sh
Installs/updates the `containerapp` extension and registers `Microsoft.App` provider (blocking until ready).

### 01_create_infra.sh
Requires `RG`, `ACR`, `ENV` (and optional `LOCATION`, default `koreacentral`). Idempotent if resources already exist.

### 10_acr_build_push.sh
Prefers local Docker build. If build or push fails (or Docker is unavailable), falls back to `az acr build`. Tag `auto` uses git short SHA (falls back to `latest` if git not available).

### 20_deploy_containerapp.sh
Implements a safe two-phase pattern to avoid timing issues with ACR permissions while Managed Identity and role assignment propagate. Includes retries, polling debug output, and final state summary.

## Troubleshooting
| Symptom | Cause | Resolution |
|---------|-------|-----------|
| principalId timeout | Identity propagation delay | Increase `WAIT_PRINCIPAL_TIMEOUT` or rerun after 1–2 minutes |
| Image pull error | `AcrPull` not yet visible | Rerun deploy script (it will only update image) |
| ACR auth error | Role/permissions not ready after creation | Wait ~30s then rebuild/push |
| Environment ScheduledForDelete | Previous delete in progress | Use a new environment name or wait for deletion to finish |

Adjust timeouts via environment variables:
```bash
export WAIT_PRINCIPAL_TIMEOUT=300   # default 240
export WAIT_ROLE_TIMEOUT=400        # default 300
```

## GitHub Actions (Optional)
The initial workflow is present but does not yet include the full placeholder + two‑phase logic. To integrate, run:
1. `10_acr_build_push.sh`
2. `20_deploy_containerapp.sh` with the produced image reference

## Summary
This sample demonstrates a reliable pattern for deploying ACR images to Azure Container Apps with Managed Identity and role propagation handling. You can extend it with Bicep/Terraform IaC, Key Vault integration, scaling rules (KEDA), or secrets management as needed.

---
Feel free to request additions (e.g., GitHub Actions enhancements, IaC templates).
