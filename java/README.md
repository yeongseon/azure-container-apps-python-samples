# Java Samples

Contains Spring Boot quickstart targeting Java 11.

## Build (Recommended Usage)
Run from repository root. Create infra before building to ensure push works.

1. Generate names & set location:
```bash
eval $(./infra/shared/name_helpers.sh print springboot)
export LOCATION=koreacentral
```
2. Prepare + create infra:
```bash
./infra/scripts/00_prepare.sh
RG="$RG" ENV="$ENV" ACR="$ACR" LOCATION="$LOCATION" ./infra/scripts/01_create_infra.sh
```
3. Build & push image:
```bash
./infra/scripts/10_acr_build_push.sh "$ACR" quickstart-springboot auto
```

Manual naming:
```bash
ACR=myprojacr$(date +%Y%m%d)xyz
RG=myproj-rg-$(date +%Y%m%d)
ENV=myproj-env-$(date +%Y%m%d)
LOCATION=koreacentral
./infra/scripts/00_prepare.sh
RG="$RG" ENV="$ENV" ACR="$ACR" LOCATION="$LOCATION" ./infra/scripts/01_create_infra.sh
./infra/scripts/10_acr_build_push.sh "$ACR" quickstart-springboot auto
```

Note: Build script has an ACR preflight check. To build a local-only image without creating ACR yet:
```bash
ALLOW_BUILD_WITHOUT_ACR=1 ./infra/scripts/10_acr_build_push.sh "$ACR" quickstart-springboot auto
```

## Local Run
```bash
(cd java/samples/quickstart-springboot && mvn spring-boot:run)
```

## Deploy (Example)
Dynamic naming path (same shell as build, variables still exported):
```bash
LOCATION=koreacentral
APP=springboot-app
IMAGE="$ACR.azurecr.io/quickstart-springboot:$(git rev-parse --short HEAD)"
./infra/scripts/20_deploy_containerapp.sh "$RG" "$ENV" "$APP" "$ACR" "$IMAGE" "$LOCATION"
```

Manual naming path:
```bash
RG=myproj-rg-$(date +%Y%m%d)
ENV=myproj-env-$(date +%Y%m%d)
ACR=myprojacr$(date +%Y%m%d)xyz
LOCATION=koreacentral
APP=springboot-app
IMAGE="$ACR.azurecr.io/quickstart-springboot:$(git rev-parse --short HEAD)"
./infra/scripts/20_deploy_containerapp.sh "$RG" "$ENV" "$APP" "$ACR" "$IMAGE" "$LOCATION"
```

## Runtime
- Java 11 base; adjust `ARG JDK_VERSION` to test 17/21 (also update Maven compiler target)
- Multi-stage Dockerfile caches dependencies for faster rebuilds

## Notes
- Script fallbacks: remote ACR build if local Docker unavailable
- Two-phase deployment ensures identity + AcrPull role propagation before private image
