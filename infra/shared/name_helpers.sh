#!/usr/bin/env bash
# name_helpers.sh - Generate unique Azure resource names with current date.
#
# Dual usage:
# 1. Source mode (functions & exported vars):
#      source ./infra/shared/name_helpers.sh
#      generate_names myproj
#      echo "$RG $ENV $ACR"
# 2. Direct execution (no sourcing):
#      ./infra/shared/name_helpers.sh print myproj   # prints export lines
#      eval $(./infra/shared/name_helpers.sh print myproj)
#      ./infra/shared/name_helpers.sh json myproj    # machine-readable JSON
#      ./infra/shared/name_helpers.sh names myproj   # space-separated values
#
# Output modes:
#   print  -> shell export lines (safe for eval)
#   json   -> JSON object {RG,ENV,ACR,DATE}
#   names  -> "RG ENV ACR" single line
#   help   -> usage
# Default prefix: demo
#
# Notes:
# - ACR name: lower alphanumeric, 5-50 chars; we append a 3-char random suffix.
# - DATE format: YYYYMMDD
#
# Example one-liner:
#   eval $(./infra/shared/name_helpers.sh print myproj); ./infra/scripts/01_create_infra.sh

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

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
}

# If executed directly (not sourced), process command-line
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  mode=${1:-help}
  prefix=${2:-demo}
  case "$mode" in
    print)
      generate_names "$prefix" >/dev/null
      # Re-run to capture exported vars (already exported by function)
      echo "export DATE=$DATE"
      echo "export RG=$RG"
      echo "export ENV=$ENV"
      echo "export ACR=$ACR"
      ;;
    json)
      generate_names "$prefix" >/dev/null
      printf '{"DATE":"%s","RG":"%s","ENV":"%s","ACR":"%s"}\n' "$DATE" "$RG" "$ENV" "$ACR"
      ;;
    names)
      generate_names "$prefix" >/dev/null
      echo "$RG $ENV $ACR"
      ;;
    help|--help|-h)
      usage
      ;;
    *)
      # Treat first arg as prefix if unrecognized mode
      prefix="$mode"
      generate_names "$prefix" >/dev/null
      echo "$RG $ENV $ACR"
      ;;
  esac
fi
