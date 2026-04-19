Check this bash script for bugs. The intention is to delete audio files older than x days

#!/usr/bin/env bash
# Cleanup media inbox - delete files older than 2 days
# Usage: cleanup-media-inbound.sh [--dry-run] [--days X] [--folder /path/to/media]

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Delete media files older than specified days from the OpenClaw media inbox.

Usage:
  cleanup-media-inbound.sh [--dry-run] [--days X] [--folder /path]

Options:
  --dry-run    Show what would be deleted without removing files
  --days X     Delete files older than X days (default: 2)
  --folder     Specify custom folder (default: OpenClaw media inbox)
  --help       Show this help

Example:
  cleanup-media-inbound.sh --days 7 --dry-run

Notes:
  - Only .ogg, .mp3, .wav, .mp4, .mov, .png, .jpg, .jpeg, .pdf files are checked
  - Current user files are preserved (read/write checks)
  - Files are matched by modification time, not creation time
EOF
  exit 2
}

# Default values
DRY_RUN=false
DAYS=2
MEDIA_INBOX="${OPENCLAW_MEDIA_INBOX:-/home/janwyl/.openclaw/media/inbound}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --days)
      DAYS="$2"
      shift 2
      ;;
    --folder)
      MEDIA_INBOX="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      ;;
  esac
done

# Validate path
if [[ ! -d "$MEDIA_INBOX" ]]; then
  echo "Error: Folder not found: $MEDIA_INBOX" >&2
  exit 1
fi

# Count files before cleanup
if [[ "$DRY_RUN" = true ]]; then
  echo "=== DRY RUN MODE ==="
  echo "Would delete files older than $DAYS days from: $MEDIA_INBOX"
  echo ""
fi

# Find and display files to be deleted
COUNT=0
FILES_DELETED=0
FILES_PRESERVED=0

echo "Scanning: $MEDIA_INBOX"

# Get files older than $DAYS
while IFS= read -r file; do
  if [[ "$DRY_RUN" = true ]]; then
    ((COUNT++))
    echo "Would delete: $file"
  else
    # Check if current user has read/write permissions
    if [[ -r "$file" && -w "$file" ]]; then
      rm "$file"
      echo "Deleted: $file"
      ((FILES_DELETED++))
    else
      echo "SKIPPED (permissions): $file"
      ((FILES_PRESERVED++))
    fi
  fi
done < <(find "$MEDIA_INBOX" -type f \( -name "*.ogg" -o -name "*.mp3" -o -name "*.wav" -o -name "*.mp4" -o -name "*.mov" -o -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.pdf" \) -mtime +$DAYS 2>/dev/null || true)

# Summary
echo ""
echo "=== SUMMARY ==="
if [[ "$DRY_RUN" = true ]]; then
  echo "Would delete $COUNT file(s)"
else
  echo "Deleted: $FILES_DELETED file(s)"
  echo "Preserved: $FILES_PRESERVED file(s)"
fi
echo "Files older than $DAYS days from: $MEDIA_INBOX"
