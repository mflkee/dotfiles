#!/usr/bin/env bash
set -euo pipefail

# RAM percent used (MemTotal - MemAvailable)
read -r MEM_TOTAL_KB MEM_AVAIL_KB < <(awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END {print t, a}' /proc/meminfo)
if [[ -z "${MEM_TOTAL_KB:-}" || -z "${MEM_AVAIL_KB:-}" ]]; then
  MEM_PCT=0
else
  MEM_PCT=$(( ( (MEM_TOTAL_KB - MEM_AVAIL_KB) * 100 ) / MEM_TOTAL_KB ))
fi

# CPU percent over ~0.5s using /proc/stat deltas
read -r u1 n1 s1 i1 w1 irq1 sirq1 st1 g1 gn1 < <(awk '/^cpu /{for(i=2;i<=NF;i++) printf "%s ", $i; print ""}' /proc/stat)
TOTAL1=0; for v in $u1 $n1 $s1 $i1 $w1 $irq1 $sirq1 $st1 $g1 $gn1; do (( TOTAL1 += v )); done
IDLE1=$i1
sleep 0.5
read -r u2 n2 s2 i2 w2 irq2 sirq2 st2 g2 gn2 < <(awk '/^cpu /{for(i=2;i<=NF;i++) printf "%s ", $i; print ""}' /proc/stat)
TOTAL2=0; for v in $u2 $n2 $s2 $i2 $w2 $irq2 $sirq2 $st2 $g2 $gn2; do (( TOTAL2 += v )); done
IDLE2=$i2
DT=$(( TOTAL2 - TOTAL1 ))
DI=$(( IDLE2 - IDLE1 ))
if (( DT > 0 )); then
  CPU_PCT=$(( (100 * (DT - DI)) / DT ))
else
  CPU_PCT=0
fi

# Free disk space on root mount
DISK_AVAIL=$(df -h -x tmpfs -x devtmpfs --output=avail / | tail -n +2 | tr -d ' ')

# CPU temperature (search hwmon labels; prefer Package id 0/Tctl/Tdie)
get_cpu_temp_c() {
  local cand labelpath inputpath idx tempm
  cand=$(grep -H -E 'Package id 0|Tctl|Tdie' /sys/class/hwmon/hwmon*/temp*_label 2>/dev/null | head -n1 | cut -d: -f1 || true)
  if [[ -n "$cand" ]]; then
    labelpath="$cand"
    idx=${labelpath##*temp}
    idx=${idx%_label}
    inputpath=${labelpath%_label}_input
  else
    # Fallbacks
    for p in /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input \
             /sys/devices/platform/k10temp.0/hwmon/hwmon*/temp1_input \
             /sys/class/hwmon/hwmon*/temp1_input; do
      if [[ -r "$p" ]]; then inputpath="$p"; break; fi
    done
  fi
  if [[ -r "${inputpath:-}" ]]; then
    tempm=$(cat "$inputpath" 2>/dev/null || echo 0)
    echo $(( tempm / 1000 ))
  else
    echo 0
  fi
}

CPU_TEMP_C=$(get_cpu_temp_c)

# Compose text: MEM% / CPU% / TEMP°C / Free
TEXT="${MEM_PCT}% / ${CPU_PCT}% / ${CPU_TEMP_C}°C / ${DISK_AVAIL}"

# Severity class for CSS
CLASS="normal"
if (( MEM_PCT >= 90 || CPU_PCT >= 90 || CPU_TEMP_C >= 85 )); then
  CLASS="critical"
elif (( MEM_PCT >= 75 || CPU_PCT >= 75 || CPU_TEMP_C >= 75 )); then
  CLASS="warning"
fi

printf '{"text":"%s","class":"%s"}\n' "$TEXT" "$CLASS"
