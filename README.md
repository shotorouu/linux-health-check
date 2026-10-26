## About this project

This is a small sample project, built in about 5 minutes entirely by the
Cursor AI agent. It was my first time working with an AI agent, and I made it
to see how the workflow feels.

I gave the agent the requirements (check CPU, memory, and disk, and report
healthy when each has more than 60% free), and it wrote the script and this
README.


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
chmod +x ./health.sh
./health.sh
./health.sh explain
```

Exit code `0` means overall healthy; non-zero means unhealthy.

## Requirements

- Ubuntu (uses `/proc` and GNU `df`)
- `bash`, `awk`, `df`, `sleep`
