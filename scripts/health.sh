#!/usr/bin/env bash

# Linux Server Health & Backup Toolkit
# System Health Monitoring Module

set -o pipefail

# ================= CONFIGURATION =================

TARGET="/mnt/c"

DISK_WARNING=80
DISK_CRITICAL=90

RAM_WARNING=80
RAM_CRITICAL=90

CPU_WARNING=80
CPU_CRITICAL=90

# ================= FUNCTIONS =================

# Extract disk utilization
check_disk() {
    local output usage

    if ! output=$(df -P "$TARGET"); then
        echo "ERROR: Unable to check disk: $TARGET" >&2
        return 2
    fi

    usage=$(awk 'NR==2 {print $5}' <<< "$output")
    usage=${usage%\%}

    if ! [[ "$usage" =~ ^[0-9]+$ ]] || (( 10#$usage > 100 )); then
        echo "ERROR: Invalid disk usage" >&2
        return 2
    fi

    echo "Disk Usage: ${usage}%"
    print_status "$usage" "$DISK_WARNING" "$DISK_CRITICAL"
}

# Calculate RAM utilization
check_ram() {
    local total available usage

    read -r total available < <(
        free -m | awk '/^Mem:/ {print $2, $7}'
    )

    if ! [[ "$total" =~ ^[0-9]+$ && "$available" =~ ^[0-9]+$ ]] || (( total == 0 )); then
        echo "ERROR: Unable to read RAM information" >&2
        return 2
    fi

    usage=$(( (total - available) * 100 / total ))

    echo "RAM Usage: ${usage}%"
    print_status "$usage" "$RAM_WARNING" "$RAM_CRITICAL"
}

# Calculate CPU usage from two snapshots
check_cpu() {
    local idle1 total1 idle2 total2
    local delta_total delta_idle usage
    local values1 values2

    values1=$(awk '/^cpu / {
        idle=$5+$6
        total=0
        for(i=2;i<=NF;i++) total+=$i
        print idle, total
    }' /proc/stat) || return 2

    sleep 1

    values2=$(awk '/^cpu / {
        idle=$5+$6
        total=0
        for(i=2;i<=NF;i++) total+=$i
        print idle, total
    }' /proc/stat) || return 2

    read -r idle1 total1 <<< "$values1"
    read -r idle2 total2 <<< "$values2"

    if ! [[ "$idle1" =~ ^[0-9]+$ && "$total1" =~ ^[0-9]+$ &&
            "$idle2" =~ ^[0-9]+$ && "$total2" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Invalid CPU information" >&2
        return 2
    fi

    delta_total=$((total2 - total1))
    delta_idle=$((idle2 - idle1))

    if (( delta_total <= 0 )); then
        echo "ERROR: Invalid CPU sampling interval" >&2
        return 2
    fi

    usage=$((100 * (delta_total - delta_idle) / delta_total))

    echo "CPU Usage: ${usage}%"
    print_status "$usage" "$CPU_WARNING" "$CPU_CRITICAL"
}

# Show system uptime
check_uptime() {
    echo "Uptime: $(uptime -p)"
}

# Determine status
print_status() {
    local usage=$1 warning=$2 critical=$3

    if (( usage >= critical )); then
        echo "Status: CRITICAL"
    elif (( usage >= warning )); then
        echo "Status: WARNING"
    else
        echo "Status: HEALTHY"
    fi
}

# ================= MAIN =================

echo "===================================="
echo "       LINUX SERVER HEALTH"
echo "===================================="
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

echo "--- DISK ---"
check_disk || exit 2

echo ""
echo "--- RAM ---"
check_ram || exit 2

echo ""
echo "--- CPU ---"
check_cpu || exit 2

echo ""
echo "--- UPTIME ---"
check_uptime || exit 2

echo ""
echo "===================================="
echo "Health check completed"
echo "===================================="

exit 0
