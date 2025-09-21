#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$DIR/shared/20_deploy_containerapp.sh" "$@"#!/usr/bin/env bash
set -euo pipefail

# 20_deploy_containerapp.sh
# Description: Deploy an application to Azure Container Apps, enable managed identity, and assign AcrPull role so the app can pull images from ACR.
# Usage:
# ./infra/scripts/20_deploy_containerapp.sh <RESOURCE_GROUP> <ENV_NAME> <CONTAINER_APP_NAME> <ACR_NAME> <IMAGE> <LOCATION>
# Example:
# ./infra/scripts/20_deploy_containerapp.sh my-rg my-env my-app myacr myacr.azurecr.io/myapp:v1 eastus

if [ "$#" -lt 6 ]; then
  echo "Usage: $0 <RESOURCE_GROUP> <ENV_NAME> <CONTAINER_APP_NAME> <ACR_NAME> <IMAGE> <LOCATION>"
  exit 1
fi

RESOURCE_GROUP="$1"
ENV_NAME="$2"
CONTAINER_APP_NAME="$3"
ACR_NAME="$4"
IMAGE="$5"
LOCATION="$6"

ACR_RESOURCE_ID="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME"

# Ensure resource group exists
az group create -n "$RESOURCE_GROUP" -l "$LOCATION" --only-show-errors || true

echo "==> Ensure environment exists"
az containerapp env create -g "$RESOURCE_GROUP" -n "$ENV_NAME" --location "$LOCATION" --only-show-errors || true

echo "==> Create (if needed) container app with placeholder image"
PLACEHOLDER_IMAGE="nginx:latest"
if ! az containerapp show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_NAME" >/dev/null 2>&1; then
  # First attempt: create with system-assigned identity directly
  if ! az containerapp create \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$ENV_NAME" \
    --image "$PLACEHOLDER_IMAGE" \
    --ingress external \
    --target-port 80 \
    --cpu 0.25 --memory 0.5 \
    --system-assigned 2>/dev/null; then
      echo "[INFO] Re-attempt create without identity then assign later"
      az containerapp create \
        --name "$CONTAINER_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --environment "$ENV_NAME" \
        --image "$PLACEHOLDER_IMAGE" \
        --ingress external \
        --target-port 80 \
        --cpu 0.25 --memory 0.5
  fi
else
  echo "[INFO] Container app already exists; will update in place"
fi

