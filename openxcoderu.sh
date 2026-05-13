#!/bin/bash
set -e

# Fenixuz Xcode project generator.
#
# Generates Telegram.xcodeproj from Bazel using rules_xcodeproj. Run after
# upgrading Xcode (e.g. 26.3 → 26.5) or whenever Xcode complains about a
# stale project. Uses --overrideXcodeVersion so Make.py won't reject newer
# Xcode versions than the codebase was last tested against.
#
# Two profiles:
#   ./openxcoderu.sh           — simulator config (my-config.json)
#                                fake-codesigning + disableProvisioningProfiles
#   ./openxcoderu.sh device    — real iPhone config (my-device-config.json)
#                                ZDBP5RSRZF team, requires Development profiles
#
# After generation, open the project:
#   open Telegram_Bazel.xcodeproj

cd "$(dirname "${BASH_SOURCE[0]}")"

MODE="${1:-sim}"

if [ "$MODE" = "device" ] || [ "$MODE" = "-d" ] || [ "$MODE" = "real" ]; then
    CONFIG="build-system/my-device-config.json"
    CODESIGN_FLAGS=""
    echo "▶ Generating xcodeproj for REAL DEVICE (Vipads MCHJ ZDBP5RSRZF)"
else
    CONFIG="build-system/my-config.json"
    CODESIGN_FLAGS="--codesigningInformationPath=build-system/fake-codesigning --disableProvisioningProfiles"
    echo "▶ Generating xcodeproj for SIMULATOR (fake-codesigning)"
fi

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    python3 build-system/Make/Make.py \
        --overrideXcodeVersion \
        --cacheDir="$HOME/telegram-bazel-cache" \
        generateProject \
        --configurationPath="$CONFIG" \
        $CODESIGN_FLAGS

echo
echo "✓ xcodeproj generated. Open with:"
echo "  open Telegram_Bazel.xcodeproj"
