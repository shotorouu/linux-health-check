#!/usr/bin/env bash
# Ubuntu health check: CPU, memory, and disk free capacity.
# Healthy when free/available capacity is ABOVE 60% for every metric.

set -euo pipefail

THRESHOLD=60
EXPLAIN=0
HOSTNAME="$(hostname)"
TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

usage() {
  cat <<'EOF'
Usage: ./health.sh [explain]

Checks CPU idle, memory available, and root disk free on Ubuntu.
A metric is healthy when its free/available capacity is above 60%.
Overall status is healthy only when all metrics are healthy.

  explain   Print why the machine is healthy or unhealthy
EOF
}

for arg in "$@"; do
  case "$arg" in
    explain) EXPLAIN=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# --- CPU: idle % from /proc/stat (two samples) ---
read_cpu() {
  # fields: user nice system idle iowait irq softirq steal
  awk '/^cpu / {print $2,$3,$4,$5,$6,$7,$8,$9; exit}' /proc/stat
}

cpu_idle_pct() {
  local a1 a2 b1 b2 c1 c2 d1 d2 e1 e2 f1 f2 g1 g2 h1 h2
  read -r a1 b1 c1 d1 e1 f1 g1 h1 < <(read_cpu)
  sleep 1
  read -r a2 b2 c2 d2 e2 f2 g2 h2 < <(read_cpu)

  local idle1=$((d1 + e1))
  local idle2=$((d2 + e2))
  local total1=$((a1 + b1 + c1 + d1 + e1 + f1 + g1 + h1))
  local total2=$((a2 + b2 + c2 + d2 + e2 + f2 + g2 + h2))
  local didle=$((idle2 - idle1))
  local dtotal=$((total2 - total1))

  if (( dtotal <= 0 )); then
    echo "0"
    return
  fi
  awk -v idle="$didle" -v total="$dtotal" 'BEGIN { printf "%.1f", (idle * 100) / total }'
}

# --- Memory: available % (MemAvailable / MemTotal) ---
mem_available_pct() {
  awk '
    /^MemTotal:/     { total = $2 }
    /^MemAvailable:/ { avail = $2 }
    END {
      if (total <= 0) { print "0"; exit }
      printf "%.1f", (avail * 100) / total
    }
  ' /proc/meminfo
}

# --- Disk: free % on root filesystem ---
disk_free_pct() {
  df -P -B1 / | awk 'NR==2 {
    total = $2
    avail = $4
    if (total <= 0) { print "0"; exit }
    printf "%.1f", (avail * 100) / total
  }'
}

metric_status() {
  local value="$1"
  awk -v v="$value" -v t="$THRESHOLD" 'BEGIN { exit !(v > t) }' && echo "healthy" || echo "unhealthy"
}

CPU_FREE="$(cpu_idle_pct)"
MEM_FREE="$(mem_available_pct)"
DISK_FREE="$(disk_free_pct)"

CPU_STATUS="$(metric_status "$CPU_FREE")"
MEM_STATUS="$(metric_status "$MEM_FREE")"
DISK_STATUS="$(metric_status "$DISK_FREE")"

OVERALL="healthy"
if [[ "$CPU_STATUS" == "unhealthy" || "$MEM_STATUS" == "unhealthy" || "$DISK_STATUS" == "unhealthy" ]]; then
  OVERALL="unhealthy"
fi

CPU_USED="$(awk -v f="$CPU_FREE" 'BEGIN { printf "%.1f", 100 - f }')"
MEM_USED="$(awk -v f="$MEM_FREE" 'BEGIN { printf "%.1f", 100 - f }')"
DISK_USED="$(awk -v f="$DISK_FREE" 'BEGIN { printf "%.1f", 100 - f }')"

echo "Host:      $HOSTNAME"
echo "Time:      $TIMESTAMP"
echo "Threshold: free/available > ${THRESHOLD}%"
echo
echo "CPU:  free ${CPU_FREE}% (used ${CPU_USED}%)  [$CPU_STATUS]"
echo "MEM:  free ${MEM_FREE}% (used ${MEM_USED}%)  [$MEM_STATUS]"
echo "DISK: free ${DISK_FREE}% (used ${DISK_USED}%)  [$DISK_STATUS]"
echo
echo "Overall: $OVERALL"

if (( EXPLAIN )); then
  echo
  echo "Explanation:"
  if [[ "$CPU_STATUS" == "healthy" ]]; then
    echo "  - CPU is healthy because idle capacity is ${CPU_FREE}% (above ${THRESHOLD}%)."
  else
    echo "  - CPU is unhealthy because idle capacity is ${CPU_FREE}% (not above ${THRESHOLD}%). Usage is ${CPU_USED}%."
  fi
  if [[ "$MEM_STATUS" == "healthy" ]]; then
    echo "  - Memory is healthy because available capacity is ${MEM_FREE}% (above ${THRESHOLD}%)."
  else
    echo "  - Memory is unhealthy because available capacity is ${MEM_FREE}% (not above ${THRESHOLD}%). Usage is ${MEM_USED}%."
  fi
  if [[ "$DISK_STATUS" == "healthy" ]]; then
    echo "  - Disk is healthy because free space on / is ${DISK_FREE}% (above ${THRESHOLD}%)."
  else
    echo "  - Disk is unhealthy because free space on / is ${DISK_FREE}% (not above ${THRESHOLD}%). Usage is ${DISK_USED}%."
  fi
  if [[ "$OVERALL" == "healthy" ]]; then
    echo "  - Overall healthy: every metric has free/available capacity above ${THRESHOLD}%."
  else
    echo "  - Overall unhealthy: at least one metric is at or below ${THRESHOLD}% free/available."
  fi
fi

[[ "$OVERALL" == "healthy" ]]
