# linux-health-check

Simple Ubuntu health check for CPU, memory, and root disk.

## Rule

A metric is **healthy** when its free/available capacity is **above 60%**:

| Metric | What is measured |
|--------|------------------|
| CPU    | Idle % (from `/proc/stat`) |
| MEM    | `MemAvailable` / `MemTotal` |
| DISK   | Free space on `/` |

Overall status is healthy only when all three pass.

## Usage

```bash
chmod +x ./health
./health
./health explain
```

Exit code `0` means overall healthy; non-zero means unhealthy.

## Requirements

- Ubuntu (uses `/proc` and GNU `df`)
- `bash`, `awk`, `df`, `sleep`
