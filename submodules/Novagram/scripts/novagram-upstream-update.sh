#!/bin/bash
# novagram-upstream-update.sh - take the latest official Telegram iOS (upstream/master) into a new branch.
#
# main does not carry Telegram's history. Telegram's code comes in as snapshot commits: a commit with
# upstream's tree whose parent is the previous snapshot, marked "Upstream-Commit: <sha>". main merges
# each new snapshot, so the merge base is always the previous snapshot, and a rewrite of upstream's
# history (Telegram force-pushed master in October 2026) changes nothing here.
#
# Steps:
#   1. check the tree: on main, no merge in progress, nothing uncommitted
#   2. fetch upstream/master; make a snapshot commit of it on top of the last snapshot in main
#   3. create feature/upstream-<date> and merge the snapshot. -X ignore-space-change: a formatter
#      re-indented many Telegram files on our side, whitespace-only differences must not conflict
#   4. update the submodules upstream moved; check that no "// Novagram" hook was lost and that the
#      Apple-critical anchors are there (verify-hooks.sh)
#   5. build with ./run.sh and print what to check on screen
#
# main is never touched. When the build is green and the app was checked on screen:
#   git switch main && git merge --ff-only <branch> && git push origin main && git branch -d <branch>
#
# Usage:
#   submodules/Novagram/scripts/novagram-upstream-update.sh            everything (steps 1-5)
#   submodules/Novagram/scripts/novagram-upstream-update.sh --check    only report what upstream has and a trial merge against
#                                                                      main: works from any branch and any working tree, changes
#                                                                      nothing but the upstream/master ref (safe in the background)
#   submodules/Novagram/scripts/novagram-upstream-update.sh --finish   after resolving merge conflicts by hand: steps 4-5
#   NOVAGRAM_TRAILER='Co-Authored-By: ...'  optional trailer line for the snapshot and merge commits
#   NOVAGRAM_HOOKS_REVIEWED=1               go past a hook-count drop you checked (a hook ported because
#                                           upstream deleted or moved its file)
#   NOVAGRAM_SKIP_BUILD=1                   skip step 5
#   NOVAGRAM_BASE_BRANCH=<branch>           start from another branch than main (testing)
#
# Exit codes: 0 ok, 1 tree not ready, 2 merge conflicts (resolve, commit, then --finish),
#             3 submodule problem, 4 a hook was lost, 5 build failed

set -o pipefail
cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 1
GIT_DIR="$(git rev-parse --git-dir)"
STATE="$GIT_DIR/novagram-upstream"
LOG="${NOVAGRAM_UPSTREAM_LOG:-/tmp/novagram-upstream-update.log}"
BASE_BRANCH="${NOVAGRAM_BASE_BRANCH:-main}"
UPSTREAM_REF="upstream/master"
MODE="${1:-start}"

: > "$LOG"

die() {
    echo "ERROR: $1" >&2
    exit "${2:-1}"
}

# ---- snapshots ----------------------------------------------------------------

last_snapshot() { # $1 = branch
    git log "$1" --format=%H -E --grep='^Upstream-Commit: [0-9a-f]{40}$' -1
}

snapshot_upstream_commit() { # $1 = snapshot commit
    git log -1 --format=%B "$1" | sed -n -E 's/^Upstream-Commit: ([0-9a-f]{40})$/\1/p' | head -1
}

make_snapshot() { # $1 = parent snapshot, $2 = upstream commit; prints the new snapshot commit
    local msg
    msg="$(mktemp)"
    {
        printf 'updated telegram to %s (%s)\n\n' "$(git rev-parse --short "$2")" "$(git log -1 --format=%cs "$2")"
        printf 'Snapshot of TelegramMessenger/Telegram-iOS master, merged into main next.\n\n'
        printf 'Upstream-Commit: %s\n' "$(git rev-parse "$2")"
        [ -n "${NOVAGRAM_TRAILER:-}" ] && printf '%s\n' "$NOVAGRAM_TRAILER"
    } > "$msg"
    git commit-tree "$2^{tree}" -p "$1" -F "$msg"
    rm -f "$msg"
}

# ---- "// Novagram" hooks --------------------------------------------------------

hooks_snapshot() { # $1 = revision, $2 = output file
    git grep -c -e '// Novagram' "$1" -- ':!*.md' ':!docs/*' ':!*.xcframework/*' | sed "s#^$1:##" > "$2" || true
}

hooks_compare() {
    awk -F: '
        NR == FNR { before[$1] = $2; next }
        { after[$1] = $2 }
        END {
            lost = 0
            for (f in before) {
                if (!(f in after)) { printf "  LOST file with hooks: %s (%d)\n", f, before[f]; lost++ }
                else if (after[f] < before[f]) { printf "  FEWER hooks: %s (%d -> %d)\n", f, before[f], after[f]; lost++ }
            }
            for (f in after) if (!(f in before)) printf "  new file with hooks: %s (%d)\n", f, after[f]
            exit lost ? 1 : 0
        }' "$1" "$2"
}

# ---- reporting ---------------------------------------------------------------

