#!/usr/bin/env bash

set -euo pipefail

# check-proxmox-vm-status.sh
# Monitor Proxmox VMs and containers

NODE=$(hostname)
TMP_QEMU=$(mktemp)
TMP_LXC=$(mktemp)

trap "rm -f '$TMP_QEMU' '$TMP_LXC'" EXIT

pvesh get "/nodes/$NODE/qemu" --output-format json >"$TMP_QEMU" 2>/dev/null || true
pvesh get "/nodes/$NODE/lxc" --output-format json >"$TMP_LXC" 2>/dev/null || true

human_time() {
  local secs=$1
  local days=$((secs / 86400))
  local hours=$(((secs % 86400) / 3600))
  local minutes=$(((secs % 3600) / 60))
  local seconds=$((secs % 60))
  local out=""

  ((days > 0)) && out+="${days}d "
  ((hours > 0)) && out+="${hours}h "
  ((minutes > 0)) && out+="${minutes}m "
  ((seconds > 0)) && out+="${seconds}s"

  [[ -z "$out" ]] && out="0s"
  echo "$out" | xargs
}

uppercase() {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

if [[ ! -s "$TMP_QEMU" && ! -s "$TMP_LXC" ]]; then
  echo "2 Proxmox_VM_Global - ERROR: cannot get VM/LXC list"
  exit 2
fi

QEMU_TOTAL=$(jq 'length' "$TMP_QEMU" 2>/dev/null || echo 0)
QEMU_RUNNING=$(jq '[.[] | select(.status=="running")] | length' "$TMP_QEMU" 2>/dev/null || echo 0)
LXC_TOTAL=$(jq 'length' "$TMP_LXC" 2>/dev/null || echo 0)
LXC_RUNNING=$(jq '[.[] | select(.status=="running")] | length' "$TMP_LXC" 2>/dev/null || echo 0)

TOTAL=$((QEMU_TOTAL + LXC_TOTAL))
RUNNING=$((QEMU_RUNNING + LXC_RUNNING))
STOPPED=$((TOTAL - RUNNING))

if ((RUNNING == 0)); then
  STATUS=2
  MSG="CRIT: no active VMs or containers"
elif ((STOPPED > 0)); then
  STATUS=1
  MSG="WARN: $RUNNING/$TOTAL active ($STOPPED stopped)"
else
  STATUS=0
  MSG="OK: all $TOTAL active"
fi

echo "$STATUS Proxmox_VM_Global total_active=$RUNNING;0;$TOTAL;0;$TOTAL total_total=$TOTAL;0;$TOTAL;0;$TOTAL - $MSG"

if ((QEMU_TOTAL > 0)); then
  jq -r '.[] | "\(.vmid) \(.name) \(.status) \(.uptime)"' "$TMP_QEMU" | while read -r id name statustxt uptime; do
    name_upper=$(uppercase "$name")
    service_name=$(uppercase "vm_${id}_${name}")
    uptime_human=$(human_time "$uptime")

    if [[ "$statustxt" == "running" ]]; then
      echo "0 ${service_name} uptime=${uptime}s;0;;0; VMID:${id} (${name_upper}) Running, Uptime ${uptime_human}"
    else
      echo "1 ${service_name} uptime=${uptime}s;0;;0; VMID:${id} (${name_upper}) Stopped, Uptime ${uptime_human}"
    fi
  done
fi

if ((LXC_TOTAL > 0)); then
  jq -r '.[] | "\(.vmid) \(.name) \(.status) \(.uptime)"' "$TMP_LXC" | while read -r id name statustxt uptime; do
    name_upper=$(uppercase "$name")
    service_name=$(uppercase "lxc_${id}_${name}")
    uptime_human=$(human_time "$uptime")

    if [[ "$statustxt" == "running" ]]; then
      echo "0 ${service_name} uptime=${uptime}s;0;;0; CTID:${id} (${name_upper}) Running, Uptime ${uptime_human}"
    else
      echo "1 ${service_name} uptime=${uptime}s;0;;0; CTID:${id} (${name_upper}) Stopped, Uptime ${uptime_human}"
    fi
  done
fi

exit 0
