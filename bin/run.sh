#!/usr/bin/env bash

# Linux Server Health & Backup Toolkit
# Central Automation Runner

set -u
set -o pipefail

# Restrict permissions on newly created files
umask 077

die() {
    echo "ERROR: $*" >&2
    exit 2
}

# ---------- PROJECT PATHS ----------

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" ||
    die "Cannot locate project directory"

SCRIPTS_DIR="$PROJECT_DIR/scripts"
LOG_DIR="$PROJECT_DIR/runtime/logs"

# ---------- EXECUTION MODE ----------

(( $# <= 1 )) || die "Too many arguments"

MODE="${1:-checks}"

case "$MODE" in
    checks|daily) ;;
    *) die "Use checks or daily" ;;
esac

# ---------- LOGGING SETUP ----------

for DIR in "$PROJECT_DIR/runtime" "$LOG_DIR"; do
    [[ ! -L "$DIR" ]] || die "Unsafe symlink directory: $DIR"
done

mkdir -p -- "$LOG_DIR" || die "Cannot create log directory"

[[ -d "$LOG_DIR" ]] || die "Invalid log directory"

LOG_FILE="$LOG_DIR/${MODE}_$(date +%Y-%m-%d).log"
LOCK_FILE="$LOG_DIR/${MODE}.lock"

# Reject symlinks before opening files
for FILE in "$LOG_FILE" "$LOCK_FILE"; do
    [[ ! -L "$FILE" ]] || die "Unsafe symlink: $FILE"
    [[ ! -e "$FILE" || -f "$FILE" ]] ||
        die "Not a regular file: $FILE"
done

# Create log file
touch -- "$LOG_FILE" || die "Cannot create log file"

# Acquire process lock
exec 9>>"$LOCK_FILE" || die "Cannot open lock file"

if ! flock -n 9; then
    die "Another $MODE run is active"
fi

# ---------- LOGGING ----------

log_message() {
    local message="$1"

    printf '[%s] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$message" | tee -a "$LOG_FILE" || die "Log write failed"
}

# ---------- MODULE EXECUTION ----------

FAILED=0

run_module() {
    local script_name="$1"
    local exit_code

    log_message "START: $script_name"

    if bash "$SCRIPTS_DIR/$script_name" >> "$LOG_FILE" 2>&1; then
        log_message "SUCCESS: $script_name"
    else
        exit_code=$?
        log_message "FAILED: $script_name (exit $exit_code)"
        FAILED=1
    fi
}

# ---------- MAIN ----------

log_message "================================"
log_message "TOOLKIT RUN STARTED: $MODE"

case "$MODE" in
    checks)
        run_module "health.sh"
        run_module "services.sh"
        ;;
    daily)
        run_module "backup.sh"
        run_module "cleanup.sh"
        ;;
esac

if (( FAILED == 0 )); then
    log_message "OVERALL: SUCCESS"
else
    log_message "OVERALL: ATTENTION REQUIRED"
fi

log_message "TOOLKIT RUN FINISHED"

exit "$FAILED"
