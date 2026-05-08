#!/bin/bash
set -e

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

# ─── Help ─────────────────────────────────────────────────────────────────────
show_help() {
    cat <<'HELP'
Telegram iOS — Build & Run

Usage:
  ./run.sh                         Simulator (default: iPhone 17 Pro Max)
  ./run.sh -s "iPhone 16 Pro"      Simulator with custom device name
  ./run.sh -r                      Real device (auto-pick first paired iPhone)
  ./run.sh -r -d "iPhone 13 Pro"   Real device by name
  ./run.sh -r --udid <UDID>        Real device by UDID
  ./run.sh -h                      Show this help

Flags:
  -s, --simulator [name]   Build for simulator (default mode).
                           Optional name overrides default "iPhone 17 Pro Max".
                           Env equivalent: SIM_NAME="iPhone 16 Pro" ./run.sh

  -r, --real               Build for a real iPhone (Vipads MCHJ team ZDBP5RSRZF).
                           Requires:
                             • iPhone connected and trusted on this Mac
                             • Apple Development cert "Azimjon Abdurasulov (DGZS4A5M4D)"
                               in Keychain (already present on this machine)
                             • A development provisioning profile for the bundle ID
                               registered for the device's UDID. If missing, run.sh
                               prints exact next steps (one-time Xcode setup).

  -d, --device <name>      Real-device name to target (used with -r).
      --udid <UDID>        Real-device UDID to target (used with -r).
                           If neither given, the first paired iPhone is used.

  -h, --help               Show this help and exit.

Notes:
  • This script is the canonical build path. Never call simctl uninstall —
    it wipes the user session. ./run.sh installs in overwrite mode and
    preserves login + chat history.
  • Bazel cache lives at ~/telegram-bazel-cache (~3-8 GB, regenerable).
HELP
    exit 0
}

# ─── Parse args ───────────────────────────────────────────────────────────────
MODE="simulator"           # simulator | real
SIM_NAME="${SIM_NAME:-iPhone 17 Pro Max}"
DEVICE_NAME=""
DEVICE_UDID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)         show_help ;;
        -r|--real)         MODE="real"; shift ;;
        -s|--simulator)    MODE="simulator"
                           if [[ -n "$2" && "$2" != -* ]]; then SIM_NAME="$2"; shift; fi
                           shift ;;
        -d|--device)       DEVICE_NAME="$2"; shift 2 ;;
        --udid)            DEVICE_UDID="$2"; shift 2 ;;
        *)                 err "Unknown argument: $1 (run ./run.sh -h)" ;;
    esac
done

# ─── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Disk tekshiruvi (5GB dan kam bo'lsa cache tozalaydi) ─────────────────────
AVAIL_GB=$(df -g . | awk 'NR==2 {print $4}')
if [ "$AVAIL_GB" -lt 50 ] 2>/dev/null; then
    warn "Disk da faqat ${AVAIL_GB}GB bo'sh joy qoldi! Cache tozalanmoqda..."
    rm -rf "$HOME/telegram-bazel-cache/cas" 2>/dev/null
    rm -rf /private/tmp/telegram-sim-app 2>/dev/null
    rm -rf /private/tmp/telegram-device-app 2>/dev/null
    ok "Cache tozalandi. $(df -h . | awk 'NR==2 {print $4}') bo'sh joy mavjud"
fi

CACHE_DIR="$HOME/telegram-bazel-cache"

# Mode-specific paths
if [ "$MODE" = "simulator" ]; then
    CONFIG_PATH="build-system/my-config.json"
    EXTRACT_DIR="/tmp/telegram-sim-app"
else
    CONFIG_PATH="build-system/my-device-config.json"
    EXTRACT_DIR="/tmp/telegram-device-app"
fi

# API credentials (Coding Tech HR — used for both modes)
API_ID="0"
API_HASH="1351b4f50d0fc65dc724d62bd09b6c79"

# Real Vipads MCHJ team for device builds. Simulator uses the same value but
# disableProvisioningProfiles makes it irrelevant.
VIPADS_TEAM_ID="ZDBP5RSRZF"
KNOWN_TEAM_ID="$VIPADS_TEAM_ID"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
if [ "$MODE" = "simulator" ]; then
    echo "║   Telegram iOS — Simulator Runner      ║"
