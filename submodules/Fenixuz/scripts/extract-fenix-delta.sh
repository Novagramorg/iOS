#!/usr/bin/env bash
#
# extract-fenix-delta.sh — Fenixuz iOS fork: pull the fork's own changes off
#                          a chosen upstream base, ready to re-apply on a new base.
#
# WHAT IT DOES
#   Given an <upstream-base-ref> (a commit/tag that represents the upstream
#   point our fork last sat on — e.g. the 12.7 version-bump commit c64653ed37),
#   it produces the PURE FORK DELTA — i.e. everything that is "us" and nothing
#   that is upstream:
#
#     (a) Fenixuz-OWNED added paths under submodules/Fenixuz/ — these are NEW
#         files (14 modules, ~7000 lines) that never conflict on re-apply.
#     (b) For each HOOKED in-tree file, `git diff <base>..HEAD -- <file>` — the
#         exact lines the fork injected into upstream files.
#
#   The combined patch is written to:  /tmp/fenix-delta.patch
#   Re-apply it onto a new upstream base with:  git apply --3way /tmp/fenix-delta.patch
#   (See RE-PORT-PLAYBOOK.md section 4, REJIM B "full version bump".)
#
# USAGE
#   extract-fenix-delta.sh <upstream-base-ref>
#
#   <upstream-base-ref>   a ref our fork diverged from, e.g.:
#                           c64653ed37   (12.7 version-bump anchor)
#                           64190e2c34   (12.8 version-bump anchor)
#                           upstream/master
#
# OUTPUT
#   /tmp/fenix-delta.patch   combined fork delta (Fenixuz files + hook diffs)
#   stdout                   human-readable summary of what went in
#
# NOTES
#   * Run from inside the fork repo (any subdir is fine).
#   * The hooked-file list below is derived from submodules/Fenixuz/HOOKS.md.
#     Keep it in sync if a new upstream file gets hooked.
#
set -euo pipefail

OUT="/tmp/fenix-delta.patch"
FENIX_DIR="submodules/Fenixuz"

# --- help / arg check ----------------------------------------------------
print_usage() {
    sed -n '2,38p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
    print_usage
    [[ $# -eq 0 ]] && { echo; echo "ERROR: missing <upstream-base-ref>." >&2; exit 2; }
    exit 0
fi

BASE="$1"

# --- locate repo root ----------------------------------------------------
if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    echo "ERROR: not inside a git repository." >&2
    exit 2
fi
cd "$repo_root"

# --- validate the base ref ----------------------------------------------
if ! git rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null; then
    echo "ERROR: '$BASE' is not a valid commit/ref in this repo." >&2
    echo "       Try: git fetch upstream --tags   (then re-run)." >&2
    exit 2
fi

# --- the hooked in-tree files (from HOOKS.md) ---------------------------
# These are regular tracked files the fork injected hooks into. NOT submodules.
# If you add a new hook to an upstream file, add its path here.
hooked_files=(
    "submodules/AuthorizationUI/Sources/AuthorizationSequenceCodeEntryController.swift"
    "submodules/AuthorizationUI/Sources/AuthorizationSequenceCodeEntryControllerNode.swift"
    "submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryController.swift"
    "submodules/TelegramUI/Sources/AppDelegate.swift"
    "submodules/TelegramUI/Sources/ChatController.swift"
    "submodules/TelegramUI/Sources/OpenResolvedUrl.swift"
    "submodules/WebUI/Sources/WebAppController.swift"
    "submodules/InAppPurchaseManager/Sources/InAppPurchaseManager.swift"
)

echo "extract-fenix-delta.sh"
echo "repo:  $repo_root"
echo "base:  $BASE  ($(git rev-parse --short "$BASE"))"
echo "head:  $(git rev-parse --short HEAD)"
echo "out:   $OUT"
echo "================================================================"

# --- (a) Fenixuz-owned added paths --------------------------------------
# Everything under submodules/Fenixuz/ that exists at HEAD. These are our new
# files; on a fresh upstream base they apply cleanly (no upstream counterpart).
echo
echo "(a) Fenixuz-owned paths under $FENIX_DIR/ (NEW files, never conflict):"
echo "----------------------------------------------------------------"
if git ls-files --error-unmatch "$FENIX_DIR" >/dev/null 2>&1; then
    git ls-files "$FENIX_DIR" | sed 's/^/    /'
    fenix_file_count="$(git ls-files "$FENIX_DIR" | wc -l | tr -d ' ')"
    echo "    ($fenix_file_count Fenixuz-owned tracked files)"
else
    echo "    WARNING: no tracked files under $FENIX_DIR — is this the fork repo?"
    fenix_file_count=0
fi

# --- build the combined patch -------------------------------------------
# Order: Fenixuz files first (clean adds), then per-hook diffs.
: > "$OUT"   # truncate / create

# (a) full diff of the Fenixuz tree base..HEAD (captures additions + any edits)
git diff "$BASE"..HEAD -- "$FENIX_DIR" >> "$OUT" || true

# (b) per-hooked-file diffs
echo
echo "(b) Hooked in-tree files — pure fork delta (git diff $BASE..HEAD):"
echo "----------------------------------------------------------------"
hook_with_delta=0
for f in "${hooked_files[@]}"; do
    if [[ ! -e "$f" ]]; then
        printf '    %-72s [skip: not present]\n' "$f"
        continue
    fi
    delta="$(git diff "$BASE"..HEAD -- "$f" || true)"
    if [[ -n "$delta" ]]; then
        lines="$(printf '%s\n' "$delta" | grep -c '^[+-]' || true)"
        printf '    %-72s [+/- %s]\n' "$f" "${lines:-0}"
        printf '%s\n' "$delta" >> "$OUT"
        hook_with_delta=$((hook_with_delta + 1))
    else
        printf '    %-72s [no delta vs base]\n' "$f"
    fi
done

# --- summary -------------------------------------------------------------
echo "================================================================"
patch_lines="$(wc -l < "$OUT" | tr -d ' ')"
echo "Wrote combined fork delta -> $OUT"
echo "  Fenixuz-owned tracked files : $fenix_file_count"
echo "  Hooked files with delta     : $hook_with_delta / ${#hooked_files[@]}"
echo "  Patch size (lines)          : $patch_lines"
echo
echo "Re-apply on a new upstream base with:"
echo "  git apply --3way $OUT"
echo
echo "Then verify the hooks survived:"
echo "  bash submodules/Fenixuz/scripts/verify-hooks.sh"
