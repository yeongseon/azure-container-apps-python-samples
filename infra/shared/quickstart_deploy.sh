#!/usr/bin/env bash
set -euo pipefail

# quickstart_deploy.sh
# One-shot helper: prepare, provision infra, build image, deploy app.
#
# Usage:
#   ./infra/shared/quickstart_deploy.sh --sample <fastapi|springboot> [--prefix <name>] [--location <azure-region>] [--tag <tag|auto>] \
#       [--skip-build] [--reuse] [--acr <acr>] [--rg <rg>] [--env <env>]
#
# Options:
#   --sample       Required. Which sample to deploy.
#   --prefix       Name prefix for generated resources (default: demo)
#   --location     Azure region (default: koreacentral)
#   --tag          Image tag (default: auto)
#   --skip-build   Assume image already exists (requires --acr and --tag not auto)
#   --reuse        Reuse provided/existing resources (skips name generation)
#   --acr/--rg/--env Explicit resource names (implies reuse if all provided)
#
# Examples:
#   ./infra/shared/quickstart_deploy.sh --sample fastapi --prefix myproj
#   ./infra/shared/quickstart_deploy.sh --sample springboot --location eastus --tag auto

usage(){ grep '^#' "$0" | sed 's/^# \{0,1\}//'; }

SAMPLE=""
PREFIX="demo"
LOCATION="koreacentral"
TAG="auto"
SKIP_BUILD=0
REUSE=0
RG=""
ACR=""
ENV_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sample) SAMPLE="$2"; shift 2;;
    --prefix) PREFIX="$2"; shift 2;;
    --location) LOCATION="$2"; shift 2;;
    --tag) TAG="$2"; shift 2;;
    --skip-build) SKIP_BUILD=1; shift 1;;
    --reuse) REUSE=1; shift 1;;
    --rg) RG="$2"; shift 2;;
    --acr) ACR="$2"; shift 2;;
    --env) ENV_NAME="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "[ERROR] Unknown arg $1"; usage; exit 1;;
  esac
done

if [[ -z "$SAMPLE" ]]; then
  echo "[ERROR] --sample required" >&2; usage; exit 1
fi

case "$SAMPLE" in
  fastapi) IMAGE_NAME="quickstart-fastapi"; APP_NAME="fastapi-app";;
  springboot) IMAGE_NAME="quickstart-springboot"; APP_NAME="springboot-app";;
  *) echo "[ERROR] Unsupported sample: $SAMPLE"; exit 1;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $REUSE -eq 0 && ( -z "$RG" || -z "$ACR" || -z "$ENV_NAME" ) ]]; then
  # Generate names if not provided
  source "$SCRIPT_DIR/name_helpers.sh"
  generate_names "$PREFIX"
  RG=${RG:-$RG}
  ACR=${ACR:-$ACR}
  ENV_NAME=${ENV:-$ENV_NAME}
else
  # If user provided all, treat as reuse
  if [[ -n "$RG" && -n "$ACR" && -n "$ENV_NAME" ]]; then
    REUSE=1
  fi
fi

echo "==> Using resources:" >&2
echo " RG=$RG" >&2
echo " ENV=$ENV_NAME" >&2
echo " ACR=$ACR" >&2
echo " Location=$LOCATION" >&2
echo " Sample=$SAMPLE (image: $IMAGE_NAME)" >&2

export RG ACR ENV="$ENV_NAME" LOCATION

echo "==> Preparing Azure extensions/providers"
"$SCRIPT_DIR/00_prepare.sh"

echo "==> Provisioning infra (idempotent)"
"$SCRIPT_DIR/01_create_infra.sh"

if [[ $SKIP_BUILD -eq 0 ]]; then
  echo "==> Building & pushing image"
  "$SCRIPT_DIR/build_image.sh" --acr "$ACR" --sample "$SAMPLE" --tag "$TAG"
else
  if [[ "$TAG" == "auto" ]]; then
    echo "[ERROR] --skip-build requires explicit --tag" >&2; exit 1
  fi
  echo "==> Skipping build; assuming image already exists"
fi

if [[ "$TAG" == "auto" ]]; then
  if command -v git >/dev/null 2>&1; then
    GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo latest)
    TAG="$GIT_SHA"
  else
    TAG="latest"
  fi
fi

IMAGE_REF="$ACR.azurecr.io/$IMAGE_NAME:$TAG"
echo "==> Deploying image $IMAGE_REF"
"$SCRIPT_DIR/20_deploy_containerapp.sh" "$RG" "$ENV_NAME" "$APP_NAME" "$ACR" "$IMAGE_REF" "$LOCATION"

echo "==> Done"
echo "App Name: $APP_NAME"
echo "Image:    $IMAGE_REF"
echo "Resource Group: $RG"