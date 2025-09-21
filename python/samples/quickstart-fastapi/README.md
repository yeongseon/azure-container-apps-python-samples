# Quickstart FastAPI (Python 3.10)

Minimal FastAPI sample for Azure Container Apps using the shared two-phase deployment scripts.

## Build & Push
```bash
# Use a globally unique ACR name (example below). Change 'myacrdemo12345' to your own.
ACR_NAME=acrdemo20250921x01
IMAGE_NAME=quickstart-fastapi
TAG=auto   # uses git short SHA
./infra/scripts/10_acr_build_push.sh "$ACR_NAME" "$IMAGE_NAME" "$TAG"
```
Resulting image reference:
```
$ACR_NAME.azurecr.io/quickstart-fastapi:<sha>
```

## Local Run
```bash
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8080
# In another terminal:
curl http://localhost:8080/health
```

## Deploy
```bash
RG=aca-demo-rg-20250921
ENV=aca-demo-env-20250921
LOCATION=koreacentral
# Reuse the same ACR name used during build
ACR_NAME=acrdemo20250921x01
IMAGE="$ACR_NAME.azurecr.io/quickstart-fastapi:<sha>"
APP_NAME=fastapi-app
./infra/scripts/20_deploy_containerapp.sh "$RG" "$ENV" "$APP_NAME" "$ACR_NAME" "$IMAGE" "$LOCATION"
```

## Endpoints
- `/` root message
- `/health` liveness probe style endpoint

## Update Cycle
Repeat build (new tag) then rerun deploy script with updated `IMAGE` value; script will patch revision only.

## Troubleshooting
- Identity / role propagation delays: rerun deploy (idempotent)
- Docker unavailable: script falls back to `az acr build`

