#!/bin/bash
# Keeps the Bazel disk cache under a hard size cap by deleting its least recently used entries.
#
# Bazel's own limit (--experimental_disk_cache_gc_max_size) is applied only while the Bazel server is idle, so on a
# day of back-to-back builds the cache grew to 61GB against a 35GB limit and filled the disk (2026-10-31).
# Bazel refreshes an entry's mtime when it uses it, so the oldest mtimes are the least recently used entries and the
# next build stays fast. When the disk has less than LOW_DISK_GB free, the cap drops to LOW_DISK_CAP_GB.
#
# Usage: trim-bazel-disk-cache.sh [cap in GB, default 30]
set -u

CACHE="$HOME/telegram-bazel-cache/disk"
CAP_GB="${1:-30}"
LOW_DISK_GB=25
LOW_DISK_CAP_GB=15

[ -d "$CACHE" ] || exit 0

AVAIL_GB=$(df -g "$HOME" | awk 'NR==2 {print $4}')
if [ "${AVAIL_GB:-999}" -lt "$LOW_DISK_GB" ] 2>/dev/null; then
    CAP_GB="$LOW_DISK_CAP_GB"
fi

CACHE_KB=$(du -sk "$CACHE" 2>/dev/null | cut -f1)
CAP_KB=$((CAP_GB * 1024 * 1024))
if [ "${CACHE_KB:-0}" -le "$CAP_KB" ]; then
    exit 0
fi

TO_FREE_BYTES=$(( (CACHE_KB - CAP_KB) * 1024 ))
echo "Bazel disk cache is $((CACHE_KB / 1024 / 1024))GB, over the ${CAP_GB}GB cap: removing the least recently used entries..."
# Entry names are content hashes (no spaces or newlines), so one path per line is safe.
find "$CACHE" -type f -print0 \
    | xargs -0 stat -f '%m %z %N' \
    | sort -n \
    | awk -v need="$TO_FREE_BYTES" '{ if (freed < need) { freed += $2; sub(/^[0-9]+ [0-9]+ /, ""); print } }' \
    | tr '\n' '\0' \
    | xargs -0 rm -f
echo "Bazel disk cache is now $(du -sh "$CACHE" 2>/dev/null | cut -f1)"
