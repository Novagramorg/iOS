#!/bin/bash
set -e

# ─── release.sh ──────────────────────────────────────────────────────────────
# Build a release Fenixuz.ipa signed for App Store distribution.
# Companion to run.sh (which builds debug for simulator / real-device dev).
#
# Usage:
#   ./release.sh              Build only — produces bazel-bin/Telegram/Fenixuz.ipa
#   ./release.sh --upload     Build + upload to App Store Connect via altool
#   ./release.sh -h           Show this help
#
# Prerequisites:
#   1. Apple Distribution certificate in keychain (Vipads MCHJ team ZDBP5RSRZF).
#   2. 7 App Store provisioning profiles in ~/Downloads/ named
#      Fenixuz_AppStore*.mobileprovision (one per Bundle ID).
#   3. (For --upload) App Store Connect API key file at
#      ~/.appstoreconnect/AuthKey_<KEY_ID>.p8 and env vars
#      ASC_KEY_ID + ASC_ISSUER_ID set.
#
# Output: bazel-bin/Telegram/Fenixuz.ipa  (signed App Store IPA)

# ─── Colors ───────────────────────────────────────────────────────────────────
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

step() { echo -e "\n${BLUE}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
err()  { echo -e "${RED}✗ $1${NC}"; exit 1; }

show_help() {
    cat <<'HELP'
Fenixuz Release Builder

Usage:
  ./release.sh              Build .ipa only
  ./release.sh --upload     Build + upload to App Store Connect (TestFlight)
  ./release.sh -h           Show this help

Prerequisites (one-time setup):
  • Apple Distribution certificate in Keychain (Vipads MCHJ, ZDBP5RSRZF)
  • 7 App Store provisioning profiles in ~/Downloads/:
      Fenixuz_AppStore.mobileprovision                     (uz.fenixuz.app)
      Fenixuz_AppStore_Share.mobileprovision               (uz.fenixuz.app.Share)
      Fenixuz_AppStore_NotificationService.mobileprovision (uz.fenixuz.app.NotificationService)
      Fenixuz_AppStore_NotificationContent.mobileprovision (uz.fenixuz.app.NotificationContent)
      Fenixuz_AppStore_Widget.mobileprovision              (uz.fenixuz.app.Widget)
      Fenixuz_AppStore_SiriIntents.mobileprovision         (uz.fenixuz.app.SiriIntents)
      Fenixuz_AppStore_BroadcastUpload.mobileprovision     (uz.fenixuz.app.BroadcastUpload)
    (Name suffixes are flexible — script auto-maps by App ID inside the profile.)
  • For --upload: ASC_KEY_ID, ASC_ISSUER_ID env + ~/.appstoreconnect/AuthKey_*.p8

What this script does:
  1. Pre-flight: verify Apple Distribution cert + 7 App Store profiles
  2. Copy App Store profiles into Bazel's expected paths
  3. Bazel release build (-c opt --ios_multi_cpus=arm64)
  4. Rename Telegram.ipa -> Fenixuz.ipa
  5. (--upload only) altool upload to App Store Connect

After successful upload, processing on App Store Connect takes 5-30 min.
Then go to App Store Connect > TestFlight > add internal/external testers.
HELP
    exit 0
}

# ─── Parse args ───────────────────────────────────────────────────────────────
UPLOAD=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)   show_help ;;
        --upload)    UPLOAD=1; shift ;;
        *)           err "Unknown arg: $1 (./release.sh -h for help)" ;;
    esac
done

# ─── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG_PATH="build-system/appstore-configuration.json"
CACHE_DIR="$HOME/telegram-bazel-cache"
PROV_DIR="$SCRIPT_DIR/build-input/configuration-repository/provisioning"
EXTRACT_DIR="/tmp/telegram-appstore-app"
VIPADS_TEAM_ID="ZDBP5RSRZF"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║   Fenixuz — App Store Release Builder  ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# ─── Pre-flight: Config ──────────────────────────────────────────────────────
step "Konfiguratsiya tekshirilmoqda..."
[ ! -f "$CONFIG_PATH" ] && err "Config topilmadi: $CONFIG_PATH"

