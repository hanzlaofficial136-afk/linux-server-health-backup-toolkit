
# Troubleshooting Guide

## Linux Server Health & Backup Toolkit

This document explains common failures, diagnostic commands, and recommended troubleshooting steps.

## 1. Health Monitoring Reports CRITICAL Disk Usage

**Symptom:** Disk usage exceeds the configured critical threshold.

**Diagnosis:**

```bash
df -h
df -h /mnt/c
```

**Explanation:** The monitored filesystem may be nearly full even if other mounted filesystems have available storage.

**Resolution:**
- Identify the filesystem consuming storage.
- Investigate large directories and files.
- Review backup and log retention policies.
- Do not delete system files without verifying their purpose.

## 2. Service or TCP Port Is Unavailable

**Symptom:**

```text
Status: UNREACHABLE
Overall Status: ATTENTION REQUIRED
```

**Diagnosis:**

```bash
systemctl status cron
ss -lnt
```

**Explanation:** A running Linux service does not guarantee that a specific TCP port is accepting connections.

**Resolution:**
- Verify the configured service and port.
- Check whether the application is running and listening.
- Investigate network configuration if connectivity is expected.
- Avoid treating intentionally closed ports as unexpected production failures.

The toolkit's demonstration configuration checks TCP port 22, which may be closed on WSL.

## 3. Backup Creation Fails

**Diagnosis:**

```bash
df -h
ls -ld runtime/test-data runtime/backups
```

**Possible causes:**
- Missing source directory
- Insufficient storage
- Permission problems
- Archive creation errors

**Resolution:**
- Confirm source and destination paths.
- Check available storage.
- Inspect reported error messages.
- Verify the archive before relying on it.

## 4. Restore Verification Fails

**Symptom:** The smoke test reports a backup restore failure.

**Diagnosis:**
- Check archive readability using `tar -tzf`.
- Confirm archive extraction succeeds.
- Compare original and restored files using `diff -r`.

**Resolution:** Investigate incomplete archives, missing files, incorrect paths, or changed source data.

## 5. Cleanup Does Not Delete Files

**Explanation:** The cleanup script operates in dry-run mode by default.

Preview:

```bash
bash scripts/cleanup.sh
```

Apply only after reviewing deletion candidates:

```bash
bash scripts/cleanup.sh --apply
```

**Warning:** Actual deletion is irreversible without a separate backup.

The cleanup script only considers eligible top-level `.log` files inside its managed directory.

## 6. Invalid Retention Parameter

**Example:**

```bash
bash scripts/cleanup.sh --days abc
```

**Result:** The script rejects nonnumeric retention values.

Use a supported positive retention period between 1 and 365 days.

## 7. Cron Job Does Not Execute

**Diagnosis:**

```bash
systemctl is-active cron
crontab -l
sudo journalctl -u cron --no-pager -n 30
```

**Resolution:**
- Confirm the Cron service is running.
- Verify schedule syntax.
- Verify the script path and permissions.
- Review toolkit execution logs.
- Account for WSL not running continuously.

## 8. Runner Reports ATTENTION REQUIRED

Check the recent runner log:

```bash
tail -n 30 runtime/logs/checks_$(date +%Y-%m-%d).log
```

Identify which module returned a nonzero exit code and investigate its detailed output.

A failed check does not necessarily indicate that the runner itself crashed.

## 9. Git Does Not Track Runtime Files

The `.gitignore` intentionally excludes:

```text
runtime/
```

Backups, logs, and local test data should remain outside Git history.

## 10. General Debugging Workflow

1. Reproduce the problem.
2. Read the full error message.
3. Check exit codes.
4. Inspect the relevant script and logs.
5. Verify paths and permissions.
6. Test a focused fix.
7. Run ShellCheck and smoke tests.
8. Commit the verified improvement.