else
    echo "║   Telegram iOS — Real Device Runner    ║"
fi
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# ─── Step 1: Config ───────────────────────────────────────────────────────────
step "Konfiguratsiya tekshirilmoqda... ($MODE)"

if [ ! -f "$CONFIG_PATH" ]; then
    warn "Config topilmadi. Yaratilmoqda: $CONFIG_PATH"

    if [ "$MODE" = "simulator" ]; then
        # Simulator: random bundle ID + fake codesigning
        TEAM_ID="$KNOWN_TEAM_ID"
        RAND_ID=$(openssl rand -hex 8)
        BUNDLE_ID="org.${RAND_ID}.Telegram"
        cat > "$CONFIG_PATH" <<EOF
{
    "bundle_id": "${BUNDLE_ID}",
    "api_id": "${API_ID}",
    "api_hash": "${API_HASH}",
    "team_id": "${TEAM_ID}",
    "app_center_id": "0",
    "is_internal_build": "true",
    "is_appstore_build": "false",
    "appstore_id": "0",
    "app_specific_url_scheme": "tg",
    "premium_iap_product_id": "",
    "enable_siri": false,
    "enable_icloud": false
}
EOF
        ok "Simulator config yaratildi"
    else
        # Real device: Vipads team + Fenixuz dev bundle ID
        TEAM_ID="$VIPADS_TEAM_ID"
        BUNDLE_ID="uz.fenixuz.dev"
        cat > "$CONFIG_PATH" <<EOF
{
    "bundle_id": "${BUNDLE_ID}",
    "api_id": "${API_ID}",
    "api_hash": "${API_HASH}",
    "team_id": "${TEAM_ID}",
    "app_center_id": "0",
    "is_internal_build": "true",
    "is_appstore_build": "false",
    "appstore_id": "0",
    "app_specific_url_scheme": "tg",
    "premium_iap_product_id": "",
    "enable_siri": false,
    "enable_icloud": false
}
EOF
        ok "Real-device config yaratildi (Team: $TEAM_ID, Bundle: $BUNDLE_ID)"
    fi
else
    ok "Config topildi: $CONFIG_PATH"
fi

# ─── Step 2: Bazel topish va config repository sozlash ───────────────────────
step "Bazel va konfiguratsiya tayyorlanmoqda..."

BAZEL_PATH=$(python3 - <<'PYEOF'
import sys, os
sys.path.insert(0, 'build-system/Make')
from BazelLocation import locate_bazel

bazel = locate_bazel(
    base_path=os.getcwd(),
    cache_host_or_path=None,
    cache_dir=os.path.expanduser('~/telegram-bazel-cache')
)
print(bazel)
PYEOF
)

ok "Bazel: $BAZEL_PATH"

python3 - <<PYEOF
import sys, os, hashlib
sys.path.insert(0, 'build-system/Make')
from BuildConfiguration import build_configuration_from_json
from BazelLocation import locate_bazel

def write_if_changed(path, content):
    """Fayl mazmuni o'zgarmasa yozmaymiz — Bazel cache saqlanadi"""
    if os.path.exists(path) and open(path).read() == content:
        return False
    with open(path, 'w') as f:
        f.write(content)
    return True

base_path = os.getcwd()
config    = build_configuration_from_json('$CONFIG_PATH')
bazel     = locate_bazel(base_path=base_path, cache_host_or_path=None,
                         cache_dir=os.path.expanduser('~/telegram-bazel-cache'))

repo = '{}/build-input/configuration-repository'.format(base_path)
os.makedirs(repo, exist_ok=True)

for fname, content in [
    ('/WORKSPACE',   ''),
    ('/MODULE.bazel','module(\n    name = "build_configuration",\n)\n'),
    ('/BUILD',       ''),
]:
    p = repo + fname
    if not os.path.exists(p):
        open(p, 'w').write(content)

prov = repo + '/provisioning'
os.makedirs(prov, exist_ok=True)
prov_build = prov + '/BUILD'
if not os.path.exists(prov_build):
    open(prov_build, 'w').write('exports_files([])\n')