# Verify bundle_id + team_id are correct in appstore config
ACTUAL_BUNDLE=$(python3 -c "import json; print(json.load(open('$CONFIG_PATH'))['bundle_id'])")
ACTUAL_TEAM=$(python3 -c "import json; print(json.load(open('$CONFIG_PATH'))['team_id'])")
[ "$ACTUAL_BUNDLE" != "uz.fenixuz.app" ] && err "Config bundle_id noto'g'ri: $ACTUAL_BUNDLE (kutilgan: uz.fenixuz.app)"
[ "$ACTUAL_TEAM" != "$VIPADS_TEAM_ID" ]  && err "Config team_id noto'g'ri: $ACTUAL_TEAM (kutilgan: $VIPADS_TEAM_ID)"
ok "Config OK: bundle=$ACTUAL_BUNDLE, team=$ACTUAL_TEAM"

# ─── Pre-flight: Apple Distribution cert ─────────────────────────────────────
step "Apple Distribution sertifikati tekshirilmoqda..."

DIST_CERT=$(security find-identity -v -p codesigning | grep "Apple Distribution.*$VIPADS_TEAM_ID\|Apple Distribution.*Vipads" | head -1 || true)
if [ -z "$DIST_CERT" ]; then
    cat <<INSTRUCTIONS

${RED}Apple Distribution sertifikati topilmadi.${NC}

Bir marotabalik sozlash:

  1. Mac'da Keychain Access oching:
       open "/Applications/Utilities/Keychain Access.app"

  2. Menu: Keychain Access -> Certificate Assistant
       -> Request a Certificate From a Certificate Authority

  3. Maydonlarni to'ldiring:
       - Email: vipadsllc@gmail.com
       - Common Name: Vipads MCHJ
       - "Saved to disk" tanlang -> Save (CSR fayli yaratiladi)

  4. https://developer.apple.com/account/resources/certificates/list ga kiring
       -> + tugmasi
       -> "Apple Distribution" tanlang -> Continue
       -> CSR faylni yuklang
       -> Sertifikatni yuklab oling

  5. Yuklangan .cer faylni ikki marta bosing - keychain'ga qo'shiladi

  6. ./release.sh ni qaytadan ishga tushiring

INSTRUCTIONS
    err "Distribution cert kerak"
fi
ok "Distribution sertifikat topildi"

# ─── Pre-flight: App Store provisioning profiles ─────────────────────────────
step "App Store provisioning profillari topilmoqda (~/Downloads, ~/Documents/Apple/Distribution)..."

# App ID suffix -> Bazel-expected filename mapping is defined inside the
# Python heredoc below (macOS bash 3.2 has no associative arrays).

