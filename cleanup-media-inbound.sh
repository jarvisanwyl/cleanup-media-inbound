#!/usr/bin/env bash
# cleanup-media-inbound
#
# Safely delete media files older than X days.
# Supports dry-run, locking, robust filenames, and summary output.

set -euo pipefail

#######################################
# Defaults
#######################################
DRY_RUN=false
DAYS=2
MEDIA_INBOX="${OPENCLAW_MEDIA_INBOX:-/home/janwyl/.openclaw/media/inbound}"
LOCK_FILE="/tmp/cleanup-media-inbound.lock"

MATCHED=0
DELETED=0
FAILED=0

#######################################
# Usage
#######################################
usage() {
cat <<EOF
Usage:
  cleanup-media-inbound [options]

Options:
  --dry-run         Show what would be deleted
  --days N          Delete files older than N days (default: 2)
  --folder PATH     Folder to clean
  --help            Show help

Examples:
  cleanup-media-inbound --dry-run
  cleanup-media-inbound --days 7
  cleanup-media-inbound --folder /tmp/uploads
EOF
exit 2
}

#######################################
# Logging
#######################################
log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

#######################################
# Parse arguments
#######################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --days)
      [[ $# -ge 2 ]] || { echo "Missing value for --days" >&2; exit 2; }
      DAYS="$2"
      shift 2
      ;;
    --folder)
      [[ $# -ge 2 ]] || { echo "Missing value for --folder" >&2; exit 2; }
      MEDIA_INBOX="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      ;;
  esac
done

#######################################
# Validation
#######################################
[[ "$DAYS" =~ ^[0-9]+$ ]] || {
  echo "--days must be a non-negative integer" >&2
  exit 2
}

[[ -d "$MEDIA_INBOX" ]] || {
  echo "Folder not found: $MEDIA_INBOX" >&2
  exit 1
}

#######################################
# Prevent concurrent runs
#######################################
exec 9>"$LOCK_FILE"

if ! flock -n 9; then
  echo "Another cleanup process is already running." >&2
  exit 1
fi

#######################################
# Start
#######################################
if [[ "$DRY_RUN" == true ]]; then
  echo "=== DRY RUN MODE ==="
  echo "Would delete files older than $DAYS day(s) from: $MEDIA_INBOX"
  echo
fi

echo "Scanning: $MEDIA_INBOX"

#######################################
# Process files
#######################################
while IFS= read -r -d '' file; do
  ((++MATCHED))

  if [[ "$DRY_RUN" == true ]]; then
    echo "Would delete: $file"
    continue
  fi

  if rm -- "$file"; then
    echo "Deleted: $file"
    ((++DELETED))
  else
    echo "FAILED: $file"
    ((++FAILED))
  fi

done < <(
  find "$MEDIA_INBOX" -type f \
    \( \
      -iname "*.ogg"  -o \
      -iname "*.mp3"  -o \
      -iname "*.wav"  -o \
      -iname "*.mp4"  -o \
      -iname "*.mov"  -o \
      -iname "*.png"  -o \
      -iname "*.jpg"  -o \
      -iname "*.jpeg" -o \
      -iname "*.pdf" \
    \) \
    -mtime +"$DAYS" \
    -print0
)

#######################################
# Summary
#######################################
echo
echo "=== SUMMARY ==="

if [[ "$DRY_RUN" == true ]]; then
  echo "Would delete: $MATCHED file(s)"
else
  echo "Matched : $MATCHED file(s)"
  echo "Deleted : $DELETED file(s)"
  echo "Failed  : $FAILED file(s)"
fi

echo "Folder: $MEDIA_INBOX"
echo "Done."
