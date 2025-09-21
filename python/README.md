# Python Samples

Contains FastAPI quickstart targeting Python 3.10.

## Build (Example)
```bash
ACR_NAME=acrdemo20250921x01   # globally unique ACR
./infra/scripts/10_acr_build_push.sh "$ACR_NAME" quickstart-fastapi auto
```

## Local Run
```bash
pip install -r python/samples/quickstart-fastapi/requirements.txt
uvicorn app.main:app --app-dir python/samples/quickstart-fastapi/app --host 0.0.0.0 --port 8080
```

## Deploy (Example)
```bash
RG=aca-demo-rg-20250921
ENV=aca-demo-env-20250921
LOCATION=koreacentral
ACR_NAME=acrdemo20250921x01
IMAGE="$ACR_NAME.azurecr.io/quickstart-fastapi:<sha>"
APP=fastapi-app
./infra/scripts/20_deploy_containerapp.sh "$RG" "$ENV" "$APP" "$ACR_NAME" "$IMAGE" "$LOCATION"
```

## Runtime
- Default Python version pinned via `ARG PYTHON_VERSION=3.10` in Dockerfile.
- Override build arg for experimentation: `docker build --build-arg PYTHON_VERSION=3.11 ...` (ensure runtime available).
