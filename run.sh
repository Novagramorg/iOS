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

CONFIG_PATH="build-system/my-config.json"
CACHE_DIR="$HOME/telegram-bazel-cache"
SIM_NAME="iPhone 17 Pro"
EXTRACT_DIR="/tmp/telegram-sim-app"

# API credentials (Coding Tech HR)
API_ID="0"
API_HASH="1351b4f50d0fc65dc724d62bd09b6c79"
KNOWN_TEAM_ID="59VH6CVPK3"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║   Telegram iOS — Simulator Runner      ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# ─── Step 1: Config ───────────────────────────────────────────────────────────
step "Konfiguratsiya tekshirilmoqda..."

if [ ! -f "$CONFIG_PATH" ]; then
    warn "Config topilmadi. Yaratilmoqda..."

    TEAM_ID=$(security find-certificate -c "Apple Development" -p 2>/dev/null \
        | openssl x509 -noout -subject 2>/dev/null \
        | grep -oE 'OU=[A-Z0-9]{10}' | head -1 | cut -d= -f2 || echo "")

    if   [ -n "$TEAM_ID" ];       then ok "Team ID Keychain dan: $TEAM_ID"
    elif [ -n "$KNOWN_TEAM_ID" ]; then TEAM_ID="$KNOWN_TEAM_ID"; ok "Saqlangan Team ID: $TEAM_ID"
    else TEAM_ID="SIMULATOR";          warn "Placeholder: $TEAM_ID"
    fi

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
    ok "Config yaratildi: $CONFIG_PATH"
else
    ok "Config topildi: $CONFIG_PATH"
fi

# ─── Step 2: Bazel topish va config repository sozlash ───────────────────────
# generateProject va Xcode ishlatilmaydi. Python orqali to'g'ridan-to'g'ri
# variables.bzl va provisioning/BUILD yaratamiz, keyin Bazel chaqiramiz.

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

def file_hash(path):
    if not os.path.exists(path): return ''
    return hashlib.md5(open(path,'rb').read()).hexdigest()

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

# Kerakli Bazel fayllar (bir marta yoziladi)
for fname, content in [
    ('/WORKSPACE',   ''),
    ('/MODULE.bazel','module(\n    name = "build_configuration",\n)\n'),
    ('/BUILD',       ''),
]:
    p = repo + fname
    if not os.path.exists(p):
        open(p, 'w').write(content)

# Bo'sh provisioning BUILD
prov = repo + '/provisioning'
os.makedirs(prov, exist_ok=True)
prov_build = prov + '/BUILD'
if not os.path.exists(prov_build):
    open(prov_build, 'w').write('exports_files([])\n')

# variables.bzl — faqat o'zgarganda yozamiz (cache miss oldini olish)
import io
buf = io.StringIO()
orig_write = open.__class__  # save
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

# ─── Step 3: Bazel build (simulator, Xcode YO'Q) ─────────────────────────────
step "Bazel build (debug_sim_arm64, Xcode ochmaydi)..."
warn "Birinchi run 10-30 daqiqa olishi mumkin..."

# .bazelrc ni o'qib Bazel flaglarini olamiz
"$BAZEL_PATH" \
    --output_user_root="$CACHE_DIR/bazel-user-root" \
    build \
    Telegram/Telegram \
    --announce_rc \
    --features=swift.use_global_module_cache \
    --verbose_failures \
    --remote_cache_async \
    --features=swift.skip_function_bodies_for_derived_files \
    --jobs="4" \
    --local_ram_resources="8192" \
    --define=buildNumber=10000 \
    --define=telegramVersion=12.4 \
    --disk_cache="$CACHE_DIR" \
    -c dbg \
    --ios_multi_cpus=sim_arm64 \
    --watchos_cpus=arm64_32 \
    --//Telegram:disableProvisioningProfiles

ok "Build muvaffaqiyatli tugadi"

# ─── Step 4: .app faylini topish ─────────────────────────────────────────────
step ".app fayl tayyorlanmoqda..."

APP_PATH=""

# 1) To'g'ridan-to'g'ri .app
APP_PATH=$(find "$SCRIPT_DIR/bazel-bin/Telegram" -name "Telegram.app" -maxdepth 5 2>/dev/null | head -1 || true)

# 2) IPA dan extract
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

# ─── Step 5: Simulator ────────────────────────────────────────────────────────
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

# ─── Step 6: Boot ─────────────────────────────────────────────────────────────
step "Simulator boot qilinmoqda..."

# Simulator holatidan qat'iy nazar boot qilamiz (allaqachon booted bo'lsa xato e'tiborga olinmaydi)
xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
open -a Simulator
ok "Simulator tayyor"

# ─── Step 7: Install & Launch ─────────────────────────────────────────────────
step "O'rnatilmoqda va ishga tushirilmoqda..."

xcrun simctl install "$SIM_UDID" "$APP_PATH"
ok "O'rnatildi"

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null || \
    python3 -c "import plistlib; p=plistlib.load(open('$APP_PATH/Info.plist','rb')); print(p['CFBundleIdentifier'])")

xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Telegram $SIM_NAME da ishlamoqda!  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