import io
tmp_path = repo + '/variables.bzl.tmp'
config.write_to_variables_file(
    bazel_path=bazel,
    use_xcode_managed_codesigning=True,
    aps_environment='',
    path=tmp_path
)
new_content = open(tmp_path).read()
changed = write_if_changed(repo + '/variables.bzl', new_content)
os.remove(tmp_path)

if changed:
    print('variables.bzl yangilandi')
else:
    print('variables.bzl o\'zgarmadi — cache saqlanadi')
PYEOF

ok "Konfiguratsiya repository tayyor"

# ─── Step 2.5: Pre-flight check for real-device provisioning profiles ────────
if [ "$MODE" = "real" ]; then
    step "Provisioning profillar tekshirilmoqda..."
    PROV_DIR="$SCRIPT_DIR/build-input/configuration-repository/provisioning"
    PROV_OK=1

    # Check that the main Telegram.mobileprovision belongs to Vipads team and
    # references the uz.fenixuz.dev bundle ID. If not (i.e. the leftover
    # leaked Telegram FZ-LLC profile is still here), refuse to build.
    if [ ! -f "$PROV_DIR/Telegram.mobileprovision" ]; then
        warn "Telegram.mobileprovision topilmadi"
        PROV_OK=0
    else
        # Decode the embedded plist and check team_id + app-id
        PROV_PLIST=$(security cms -D -i "$PROV_DIR/Telegram.mobileprovision" 2>/dev/null)
        PROV_TEAM=$(echo "$PROV_PLIST" | python3 -c "
import sys, plistlib
try:
    p = plistlib.loads(sys.stdin.read().encode())
    print((p.get('TeamIdentifier') or [''])[0])
except Exception:
    pass
" 2>/dev/null)
        PROV_APP_ID=$(echo "$PROV_PLIST" | python3 -c "
import sys, plistlib
try:
    p = plistlib.loads(sys.stdin.read().encode())
    ent = p.get('Entitlements', {})
    print(ent.get('application-identifier', ''))
except Exception:
    pass
" 2>/dev/null)

        if [ "$PROV_TEAM" != "$VIPADS_TEAM_ID" ] || [[ "$PROV_APP_ID" != *"uz.fenixuz.dev" ]]; then
            warn "Joriy profil Vipads emas:  team=$PROV_TEAM, app-id=$PROV_APP_ID"
            PROV_OK=0
        fi
    fi

    if [ "$PROV_OK" = "0" ]; then
        echo ""
        echo -e "${RED}Vipads MCHJ uchun provisioning profillari topilmadi.${NC}"
        echo ""
        echo "Bir marotabalik manual sozlash kerak (~25-35 daqiqa)."
        echo "To'liq qo'llanma:"
        echo ""
        echo -e "    ${BLUE}REAL_DEVICE_SETUP.md${NC}"
        echo ""
        echo "Qisqacha tartib:"
        echo "  1. https://developer.apple.com/account → Vipads MCHJ team"
        echo "  2. App Group yarating:  group.uz.fenixuz.dev"
        echo "  3. 7 ta Bundle ID register qiling (uz.fenixuz.dev[.Widget|.Share|...])"
        echo "  4. iPhone UDID qo'shing:  3BFC6F79-5233-5749-90A3-3D5E512DD737"
        echo "  5. 7 ta Development provisioning profile yarating va yuklab oling"
        echo "  6. REAL_DEVICE_SETUP.md'dagi 'cp' buyruqlari bilan ko'chiring"
        echo "  7. ./run.sh -r ni qaytadan ishga tushiring"
        echo ""
        err "Setup tugagunicha real device build mumkin emas."
    fi
    ok "Vipads profillari mavjud (team: $PROV_TEAM)"
fi

# ─── Step 3: Bazel build ──────────────────────────────────────────────────────
if [ "$MODE" = "simulator" ]; then
    step "Bazel build (debug_sim_arm64, simulator)..."
else
    step "Bazel build (debug_arm64, real device)..."
fi
warn "Birinchi run 10-30 daqiqa olishi mumkin..."

# Hardware-aware resurs sozlamalari
TOTAL_CORES=$(sysctl -n hw.logicalcpu)
TOTAL_RAM_MB=$(($(sysctl -n hw.memsize) / 1024 / 1024))
BAZEL_RAM_MB=$((TOTAL_RAM_MB - 6144))
[ "$BAZEL_RAM_MB" -lt 4096 ] && BAZEL_RAM_MB=4096
BAZEL_JOBS=$((TOTAL_CORES - 2))
[ "$BAZEL_JOBS" -lt 2 ] && BAZEL_JOBS=2

ok "Resurs: ${BAZEL_JOBS} jobs, ${BAZEL_RAM_MB}MB RAM ($TOTAL_CORES cores, ${TOTAL_RAM_MB}MB RAM mavjud)"

# Mode-specific Bazel flags
if [ "$MODE" = "simulator" ]; then
    BAZEL_CPU_FLAG="--ios_multi_cpus=sim_arm64"
    BAZEL_PROV_FLAG="--//Telegram:disableProvisioningProfiles"
else
    BAZEL_CPU_FLAG="--ios_multi_cpus=arm64"
    # Real device: do NOT disable provisioning profiles. Bazel will look for
    # local profiles in ~/Library/MobileDevice/Provisioning Profiles/ via
    # local_provisioning_profile rule. If none match, codesigning will fail
    # with a clear error mentioning the missing profile.
    BAZEL_PROV_FLAG=""
fi

"$BAZEL_PATH" \
    --output_user_root="$CACHE_DIR/bazel-user-root" \
    build \
    Telegram/Telegram \
    --keep_going \
    --announce_rc \
    --features=swift.use_global_module_cache \
    --features=swift.use_global_index_store \
    --features=swift.skip_function_bodies_for_derived_files \
    --features=swift.cacheable_swiftmodules \
    --verbose_failures \
    --remote_cache_async \
    --jobs="$BAZEL_JOBS" \
    --local_resources=memory=$BAZEL_RAM_MB \
    --local_resources=cpu=$BAZEL_JOBS \
    --define=buildNumber=10000 \
    --define=telegramVersion=12.4 \
    --disk_cache="$CACHE_DIR" \
    --repository_cache="$CACHE_DIR/repo-cache" \
    --experimental_repository_cache_hardlinks \
    -c dbg \
    $BAZEL_CPU_FLAG \
    --watchos_cpus=arm64_32 \
    $BAZEL_PROV_FLAG

ok "Build muvaffaqiyatli tugadi"

# ─── Step 4: .app faylini topish ─────────────────────────────────────────────
step ".app fayl tayyorlanmoqda..."

APP_PATH=""
APP_PATH=$(find "$SCRIPT_DIR/bazel-bin/Telegram" -name "Telegram.app" -maxdepth 5 2>/dev/null | head -1 || true)

if [ -z "$APP_PATH" ]; then
    IPA_PATH=$(find "$SCRIPT_DIR/bazel-bin/Telegram" -name "Telegram.ipa" -maxdepth 5 2>/dev/null | head -1 || true)
    if [ -n "$IPA_PATH" ]; then
        ok "IPA topildi: $(basename "$IPA_PATH")"
        rm -rf "$EXTRACT_DIR"
        mkdir -p "$EXTRACT_DIR"
        unzip -q "$IPA_PATH" -d "$EXTRACT_DIR"
        APP_PATH=$(find "$EXTRACT_DIR" -name "*.app" -maxdepth 4 2>/dev/null | head -1 || true)
    fi
fi

[ -z "$APP_PATH" ] && err ".app fayl topilmadi. bazel-bin/Telegram/ papkasini tekshiring."
ok "App: $(basename "$APP_PATH")"

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null || \
    python3 -c "import plistlib; p=plistlib.load(open('$APP_PATH/Info.plist','rb')); print(p['CFBundleIdentifier'])")

# ─── Step 5: Install & Launch ─────────────────────────────────────────────────
if [ "$MODE" = "simulator" ]; then
    # ─── Simulator path ───────────────────────────────────────────────────────
    step "'$SIM_NAME' simulatori qidirilmoqda..."

    SIM_UDID=$(xcrun simctl list devices available -j 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d.get('name','') == '${SIM_NAME}' and d.get('isAvailable', False):
            print(d['udid'])
            sys.exit(0)
" 2>/dev/null || true)

    if [ -z "$SIM_UDID" ]; then
        warn "'$SIM_NAME' topilmadi. Mavjud iPhone simulatorlar:"
        xcrun simctl list devices available | grep -i iphone
        err "Simulator topilmadi."
    fi
    ok "UDID: $SIM_UDID"

    step "Simulator boot qilinmoqda..."
    xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
    open -a Simulator
    ok "Simulator tayyor"

    step "O'rnatilmoqda va ishga tushirilmoqda..."
    # NOTE: we use `install` (overwrite mode), NOT `uninstall + install`.
    # The latter wipes the user's session and chat history.
    xcrun simctl install "$SIM_UDID" "$APP_PATH"
    ok "O'rnatildi"

    xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Telegram $SIM_NAME da ishlamoqda!  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
else
    # ─── Real device path ─────────────────────────────────────────────────────
    step "Real iPhone qidirilmoqda..."

    if [ -n "$DEVICE_UDID" ]; then
        ok "UDID berilgan: $DEVICE_UDID"
    else
        # Auto-pick first paired iPhone, or filter by name if -d given
        DEVICES_JSON=$(xcrun devicectl list devices --json-output /tmp/devicectl-list.json 2>&1 || true)
        if [ ! -f /tmp/devicectl-list.json ]; then
            err "devicectl ishlamadi. Xcode 15+ kerak. Tekshiring: xcrun devicectl list devices"
        fi

        DEVICE_UDID=$(python3 - <<PYEOF
import json
with open('/tmp/devicectl-list.json') as f:
    data = json.load(f)
target_name = "$DEVICE_NAME".strip()
for dev in data.get('result', {}).get('devices', []):
    name = dev.get('deviceProperties', {}).get('name', '')
    udid = dev.get('hardwareProperties', {}).get('udid', '')
    state = dev.get('connectionProperties', {}).get('pairingState', '')
    if state != 'paired':
        continue
    if target_name and target_name.lower() not in name.lower():
        continue
    print(udid)
    break
PYEOF
)
        rm -f /tmp/devicectl-list.json

        if [ -z "$DEVICE_UDID" ]; then
            warn "Paired iPhone topilmadi. Ulangan qurilmalar:"
            xcrun devicectl list devices
            err "iPhone'ni Mac'ga ulang va 'Trust' bosing."
        fi
        ok "Topildi: $DEVICE_UDID"
    fi

    step "iPhone'ga o'rnatilmoqda..."
    # devicectl install — overwrite mode by default, preserves app data
    if ! xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"; then
        echo ""
        warn "Install fail bo'ldi. Eng ko'p uchraydigan sabab — provisioning profile yo'q."
        cat <<INSTRUCTIONS

${YELLOW}Birinchi marta real device build uchun (one-time setup):${NC}

  1. Xcode'ni oching:
       open Telegram_Bazel.xcodeproj  (yoki generate qilib oling)

  2. Top toolbar'da:
       • Team: Vipads MCHJ (ZDBP5RSRZF) ni tanlang
       • Signing: "Automatically manage signing" yoqing
       • Destination: sizning iPhone'ingiz

  3. ⌘B bilan build qiling — Xcode automatic ravishda:
       • Bundle ID 'uz.fenixuz.dev'ni Apple Developer Portal'da register qiladi
       • iPhone UDID'ingizni qo'shadi
       • Development provisioning profile yaratadi va Mac'ga yuklab oladi

  4. Profillar saqlanganidan keyin (~/Library/MobileDevice/Provisioning Profiles/):
       ./run.sh -r  # endi ishlaydi

INSTRUCTIONS
        err "Setup kerak (yuqoridagi instruction'larga qarang)."
    fi
    ok "O'rnatildi: $BUNDLE_ID"

    step "iPhone'da ishga tushirilmoqda..."
    xcrun devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID" || \
        warn "Auto-launch ishlamadi. iPhone'dan qo'lda oching."

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Telegram iPhone'ingizda ishlamoqda!   ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
fi