echo "==> Ensure system-assigned managed identity is enabled"
CURRENT_ID_TYPE=$(az containerapp show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_NAME" --query identity.type -o tsv 2>/dev/null || echo "None")
if [ "$CURRENT_ID_TYPE" = "None" ] || [ -z "$CURRENT_ID_TYPE" ]; then
  ASSIGN_ATTEMPTS=0
  MAX_ASSIGN_ATTEMPTS=${MAX_ASSIGN_ATTEMPTS:-5}
  while [ $ASSIGN_ATTEMPTS -lt $MAX_ASSIGN_ATTEMPTS ]; do
    if az containerapp identity assign -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_NAME" --system-assigned >/dev/null 2>&1; then
      echo "[INFO] Managed identity assigned (attempt $((ASSIGN_ATTEMPTS+1)))"
      break
    fi
    ASSIGN_ATTEMPTS=$((ASSIGN_ATTEMPTS + 1))
    echo "[WARN] identity assign attempt $ASSIGN_ATTEMPTS failed; retrying in 5s..."
    sleep 5
  done
  CURRENT_ID_TYPE=$(az containerapp show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_NAME" --query identity.type -o tsv 2>/dev/null || echo "None")
  if [ "$CURRENT_ID_TYPE" = "None" ]; then
    APP_ID=$(az containerapp show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_NAME" --query id -o tsv 2>/dev/null || true)
    if [ -n "$APP_ID" ]; then
      echo "[INFO] Fallback resource update to set identity"
      az resource update --ids "$APP_ID" --set identity.type=SystemAssigned --only-show-errors >/dev/null 2>&1 || true
    fi
  fi
fi

echo "==> Poll for principalId"
PRINCIPAL_ID=""
WAIT_PRINCIPAL_TIMEOUT=${WAIT_PRINCIPAL_TIMEOUT:-240}
WAIT_PRINCIPAL_INTERVAL=${WAIT_PRINCIPAL_INTERVAL:-5}
ELAPSED=0
while true; do
  PRINCIPAL_ID=$(az containerapp show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_NAME" --query identity.principalId -o tsv 2>/dev/null || true)
  ID_TYPE_NOW=$(az containerapp show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_NAME" --query identity.type -o tsv 2>/dev/null || echo "None")
  if [ -n "$PRINCIPAL_ID" ] && [ "$PRINCIPAL_ID" != "null" ]; then
    echo "Found principalId: $PRINCIPAL_ID (identity.type=$ID_TYPE_NOW)"
    break
  fi
  if [ "$ELAPSED" -ge "$WAIT_PRINCIPAL_TIMEOUT" ]; then
    echo "[ERROR] Timed out waiting for principalId after $WAIT_PRINCIPAL_TIMEOUT seconds"
    az containerapp show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_NAME" -o jsonc || true
    exit 1
  fi
  echo "[DEBUG] Waiting for principalId... elapsed=${ELAPSED}s (identity.type=$ID_TYPE_NOW)"
  sleep "$WAIT_PRINCIPAL_INTERVAL"
  ELAPSED=$((ELAPSED + WAIT_PRINCIPAL_INTERVAL))
done

echo "==> Assign AcrPull role"
ASSIGN_ROLE_ATTEMPTS=0
MAX_ROLE_ATTEMPTS=${MAX_ROLE_ATTEMPTS:-3}
while [ $ASSIGN_ROLE_ATTEMPTS -lt $MAX_ROLE_ATTEMPTS ]; do
  if az role assignment create --assignee "$PRINCIPAL_ID" --role AcrPull --scope "$ACR_RESOURCE_ID" >/dev/null 2>&1; then
    echo "[INFO] Role assignment submitted"
    break
  fi
  ASSIGN_ROLE_ATTEMPTS=$((ASSIGN_ROLE_ATTEMPTS + 1))
  echo "[WARN] Role assignment attempt $ASSIGN_ROLE_ATTEMPTS failed; retrying in 5s..."
  sleep 5
done

# Wait for role assignment to propagate
WAIT_ROLE_TIMEOUT=${WAIT_ROLE_TIMEOUT:-300}
WAIT_ROLE_INTERVAL=${WAIT_ROLE_INTERVAL:-5}
ELAPSED=0
while true; do
  if az role assignment list --assignee "$PRINCIPAL_ID" --scope "$ACR_RESOURCE_ID" --query "[?roleDefinitionName=='AcrPull'] | length(@)" -o tsv >/dev/null 2>&1; then
    COUNT=$(az role assignment list --assignee "$PRINCIPAL_ID" --scope "$ACR_RESOURCE_ID" --query "[?roleDefinitionName=='AcrPull'] | length(@)" -o tsv 2>/dev/null || echo "0")
    if [ "$COUNT" -ge 1 ]; then
      echo "Role assignment visible (AcrPull)"
      break
    fi
  fi
  if [ "$ELAPSED" -ge "$WAIT_ROLE_TIMEOUT" ]; then
    echo "Timed out waiting for role assignment to propagate after $WAIT_ROLE_TIMEOUT seconds"
    break
  fi
  sleep "$WAIT_ROLE_INTERVAL"
  ELAPSED=$((ELAPSED + WAIT_ROLE_INTERVAL))
done

echo "==> Force revision update with target image"
if ! az containerapp update \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --image "$IMAGE" \
  --registry-server "$ACR_NAME.azurecr.io" \
  --registry-identity system; then
  echo "[ERROR] Failed to update container app with target image"
  exit 1
fi

echo "==> Final state summary"
az containerapp show -g "$RESOURCE_GROUP" -n "$CONTAINER_APP_NAME" --query '{fqdn:properties.configuration.ingress.fqdn,image:properties.template.containers[0].image,identity:identity}' -o jsonc || true

echo "Deployment finished. App: $CONTAINER_APP_NAME, Image: $IMAGE"