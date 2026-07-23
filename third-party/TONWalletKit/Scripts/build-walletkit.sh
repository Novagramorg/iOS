#!/bin/bash

set -e  # Exit on error

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the project root (parent of Scripts folder)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
echo "Running pnpm build..."
if ! command -v pnpm &> /dev/null; then
    echo "Error: pnpm is not installed. Please install it first."
    echo "Run: npm install -g pnpm"
    exit 1
fi

pnpm install
pnpm build --force

# Source file path
WALLETKIT_SOURCE_FILE="$WALLETKIT_PATH/packages/walletkit-ios-bridge/dist/walletkit-ios-bridge.mjs"
WALLETKIT_INJECTION_SOURCE_FILE="$WALLETKIT_PATH/packages/walletkit-ios-bridge/dist/inject.mjs"

# Destination directory (relative to project root)
DEST_DIR="$PROJECT_ROOT/Sources/TONWalletKit/Resources/JS"

# Check if source file exists
if [ ! -f "$WALLETKIT_SOURCE_FILE" ]; then
    echo "Error: Source file not found: $WALLETKIT_SOURCE_FILE"
    exit 1
fi

# Check if source file exists
if [ ! -f "$WALLETKIT_INJECTION_SOURCE_FILE" ]; then
    echo "Error: Source file not found: $WALLETKIT_SOURCE_FILE"
    exit 1
fi

# Create destination directory if it doesn't exist
echo "Creating destination directory if needed..."
mkdir -p "$DEST_DIR"

# Copy the file
echo "Copying $WALLETKIT_SOURCE_FILE to $DEST_DIR..."
cp "$WALLETKIT_SOURCE_FILE" "$DEST_DIR/"

echo "Copying $WALLETKIT_INJECTION_SOURCE_FILE to $DEST_DIR..."
cp "$WALLETKIT_INJECTION_SOURCE_FILE" "$DEST_DIR/"

echo "✅ Done! File copied successfully to $DEST_DIR/walletkit-ios-bridge.mjs"