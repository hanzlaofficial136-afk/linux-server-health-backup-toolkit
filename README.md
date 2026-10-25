# Linux Server Health & Backup Toolkit

A Bash-based Linux server monitoring, backup, and maintenance automation toolkit.

## Overview

This project automates routine Linux server administration tasks, including system health monitoring, service and TCP port checks, timestamped backups, and controlled log cleanup.

It was developed as a hands-on Cloud & DevOps engineering project to practice Linux administration, Bash scripting, automation, Git, troubleshooting, and reliable operational workflows.

## Features

### 1. System Health Monitoring
- CPU utilization monitoring using `/proc/stat`
- RAM utilization monitoring using `free`
- Disk utilization monitoring using `df`
- System uptime reporting
- HEALTHY, WARNING, and CRITICAL classifications
- Basic input validation and error handling

### 2. Service & Port Monitoring
- Check Linux service status using `systemctl`
- Test TCP port connectivity
- Report running and unavailable services
- Return nonzero exit codes for failed checks

### 3. Timestamped Backups
- Create compressed `.tar.gz` archives
- Generate timestamped backup filenames
- Use temporary archives before final publication
- Perform basic archive readability checks
- Support manual and automated restore verification

### 4. Safe Log Cleanup
- Restrict cleanup to a toolkit-managed directory
- Default to dry-run mode
- Require `--apply` for actual deletion
- Support configurable retention periods
- Skip symbolic links and non-log files
- Validate retention arguments

### 5. Automation & Logging
- Central execution runner with `checks` and `daily` modes
- Timestamped execution logs
- Exit-code reporting
- Basic file locking to prevent overlapping runs
- Cron scheduling support

### 6. Automated Testing
- Bash syntax checking
- ShellCheck static analysis
- Automated smoke tests
- Backup restoration and file comparison
- Basic invalid-input and failure checks

## Project Structure

```text
linux-server-health-backup-toolkit/
├── bin/
│   └── run.sh
├── scripts/
│   ├── health.sh
│   ├── services.sh
│   ├── backup.sh
│   └── cleanup.sh
├── tests/
│   └── smoke_test.sh
├── config/
├── docs/
├── runtime/             # Generated locally, ignored by Git
│   ├── backups/
│   ├── logs/
│   └── test-data/
├── .gitignore
└── README.md
```

## Requirements

- Linux environment with Bash
- `systemd` for service monitoring
- Python 3 for optional local testing
- `tar`, `gzip`, `awk`, `df`, `free`, `stat`, `flock`, and standard GNU utilities
- Git
- ShellCheck (recommended for development)
- Cron for scheduled execution

Development and initial testing were performed using Ubuntu under WSL2.

## Getting Started

Clone the repository:

```bash
git clone https://github.com/hanzlaofficial136-afk/linux-server-health-backup-toolkit.git
cd linux-server-health-backup-toolkit
```

Prepare local test data:

```bash
mkdir -p runtime/test-data runtime/backups runtime/logs/managed

echo "Example application configuration" > runtime/test-data/app.conf
echo "Example database configuration" > runtime/test-data/database.conf
```

The current scripts use local demonstration paths. Review the target filesystem, monitored service, TCP port, and backup directories before running them in another environment.

## Usage

Run system health monitoring:

```bash
bash scripts/health.sh
```

Run service and port monitoring:

```bash
bash scripts/services.sh
```

Create a timestamped backup:

```bash
bash scripts/backup.sh
```

Preview cleanup without deleting files:

```bash
bash scripts/cleanup.sh
```

Preview cleanup with a custom retention period:

```bash
bash scripts/cleanup.sh --days 14
```

Delete eligible files in the restricted managed directory:

```bash
bash scripts/cleanup.sh --days 7 --apply
```

**Warning:** Review dry-run results before using `--apply`.

## Central Automation Runner

Run health and service checks:

```bash
bash bin/run.sh checks
```

Run a backup followed by cleanup dry-run:

```bash
bash bin/run.sh daily
```

Execution details are recorded in:

```text
runtime/logs/checks_YYYY-MM-DD.log
runtime/logs/daily_YYYY-MM-DD.log
```

The `checks` mode may return a nonzero exit code when the configured service or TCP port is unavailable.

## Cron Automation

Example schedule for monitoring every 15 minutes:

```cron
*/15 * * * * /bin/bash "/absolute/path/to/linux-server-health-backup-toolkit/bin/run.sh" checks
```

Replace the example path with the actual repository location.

Edit the current user's crontab:

```bash
crontab -e
```

Verify:

```bash
crontab -l
systemctl is-active cron
```

The `daily` mode is not scheduled by default. Backups consume storage, so assess free space and retention before enabling unattended backups.

**WSL2 limitation:** Scheduled execution depends on the WSL environment and Cron service remaining active. WSL should not be assumed to provide the same availability as a continuously running Linux server.

## Testing

Run automated smoke tests:

```bash
bash tests/smoke_test.sh
```

Run ShellCheck:

```bash
shellcheck scripts/*.sh bin/run.sh tests/*.sh
```

Check Bash syntax:

```bash
for file in scripts/*.sh bin/*.sh tests/*.sh; do
    bash -n "$file" || exit 1
done
```

The smoke tests cover main execution paths, basic failure handling, and backup restoration.

## Safety Considerations

- Generated backups, logs, and runtime data are excluded from Git.
- Cleanup is dry-run by default.
- Actual cleanup requires explicit `--apply`.
- Cleanup processes only top-level eligible `.log` files inside the managed directory.
- Backup archives are checked before final publication.
- Scripts use quoted paths to support directories containing spaces.
- Existing Cron jobs should be preserved when adding toolkit schedules.
- Never place credentials or production secrets in tracked files.

## Known Limitations

This project is a learning and portfolio implementation, not a complete enterprise monitoring or disaster recovery platform.

- Monitoring targets and thresholds are currently configured directly in scripts.
- TCP connectivity does not guarantee application-level health.
- CPU utilization is a sampled estimate.
- Backups are local and do not provide off-site disaster recovery.
- Backups are not automatically rotated.
- Concurrent filesystem modifications may affect backup consistency.
- Cleanup uses filesystem checks but does not eliminate every race condition.
- Smoke tests do not cover all failure scenarios.
- WSL2 availability depends on the host environment.

## Troubleshooting

**Service monitoring reports ATTENTION REQUIRED**

Verify the configured service and TCP port:

```bash
systemctl status cron
ss -lnt
```

**Backup creation fails**

Check source and destination directories, permissions, and available disk space:

```bash
df -h
```

**Cron job does not appear to run**

Check Cron and its journal:

```bash
systemctl is-active cron
sudo journalctl -u cron --no-pager -n 30
```

**Script produces unexpected behavior**

Use Bash execution tracing for diagnosis:

```bash
bash -x scripts/health.sh
```

Avoid exposing sensitive values when sharing trace output.

## Future Improvements

- External configuration file support
- Automated backup retention and off-site storage
- Application-level HTTP health checks
- Notifications for critical conditions
- More comprehensive automated failure testing
- Docker-based reproducible test environments
- CI pipeline for ShellCheck and smoke tests

## License

No license has been selected yet.

