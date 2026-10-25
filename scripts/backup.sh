#!/usr/bin/env bash

# Linux Server Health & Backup Toolkit
# Safe Timestamped Backup Module

set -o pipefail
set -u

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 2

SOURCE_DIR="$PROJECT_DIR/runtime/test-data"
BACKUP_DIR="$PROJECT_DIR/runtime/backups"

# Validate source
if [[ ! -d "$SOURCE_DIR" || -L "$SOURCE_DIR" ]]; then
    echo "ERROR: Invalid source directory: $SOURCE_DIR" >&2
    exit 2
fi

# Validate backup destination
if [[ -L "$BACKUP_DIR" ]]; then
    echo "ERROR: Backup directory cannot be a symlink" >&2
    exit 2
fi

if ! mkdir -p -- "$BACKUP_DIR"; then
    echo "ERROR: Cannot create backup directory" >&2
    exit 2
fi

# Generate unique final backup filename
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
BACKUP_FILE="$BACKUP_DIR/backup_${TIMESTAMP}_$$.tar.gz"

# Create temporary archive on the same filesystem
TEMP_FILE=$(mktemp "$BACKUP_DIR/.backup_tmp_XXXXXXXX") || {
    echo "ERROR: Cannot create temporary backup file" >&2
    exit 2
}

# Remove temporary archive when script exits
trap 'rm -f -- "$TEMP_FILE"' EXIT

echo "================================"
echo "        BACKUP MANAGER"
echo "================================"
echo "Source: $SOURCE_DIR"
echo "Destination: $BACKUP_FILE"

# Create archive in temporary location
if ! tar -czf "$TEMP_FILE" \
    -C "$(dirname "$SOURCE_DIR")" \
    "$(basename "$SOURCE_DIR")"; then
    echo "ERROR: Backup creation failed" >&2
    exit 2
fi

# Verify archive readability
if ! tar -tzf "$TEMP_FILE" >/dev/null; then
    echo "ERROR: Backup verification failed" >&2
    exit 2
fi

# Publish backup only after successful verification
# Check if final backup filename already exists
if [[ -e "$BACKUP_FILE" || -L "$BACKUP_FILE" ]]; then
    echo "ERROR: Backup filename already exists" >&2
    exit 2
fi
if ! mv -n -- "$TEMP_FILE" "$BACKUP_FILE"; then
    echo "ERROR: Cannot publish backup" >&2
    exit 2
fi

# Confirm final backup exists
if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "ERROR: Final backup not found" >&2
    exit 2
fi

echo "Backup created successfully!"
echo "Archive: $BACKUP_FILE"
echo "Status: SUCCESS"

exit 0
