#!/usr/bin/env bash
#
# verify-hooks.sh — Fenixuz iOS fork: Apple-critical hook anchor verifier
#
# WHAT IT DOES
#   Greps a source tree for each Apple-critical anchor token and reports
#   PRESENT / MISSING with a per-token file+match count. Exits non-zero if
#   ANY apple-critical anchor is missing, so it can gate a re-port / version
#   bump (see RE-PORT-PLAYBOOK.md section 5 "HOOK himoyasi").
#
#   The anchors checked here are the SUBSET that, if lost, get the app
#   rejected by Apple (demo-login auto-fill + IAP 3.1.1 gate + brand).
#   The FULL anchor list for every one of the ~30-40 hooks lives in
#   the sibling file:  submodules/Fenixuz/HOOK_INVENTORY.md
#
# USAGE
#   verify-hooks.sh [TREE_DIR]
#     TREE_DIR   directory to scan (default: git repo root, else this
#                script's repo). Pass a temp upstream clone or a new
#                report/* working tree to verify the hooks survived a merge.
#
# EXIT CODES
#   0  all apple-critical anchors PRESENT
#   1  at least one apple-critical anchor MISSING
#   2  usage / environment error
#
set -euo pipefail

# --- locate the tree to scan ---------------------------------------------
# Default: the git repo root we are run from. Fall back to the repo that
# contains this script (scripts/ -> Fenixuz/ -> submodules/ -> repo root).
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    sed -n '2,33p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
fi

tree="${1:-}"
if [[ -z "$tree" ]]; then
    if tree="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"; then
        :  # use the git repo root we live in
    else
        # not a git checkout: scan three levels up (repo root) from scripts/
        tree="$(cd "$script_dir/../../.." >/dev/null 2>&1 && pwd)"
    fi
fi

if [[ ! -d "$tree" ]]; then
    echo "ERROR: tree to scan is not a directory: $tree" >&2
    exit 2
fi

# --- the apple-critical anchor list --------------------------------------
# Keep this list SHORT and deadly: only the hooks whose loss => Apple reject.
# Full inventory: submodules/Fenixuz/HOOK_INVENTORY.md
anchors=(
    "FenixuzDemoCodeFetcher"   # demo-login: polling code fetcher (core)
    "fenixuzHideNextOption"    # demo-login: code-entry "Next" hide hook
    "FenixuzAppStoreIAP"       # IAP 3.1.1 gate: block + alert
    "FenixuzBrandColors"       # brand: fork identity / theming anchor
    "FenixuzAppleReview"       # demo-login: AppleReview module marker
)

# --- choose the fastest available grep -----------------------------------
# Prefer `git grep` (respects tracked files, fast) when scanning a git tree;
# otherwise fall back to a recursive grep over *.swift / BUILD files.
count_token() {
    # echoes "<file_count> <match_count>" for a token in $tree
    local token="$1"
    local files matches
    if git -C "$tree" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        files="$(git -C "$tree" grep -l -F -- "$token" 2>/dev/null | wc -l | tr -d ' ')"
        matches="$(git -C "$tree" grep -c -F -- "$token" 2>/dev/null \
                    | awk -F: '{s += $NF} END {print s + 0}')"
    else
        files="$(grep -rIl -F --include='*.swift' --include='BUILD' \
                    -- "$token" "$tree" 2>/dev/null | wc -l | tr -d ' ')"
        matches="$(grep -rI -F --include='*.swift' --include='BUILD' \
                    -- "$token" "$tree" 2>/dev/null | wc -l | tr -d ' ')"
    fi
    printf '%s %s\n' "${files:-0}" "${matches:-0}"
}

# --- run -----------------------------------------------------------------
echo "verify-hooks.sh — Apple-critical anchor check"
echo "tree: $tree"
echo "----------------------------------------------------------------"
printf '%-26s %-9s %-7s %s\n' "ANCHOR" "STATUS" "FILES" "MATCHES"
echo "----------------------------------------------------------------"

missing=0
for token in "${anchors[@]}"; do
    read -r fcount mcount < <(count_token "$token") || true
    fcount="${fcount:-0}"; mcount="${mcount:-0}"   # normalize empties to 0
    if [[ "$fcount" -gt 0 ]]; then
        status="PRESENT"
    else
        status="MISSING"
        missing=$((missing + 1))
    fi
    printf '%-26s %-9s %-7s %s\n' "$token" "$status" "$fcount" "$mcount"
done

echo "----------------------------------------------------------------"
echo "(full hook anchor list: submodules/Fenixuz/HOOK_INVENTORY.md)"

if [[ "$missing" -gt 0 ]]; then
    echo "RESULT: FAIL — $missing apple-critical anchor(s) MISSING." >&2
    echo "Do NOT continue the re-port. Restore the hook(s) first" >&2
    echo "(see RE-PORT-PLAYBOOK.md section 5)." >&2
    exit 1
fi

echo "RESULT: OK — all apple-critical anchors present."
exit 0
