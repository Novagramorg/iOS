#!/bin/bash
#
# Shared helper: generate Swift models from the codegen-fixtures spec into a
# destination directory, with blank lines stripped and empty files removed.
#
# Used by both sync-fixtures.sh (writes the checked-in STANDARD) and
# test-fixtures.sh (writes a gitignored actual-output tree for diffing).
#
# Args:
#   $1  WALLETKIT_PATH — absolute path to packages/walletkit
#   $2  DEST_DIR       — absolute path where the stripped .swift files land
#                        (will be wiped + recreated)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WALLETKIT_PATH="${1}"
DEST_DIR="${2}"

if [ -z "$WALLETKIT_PATH" ]; then
    echo "❌ Error: WALLETKIT_PATH (arg 1) is required" >&2
    exit 1
fi
if [ -z "$DEST_DIR" ]; then
    echo "❌ Error: DEST_DIR (arg 2) is required" >&2
    exit 1
fi

if ! command -v pnpm &> /dev/null; then
    echo "❌ Error: pnpm is not installed. Run: npm install -g pnpm" >&2
    exit 1
fi

echo "📁 Walletkit path: $WALLETKIT_PATH"
echo "📦 Destination:    $DEST_DIR"

# Step 1: Generate the fixtures OpenAPI spec on the JS side.
cd "$WALLETKIT_PATH"
pnpm install
OPENAPI_SPEC=$(pnpm generate-openapi-spec-fixtures 2>&1 | grep 'OPENAPI_SPEC_PATH=' | cut -d'=' -f2- | tr -d ' \n\r')

if [ -z "$OPENAPI_SPEC" ] || [ ! -f "$OPENAPI_SPEC" ]; then
    echo "❌ Error: fixtures OpenAPI specification not produced" >&2
    exit 1
fi
echo "📄 Fixtures OpenAPI spec: $OPENAPI_SPEC"

# Step 2: Run the Swift codegen, reusing the regular config + templates.
OUTPUT_DIR="${SCRIPT_DIR}/generated/openapi-fixtures"
CONFIG_FILE="${SCRIPT_DIR}/generate-api-models-config.json"

if [ -d "$OUTPUT_DIR" ]; then
    rm -rf "$OUTPUT_DIR"
fi

echo "🔨 Generating Swift models from fixtures..."
openapi-generator generate \
    -i "$OPENAPI_SPEC" \
    -g swift5 \
    -o "$OUTPUT_DIR" \
    -c "$CONFIG_FILE" \
    -t "$SCRIPT_DIR/templates"

MODELS_DIR="$OUTPUT_DIR/TONWalletKitAPIModels/Classes/OpenAPIs/Models"
if [ ! -d "$MODELS_DIR" ]; then
    echo "❌ Error: Generated models directory not found at '$MODELS_DIR'" >&2
    rm -rf "$OUTPUT_DIR"
    exit 1
fi

# Step 3: Wipe + repopulate the destination.
rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"
cp -R "$MODELS_DIR/"* "$DEST_DIR/"

# Step 4: Remove empty/whitespace-only files (from x-skip-model suppression).
find "$DEST_DIR" -name '*.swift' -type f | while read -r file; do
    if ! grep -q '[^[:space:]]' "$file"; then
        rm "$file"
    fi
done

# Step 5: Strip blank lines from every remaining .swift file so the STANDARD
# is whitespace-normalized and diffs stay focused on actual structure.
find "$DEST_DIR" -name '*.swift' -type f | while read -r file; do
    sed -i '' '/^[[:space:]]*$/d' "$file"
done

# Step 6: Clean up the openapi-generator scratch dir.
rm -rf "$OUTPUT_DIR"

echo "✅ Generated $(ls "$DEST_DIR" | wc -l | tr -d ' ') Swift file(s) in $DEST_DIR"
