#!/usr/bin/env bash
set -euo pipefail

PVE_TIMEOUT=15

echo "<<<local>>>"

if ! command -v qm >/dev/null 2>&1; then
  echo "3 PVE_QEMU - qm command not found"
  exit 0
fi

# Summary
total="$(timeout "${PVE_TIMEOUT}" qm list 2>/dev/null | awk 'NR>1{c++} END{print c+0}')"
running="$(timeout "${PVE_TIMEOUT}" qm list 2>/dev/null | awk 'NR>1 && $3=="running"{c++} END{print c+0}')"
echo "0 PVE_QEMU_Summary running=${running} total=${total} OK - ${running}/${total} running"
stopped=$(( total - running ))
echo "0 PVE_QEMU_Stopped_Count stopped=${stopped} OK - ${stopped} stopped"

# Per-VM status
timeout "${PVE_TIMEOUT}" qm list 2>/dev/null | awk 'NR>1{print $1}' | while read -r vmid; do
  name="$(timeout "${PVE_TIMEOUT}" qm config "$vmid" 2>/dev/null | awk -F': ' '/^name: /{print $2; exit}')"
  [[ -z "${name:-}" ]] && name="vm${vmid}"
  status="$(timeout "${PVE_TIMEOUT}" qm status "$vmid" 2>/dev/null | awk '{print $2}')"

  svc="PVE_QEMU_${vmid}_$(echo "$name" | tr ' /' '__' | tr -cd 'A-Za-z0-9_.:-')"

  if [[ "$status" == "running" ]]; then
    echo "0 ${svc} - OK - running"
  elif [[ "$status" == "stopped" ]]; then
    echo "0 ${svc} - OK - stopped"
  else
    echo "2 ${svc} - CRIT - status ${status:-unknown}"
  fi

done
