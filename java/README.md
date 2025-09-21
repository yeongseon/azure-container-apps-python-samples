# Java Samples

Contains Spring Boot quickstart targeting Java 11.

## Build (Example)
```bash
ACR_NAME=acrdemo20250921x01
./infra/scripts/10_acr_build_push.sh "$ACR_NAME" quickstart-springboot auto
```

## Local Run
```bash
(cd java/samples/quickstart-springboot && mvn spring-boot:run)
```

## Deploy (Example)
```bash
RG=aca-demo-rg-20250921
ENV=aca-demo-env-20250921
LOCATION=koreacentral
ACR_NAME=acrdemo20250921x01
IMAGE="$ACR_NAME.azurecr.io/quickstart-springboot:<sha>"
APP=springboot-app
./infra/scripts/20_deploy_containerapp.sh "$RG" "$ENV" "$APP" "$ACR_NAME" "$IMAGE" "$LOCATION"
```

## Runtime
- Java 11 base; adjust `ARG JDK_VERSION` to test 17/21 (also update Maven compiler target)
- Multi-stage Dockerfile caches dependencies for faster rebuilds

## Notes
- Script fallbacks: remote ACR build if local Docker unavailable
- Two-phase deployment ensures identity + AcrPull role propagation before private image
