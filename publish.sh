#!/bin/bash
set -e

# ─── Fenixuz App Store IPA builder ───────────────────────────────────────────
# Production .ipa fayl yaratadi:
#   • appstore-configuration.json (is_appstore_build=true)
#   • Distribution provisioning profillar
#   • Apple Distribution: Vipads MCHJ (ZDBP5RSRZF) cert
# Tugagandan keyin .ipa Apple Transporter.app orqali qo'lda upload qilinadi
# → App Store Connect → TestFlight → App Review.

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

step() { echo -e "\n${BLUE}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
err()  { echo -e "${RED}✗ $1${NC}"; exit 1; }

# ─── Paths ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CACHE_DIR="$HOME/telegram-bazel-cache"
CONFIG_PATH="build-system/appstore-configuration.json"
DIST_SRC="$HOME/Documents/Apple/Distribution"
PROV_DIR="$SCRIPT_DIR/build-input/configuration-repository/provisioning"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/Desktop}"
VIPADS_TEAM_ID="ZDBP5RSRZF"

# ─── Step 1: API credentials ────────────────────────────────────────────────
if [ -f "build-system/local-secrets.sh" ]; then
    source build-system/local-secrets.sh
fi
API_ID="${API_ID:-0}"
API_HASH="${API_HASH:-0000000000000000000000000000000}"
if [ "$API_ID" = "0" ]; then
    err "API_ID yo'q. build-system/local-secrets.sh ni tekshiring."
fi
ok "API credentials: $API_ID"

# ─── Step 2: Distribution profillarni o'rnatish ─────────────────────────────
step "Distribution profillarni o'rnatish..."

[ ! -d "$DIST_SRC" ] && err "$DIST_SRC topilmadi. Apple Developer Portal'dan Distribution profillarni yuklab oling."
[ ! -f "$DIST_SRC/Fenixuz_AppStore.mobileprovision" ] && err "Fenixuz_AppStore.mobileprovision $DIST_SRC ichida yo'q."

mkdir -p "$PROV_DIR"
cp -f "$DIST_SRC/Fenixuz_AppStore.mobileprovision"                       "$PROV_DIR/Telegram.mobileprovision"
cp -f "$DIST_SRC/Fenixuz_AppStore_BroadcastUpload.mobileprovision"       "$PROV_DIR/BroadcastUpload.mobileprovision"
cp -f "$DIST_SRC/Fenixuz_AppStore_NotificationContent.mobileprovision"   "$PROV_DIR/NotificationContent.mobileprovision"
cp -f "$DIST_SRC/Fenixuz_AppStore_NotificationService.mobileprovision"   "$PROV_DIR/NotificationService.mobileprovision"
cp -f "$DIST_SRC/Fenixuz_AppStore_Share.mobileprovision"                 "$PROV_DIR/Share.mobileprovision"
cp -f "$DIST_SRC/Fenixuz_AppStore_SiriIntents.mobileprovision"           "$PROV_DIR/Intents.mobileprovision"
cp -f "$DIST_SRC/Fenixuz_AppStore_Widget.mobileprovision"                "$PROV_DIR/Widget.mobileprovision"
cp -f "$DIST_SRC/Fenixuz_AppStore.mobileprovision"                       "$PROV_DIR/WatchApp.mobileprovision"
cp -f "$DIST_SRC/Fenixuz_AppStore.mobileprovision"                       "$PROV_DIR/WatchExtension.mobileprovision"

ok "Distribution profillar joylashtirildi"

