#!/usr/bin/env bash

# Linux Server Health & Backup Toolkit
# Central Automation Runner

set -u

# ---------- PROJECT PATHS ----------

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 2

SCRIPTS_DIR="$PROJECT_DIR/scripts"
LOG_DIR="$PROJECT_DIR/runtime/logs"

# ---------- EXECUTION MODE ----------

if (( $# > 1 )); then
    echo "ERROR: Too many arguments" >&2
    exit 2
fi

MODE="${1:-checks}"

case "$MODE" in
    checks|daily) ;;
    *)
        echo "ERROR: Use checks or daily" >&2
        exit 2
        ;;
esac

# ---------- LOGGING SETUP ----------

if [[ -L "$LOG_DIR" ]]; then
    echo "ERROR: Log directory cannot be a symlink" >&2
    exit 2
fi

mkdir -p -- "$LOG_DIR" || exit 2

LOG_FILE="$LOG_DIR/${MODE}_$(date +%Y-%m-%d).log"

if [[ -L "$LOG_FILE" ]]; then
    echo "ERROR: Log file cannot be a symlink" >&2
    exit 2
fi

touch -- "$LOG_FILE" || exit 2

# Prevent overlapping executions of the same mode
exec 9>"$LOG_DIR/${MODE}.lock" || exit 2

if ! flock -n 9; then
    echo "ERROR: Another $MODE run is active" >&2
    exit 2
fi

# ---------- LOG MESSAGE FUNCTION ----------

log_message() {
    local message="$1"

    printf '[%s] %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$message" | tee -a "$LOG_FILE"
}

# ---------- RUN MODULE FUNCTION ----------

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

# ---------- MAIN EXECUTION ----------

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
