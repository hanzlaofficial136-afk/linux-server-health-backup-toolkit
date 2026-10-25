#!/usr/bin/env bash

# Linux Server Health & Backup Toolkit
# Safe Log Cleanup Module

set -u

# ---------- CONFIGURATION ----------

RETENTION_DAYS=7
APPLY=false

# ---------- ERROR HANDLING ----------

die() {
    echo "ERROR: $*" >&2
    exit 2
}

# ---------- ARGUMENTS ----------

while (( $# > 0 )); do
    case "$1" in
        --apply)
            APPLY=true
            shift
            ;;
        --days)
            (( $# >= 2 )) || die "Missing value for --days"
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --help)
            echo "Usage: bash cleanup.sh [--days N] [--apply]"
            exit 0
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
done

# Validate retention: 1 to 365 days
[[ "$RETENTION_DAYS" =~ ^[1-9][0-9]*$ ]] ||
    die "Retention must be a positive integer"

(( ${#RETENTION_DAYS} <= 3 )) ||
    die "Retention must be between 1 and 365"

(( RETENTION_DAYS <= 365 )) ||
    die "Retention must be between 1 and 365"

# ---------- SAFE DIRECTORY ----------

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P) ||
    die "Cannot locate project directory"

MANAGED_DIR="$PROJECT_DIR/runtime/logs/managed"

# Refuse missing directories and symlinked directory components
for DIR in \
    "$PROJECT_DIR/runtime" \
    "$PROJECT_DIR/runtime/logs" \
    "$MANAGED_DIR"
do
    [[ -d "$DIR" && ! -L "$DIR" ]] ||
        die "Unsafe or missing directory: $DIR"
done

# Age cutoff, measured in seconds
CUTOFF=$(( $(date +%s) - RETENTION_DAYS * 86400 ))

# ---------- CLEANUP ----------

echo "================================"
echo "        SAFE LOG CLEANUP"
echo "================================"
echo "Directory: $MANAGED_DIR"
echo "Retention: $RETENTION_DAYS days"

if [[ "$APPLY" == true ]]; then
    echo "Mode: APPLY"
else
    echo "Mode: DRY RUN"
fi

echo "--------------------------------"

CANDIDATES=0
DELETED=0

# Prevent unmatched wildcards from becoming literal paths
shopt -s nullglob

for FILE in "$MANAGED_DIR"/*; do
    NAME="${FILE##*/}"

    # Never process symbolic links
    if [[ -L "$FILE" ]]; then
        printf 'SKIP (symlink): %q\n' "$NAME"
        continue
    fi

    # Only regular .log files
    if [[ ! -f "$FILE" || "$NAME" != *.log ]]; then
        printf 'SKIP: %q\n' "$NAME"
        continue
    fi

    # Read file modification time
    MTIME=$(stat -c %Y -- "$FILE") ||
        die "Cannot read file timestamp: $NAME"

    [[ "$MTIME" =~ ^[0-9]+$ ]] ||
        die "Invalid file timestamp: $NAME"

    if (( MTIME > CUTOFF )); then
        printf 'KEEP (recent): %q\n' "$NAME"
        continue
    fi

    (( CANDIDATES += 1 ))

    if [[ "$APPLY" == false ]]; then
        printf 'WOULD DELETE: %q\n' "$NAME"
    else
        # Recheck file type before removing
        [[ -f "$FILE" && ! -L "$FILE" ]] ||
            die "File changed or became unsafe: $NAME"

        if rm -- "$FILE"; then
            printf 'DELETED: %q\n' "$NAME"
            (( DELETED += 1 ))
        else
            die "Failed to delete: $NAME"
        fi
    fi
done

echo "--------------------------------"
echo "Eligible files: $CANDIDATES"
echo "Files deleted: $DELETED"

if [[ "$APPLY" == false ]]; then
    echo "Dry-run complete. No files deleted."
fi

exit 0