# Backup current development profiles
PROV_BACKUP="$SCRIPT_DIR/.telegram-fz-llc-backup/provisioning_dev_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$PROV_BACKUP"
cp -f "$PROV_DIR"/*.mobileprovision "$PROV_BACKUP/" 2>/dev/null || true
ok "Dev profillar backup'ga ko'chirildi: $PROV_BACKUP/"

# Find and route App Store profiles from ~/Downloads by App ID + ProvisionsAllDevices
FOUND_COUNT=0
TOTAL_NEEDED=7
PYTHON_OUT=$(python3 - <<PYEOF
import os, glob, plistlib, subprocess, shutil, sys

PROV_DIR = "$PROV_DIR"
SEARCH_DIRS = [
    os.path.expanduser("~/Downloads"),
    os.path.expanduser("~/Documents/Apple/Distribution"),
]
APPID_MAP = {
    "uz.fenixuz.app": "Telegram.mobileprovision",
    "uz.fenixuz.app.Share": "Share.mobileprovision",
    "uz.fenixuz.app.NotificationService": "NotificationService.mobileprovision",
    "uz.fenixuz.app.NotificationContent": "NotificationContent.mobileprovision",
    "uz.fenixuz.app.Widget": "Widget.mobileprovision",
    "uz.fenixuz.app.SiriIntents": "Intents.mobileprovision",
    "uz.fenixuz.app.BroadcastUpload": "BroadcastUpload.mobileprovision",
}

mapped = {}
unmatched = []
candidate_files = []
for d in SEARCH_DIRS:
    if os.path.isdir(d):
        candidate_files.extend(sorted(glob.glob(os.path.join(d, "*.mobileprovision"))))

for f in candidate_files:
    try:
        plist_xml = subprocess.check_output(["security", "cms", "-D", "-i", f])
        p = plistlib.loads(plist_xml)
    except Exception:
        continue

    # App Store profile = ProvisionsAllDevices=True OR no ProvisionedDevices key
    provisioned = p.get("ProvisionedDevices")
    all_devices = p.get("ProvisionsAllDevices", False)
    is_app_store = (all_devices or provisioned is None)

    if not is_app_store:
        continue  # skip dev profiles

    app_id = p.get("Entitlements", {}).get("application-identifier", "")
    suffix = app_id.split(".", 1)[1] if "." in app_id else ""
    bazel_name = APPID_MAP.get(suffix)
    if not bazel_name:
        unmatched.append((os.path.basename(f), suffix))
        continue
    if bazel_name in mapped:
        continue
    mapped[bazel_name] = (f, suffix, p.get("UUID"))

# Copy mapped profiles
keychain = os.path.expanduser("~/Library/MobileDevice/Provisioning Profiles")
os.makedirs(keychain, exist_ok=True)

for bazel_name, (src, suffix, uuid) in sorted(mapped.items()):
    dst = os.path.join(PROV_DIR, bazel_name)
    shutil.copy2(src, dst)
    shutil.copy2(src, os.path.join(keychain, f"{uuid}.mobileprovision"))
    print(f"OK | {bazel_name} <- {os.path.basename(src)} ({suffix})")

# Watch placeholders
main = os.path.join(PROV_DIR, "Telegram.mobileprovision")
if os.path.exists(main):
    for ph in ["WatchApp.mobileprovision", "WatchExtension.mobileprovision"]:
        shutil.copy2(main, os.path.join(PROV_DIR, ph))
        print(f"OK | {ph} (placeholder)")

print(f"COUNT|{len(mapped)}")
for u in unmatched:
    print(f"UNMATCHED|{u[0]}|{u[1]}")
PYEOF
)

echo "$PYTHON_OUT" | grep "^OK |" | sed 's/^OK | /  ✓ /'
FOUND_COUNT=$(echo "$PYTHON_OUT" | grep "^COUNT|" | cut -d'|' -f2)

if [ "$FOUND_COUNT" != "7" ]; then
    cat <<INSTRUCTIONS

${RED}App Store profillari to'liq emas: $FOUND_COUNT / 7${NC}

Bir marotabalik sozlash:

  1. https://developer.apple.com/account/resources/profiles/list ga kiring
  2. Har bir Bundle ID uchun yangi profile yarating:
       Type: ${YELLOW}App Store${NC} (Development EMAS!)
       App ID: 7 ta uz.fenixuz.app[.Share|.Widget|...] ni navbatma-navbat
       Certificate: ${YELLOW}Apple Distribution${NC} (Apple Development EMAS!)
       (App Store profilida Device tanlash kerak emas - barcha device'lar)
  3. Har bir .mobileprovision faylni ~/Downloads/ ga yuklab oling
  4. ./release.sh ni qaytadan ishga tushiring
INSTRUCTIONS
    err "App Store profillari yetishmaydi"
fi
ok "Barcha 7 ta App Store profili joyiga ko'chirildi"

# ─── Step: Bazel release build ───────────────────────────────────────────────
step "Bazel release build (-c opt --ios_multi_cpus=arm64)..."

# Generate variables.bzl from appstore-configuration.json
python3 - <<PYEOF
import sys, os
sys.path.insert(0, 'build-system/Make')
from BuildConfiguration import build_configuration_from_json
from BazelLocation import locate_bazel

base = os.getcwd()
config = build_configuration_from_json('$CONFIG_PATH')
bazel  = locate_bazel(base_path=base, cache_host_or_path=None,
                      cache_dir=os.path.expanduser('~/telegram-bazel-cache'))
repo = '{}/build-input/configuration-repository'.format(base)
# aps_environment is empty because the uz.fenixuz.app App ID doesn't yet
# have Push Notifications capability enabled in Apple Developer Portal.
# Push notifications wouldn't work end-to-end anyway (Telegram's server
# has the APNS cert for ph.telegra.Telegraph, not for us). When we want
# push, we will: enable Push Notifications on the App ID + 6 extensions,
# generate APNS .p8 key, regenerate the 7 App Store profiles, then set
# aps_environment='production' here.
config.write_to_variables_file(
    bazel_path=bazel,
    use_xcode_managed_codesigning=False,
    aps_environment='',
    path=repo + '/variables.bzl'
)
print("variables.bzl regenerated for appstore config")
PYEOF

BAZEL_PATH=$(python3 - <<'PYEOF'
import sys, os
sys.path.insert(0, 'build-system/Make')
from BazelLocation import locate_bazel
print(locate_bazel(base_path=os.getcwd(), cache_host_or_path=None,
                   cache_dir=os.path.expanduser('~/telegram-bazel-cache')))
PYEOF
)

TOTAL_CORES=$(sysctl -n hw.logicalcpu)
TOTAL_RAM_MB=$(($(sysctl -n hw.memsize) / 1024 / 1024))
BAZEL_RAM_MB=$((TOTAL_RAM_MB - 6144))
[ "$BAZEL_RAM_MB" -lt 4096 ] && BAZEL_RAM_MB=4096
BAZEL_JOBS=$((TOTAL_CORES - 2))
[ "$BAZEL_JOBS" -lt 2 ] && BAZEL_JOBS=2

ok "Resurs: $BAZEL_JOBS jobs, ${BAZEL_RAM_MB}MB RAM"

"$BAZEL_PATH" \
    --output_user_root="$CACHE_DIR/bazel-user-root" \
    build \
    Telegram/Telegram \
    --keep_going \
    --features=swift.use_global_module_cache \
    --features=swift.use_global_index_store \
    --features=swift.cacheable_swiftmodules \
    --verbose_failures \
    --remote_cache_async \
    --jobs="$BAZEL_JOBS" \
    --local_resources=memory=$BAZEL_RAM_MB \
    --local_resources=cpu=$BAZEL_JOBS \
    --define=buildNumber=2 \
    --define=telegramVersion=12.4 \
    --disk_cache="$CACHE_DIR" \
    --repository_cache="$CACHE_DIR/repo-cache" \
    --experimental_repository_cache_hardlinks \
    -c opt \
    --ios_multi_cpus=arm64 \
    --watchos_cpus=arm64_32

ok "Build muvaffaqiyatli tugadi"

# ─── Find + rename IPA ───────────────────────────────────────────────────────
step "Fenixuz.ipa tayyorlanmoqda..."
IPA_SRC=$(find "$SCRIPT_DIR/bazel-bin/Telegram" -name "Telegram.ipa" -maxdepth 5 2>/dev/null | head -1)
[ -z "$IPA_SRC" ] && err "Telegram.ipa Bazel output'da topilmadi"

IPA_DST="$SCRIPT_DIR/bazel-bin/Telegram/Fenixuz.ipa"
cp -f "$IPA_SRC" "$IPA_DST"
ok "IPA: $IPA_DST"
ls -lh "$IPA_DST" | awk '{printf "   Hajmi: %s\n", $5}'

# ─── Upload (optional) ────────────────────────────────────────────────────────
if [ "$UPLOAD" = "1" ]; then
    step "App Store Connect'ga yuklanmoqda..."

    [ -z "$ASC_KEY_ID" ]    && err "ASC_KEY_ID env yo'q (App Store Connect API Key ID)"
    [ -z "$ASC_ISSUER_ID" ] && err "ASC_ISSUER_ID env yo'q (App Store Connect API Issuer ID)"

    P8_FILE=$(ls ~/.appstoreconnect/AuthKey_${ASC_KEY_ID}.p8 2>/dev/null | head -1)
    [ -z "$P8_FILE" ] && err "API key fayli topilmadi: ~/.appstoreconnect/AuthKey_${ASC_KEY_ID}.p8"

    xcrun altool --upload-app \
        --type ios \
        --file "$IPA_DST" \
        --apiKey "$ASC_KEY_ID" \
        --apiIssuer "$ASC_ISSUER_ID"

    ok "Upload muvaffaqiyatli! App Store Connect'da processing kutamiz (5-30 daq)"
    echo "    Keyin: appstoreconnect.apple.com → My Apps → Fenixuz → TestFlight"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Fenixuz.ipa tayyor!               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "Keyingi qadam:"
if [ "$UPLOAD" != "1" ]; then
    echo "  • Transporter app bilan upload qiling (drag-and-drop), yoki"
    echo "  • ASC_KEY_ID va ASC_ISSUER_ID set qilib: ./release.sh --upload"
else
    echo "  • https://appstoreconnect.apple.com → My Apps → Fenixuz → TestFlight"
    echo "  • 5-30 daq processing kutamiz, keyin tester qo'shamiz"
fi
echo ""
