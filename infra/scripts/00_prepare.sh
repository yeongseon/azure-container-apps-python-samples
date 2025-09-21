#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$DIR/shared/00_prepare.sh" "$@"#!/usr/bin/env bash
set -euo pipefail

# 00_prepare.sh
# Description: Install/upgrade required Azure CLI extensions and register resource providers.
# Usage: ./infra/scripts/00_prepare.sh

az extension add -n containerapp --upgrade
az provider register --namespace Microsoft.App --wait

echo "Prepare step completed. Verify with 'az extension list' and 'az provider show --namespace Microsoft.App'"