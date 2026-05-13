#!/bin/bash
# Renew expired Fenixuz provisioning profiles via fastlane sigh.
# Talab qiladi: Apple ID + 2FA code (faqat birinchi profilda — keyin session cache).
# Vipads MCHJ Apple ID kerak (ehtimol codingtechmchj@gmail.com).

set -e

FASTLANE=/opt/homebrew/bin/fastlane
TEAM_ID="ZDBP5RSRZF"
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"

mkdir -p "$PROFILE_DIR"

# 7 ta app/extension bundle ID
BUNDLES=(
    "uz.fenixuz.app"
    "uz.fenixuz.app.BroadcastUpload"
    "uz.fenixuz.app.NotificationContent"
    "uz.fenixuz.app.NotificationService"
    "uz.fenixuz.app.Share"
    "uz.fenixuz.app.SiriIntents"
    "uz.fenixuz.app.Widget"
)

cd "$PROFILE_DIR"

echo "══════════════════════════════════════════════════════════════"
echo "  Fenixuz Provisioning Profiles renewal"
echo "  Team: Vipads MCHJ ($TEAM_ID)"
echo "  Output dir: $PROFILE_DIR"
echo "══════════════════════════════════════════════════════════════"
echo

if [ "${1:-}" = "--dist" ] || [ "${1:-}" = "--all" ]; then
    MODE="Distribution (AppStore)"
    DEV_FLAG=""
else
    MODE="Development"
    DEV_FLAG="--development"
fi

echo "▶ Renewing $MODE profiles..."
echo

for bundle in "${BUNDLES[@]}"; do
    echo "── $bundle"
    $FASTLANE sigh \
        --app_identifier "$bundle" \
        --team_id "$TEAM_ID" \
        $DEV_FLAG \
        --force \
        --output_path "$PROFILE_DIR" \
        --skip_install false \
        || { echo "✗ FAILED: $bundle"; exit 1; }
    echo
done

if [ "${1:-}" = "--all" ]; then
    echo "▶ Now renewing Distribution profiles..."
    for bundle in "${BUNDLES[@]}"; do
        echo "── $bundle (Distribution)"
        $FASTLANE sigh \
            --app_identifier "$bundle" \
            --team_id "$TEAM_ID" \
            --force \
            --output_path "$PROFILE_DIR" \
            --skip_install false \
            || { echo "✗ FAILED: $bundle"; exit 1; }
        echo
    done
fi

echo "══════════════════════════════════════════════════════════════"
echo "✓ All profiles renewed successfully"
echo "  Run: ./run.sh -r"
echo "══════════════════════════════════════════════════════════════"
