#!/usr/bin/env bash

# Automated smoke tests for DevOps Toolkit

set -u

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)" || exit 2

PASSED=0
FAILED=0

pass() {
    echo "PASS: $1"
    (( PASSED += 1 ))
}

fail() {
    echo "FAIL: $1"
    (( FAILED += 1 ))
}

# Temporary test workspace
TEST_DIR=$(mktemp -d) || exit 2
trap 'rm -rf -- "$TEST_DIR"' EXIT

echo "========== SMOKE TESTS =========="

# TEST 1: Bash syntax
syntax_ok=true
for file in "$PROJECT_DIR"/scripts/*.sh "$PROJECT_DIR"/bin/*.sh; do
    if ! bash -n "$file"; then
        syntax_ok=false
    fi
done

if [[ "$syntax_ok" == true ]]; then
    pass "Bash syntax"
else
    fail "Bash syntax"
fi

# TEST 2: Health monitoring
if bash "$PROJECT_DIR/scripts/health.sh" > "$TEST_DIR/health.txt" 2>&1 &&
   grep -q "Disk Usage:" "$TEST_DIR/health.txt" &&
   grep -q "RAM Usage:" "$TEST_DIR/health.txt" &&
   grep -q "CPU Usage:" "$TEST_DIR/health.txt" &&
   grep -q "Uptime:" "$TEST_DIR/health.txt"; then
    pass "System health monitoring"
else
    fail "System health monitoring"
fi

# TEST 3: Service monitoring
# Both healthy and unhealthy results are valid monitoring outcomes.
SERVICE_RC=0
bash "$PROJECT_DIR/scripts/services.sh" > "$TEST_DIR/services.txt" 2>&1 || SERVICE_RC=$?

if (( SERVICE_RC == 0 || SERVICE_RC == 1 )) &&
   grep -q "Overall Status:" "$TEST_DIR/services.txt"; then
    pass "Service and port monitoring"
else
    fail "Service and port monitoring"
fi

# TEST 4: Backup creation

# TEST 4: Backup creation and restore verification

BACKUP_PATH=""

if bash "$PROJECT_DIR/scripts/backup.sh" > "$TEST_DIR/backup.txt" 2>&1; then

    # Extract archive path reported by backup script
    BACKUP_PATH=$(sed -n 's/^Archive: //p' "$TEST_DIR/backup.txt" | tail -n 1)

    if [[ -n "$BACKUP_PATH" && -f "$BACKUP_PATH" ]] &&
       tar -tzf "$BACKUP_PATH" >/dev/null &&
       mkdir -p "$TEST_DIR/restored" &&
       tar -xzf "$BACKUP_PATH" -C "$TEST_DIR/restored" &&
       diff -r "$PROJECT_DIR/runtime/test-data" "$TEST_DIR/restored/test-data" >/dev/null; then

        pass "Backup creation and restore integrity"
    else
        fail "Backup creation and restore integrity"
    fi

else
    fail "Backup creation and restore integrity"
fi

# TEST 5: Cleanup dry-run
if bash "$PROJECT_DIR/scripts/cleanup.sh" > "$TEST_DIR/cleanup.txt" 2>&1 &&
   grep -q "Mode: DRY RUN" "$TEST_DIR/cleanup.txt" &&
   grep -q "Files deleted: 0" "$TEST_DIR/cleanup.txt"; then
    pass "Cleanup dry-run"
else
    fail "Cleanup dry-run"
fi

# TEST 6: Invalid retention
if bash "$PROJECT_DIR/scripts/cleanup.sh" --days 0 \
   > "$TEST_DIR/invalid.txt" 2>&1; then
    fail "Invalid retention rejected"
else
    pass "Invalid retention rejected"
fi

if bash "$PROJECT_DIR/scripts/cleanup.sh" --days abc \
   > "$TEST_DIR/invalid_abc.txt" 2>&1; then
    fail "Non-numeric retention rejected"
else
    pass "Non-numeric retention rejected"
fi

# TEST 7: Invalid runner mode
if bash "$PROJECT_DIR/bin/run.sh" invalid-mode \
   > "$TEST_DIR/runner.txt" 2>&1; then
    fail "Invalid runner mode rejected"
else
    pass "Invalid runner mode rejected"
fi

echo "================================="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if (( FAILED > 0 )); then
    exit 1
fi

exit 0
