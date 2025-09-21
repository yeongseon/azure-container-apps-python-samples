# Quickstart Spring Boot (Java 11)

Minimal Spring Boot sample for Azure Container Apps using the shared two-phase deployment pattern.

## Build & Push
```bash
# Use a globally unique ACR name (example below). Change 'myacrdemo12345' to your own.
ACR_NAME=acrdemo20250921x01
IMAGE_NAME=quickstart-springboot
TAG=auto   # git short SHA
./infra/scripts/10_acr_build_push.sh "$ACR_NAME" "$IMAGE_NAME" "$TAG"
```
Image reference:
```
$ACR_NAME.azurecr.io/quickstart-springboot:<sha>
```

## Local Run
```bash
mvn spring-boot:run
curl http://localhost:8080/
```

## Deploy
```bash
RG=aca-demo-rg-20250921
ENV=aca-demo-env-20250921
LOCATION=koreacentral
# Reuse the same ACR name used during build
ACR_NAME=acrdemo20250921x01
IMAGE="$ACR_NAME.azurecr.io/quickstart-springboot:<sha>"
APP_NAME=springboot-app
./infra/scripts/20_deploy_containerapp.sh "$RG" "$ENV" "$APP_NAME" "$ACR_NAME" "$IMAGE" "$LOCATION"
```

## Endpoints
- `/` root message
- `/health` simple health check (if added later)

## Iteration
Rebuild with a new tag (auto) and redeploy with updated `IMAGE` variable. Script patches revision only.

## Notes
- Java 11 baseline; to move to 17/21, adjust `ARG JDK_VERSION` and the Maven compiler target.
- Remote ACR build fallback triggers automatically if local Docker build fails.

## Troubleshooting
Same identity/role propagation considerations as Python sample.
