#!/bin/bash
#
# Snapshots the current generator output for the codegen fixtures into
# Scripts/generate-api/fixtures/ as the STANDARD. Re-run only when fixtures
# change or the generator's intended behavior changes.
#
# Args:
#   $1  WALLETKIT_PATH — absolute path to packages/walletkit

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WALLETKIT_PATH="${1}"
if [ -z "$WALLETKIT_PATH" ]; then
    echo "❌ Error: WALLETKIT_PATH (arg 1) is required" >&2
    exit 1
fi

DEST="$SCRIPT_DIR/fixtures"

bash "$SCRIPT_DIR/generate-fixtures-into.sh" "$WALLETKIT_PATH" "$DEST"

echo ""
echo "✅ Fixtures STANDARD synced to $DEST"
echo "   Commit the change to lock in the new generator output."
