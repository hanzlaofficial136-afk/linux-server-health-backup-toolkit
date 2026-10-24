
#!/usr/bin/env bash

# Linux Server Health & Backup Toolkit
# Timestamped Backup Module

set -o pipefail

# Project root (works even if path contains spaces)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SOURCE_DIR="$PROJECT_DIR/runtime/test-data"
BACKUP_DIR="$PROJECT_DIR/runtime/backups"

# Validate source directory
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "ERROR: Source directory does not exist: $SOURCE_DIR" >&2
    exit 2
fi

# Create backup destination
if ! mkdir -p "$BACKUP_DIR"; then
    echo "ERROR: Cannot create backup directory" >&2
    exit 2
fi

# Generate timestamped filename
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
BACKUP_FILE="$BACKUP_DIR/backup_${TIMESTAMP}_$$.tar.gz"

echo "================================"
echo "        BACKUP MANAGER"
echo "================================"
echo "Source: $SOURCE_DIR"
echo "Destination: $BACKUP_FILE"

# Create compressed archive
if ! tar -czf "$BACKUP_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"; then
    echo "ERROR: Backup creation failed" >&2
    rm -f -- "$BACKUP_FILE"
    exit 2
fi

# Verify archive structure and readability
if ! tar -tzf "$BACKUP_FILE" >/dev/null; then
    echo "ERROR: Backup verification failed" >&2
    exit 2
fi

echo "Backup created successfully!"
echo "Archive: $BACKUP_FILE"
echo "Status: SUCCESS"

exit 0
