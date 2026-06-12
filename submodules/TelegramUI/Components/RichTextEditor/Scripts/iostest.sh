#!/bin/bash
# Runs the package's iOS-simulator tests. $1 = optional -only-testing filter
# (e.g. RichTextEditorUIKitTests/MapperTests). Set SCHEME/DEVICE env to override.
set -o pipefail
SCHEME="${SCHEME:-RichTextEditor-Package}"
DEVICE="${DEVICE:-iPhone 17 Pro}"
FILTER=""
[ -n "$1" ] && FILTER="-only-testing:$1"
xcodebuild test -scheme "$SCHEME" -destination "platform=iOS Simulator,name=$DEVICE" $FILTER 2>&1 \
  | grep -E "Test Case .*(passed|failed)|error:|BUILD (SUCCEEDED|FAILED)|Executed [0-9]+ test"
