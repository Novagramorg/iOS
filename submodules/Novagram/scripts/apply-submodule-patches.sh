#!/usr/bin/env bash
#
# Puts our hooks back into git submodules we cannot push to.
#
# Why: submodules/TgVoipWebrtc/tgcalls is pinned to a TelegramMessenger/tgcalls commit. The parent repo
# does not track files inside it, and `git submodule update` resets them, silently dropping our hooks.
# So the hooks live here as patch files (submodules/Novagram/patches/<name>.patch) and run.sh,
# publish.sh and release.sh apply them before every build. Same idea as the Mac's fork-patches/.
#
#   apply-submodule-patches.sh            apply every patch that is not applied yet (running it twice is a no-op)
#   apply-submodule-patches.sh --unapply  take them out again (before `git submodule update` moves a submodule)
#   apply-submodule-patches.sh --save     after editing a patched submodule: write its diff back into the patch
#
# A patch that neither applies nor is already applied means upstream changed those lines: re-apply the
# hook by hand (HOOKS.md lists every line), then run --save.
#
# Exit codes: 0 ok, 1 a patch does not apply / unapply, 2 usage error.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PATCHES="$ROOT/submodules/Novagram/patches"

# patch name -> submodule path (relative to the repo root)
SUBMODULES=(
    "tgcalls:submodules/TgVoipWebrtc/tgcalls"
)

mode="${1:-apply}"
case "$mode" in
    apply|--unapply|--save) ;;
    -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "usage: $0 [--unapply|--save]" >&2; exit 2 ;;
esac

failed=0
for entry in "${SUBMODULES[@]}"; do
    name="${entry%%:*}"
    dir="$ROOT/${entry#*:}"
    patch="$PATCHES/$name.patch"

    if [ ! -e "$dir/.git" ]; then
        echo "ERROR: $dir is not checked out (git submodule update --init -- ${entry#*:})" >&2
        failed=1
        continue
    fi

    if [ "$mode" = "--save" ]; then
        mkdir -p "$PATCHES"
        git -C "$dir" diff > "$patch"
        echo "$name: saved $(grep -c '^+[^+]' "$patch" || true) added lines into ${patch#"$ROOT"/}"
        continue
    fi

    [ -s "$patch" ] || continue

    applied=0
    git -C "$dir" apply --reverse --check "$patch" 2> /dev/null && applied=1

    if [ "$mode" = "--unapply" ]; then
        if [ "$applied" = 1 ]; then
            git -C "$dir" apply --reverse "$patch"
            echo "$name: patch taken out"
        elif git -C "$dir" diff --quiet; then
            echo "$name: patch not applied, nothing to take out"
        else
            echo "ERROR: $name has changes that differ from ${patch#"$ROOT"/}; run --save first or revert them" >&2
            failed=1
        fi
        continue
    fi

    if [ "$applied" = 1 ]; then
        echo "$name: patch already applied"
    elif git -C "$dir" apply --check "$patch" 2> /dev/null; then
        git -C "$dir" apply "$patch"
        echo "$name: patch applied"
    else
        echo "ERROR: ${patch#"$ROOT"/} does not apply to ${entry#*:} ($(git -C "$dir" rev-parse --short HEAD))." >&2
        echo "  Either the submodule has other local edits (save them with --save) or upstream changed those lines" >&2
        echo "  (re-apply the hook by hand from HOOKS.md, then --save)." >&2
        failed=1
    fi
done

exit "$failed"
