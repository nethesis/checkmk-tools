#!/usr/bin/env bash

set -euo pipefail

# proxmox_vm_api.sh - Proxmox VM monitoring via API

echo "<<<local>>>"

vms=$(pvesh get /cluster/resources --type vm --output-format json 2>/dev/null | jq -c '.[] | select(.type=="qemu")' || true)

while IFS= read -r vm; do
  [[ -z "$vm" ]] && continue

  vmid=$(echo "$vm" | jq -r '.vmid')
  name=$(echo "$vm" | jq -r '.name')
  status=$(echo "$vm" | jq -r '.status')
  maxmem=$(echo "$vm" | jq -r '.maxmem')
  mem=$(echo "$vm" | jq -r '.mem')

  # Status
  if [[ "$status" == "running" ]]; then
    echo "0 vm_${vmid}_${name} Status - VM ${vmid} (${name}) running"
  else
    echo "0 vm_${vmid}_${name} Status - VM ${vmid} (${name}) stopped"
  fi

  # RAM
  if [[ "$status" == "running" && "$maxmem" -gt 0 ]]; then
    used_percent=$((mem * 100 / maxmem))
    echo "0 vm_${vmid}_${name} RAM used=${mem};;;0;${maxmem} RAM: ${used_percent}%"
  else
    conf="/etc/pve/qemu-server/${vmid}.conf"
    if [[ -f "$conf" ]]; then
      conf_mem=$(grep -i '^memory:' "$conf" | awk '{print $2}' || true)
      if [[ -n "$conf_mem" ]]; then
        maxmem_conf=$((conf_mem * 1024 * 1024))
        echo "0 vm_${vmid}_${name} RAM used=0;;;0;${maxmem_conf} RAM: 0% (VM stopped)"
      else
        echo "0 vm_${vmid}_${name} RAM - RAM not configured (VM stopped)"
      fi
    else
      echo "0 vm_${vmid}_${name} RAM - Config missing (VM stopped)"
    fi
  fi
done <<< "$vms"

exit 0
