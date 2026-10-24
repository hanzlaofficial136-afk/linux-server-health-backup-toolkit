
#!/usr/bin/env bash

# Linux Server Health & Backup Toolkit
# Service and TCP Port Monitoring Module

SERVICE="cron.service"
HOST="127.0.0.1"
PORT=22

# Check Linux service
check_service() {
    echo "--- SERVICE CHECK ---"

    if systemctl is-active --quiet "$SERVICE"; then
        echo "Service: $SERVICE"
        echo "Status: RUNNING"
    else
        echo "Service: $SERVICE"
        echo "Status: NOT RUNNING"
        return 1
    fi
}

# Check TCP port connectivity
check_port() {
    echo "--- TCP PORT CHECK ---"

    if timeout 3 bash -c 'echo > /dev/tcp/"$1"/"$2"' _ "$HOST" "$PORT" 2>/dev/null; then
        echo "Host: $HOST"
        echo "Port: $PORT"
        echo "Status: REACHABLE"
    else
        echo "Host: $HOST"
        echo "Port: $PORT"
        echo "Status: UNREACHABLE"
        return 1
    fi
}

# Main execution
echo "================================"
echo "    SERVICE & PORT MONITOR"
echo "================================"

FAILED=0

check_service || FAILED=1
echo ""

check_port || FAILED=1

echo ""
if (( FAILED == 0 )); then
    echo "Overall Status: HEALTHY"
else
    echo "Overall Status: ATTENTION REQUIRED"
fi

exit "$FAILED"
