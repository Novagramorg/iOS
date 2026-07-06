#!/bin/bash
set -e

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

step()    { echo -e "\n${BLUE}${BOLD}▶ $1${NC}"; }
ok()      { echo -e "${GREEN}✓ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $1${NC}"; }
err()     { echo -e "${RED}✗ ERROR: $1${NC}"; exit 1; }
info()    { echo -e "${CYAN}  $1${NC}"; }

# ─── Defaults ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG_PATH="build-system/my-config.json"
CACHE_DIR="$HOME/telegram-bazel-cache"
OUTPUT_DIR="$SCRIPT_DIR/build-output"
BUILD_NUMBER="${BUILD_NUMBER:-100001}"
CODESIGNING_PATH=""
TARGET="simulator"   # simulator | device
MODE=""

# API credentials (Coding Tech HR)
API_ID="0"
API_HASH="1351b4f50d0fc65dc724d62bd09b6c79"
KNOWN_TEAM_ID="59VH6CVPK3"

# ─── Usage ────────────────────────────────────────────────────────────────────
usage() {
    echo ""
    echo -e "${BOLD}Telegram iOS — Build Script${NC}"
    echo ""
    echo -e "  ${CYAN}./build.sh generate${NC}                                    Simulator uchun Xcode project"
    echo -e "  ${CYAN}./build.sh generate --device${NC}                           Real device uchun Xcode project"
    echo -e "  ${CYAN}./build.sh ipa --codesigning <path>${NC}                    .ipa fayl yaratish"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo -e "  --device               Real device uchun build (team_id va signing kerak)"
    echo -e "  --codesigning <path>   Certs va profiles papkasi yo'li (ipa uchun majburiy)"
    echo -e "  --build-number <num>   Build raqami (default: 100001)"
    echo -e "  --config <path>        Config fayl yo'li (default: build-system/my-config.json)"
    echo -e "  --output <path>        IPA saqlash papkasi (default: build-output/)"
    echo ""
    echo -e "${BOLD}Codesigning papka tuzilmasi (generate --device va ipa uchun):${NC}"
    echo -e "  codesigning/"
    echo -e "  ├── certs/"
    echo -e "  │   ├── distribution.p12"
    echo -e "  │   └── AppleWWDR.cer"
    echo -e "  └── profiles/"
    echo -e "      ├── Telegram.mobileprovision"
    echo -e "      ├── Share.mobileprovision"
    echo -e "      ├── NotificationService.mobileprovision"
    echo -e "      ├── NotificationContent.mobileprovision"
    echo -e "      ├── Widget.mobileprovision"
    echo -e "      ├── Intents.mobileprovision"
    echo -e "      └── BroadcastUpload.mobileprovision"
    echo ""
    exit 0
}

# ─── Parse Arguments ──────────────────────────────────────────────────────────
if [ $# -eq 0 ]; then
    usage
fi

MODE="$1"
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        --device)       TARGET="device"              ; shift   ;;
        --codesigning)  CODESIGNING_PATH="$2"        ; shift 2 ;;
        --build-number) BUILD_NUMBER="$2"            ; shift 2 ;;
        --config)       CONFIG_PATH="$2"             ; shift 2 ;;
        --output)       OUTPUT_DIR="$2"              ; shift 2 ;;
        --help|-h)      usage ;;
        *) warn "Noma'lum argument: $1"; shift ;;
    esac
done

# ─── Banner ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║        Telegram iOS — Build System           ║${NC}"
echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo -e "  Mode        : ${CYAN}${BOLD}$MODE${NC}"
echo -e "  Target      : ${CYAN}${BOLD}$TARGET${NC}"
echo -e "  Build Number: ${CYAN}$BUILD_NUMBER${NC}"
echo -e "  Config      : ${CYAN}$CONFIG_PATH${NC}"
[ -n "$CODESIGNING_PATH" ] && echo -e "  Codesigning : ${CYAN}$CODESIGNING_PATH${NC}"

# ─── Team ID helper ───────────────────────────────────────────────────────────
# Keychain dan team_id auto-detect
detect_team_id() {
    security find-certificate -c "Apple Development" -p 2>/dev/null \
        | openssl x509 -noout -subject 2>/dev/null \
        | grep -oE 'OU=[A-Z0-9]{10}' | head -1 | cut -d= -f2 || echo ""
}

