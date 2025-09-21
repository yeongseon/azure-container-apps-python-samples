#!/usr/bin/env bash
# name_helpers.sh - Simple helpers to generate unique resource names with current date.
# Usage (source it):
#   source ./infra/shared/name_helpers.sh
#   generate_names "myproj"
# Exports:
#   DATE (YYYYMMDD)
#   RG, ACR, ENV suggestions

set -euo pipefail

DATE=$(date +%Y%m%d)

function generate_names() {
  local prefix=${1:-demo}
  # Keep within Azure naming constraints
  # ACR: 5-50 alphanumeric, lower only
  local rand=$(tr -dc a-z0-9 </dev/urandom | head -c 3)
  export RG="${prefix}-rg-${DATE}"
  export ENV="${prefix}-env-${DATE}"
  export ACR="${prefix}acr${DATE}${rand}"
  echo "Suggested names:" >&2
  echo " RG=$RG" >&2
  echo " ENV=$ENV" >&2
  echo " ACR=$ACR" >&2
}

export DATE
