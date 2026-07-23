#!/bin/bash
#
# Regenerates Swift models from the codegen fixtures into a gitignored
# tree and diffs the result against the checked-in STANDARD.
#
# Exits 0 if the regenerated output matches the STANDARD byte-for-byte.
# Exits 1 if the STANDARD is missing, files are missing/extra, or any file
# differs — printing per-file unified diffs.
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

STANDARD="$SCRIPT_DIR/fixtures"
ACTUAL="$SCRIPT_DIR/.test-fixtures"

if [ ! -d "$STANDARD" ] || [ -z "$(ls -A "$STANDARD" 2>/dev/null)" ]; then
    echo "❌ STANDARD ($STANDARD) is missing or empty." >&2
    echo "   Run 'make sync-fixtures WALLETKIT_PATH=...' first." >&2
    exit 1
fi

bash "$SCRIPT_DIR/generate-fixtures-into.sh" "$WALLETKIT_PATH" "$ACTUAL"

echo ""
echo "🔍 Comparing $ACTUAL against STANDARD at $STANDARD..."

status=0

# Files present in STANDARD but missing in ACTUAL.
for f in "$STANDARD"/*.swift; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    if [ ! -f "$ACTUAL/$name" ]; then
        echo "❌ Missing in generated output: $name"
        status=1
    fi
done

# Files present in ACTUAL but absent from STANDARD.
for f in "$ACTUAL"/*.swift; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    if [ ! -f "$STANDARD/$name" ]; then
        echo "❌ Unexpected new file in generated output: $name"
        status=1
    fi
done

# Content differences for files present on both sides.
for f in "$STANDARD"/*.swift; do
    [ -e "$f" ] || continue
    name=$(basename "$f")
    [ -f "$ACTUAL/$name" ] || continue
    if ! diff -q "$STANDARD/$name" "$ACTUAL/$name" > /dev/null; then
        echo ""
        echo "❌ $name differs from STANDARD:"
        diff -u "$STANDARD/$name" "$ACTUAL/$name" || true
        status=1
    fi
done

if [ $status -eq 0 ]; then
    echo "✅ All fixture outputs match the STANDARD."
else
    echo ""
    echo "❌ Fixture comparison failed. Review the diffs above."
    echo "   If the changes are intentional, run 'make sync-fixtures WALLETKIT_PATH=...'"
    echo "   to update the STANDARD."
fi

exit $status