# ─── Step 1: Config ───────────────────────────────────────────────────────────
step "Konfiguratsiya tekshirilmoqda..."

if [ ! -f "$CONFIG_PATH" ]; then
    warn "Config topilmadi. Yaratilmoqda..."
    echo ""

    if [ "$TARGET" = "simulator" ]; then
        # ── Simulator: team_id shart emas ─────────────────────────────────────
        TEAM_ID=$(detect_team_id)
        if [ -n "$TEAM_ID" ]; then
            ok "Team ID Keychain dan topildi: $TEAM_ID"
        elif [ -n "$KNOWN_TEAM_ID" ]; then
            TEAM_ID="$KNOWN_TEAM_ID"
            ok "Saqlangan Team ID ishlatilmoqda: $TEAM_ID"
        else
            TEAM_ID="SIMULATOR"
            warn "Team ID topilmadi. Placeholder: '$TEAM_ID' (simulator uchun muammo yo'q)"
        fi
    else
        # ── Real device: team_id majburiy ──────────────────────────────────────
        TEAM_ID=$(detect_team_id)
        if [ -n "$TEAM_ID" ]; then
            ok "Team ID Keychain dan topildi: $TEAM_ID"
        elif [ -n "$KNOWN_TEAM_ID" ]; then
            TEAM_ID="$KNOWN_TEAM_ID"
            ok "Saqlangan Team ID ishlatilmoqda: $TEAM_ID"
        else
            info "Team ID → Keychain Access → Certificates → Apple Development → Details → Organizational Unit"
            read -p "  team_id: " TEAM_ID
            [ -z "$TEAM_ID" ] && err "Real device uchun team_id majburiy!"
        fi
    fi

    RAND_ID=$(openssl rand -hex 8)
    BUNDLE_ID="org.${RAND_ID}.Telegram"

    mkdir -p "$(dirname "$CONFIG_PATH")"
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
    info "Bundle ID : $BUNDLE_ID"
    info "Team ID   : $TEAM_ID"
else
    ok "Config topildi: $CONFIG_PATH"
    BUNDLE_ID=$(python3 -c "import json; d=json.load(open('$CONFIG_PATH')); print(d.get('bundle_id','?'))" 2>/dev/null || echo "?")
    info "Bundle ID: $BUNDLE_ID"
fi

