#!/bin/bash
# Runs the package's iOS-simulator tests. $1 = optional -only-testing filter
# (e.g. RichTextEditorUIKitTests/MapperTests). Set SCHEME/DEVICE env to override.
set -o pipefail
SCHEME="${SCHEME:-RichTextEditor-Package}"
DEVICE="${DEVICE:-CA0A2186-0F4A-425B-B3B1-9B61E5FF01A9}"  # controller tweak (uncommitted): iPhone 17 Pro K1 by UDID (the bare name 'iPhone 17 Pro' collides with 7 sims → ambiguous destination)
FILTER=""
[ -n "$1" ] && FILTER="-only-testing:$1"
# `-collect-test-diagnostics never`: on a FAILING run xcodebuild otherwise launches
# `simctl diagnose … --timeout=600`, which blocks the run for up to 10 MINUTES after the tests have
# already finished — with no output, so it reads as a hung compile. We never open the .xcresult's
# diagnostic bundle; the failure lines below are the whole signal.
# `grep --line-buffered`: without it the pipeline buffers and per-test progress only appears at the end.
xcodebuild test -scheme "$SCHEME" -destination "platform=iOS Simulator,id=$DEVICE" \
  -collect-test-diagnostics never $FILTER 2>&1 \
  | grep --line-buffered -E "Test Case .*(passed|failed)|error:|BUILD (SUCCEEDED|FAILED)|Executed [0-9]+ test"
