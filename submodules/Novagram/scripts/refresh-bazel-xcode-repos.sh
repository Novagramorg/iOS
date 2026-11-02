#!/bin/bash
# Re-creates Bazel's Xcode repos after an Xcode update.
#
# After Xcode 27.1 -> 27.2 (2026-10-31) builds failed with "'27.2.0.27B52' is not an available Xcode version" and then
# "xcode-locator failed": local_config_xcode records no input that changes with Xcode, and rules_swift's system_sdk
# extension result is cached in the output base's MODULE.bazel.lock, keyed only on DEVELOPER_DIR, which an in-place
# update keeps. When the Xcode differs from the one the last build used, this script registers it with
# LaunchServices (xcode-locator finds Xcodes there, and a fresh install can be missing for a while), stops the Bazel
# server and deletes those repos and the cached extension result. Bazel re-creates them on the next build.
#
# Usage: refresh-bazel-xcode-repos.sh <bazel binary> <output_user_root> [developer dir]
set -u

BAZEL="$1"
ROOT="$2"
DEVELOPER_DIR="${3:-/Applications/Xcode.app/Contents/Developer}"
XCODE_APP="${DEVELOPER_DIR%/Contents/Developer}"
STAMP="$ROOT/.novagram-xcode-version"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

CURRENT=$("$DEVELOPER_DIR/usr/bin/xcodebuild" -version 2>/dev/null | tr '\n' ' ')
[ -n "$CURRENT" ] || exit 0
PREVIOUS=$(cat "$STAMP" 2>/dev/null || true)
[ "$CURRENT" = "$PREVIOUS" ] && exit 0

# The first run on a machine only records the Xcode.
if [ -n "$PREVIOUS" ]; then
    echo "Xcode changed ($PREVIOUS-> $CURRENT): re-creating Bazel's Xcode repos..."
    "$LSREGISTER" -f "$XCODE_APP" >/dev/null 2>&1 || true
    "$BAZEL" --output_user_root="$ROOT" shutdown >/dev/null 2>&1 || true
    for EXTERNAL in "$ROOT"/*/external; do
        [ -d "$EXTERNAL" ] || continue
        rm -rf "$EXTERNAL/bazel_tools+xcode_configure_extension+local_config_xcode"
        rm -f "$EXTERNAL/@bazel_tools+xcode_configure_extension+local_config_xcode.marker"
        rm -rf "$EXTERNAL"/rules_swift++system_sdk+system_sdk*
        rm -f "$EXTERNAL"/@rules_swift++system_sdk+system_sdk*.marker
        LOCK="$(dirname "$EXTERNAL")/MODULE.bazel.lock"
        [ -f "$LOCK" ] || continue
        python3 -I - "$LOCK" <<'PYEOF'
import json
import sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
if data.get("moduleExtensions", {}).pop("@@rules_swift+//swift:extensions.bzl%system_sdk", None) is not None:
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
PYEOF
    done
fi
mkdir -p "$ROOT"
echo "$CURRENT" > "$STAMP"