# Distribution profil yaroqliligini tekshirish
PROV_PLIST=$(security cms -D -i "$PROV_DIR/Telegram.mobileprovision" 2>/dev/null)
PROV_TEAM=$(echo "$PROV_PLIST" | python3 -c "
import sys, plistlib
p = plistlib.loads(sys.stdin.read().encode())
print((p.get('TeamIdentifier') or [''])[0])
" 2>/dev/null)
[ "$PROV_TEAM" != "$VIPADS_TEAM_ID" ] && err "Profil Vipads emas (team=$PROV_TEAM)"
ok "Profil Vipads MCHJ: $PROV_TEAM"

# Distribution sertifikat Keychain'da mavjudligini tekshirish
if ! security find-identity -v -p codesigning | grep -q "Apple Distribution: Vipads MCHJ"; then
    err "Apple Distribution: Vipads MCHJ ($VIPADS_TEAM_ID) sertifikati Keychain'da yo'q."
fi
ok "Distribution cert mavjud"

# ─── Step 3: Bazel & configuration ──────────────────────────────────────────
step "Bazel locator..."
BAZEL_PATH=$(python3 - <<PYEOF
import sys, os
sys.path.insert(0, 'build-system/Make')
from BazelLocation import locate_bazel
print(locate_bazel(base_path=os.getcwd(), cache_host_or_path=None,
                   cache_dir=os.path.expanduser('~/telegram-bazel-cache')))
PYEOF
)
ok "Bazel: $BAZEL_PATH"

step "Konfiguratsiya (App Store)..."

python3 - <<PYEOF
import sys, os, hashlib
sys.path.insert(0, 'build-system/Make')
from BuildConfiguration import build_configuration_from_json
from BazelLocation import locate_bazel

def write_if_changed(path, content):
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

tmp_path = repo + '/variables.bzl.tmp'
# aps_environment="" — push notifications entitlement qo'shilmaydi.
# Apple Developer Portal'da uz.fenixuz.app uchun Push Notifications capability
# yoqilmagan. Push kerak bo'lganda: developer.apple.com → Identifiers →
# uz.fenixuz.app → Capabilities → Push Notifications ✅ → keyin Distribution
# profilni regenerate qilib '/Users/.../Documents/Apple/Distribution/'ga
# nusxa olib, bu yerda aps_environment='production' qilib qo'ying.
config.write_to_variables_file(
    bazel_path=bazel,
    use_xcode_managed_codesigning=False,
    aps_environment='',
    path=tmp_path
)
new_content = open(tmp_path).read()
changed = write_if_changed(repo + '/variables.bzl', new_content)
os.remove(tmp_path)
print('variables.bzl ' + ('yangilandi' if changed else 'o\'zgarmadi'))
PYEOF

ok "Konfiguratsiya repository (appstore) tayyor"

# ─── Step 4: Resurs sozlamalari ─────────────────────────────────────────────
TOTAL_CORES=$(sysctl -n hw.logicalcpu)
TOTAL_RAM_MB=$(($(sysctl -n hw.memsize) / 1024 / 1024))
BAZEL_RAM_MB=$((TOTAL_RAM_MB - 6144))
[ "$BAZEL_RAM_MB" -lt 4096 ] && BAZEL_RAM_MB=4096
BAZEL_JOBS=$((TOTAL_CORES - 2))
[ "$BAZEL_JOBS" -lt 2 ] && BAZEL_JOBS=2

ok "Resurs: ${BAZEL_JOBS} jobs, ${BAZEL_RAM_MB}MB RAM"

# ─── Step 5: Build number (auto-increment) ──────────────────────────────────
BUILD_NUMBER_FILE="$SCRIPT_DIR/build-system/.appstore-build-number"
if [ -f "$BUILD_NUMBER_FILE" ]; then
    BUILD_NUMBER=$(($(cat "$BUILD_NUMBER_FILE") + 1))
else
    BUILD_NUMBER=2  # last manual upload was 1, so we start at 2
fi
echo "$BUILD_NUMBER" > "$BUILD_NUMBER_FILE"

VERSION=$(python3 -c "
import json
with open('$CONFIG_PATH') as f:
    d = json.load(f)
print(d.get('app_version') or '12.4')
" 2>/dev/null)
[ -z "$VERSION" ] && VERSION="12.4"

ok "Version: $VERSION  Build: $BUILD_NUMBER"

# ─── Step 6: Bazel build (release, real-device arm64) ───────────────────────
step "App Store build (release, -c opt)..."
warn "Birinchi opt-build 30-45 daqiqa olishi mumkin (dbg-cache yordam bermaydi)."

"$BAZEL_PATH" \
    --output_user_root="$CACHE_DIR/bazel-user-root" \
    build \
    Telegram/Telegram \
    --keep_going \
    --features=swift.use_global_module_cache \
    --features=swift.cacheable_swiftmodules \
    --verbose_failures \
    --jobs="$BAZEL_JOBS" \
    --local_resources=memory=$BAZEL_RAM_MB \
    --local_resources=cpu=$BAZEL_JOBS \
    --define=buildNumber=$BUILD_NUMBER \
    --define=telegramVersion=$VERSION \
    --disk_cache="$CACHE_DIR" \
    --repository_cache="$CACHE_DIR/repo-cache" \
    --experimental_repository_cache_hardlinks \
    -c opt \
    --ios_multi_cpus=arm64 \
    --watchos_cpus=arm64_32 \
    --//Telegram:embedWatchApp \
    --define=watchApiId="$API_ID" \
    --define=watchApiHash="$API_HASH" \
    --define=watchProvisioningProfile="$DIST_SRC/Novagram_WatchApp_App_Store.mobileprovision"

ok "App Store build muvaffaqiyatli"

# ─── Step 7: IPA → Desktop ──────────────────────────────────────────────────
step "IPA chiqarilmoqda..."
TELEGRAM_IPA=$(find "$SCRIPT_DIR/bazel-bin/Telegram" -maxdepth 2 -name "Telegram.ipa" 2>/dev/null | head -1)
[ -z "$TELEGRAM_IPA" ] && err "Telegram.ipa topilmadi."

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUT_IPA="$OUTPUT_DIR/Novagram-${VERSION}-${BUILD_NUMBER}-${TIMESTAMP}.ipa"
cp -f "$TELEGRAM_IPA" "$OUT_IPA"

ok "IPA: $OUT_IPA  ($(du -h "$OUT_IPA" | awk '{print $1}'))"

# Verify embedded profile inside IPA
TMP_VERIFY="$(mktemp -d)"
unzip -q "$OUT_IPA" -d "$TMP_VERIFY"
EMBEDDED_PROV="$TMP_VERIFY/Payload/Telegram.app/embedded.mobileprovision"
if [ -f "$EMBEDDED_PROV" ]; then
    GTA=$(security cms -D -i "$EMBEDDED_PROV" 2>/dev/null | /usr/libexec/PlistBuddy -c "Print :Entitlements:get-task-allow" /dev/stdin 2>/dev/null)
    if [ "$GTA" = "true" ]; then
        rm -rf "$TMP_VERIFY"
        err "Embedded profil Development! App Store rad qiladi. Distribution profillarni qayta tekshiring."
    fi
    PROV_NAME=$(security cms -D -i "$EMBEDDED_PROV" 2>/dev/null | /usr/libexec/PlistBuddy -c "Print :Name" /dev/stdin 2>/dev/null)
    ok "Embedded profil: $PROV_NAME (Distribution)"
fi
rm -rf "$TMP_VERIFY"

# ─── Step 8: Transporter ko'rsatma ──────────────────────────────────────────
echo
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  IPA tayyor — Transporter.app bilan upload qiling             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo
echo "  Fayl: $OUT_IPA"
echo
echo "  1. Transporter.app oching (Mac App Store'dan bepul yuklab oling)"
echo "  2. Apple ID bilan kirish (Vipads MCHJ team admin)"
echo "  3. + yoki drag-drop:   $OUT_IPA"
echo "  4. DELIVER tugmasini bosish (5-15 daqiqa upload)"
echo "  5. App Store Connect → My Apps → Novagram → TestFlight"
echo "     Build 5-15 daqiqa ichida \"Processing\" → \"Ready to Test\""
echo "  6. Build'ni TestFlight Internal Testing'ga ulang"
echo "  7. App Store Review uchun \"Submit for Review\""
echo

# ─── Step 9: Eslatma — keyingi `./run.sh -r` Development'ga qaytadi ─────────
echo -e "${YELLOW}Eslatma:${NC}"
echo "  Hozir provisioning/ ichida Distribution profillar turibdi."
echo "  Keyingi \`./run.sh -r\` ishga tushganda Development profillarga avtomatik"
echo "  qaytariladi (run.sh ichida shu mantiq qo'shilgan)."