# ─── MODE: generate ───────────────────────────────────────────────────────────
if [ "$MODE" = "generate" ]; then

    step "Xcode project generatsiya qilinmoqda ($TARGET)..."
    info "Bu jarayon bir necha daqiqa olishi mumkin..."

    if [ "$TARGET" = "simulator" ]; then
        # ── Simulator: signing yo'q ────────────────────────────────────────────
        python3 build-system/Make/Make.py \
            --cacheDir="$CACHE_DIR" \
            --overrideXcodeVersion \
            generateProject \
            --configurationPath="$CONFIG_PATH" \
            --xcodeManagedCodesigning \
            --disableProvisioningProfiles

    else
        # ── Real device: codesigning kerak ────────────────────────────────────
        if [ -z "$CODESIGNING_PATH" ]; then
            err "Real device uchun --codesigning <path> majburiy.\n\n  Misol: ./build.sh generate --device --codesigning ./my-codesigning"
        fi
        [ ! -d "$CODESIGNING_PATH" ]          && err "Codesigning papka topilmadi: $CODESIGNING_PATH"
        [ ! -d "$CODESIGNING_PATH/certs" ]    && err "certs/ papkasi topilmadi"
        [ ! -d "$CODESIGNING_PATH/profiles" ] && err "profiles/ papkasi topilmadi"

        python3 build-system/Make/Make.py \
            --cacheDir="$CACHE_DIR" \
            --overrideXcodeVersion \
            generateProject \
            --configurationPath="$CONFIG_PATH" \
            --codesigningInformationPath="$(realpath "$CODESIGNING_PATH")"
    fi

    XCODEPROJ=$(find "$SCRIPT_DIR" -maxdepth 2 -name "*.xcodeproj" 2>/dev/null | head -1)

    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║        Xcode project tayyor! ($TARGET)${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════╝${NC}"
    [ -n "$XCODEPROJ" ] && echo -e "  Project : ${CYAN}$(basename "$XCODEPROJ")${NC}"
    echo -e "  Ochish  : ${CYAN}open $(basename "${XCODEPROJ:-Telegram.xcodeproj}")${NC}"
    echo ""
    exit 0
fi

# ─── MODE: ipa ────────────────────────────────────────────────────────────────
if [ "$MODE" = "ipa" ]; then

    # IPA har doim real device uchun — signing majburiy
    if [ -z "$CODESIGNING_PATH" ]; then
        err "IPA uchun --codesigning <path> majburiy.\n\n  Misol: ./build.sh ipa --codesigning ./my-codesigning"
    fi

    [ ! -d "$CODESIGNING_PATH" ]          && err "Codesigning papka topilmadi: $CODESIGNING_PATH"
    [ ! -d "$CODESIGNING_PATH/certs" ]    && err "certs/ papkasi topilmadi: $CODESIGNING_PATH/certs"
    [ ! -d "$CODESIGNING_PATH/profiles" ] && err "profiles/ papkasi topilmadi: $CODESIGNING_PATH/profiles"

    P12_COUNT=$(find "$CODESIGNING_PATH/certs" -name "*.p12" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$P12_COUNT" -eq 0 ]; then
        warn "certs/ papkasida .p12 sertifikat topilmadi"
        info "Apple Developer → Certificates dan distribution sertifikatni yuklab, certs/ ga qo'ying"
    else
        ok "$P12_COUNT ta .p12 sertifikat topildi"
    fi

    PROFILE_COUNT=$(find "$CODESIGNING_PATH/profiles" -name "*.mobileprovision" 2>/dev/null | wc -l | tr -d ' ')
    ok "$PROFILE_COUNT ta provisioning profile topildi"
    find "$CODESIGNING_PATH/profiles" -name "*.mobileprovision" 2>/dev/null | while read f; do
        info "  → $(basename "$f")"
    done

    mkdir -p "$OUTPUT_DIR"

    step "IPA build boshlanmoqda (release_arm64)..."
    info "Build number : $BUILD_NUMBER"
    info "Natija       : $OUTPUT_DIR/Telegram.ipa"
    warn "Bu jarayon 20-60 daqiqa olishi mumkin (birinchi build)..."

    python3 build-system/Make/Make.py \
        --cacheDir="$CACHE_DIR" \
        --overrideXcodeVersion \
        build \
        --configurationPath="$CONFIG_PATH" \
        --codesigningInformationPath="$(realpath "$CODESIGNING_PATH")" \
        --buildNumber="$BUILD_NUMBER" \
        --configuration=release_arm64 \
        --outputBuildArtifactsPath="$OUTPUT_DIR"

    # IPA faylini topish
    IPA_PATH="$OUTPUT_DIR/Telegram.ipa"
    if [ ! -f "$IPA_PATH" ]; then
        IPA_BAZEL=$(find "$SCRIPT_DIR/bazel-bin/Telegram" -name "Telegram.ipa" 2>/dev/null | head -1)
        if [ -n "$IPA_BAZEL" ]; then
            cp "$IPA_BAZEL" "$OUTPUT_DIR/Telegram.ipa"
            IPA_PATH="$OUTPUT_DIR/Telegram.ipa"
        fi
    fi

    IPA_SIZE=""
    [ -f "$IPA_PATH" ] && IPA_SIZE=$(du -sh "$IPA_PATH" | cut -f1)

    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║          IPA muvaffaqiyatli yaratildi!       ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  IPA     : ${CYAN}${BOLD}$IPA_PATH${NC}"
    [ -n "$IPA_SIZE" ]                            && echo -e "  Hajmi   : ${CYAN}$IPA_SIZE${NC}"
    [ -f "$OUTPUT_DIR/Telegram.DSYMs.zip" ]       && echo -e "  DSYMs   : ${CYAN}$OUTPUT_DIR/Telegram.DSYMs.zip${NC}"
    echo ""
    echo -e "  ${BOLD}Keyingi qadamlar:${NC}"
    echo -e "  • TestFlight  : ${CYAN}xcrun altool --upload-app -f $IPA_PATH${NC}"
    echo -e "  • Transporter ilovasi orqali App Store Connect ga yuklash"
    echo ""
    exit 0
fi

# ─── Noma'lum mode ────────────────────────────────────────────────────────────
err "Noma'lum mode: '$MODE'. To'g'ri ishlatish uchun: ./build.sh --help"
