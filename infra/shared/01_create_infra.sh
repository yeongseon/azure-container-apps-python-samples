#!/usr/bin/env bash
set -euo pipefail

# 01_create_infra.sh
# Description: Create Resource Group, ACR, and Azure Container Apps environment.
# Usage:
# RG and ACR and ENV must be set as environment variables, e.g.:
# RG=my-rg ACR=myacr ENV=my-env LOCATION=koreacentral ./infra/scripts/01_create_infra.sh

: "${RG:?Resource group not set}"
: "${ACR:?ACR name not set}"
: "${ENV:?ACA environment name not set}"
LOCATION="${LOCATION:-koreacentral}"

echo "[INFO] Creating resource group $RG ..."
az group create -n "$RG" -l "$LOCATION" --only-show-errors

echo "[INFO] Creating Azure Container Registry $ACR ..."
az acr create -g "$RG" -n "$ACR" --sku Basic --only-show-errors

echo "[INFO] Creating ACA environment $ENV ..."
az containerapp env create -g "$RG" -n "$ENV" -l "$LOCATION" --only-show-errors

echo "Infrastructure creation completed."