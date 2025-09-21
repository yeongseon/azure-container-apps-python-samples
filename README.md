# Azure Container Apps Multi‑Language Samples (Python & Java)

This repository provides a hardened deployment pattern to Azure Container Apps (ACA) using Azure Container Registry (ACR), a system‑assigned Managed Identity, and a two‑phase rollout (public placeholder image first, then switch to the private ACR image after AcrPull role propagation). It currently includes:

* Python FastAPI sample (active)
* Java Spring Boot sample (initial scaffold)

The infra scripting is shared; language samples live under language‑specific folders for future expansion (.NET, Node, etc.) without duplicating deployment logic.

## Repository Structure

```
infra/
	shared/                     # Canonical scripts (called by wrappers)
		00_prepare.sh             # Install extension / register provider
		01_create_infra.sh        # Create RG, ACR, ACA environment
		10_acr_build_push.sh      # Build & push image (local first, remote fallback)
		20_deploy_containerapp.sh # Two‑phase deploy w/ Managed Identity + AcrPull
	scripts/                    # Thin wrappers (backward compatibility)

python/
	README.md
	samples/
		quickstart-fastapi/
			app/main.py
			requirements.txt
			Dockerfile              # ARG PYTHON_VERSION=3.10

java/
	samples/
		quickstart-springboot/
			src/main/java/.../DemoApplication.java
			pom.xml                 # Java 11 target
			Dockerfile              # ARG JDK_VERSION=11 (multi-stage)

.github/workflows/ (optional CI stub)
```

Legacy `samples/quickstart-fastapi` path has been relocated under `python/`; wrapper scripts keep previous command paths working.

## Runtime Matrix

| Language | Version | Status  | Notes |
|----------|---------|---------|-------|
| Python   | 3.10    | Active  | `ARG PYTHON_VERSION` in Dockerfile (default 3.10) |
| Java     | 11      | Active (sample) | `ARG JDK_VERSION` in Dockerfile; minimal API |

Additional languages can reuse the same infra scripts—only the build context and image name differ.

## Prerequisites
* Azure subscription + `az login`
* Azure CLI (latest) – extension install handled automatically
* Bash shell (Linux/WSL/macOS)
* Docker (optional; remote build fallback exists)

### Dynamic Naming (Optional)
You can auto-generate unique names with the current date:
```bash
source ./infra/shared/name_helpers.sh
generate_names myproj      # sets RG / ENV / ACR env vars
echo $RG $ENV $ACR         # inspect
```
Then proceed with provisioning using those exported variables.

## Quick Start Overview

Choose one of the flows below.

### A. One‑Shot (Recommended for first trial)
FastAPI:
```bash
./infra/shared/quickstart_deploy.sh --sample fastapi --prefix myproj --location koreacentral
```
Spring Boot:
```bash
./infra/shared/quickstart_deploy.sh --sample springboot --prefix myproj --location koreacentral
```
The script will: install extension, generate names, provision RG/ACR/ACA env, build & push image, then perform two‑phase deploy.

### B. Manual (Explained) – Works for Any Sample
1) Prepare extension/provider (idempotent):
```bash
./infra/scripts/00_prepare.sh
```
2) Generate (or define) names:
```bash
source ./infra/shared/name_helpers.sh
generate_names myproj
export LOCATION=koreacentral
echo $RG $ENV $ACR
```
3) Provision infra:
```bash
./infra/scripts/01_create_infra.sh
```
4) Build & push image (examples):
```bash
# FastAPI
./infra/scripts/10_acr_build_push.sh "$ACR" quickstart-fastapi auto
# OR via helper
./infra/shared/build_image.sh --acr "$ACR" --sample fastapi --tag auto

# Spring Boot
./infra/scripts/10_acr_build_push.sh "$ACR" quickstart-springboot auto
```
5) Deploy (two‑phase placeholder → private image):
```bash
IMAGE="$ACR.azurecr.io/quickstart-fastapi:<sha>"      # or quickstart-springboot
./infra/scripts/20_deploy_containerapp.sh "$RG" "$ENV" fastapi-app "$ACR" "$IMAGE" "$LOCATION"
# For Spring Boot change app name & image:
IMAGE="$ACR.azurecr.io/quickstart-springboot:<sha>"
./infra/scripts/20_deploy_containerapp.sh "$RG" "$ENV" springboot-app "$ACR" "$IMAGE" "$LOCATION"
```
6) Verify:
```bash
curl https://fastapi-app.<random>.${LOCATION}.azurecontainerapps.io/health
curl https://springboot-app.<random>.${LOCATION}.azurecontainerapps.io/
```

### Local Run (Optional)
FastAPI:
```bash
pip install -r python/samples/quickstart-fastapi/requirements.txt
uvicorn app.main:app --app-dir python/samples/quickstart-fastapi/app --host 0.0.0.0 --port 8080
```
Spring Boot:
```bash
(cd java/samples/quickstart-springboot && mvn spring-boot:run)
```

### Cleanup
Remove created resources when finished (irreversible):
```bash
az group delete -n "$RG" --yes --no-wait
```

## Deployment Script Flow
1. Create app with public placeholder image (`nginx:latest`)
2. Ensure system-assigned identity exists (retry/assign if needed)
3. Poll for `principalId`
4. Assign `AcrPull` role & wait for role visibility
5. Patch to real ACR image (forces pull using identity)
6. Output final status (FQDN, image, identity JSON)

## Script Highlights
* Local Docker build preferred (faster feedback) with remote ACR build fallback
* Git SHA auto-tagging for traceability
* Resilient polling for identity & role assignment propagation
* Idempotent resource provisioning (safe re-runs)

## Extending
Add a new language sample under `<language>/samples/<sample-name>` with its Dockerfile. Then call:
```bash
./infra/scripts/10_acr_build_push.sh "$ACR" <image-name> auto
./infra/scripts/20_deploy_containerapp.sh "$RG" "$ENV" <app-name> "$ACR" "$ACR.azurecr.io/<image-name>:<sha>" "$LOCATION"
```
No infra script changes required.

## Troubleshooting
| Symptom | Cause | Resolution |
|---------|-------|-----------|
| principalId timeout | Identity propagation delay | Increase `WAIT_PRINCIPAL_TIMEOUT` or wait and rerun |
| Image pull error | Role not propagated yet | Rerun deploy (image update only) |
| ACR auth error | Newly created ACR delay | Wait ~30s then retry push/build |
| Env ScheduledForDelete | Deletion still pending | Use a new env name |

Override timeouts:
```bash
export WAIT_PRINCIPAL_TIMEOUT=300
export WAIT_ROLE_TIMEOUT=400
```

## GitHub Actions (Optional)
Current workflow is a stub; integrate by invoking the same shell scripts for consistency. Future enhancement: matrix over images (fastapi, springboot) using shared steps.

## Roadmap
* Unified multi-image build helper (optional convenience)
* Add .NET sample
* GitHub Actions matrix with environment caching and OIDC-based ACR push
* Application insights / logging enrichment

## Summary
This repository demonstrates a repeatable, language-agnostic pattern for safely deploying containerized workloads to Azure Container Apps using Managed Identity + ACR with minimized race conditions.

Contributions & requests welcome.
