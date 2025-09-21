#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$DIR/shared/10_acr_build_push.sh" "$@"#!/usr/bin/env bash
set -euo pipefail

# 10_acr_build_push.sh
# Description: Build the Docker image and push it to Azure Container Registry (ACR).
# Usage: ./infra/scripts/10_acr_build_push.sh <ACR_NAME> <IMAGE_NAME> <TAG>
# Example: ./infra/scripts/10_acr_build_push.sh myacr myapp v1

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <ACR_NAME> <IMAGE_NAME> [TAG|auto]"
  exit 1
fi

ACR_NAME="$1"
IMAGE_NAME="$2"
TAG="${3:-auto}"

if [ "$TAG" = "auto" ]; then
  if command -v git >/dev/null 2>&1; then
    GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "manual")
    TAG="$GIT_SHA"
  else
    TAG="latest"
  fi
fi

FULL_IMAGE="$ACR_NAME.azurecr.io/$IMAGE_NAME:$TAG"

# Determine script and repo root paths so build works from any CWD
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_CONTEXT="$REPO_ROOT/samples/quickstart-fastapi"

echo "==> Building Docker image $FULL_IMAGE from context $BUILD_CONTEXT"

# Prefer local Docker build when the daemon is available and responsive.
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "==> Docker is available. Building image locally..."
  if ! docker build -t "$FULL_IMAGE" "$BUILD_CONTEXT"; then
    echo "[WARN] Local docker build failed; falling back to remote az acr build"
    az acr build -r "$ACR_NAME" -t "$IMAGE_NAME:$TAG" "$BUILD_CONTEXT"
  else
    echo "==> Attempting to login to ACR: $ACR_NAME"
    if az acr login --name "$ACR_NAME" >/dev/null 2>&1; then
      echo "==> Logged in to ACR. Pushing image to ACR"
      if ! docker push "$FULL_IMAGE"; then
        echo "[WARN] Docker push failed; falling back to remote rebuild in ACR"
        az acr build -r "$ACR_NAME" -t "$IMAGE_NAME:$TAG" "$BUILD_CONTEXT"
      fi
    else
      echo "==> az acr login failed (Docker daemon or pipe issue). Falling back to 'az acr build' to build/push in ACR."
      az acr build -r "$ACR_NAME" -t "$IMAGE_NAME:$TAG" "$BUILD_CONTEXT"
    fi
  fi
else
  echo "==> Docker daemon not available. Falling back to 'az acr build' (remote build in ACR)."
  az acr build -r "$ACR_NAME" -t "$IMAGE_NAME:$TAG" "$BUILD_CONTEXT"
fi

echo "Image pushed: $FULL_IMAGE"