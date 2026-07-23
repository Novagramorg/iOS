#!/bin/bash

set -e  # Exit on error

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the project root (parent of Scripts folder)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Resolve walletkit path using the resolver script
echo "Resolving walletkit path..."
WALLETKIT_PATH=${1}

if [ -z "$WALLETKIT_PATH" ]; then
    echo "Error: Failed to resolve walletkit path"
    exit 1
fi

echo "Walletkit path: $WALLETKIT_PATH"
cd "$WALLETKIT_PATH"

# Run pnpm build
echo "Running pnpm generate-openapi-spec..."
if ! command -v pnpm &> /dev/null; then
    echo "Error: pnpm is not installed. Please install it first."
    echo "Run: npm install -g pnpm"
    exit 1
fi

pnpm install

OPENAPI_SPEC=$(pnpm generate-openapi-spec 2>&1 | grep 'OPENAPI_SPEC_PATH=' | cut -d'=' -f2- | tr -d ' \n\r')

OUTPUT_DIR="${SCRIPT_DIR}/generated/openapi"
CONFIG_FILE="${SCRIPT_DIR}/generate-api-models-config.json"
DEST_DIR="${PROJECT_ROOT}/Sources/TONWalletKit/API/Models/WalletKit"

rm -rf "$DEST_DIR"

if [ -z "$OPENAPI_SPEC" ]; then
    echo "❌ Error: OpenAPI specification file is required"
    exit 1
fi

echo ""
echo "� OpenAPI spec: $OPENAPI_SPEC"
echo "�🚀 Generating Swift models from OpenAPI specification..."
echo ""

# Step 1: Validate OpenAPI spec exists
if [ ! -f "$OPENAPI_SPEC" ]; then
    echo "❌ Error: OpenAPI specification not found at '$OPENAPI_SPEC'"
    exit 1
fi

# Step 2: Clean output directory
if [ -d "$OUTPUT_DIR" ]; then
    echo "🧹 Cleaning existing output directory..."
    rm -rf "$OUTPUT_DIR"
fi

# Step 3: Generate Swift models
echo "🔨 Generating Swift models..."
openapi-generator generate \
    -i "$OPENAPI_SPEC" \
    -g swift5 \
    -o "$OUTPUT_DIR" \
    -c "$CONFIG_FILE" \
    -t "$SCRIPT_DIR/templates"

MODELS_DIR="$OUTPUT_DIR/TONWalletKitAPIModels/Classes/OpenAPIs/Models"

# Check if models directory exists
if [ ! -d "$MODELS_DIR" ]; then
    echo "❌ Error: Generated models directory not found at '$MODELS_DIR'"
    exit 1
fi

# Copty generated models to destination directory
echo "📁 Copying generated models to destination directory: $DEST_DIR"

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"
cp -R "$MODELS_DIR/"* "$DEST_DIR/"

# Remove empty/whitespace-only generated files (from x-skip-model suppression)
find "$DEST_DIR" -name '*.swift' -type f | while read -r file; do
    if ! grep -q '[^[:space:]]' "$file"; then
        rm "$file"
    fi
done

# Clean up generated directory
echo "🧹 Cleaning up generated directory..."
rm -rf "$OUTPUT_DIR"
