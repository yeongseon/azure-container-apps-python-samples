#!/usr/bin/env bash
set -euo pipefail

# build_image.sh
# Wrapper to build & push a sample's image by sample key.
# Usage:
#   ./infra/shared/build_image.sh --acr <ACR_NAME> --sample <fastapi|springboot> [--tag <tag|auto>]
# Examples:
#   ./infra/shared/build_image.sh --acr acrdemo20250921x01 --sample fastapi --tag auto
#   ./infra/shared/build_image.sh --acr acrdemo20250921x01 --sample springboot

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
}

ACR=""
SAMPLE=""
TAG="auto"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --acr) ACR="$2"; shift 2;;
    --sample) SAMPLE="$2"; shift 2;;
    --tag) TAG="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "[ERROR] Unknown arg: $1"; usage; exit 1;;
  esac
done

if [[ -z "$ACR" || -z "$SAMPLE" ]]; then
  echo "[ERROR] --acr and --sample are required" >&2
  usage; exit 1
fi

case "$SAMPLE" in
  fastapi) IMAGE_NAME="quickstart-fastapi";;
  springboot) IMAGE_NAME="quickstart-springboot";;
  *) echo "[ERROR] Unsupported sample: $SAMPLE"; exit 1;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/10_acr_build_push.sh" "$ACR" "$IMAGE_NAME" "$TAG"
