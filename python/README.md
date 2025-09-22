# Python Samples

Contains FastAPI quickstart targeting Python 3.10.

## Build (Recommended Usage)
Run from the repository root. Create infra (ACR/env) before building so push succeeds.

1. Generate names (dynamic helper) & set location:
```bash
eval $(./infra/shared/name_helpers.sh print fastapi)   # exports RG ENV ACR DATE
export LOCATION=koreacentral
```
2. Prepare + create infra (idempotent):
```bash
./infra/scripts/00_prepare.sh
RG="$RG" ENV="$ENV" ACR="$ACR" LOCATION="$LOCATION" ./infra/scripts/01_create_infra.sh
```
3. Build & push image:
```bash
./infra/scripts/10_acr_build_push.sh "$ACR" quickstart-fastapi auto
```

Manual naming (if you prefer):
```bash
ACR=myprojacr$(date +%Y%m%d)xyz
RG=myproj-rg-$(date +%Y%m%d)
ENV=myproj-env-$(date +%Y%m%d)
LOCATION=koreacentral
./infra/scripts/00_prepare.sh
RG="$RG" ENV="$ENV" ACR="$ACR" LOCATION="$LOCATION" ./infra/scripts/01_create_infra.sh
./infra/scripts/10_acr_build_push.sh "$ACR" quickstart-fastapi auto
```

Note: Build script now performs a preflight ACR existence check. To build only a local image without creating ACR yet:
```bash
ALLOW_BUILD_WITHOUT_ACR=1 ./infra/scripts/10_acr_build_push.sh "$ACR" quickstart-fastapi auto
```

## Local Run
```bash
pip install -r python/samples/quickstart-fastapi/requirements.txt
uvicorn app.main:app --app-dir python/samples/quickstart-fastapi/app --host 0.0.0.0 --port 8080
```

## Deploy (Example)
Using dynamic naming variables (assuming you already ran the build step above in the same shell and have RG / ENV / ACR exported):
```bash
LOCATION=koreacentral
APP=fastapi-app
IMAGE="$ACR.azurecr.io/quickstart-fastapi:$(git rev-parse --short HEAD)"
./infra/scripts/20_deploy_containerapp.sh "$RG" "$ENV" "$APP" "$ACR" "$IMAGE" "$LOCATION"
```

If you used the manual naming path:
```bash
RG=myproj-rg-$(date +%Y%m%d)
ENV=myproj-env-$(date +%Y%m%d)
ACR=myprojacr$(date +%Y%m%d)xyz
LOCATION=koreacentral
APP=fastapi-app
IMAGE="$ACR.azurecr.io/quickstart-fastapi:$(git rev-parse --short HEAD)"
./infra/scripts/20_deploy_containerapp.sh "$RG" "$ENV" "$APP" "$ACR" "$IMAGE" "$LOCATION"
```

## Runtime
- Default Python version pinned via `ARG PYTHON_VERSION=3.10` in Dockerfile.
- Override build arg for experimentation: `docker build --build-arg PYTHON_VERSION=3.11 ...` (ensure runtime available).
