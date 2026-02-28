#!/bin/bash
set -e

# ─── Colors ───────────────────────────────────────────────────────────────────
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

CONFIG_PATH="build-system/my-config.json"
CACHE_DIR="$HOME/telegram-bazel-cache"
EXTRACT_DIR="/tmp/telegram-device-app"

# API credentials (Coding Tech HR)
API_ID="0"
API_HASH="1351b4f50d0fc65dc724d62bd09b6c79"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║   Telegram iOS — Physical Device       ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# ─── Step 1: Device tekshirish ──────────────────────────────────────────────────
step "Ulanish tekshirilmoqda..."
xcrun devicectl list devices --json-output /tmp/devices.json > /dev/null 2>&1
DEVICE_UDID=$(python3 -c "
import json, sys
try:
    data = json.load(open('/tmp/devices.json'))
    for d in data.get('result', {}).get('devices', []):
        if d.get('connectionProperties', {}).get('transportType') in ['wired', 'network']:
            print(d.get('identifier'))
            sys.exit(0)
    # Agar topilmasa, shunchaki har qanday mavjud qurilmani olamiz:
    for d in data.get('result', {}).get('devices', []):
        print(d.get('identifier'))
        sys.exit(0)
except Exception:
    pass
")

if [ -z "$DEVICE_UDID" ]; then
    err "Hech qanday iPhone ulanmagan! Iltimos, kabel orqali ulang va 'Trust' ni bosing."
fi
ok "iPhone topildi: $DEVICE_UDID"

# ─── Step 2: Config ───────────────────────────────────────────────────────────
step "Konfiguratsiya tekshirilmoqda..."

if [ ! -f "$CONFIG_PATH" ]; then
    err "my-config.json topilmadi. Avval ./run.sh ni bir marta ishga tushiring."
else
    ok "Config topildi: $CONFIG_PATH"
fi

# ─── Step 3: Bazel topish ───────────────────────
step "Bazel va konfiguratsiya tayyorlanmoqda..."

BAZEL_PATH=$(python3 - <<'PYEOF'
import sys, os
sys.path.insert(0, 'build-system/Make')
from BazelLocation import locate_bazel
print(locate_bazel(base_path=os.getcwd(), cache_host_or_path=None, cache_dir=os.path.expanduser('~/telegram-bazel-cache')))
PYEOF
)
ok "Bazel: $BAZEL_PATH"

python3 - <<PYEOF
import sys, os
sys.path.insert(0, 'build-system/Make')
from BuildConfiguration import build_configuration_from_json
from BazelLocation import locate_bazel

def write_if_changed(path, content):
    if os.path.exists(path) and open(path).read() == content: return False
    with open(path, 'w') as f: f.write(content)
    return True

base_path = os.getcwd()
config    = build_configuration_from_json('$CONFIG_PATH')
bazel     = locate_bazel(base_path=base_path, cache_host_or_path=None, cache_dir=os.path.expanduser('~/telegram-bazel-cache'))
repo = '{}/build-input/configuration-repository'.format(base_path)

import io
tmp_path = repo + '/variables.bzl.tmp'
config.write_to_variables_file(
    bazel_path=bazel,
    use_xcode_managed_codesigning=True,
    aps_environment='',
    path=tmp_path
)
new_content = open(tmp_path).read()
write_if_changed(repo + '/variables.bzl', new_content)
os.remove(tmp_path)

provisioning_dir = repo + '/provisioning'
os.makedirs(provisioning_dir, exist_ok=True)
dummy_profiles = [
    'Telegram.mobileprovision', 'Share.mobileprovision', 'NotificationContent.mobileprovision',
    'Widget.mobileprovision', 'Intents.mobileprovision', 'BroadcastUpload.mobileprovision',
    'NotificationService.mobileprovision', 'WatchApp.mobileprovision', 'WatchExtension.mobileprovision'
]
for p in dummy_profiles:
    open(provisioning_dir + '/' + p, 'w').close()

with open(provisioning_dir + '/BUILD', 'w') as f:
    f.write('exports_files([\n')
    for p in dummy_profiles:
        f.write('    "{}",\n'.format(p))
    f.write('])\n')

PYEOF

ok "Konfiguratsiya repository tayyor"

# ─── Step 4: Bazel build (arm64 qurilma uchun) ─────────────────────────────
step "Bazel build (arm64 - Haqiqiy telefon uchun)..."
warn "Birinchi run ozroq vaqt olishi mumkin..."

# Provisioning profilni tekshirish va yaratish
BUNDLE_ID=$(python3 -c "
import json
config = json.load(open('$CONFIG_PATH'))
print(config.get('bundle_id', ''))
")
TEAM_ID=$(python3 -c "
import json
config = json.load(open('$CONFIG_PATH'))
print(config.get('team_id', ''))
")

PROFILE_EXISTS=$(python3 -c "
import os, subprocess, plistlib
directory = os.path.expanduser('~/Library/Developer/Xcode/UserData/Provisioning Profiles')
for f in os.listdir(directory):
    if not f.endswith(('.mobileprovision', '.provisionprofile')): continue
    try:
        data = subprocess.check_output(['security', 'cms', '-D', '-i', os.path.join(directory, f)], stderr=subprocess.DEVNULL)
        plist = plistlib.loads(data)
        name = plist.get('Name', '')
        if name == 'iOS Team Provisioning Profile: $BUNDLE_ID':
            print('YES'); exit(0)
    except: pass
print('NO')
")

if [ "$PROFILE_EXISTS" = "NO" ]; then
    step "Provisioning profil yaratilmoqda (bir martalik)..."
    TEMP_PROJECT="/tmp/TelegramProfileGen"
    rm -rf "$TEMP_PROJECT"
    python3 << GENPYEOF
import os, plistlib
PROJECT_DIR = "$TEMP_PROJECT"
BUNDLE_ID = "$BUNDLE_ID"
TEAM_ID = "$TEAM_ID"
PRODUCT_NAME = "Telegram"
os.makedirs(f"{PROJECT_DIR}/{PRODUCT_NAME}.xcodeproj", exist_ok=True)
os.makedirs(f"{PROJECT_DIR}/{PRODUCT_NAME}", exist_ok=True)
with open(f"{PROJECT_DIR}/{PRODUCT_NAME}/AppDelegate.swift", "w") as f:
    f.write('import UIKit\\n@main\\nclass AppDelegate: UIResponder, UIApplicationDelegate {\\n    var window: UIWindow?\\n}\\n')
plistlib.dump({"CFBundleDevelopmentRegion":"en","CFBundleExecutable":"\$(EXECUTABLE_NAME)","CFBundleIdentifier":"\$(PRODUCT_BUNDLE_IDENTIFIER)","CFBundleInfoDictionaryVersion":"6.0","CFBundleName":"\$(PRODUCT_NAME)","CFBundlePackageType":"APPL","CFBundleShortVersionString":"1.0","CFBundleVersion":"1","UILaunchStoryboardName":"","UIRequiredDeviceCapabilities":["armv7"]}, open(f"{PROJECT_DIR}/{PRODUCT_NAME}/Info.plist","wb"))
plistlib.dump({"com.apple.security.application-groups": [f"group.{BUNDLE_ID}"]}, open(f"{PROJECT_DIR}/{PRODUCT_NAME}/{PRODUCT_NAME}.entitlements","wb"))
bs = f'''ALWAYS_SEARCH_USER_PATHS = NO
CLANG_ENABLE_MODULES = YES
CODE_SIGN_ENTITLEMENTS = {PRODUCT_NAME}/{PRODUCT_NAME}.entitlements
CODE_SIGN_STYLE = Automatic
CURRENT_PROJECT_VERSION = 1
DEVELOPMENT_TEAM = {TEAM_ID}
INFOPLIST_FILE = {PRODUCT_NAME}/Info.plist
IPHONEOS_DEPLOYMENT_TARGET = 13.0
LD_RUNPATH_SEARCH_PATHS = \$(inherited) @executable_path/Frameworks
PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}
PRODUCT_NAME = \$(TARGET_NAME)
SDKROOT = iphoneos
SWIFT_VERSION = 5.0
TARGETED_DEVICE_FAMILY = 1,2
'''
pbx = '''// !\$*UTF8*\$!
{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {
A1 = {isa = PBXBuildFile; fileRef = A2;};
A2 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppDelegate.swift; sourceTree = "<group>";};
A3 = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "Telegram.app"; sourceTree = BUILT_PRODUCTS_DIR;};
A4 = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>";};
A5 = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = "Telegram.entitlements"; sourceTree = "<group>";};
G1 = {isa = PBXGroup; children = (G2, G3); sourceTree = "<group>";};
G2 = {isa = PBXGroup; children = (A2, A4, A5); path = Telegram; sourceTree = "<group>";};
G3 = {isa = PBXGroup; children = (A3); name = Products; sourceTree = "<group>";};
T1 = {isa = PBXNativeTarget; buildConfigurationList = CL1; buildPhases = (SP1); buildRules = (); dependencies = (); name = Telegram; productName = Telegram; productReference = A3; productType = "com.apple.product-type.application";};
P1 = {isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = 1; TargetAttributes = {T1 = {CreatedOnToolsVersion = 15.4;};};}; buildConfigurationList = CL2; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en); mainGroup = G1; productRefGroup = G3; projectDirPath = ""; projectRoot = ""; targets = (T1);};
SP1 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (A1); runOnlyForDeploymentPostprocessing = 0;};
C1 = {isa = XCBuildConfiguration; buildSettings = {''' + bs + '''}; name = Debug;};
C2 = {isa = XCBuildConfiguration; buildSettings = {SDKROOT = iphoneos;}; name = Debug;};
CL1 = {isa = XCConfigurationList; buildConfigurations = (C1); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;};
CL2 = {isa = XCConfigurationList; buildConfigurations = (C2); defaultConfigurationIsVisible = 0; defaultConfigurationName = Debug;};
}; rootObject = P1;}'''
with open(f"{PROJECT_DIR}/{PRODUCT_NAME}.xcodeproj/project.pbxproj", "w") as f:
    f.write(pbx)
GENPYEOF
    xcodebuild -project "$TEMP_PROJECT/Telegram.xcodeproj" -target Telegram -configuration Debug -sdk iphoneos -allowProvisioningUpdates CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM_ID" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        ok "Provisioning profil muvaffaqiyatli yaratildi!"
    else
        err "Provisioning profil yaratib bo'lmadi. Apple ID Xcode hisoblariga qo'shilganini tekshiring."
    fi
    rm -rf "$TEMP_PROJECT"
else
    ok "Provisioning profil mavjud: $BUNDLE_ID"
fi

"$BAZEL_PATH" \
    --output_user_root="$CACHE_DIR/bazel-user-root" \
    build \
    Telegram/Telegram \
    --announce_rc \
    --features=swift.use_global_module_cache \
    --verbose_failures \
    --remote_cache_async \
    --features=swift.skip_function_bodies_for_derived_files \
    --jobs="$(sysctl -n hw.logicalcpu)" \
    --define=buildNumber=10001 \
    --define=telegramVersion=12.4 \
    --disk_cache="$CACHE_DIR" \
    -c dbg \
    --ios_multi_cpus=arm64 \
    --//Telegram:disableExtensions

ok "Build muvaffaqiyatli tugadi"

# ─── Step 5: .app faylini topish ─────────────────────────────────────────────
step ".app fayl tayyorlanmoqda..."

IPA_PATH=$(find "$SCRIPT_DIR/bazel-bin/Telegram" -name "Telegram.ipa" -maxdepth 5 | head -1)

if [ -n "$IPA_PATH" ]; then
    ok "IPA topildi: $(basename "$IPA_PATH")"
    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    unzip -q "$IPA_PATH" -d "$EXTRACT_DIR"
    APP_PATH=$(find "$EXTRACT_DIR" -name "*.app" -maxdepth 4 | head -1)
else
    APP_PATH=$(find "$SCRIPT_DIR/bazel-bin/Telegram" -name "Telegram.app" -maxdepth 5 | head -1)
fi

[ -z "$APP_PATH" ] && err ".app fayl topilmadi. bazel-bin/Telegram/ papkasini tekshiring."
ok "App: $(basename "$APP_PATH")"

# ─── Step 6: Install & Launch ─────────────────────────────────────────────────
step "Qurilmaga o'rnatilmoqda va ishga tushirilmoqda..."

xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"
ok "Muvaffaqiyatli o'rnatildi!"

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null || \
    python3 -c "import plistlib; p=plistlib.load(open('$APP_PATH/Info.plist','rb')); print(p['CFBundleIdentifier'])")

warn "Eslatma: Agar telefoningiz 'Untrusted Developer' xatoligini bersa, Settings -> General -> VPN & Device Management ga kirib ishonchni tasdiqlang."

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Telegram Telefoningizga o'rnatildi!   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