upstream_report() { # $1 = old snapshot, $2 = new snapshot, $3 = hook counts of the base
    local old_up new_up n
    old_up="$(snapshot_upstream_commit "$1")"
    new_up="$(snapshot_upstream_commit "$2")"
    if [ -n "$old_up" ] && git cat-file -e "$old_up^{commit}" 2> /dev/null && git merge-base --is-ancestor "$old_up" "$new_up"; then
        n="$(git rev-list --count "$old_up..$new_up")"
        echo "upstream has $n new commits since $(git log -1 --format=%cs "$old_up"):"
        git log --format='  %h %s' "$old_up..$new_up" | head -40
        [ "$n" -gt 40 ] && echo "  ... and $((n - 40)) more"
    else
        echo "upstream rewrote its history since the last snapshot ($(git rev-parse --short "$1")): only the file changes are listed"
    fi
    echo "upstream changed $(git diff --name-only "$1" "$2" | wc -l | tr -d ' ') files; these also hold our hooks (check them on screen):"
    comm -12 <(git diff --name-only "$1" "$2" | sort) <(cut -d: -f1 "$3" | sort) | sed 's/^/  /'
    echo "submodules moved by upstream:"
    git diff --raw "$1" "$2" | awk '$2 == "160000" { print "  " $6 }'
}

# ---- finishing ---------------------------------------------------------------

update_moved_submodules() {
    local moved p
    git submodule sync >> "$LOG" 2>&1 || die "git submodule sync failed, see $LOG" 3
    moved="$(git submodule status | awk '/^[+-]/ { print $2 }')"
    [ -z "$moved" ] && return
    echo "updating submodules: $(echo "$moved" | tr '\n' ' ')"
    # our patched submodules (tgcalls) must be clean before they move, then get the patch back
    submodules/Novagram/scripts/apply-submodule-patches.sh --unapply >> "$LOG" 2>&1 \
        || die "apply-submodule-patches.sh --unapply failed, see $LOG" 3
    for p in $moved; do
        git submodule update --init -- "$p" >> "$LOG" 2>&1 || die "git submodule update failed for $p, see $LOG" 3
    done
    submodules/Novagram/scripts/apply-submodule-patches.sh >> "$LOG" 2>&1 \
        || die "a submodule patch no longer applies: re-apply it by hand (HOOKS.md, \"Submodule patches\"), run apply-submodule-patches.sh --save, commit, then --finish" 3
}

build() {
    if [ "${NOVAGRAM_SKIP_BUILD:-0}" = 1 ]; then
        echo "build skipped (NOVAGRAM_SKIP_BUILD=1)"
        return
    fi
    echo "building with ./run.sh (output: /tmp/run-sh-output.log)..."
    nice -n 10 ./run.sh > /tmp/run-sh-output.log 2>&1
    grep -q "Build muvaffaqiyatli" /tmp/run-sh-output.log \
        || die "build failed (see /tmp/run-sh-output.log); fix it on this branch, commit, then run: $0 --finish" 5
}

finish() {
    [ -f "$STATE/branch" ] || die "no update in progress (run without --finish first)"
    local branch old new
    branch="$(cat "$STATE/branch")"
    old="$(cat "$STATE/old-snapshot")"
    new="$(cat "$STATE/new-snapshot")"
    [ "$(git rev-parse --abbrev-ref HEAD)" = "$branch" ] || die "switch to $branch first"
    [ -e "$GIT_DIR/MERGE_HEAD" ] && die "the merge is not committed yet: resolve the conflicts, git add, git commit, then run --finish"
    git merge-base --is-ancestor "$new" HEAD || die "$branch does not contain the snapshot $(git rev-parse --short "$new")"
    update_moved_submodules
    hooks_snapshot HEAD "$STATE/hooks-after.txt"
    echo "hook check (// Novagram lines per file, before -> after the merge):"
    if ! hooks_compare "$STATE/hooks-before.txt" "$STATE/hooks-after.txt"; then
        if [ "${NOVAGRAM_HOOKS_REVIEWED:-0}" != 1 ]; then
            die "a hook was lost in the merge: restore it on this branch (HOOKS.md), commit, then run: $0 --finish
(if it was ported on purpose, for example because upstream deleted its file, run: NOVAGRAM_HOOKS_REVIEWED=1 $0 --finish)" 4
        fi
        echo "  the drop above was reviewed (NOVAGRAM_HOOKS_REVIEWED=1)"
    else
        echo "  no hook lost ($(awk -F: '{ s += $2 } END { print s + 0 }' "$STATE/hooks-after.txt") lines in $(wc -l < "$STATE/hooks-after.txt" | tr -d ' ') files)"
    fi
    submodules/Novagram/scripts/verify-hooks.sh >> "$LOG" 2>&1 \
        || die "verify-hooks.sh: an Apple-critical anchor is missing (see $LOG and HOOKS.md)" 4
    echo "verify-hooks.sh: Apple-critical anchors present"
    build
    echo
    echo "DONE on branch $branch"
    upstream_report "$old" "$new" "$STATE/hooks-before.txt"
    echo
    echo "next: check the app on screen (the files above first). Then:"
    echo "  git switch main && git merge --ff-only $branch && git push origin main && git branch -d $branch"
}

check() {
    echo "fetching upstream..."
    git fetch --no-recurse-submodules upstream master >> "$LOG" 2>&1 || die "git fetch upstream failed, see $LOG"
    git update-ref "refs/remotes/$UPSTREAM_REF" FETCH_HEAD
    local base old up new hooks
    base="$(git rev-parse --verify -q "$BASE_BRANCH")" || die "no branch $BASE_BRANCH"
    old="$(last_snapshot "$base")"
    [ -n "$old" ] || die "no snapshot commit (Upstream-Commit: trailer) in $BASE_BRANCH's history"
    up="$(git rev-parse "$UPSTREAM_REF")"
    if [ "$(git rev-parse "$up^{tree}")" = "$(git rev-parse "$old^{tree}")" ]; then
        echo "already up to date with $UPSTREAM_REF ($(git rev-parse --short "$up"))"
        exit 0
    fi
    hooks="$(mktemp)"
    hooks_snapshot "$base" "$hooks"
    new="$(make_snapshot "$old" "$up")" || die "could not create the snapshot commit"
    upstream_report "$old" "$new" "$hooks"
    rm -f "$hooks"
    if git merge-tree --write-tree -X ignore-space-change "$base" "$new" > /dev/null 2>&1; then
        echo "trial merge: no conflicts"
    else
        echo "trial merge: CONFLICTS in:"
        git merge-tree --write-tree --name-only -X ignore-space-change "$base" "$new" 2> /dev/null | sed -n '2,/^$/p' | sed '/^$/d; s/^/  /'
    fi
    exit 0
}

start() {
    [ "$(git rev-parse --abbrev-ref HEAD)" = "$BASE_BRANCH" ] || die "switch to $BASE_BRANCH first (an update always starts from it)"
    [ -e "$GIT_DIR/MERGE_HEAD" ] && die "a merge is in progress: finish it (or run --finish)"
    git diff --cached --quiet || die "staged changes found, commit or unstage them first"
    local dirty
    dirty="$(git status --porcelain --untracked-files=no --ignore-submodules=all)"
    [ -z "$dirty" ] || die "uncommitted changes, commit or stash them first:
$dirty"
    echo "fetching upstream..."
    git fetch --no-recurse-submodules upstream master >> "$LOG" 2>&1 || die "git fetch upstream failed, see $LOG"
    git update-ref "refs/remotes/$UPSTREAM_REF" FETCH_HEAD
    local old up new
    old="$(last_snapshot HEAD)"
    [ -n "$old" ] || die "no snapshot commit (Upstream-Commit: trailer) in $BASE_BRANCH's history"
    up="$(git rev-parse "$UPSTREAM_REF")"
    if [ "$(git rev-parse "$up^{tree}")" = "$(git rev-parse "$old^{tree}")" ]; then
        echo "already up to date with $UPSTREAM_REF ($(git rev-parse --short "$up"))"
        exit 0
    fi
    mkdir -p "$STATE"
    hooks_snapshot HEAD "$STATE/hooks-before.txt"
    new="$(make_snapshot "$old" "$up")" || die "could not create the snapshot commit"
    upstream_report "$old" "$new" "$STATE/hooks-before.txt"
    local branch n
    branch="feature/upstream-$(date +%Y-%m-%d)"
    n=2
    while git show-ref --verify --quiet "refs/heads/$branch"; do
        branch="feature/upstream-$(date +%Y-%m-%d)-$n"
        n=$((n + 1))
    done
    git switch -c "$branch" >> "$LOG" 2>&1 || die "could not create $branch, see $LOG"
    printf '%s\n' "$branch" > "$STATE/branch"
    printf '%s\n' "$old" > "$STATE/old-snapshot"
    printf '%s\n' "$new" > "$STATE/new-snapshot"
    local subject
    subject="merged telegram $(git rev-parse --short "$up") keeping our hooks"
    echo "merging the snapshot into $branch..."
    if [ -n "${NOVAGRAM_TRAILER:-}" ]; then
        git -c submodule.recurse=false merge --no-ff -X ignore-space-change -m "$subject" -m "$NOVAGRAM_TRAILER" "$new" >> "$LOG" 2>&1
    else
        git -c submodule.recurse=false merge --no-ff -X ignore-space-change -m "$subject" "$new" >> "$LOG" 2>&1
    fi
    if [ -e "$GIT_DIR/MERGE_HEAD" ]; then
        echo "merge CONFLICTS (our side of each file has this many // Novagram lines, listed in HOOKS.md):"
        local f
        for f in $(git diff --name-only --diff-filter=U); do
            echo "  $f ($(git show ":2:$f" 2> /dev/null | grep -c '// Novagram'))"
        done
        echo "resolve them (keep every hook, HOOKS.md says what each one does), git add, git commit, then run: $0 --finish"
        exit 2
    fi
    echo "merged: $(git log -1 --format='%h %s')"
    finish
}

case "$MODE" in
    start) start ;;
    --check) check ;;
    --finish) finish ;;
    *)
        echo "usage: $0 [--check|--finish]" >&2
        exit 2
        ;;
esac
