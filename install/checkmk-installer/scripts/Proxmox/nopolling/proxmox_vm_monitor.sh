#!/usr/bin/env bash

set -euo pipefail

# proxmox_vm_monitor.sh - Monitor Proxmox VM: Status, RAM, Disk (LVM-thin)

WARN_RAM=80
CRIT_RAM=90
WARN_DISK=80
CRIT_DISK=90

NODE=$(hostname)

qm list | awk 'NR>1 {print $1, $2}' | while read -r vmid name; do

  # STATUS VM
  status=$(qm status "$vmid" 2>/dev/null | awk '{print $2}' || echo "unknown")
  if [[ "$status" == "running" ]]; then
    echo "0 vm_${vmid}_${name} Status VM ${vmid} (${name}) running"
  else
    echo "0 vm_${vmid}_${name} Status VM ${vmid} (${name}) stopped"
  fi

  # RAM
  config=$(pvesh get "/nodes/$NODE/qemu/$vmid/config" --output-format json 2>/dev/null || echo '{}')
  alloc=$(echo "$config" | jq -r '.memory // empty' 2>/dev/null || echo "")

  if [[ -n "$alloc" && "$alloc" != "null" ]]; then
    alloc_bytes=$((alloc * 1024 * 1024))

    if [[ "$status" == "running" ]]; then
      current=$(pvesh get "/nodes/$NODE/qemu/$vmid/status/current" --output-format json 2>/dev/null || echo '{}')
      used=$(echo "$current" | jq -r '.mem // 0' 2>/dev/null || echo 0)
      perc=$((used * 100 / alloc_bytes))
      used_h=$(awk "BEGIN {printf \"%.1f\", $used / 1024 / 1024 / 1024}")
      alloc_h=$(awk "BEGIN {printf \"%.1f\", $alloc_bytes / 1024 / 1024 / 1024}")

      if ((perc >= CRIT_RAM)); then
        state=2
      elif ((perc >= WARN_RAM)); then
        state=1
      else
        state=0
      fi

      echo "$state vm_${vmid}_${name} RAM | used=$used;$WARN_RAM;$CRIT_RAM;0;$alloc_bytes RAM: ${perc}% (${used_h} GB / ${alloc_h} GB)"
    else
      alloc_h=$(awk "BEGIN {printf \"%.1f\", $alloc_bytes / 1024 / 1024 / 1024}")
      echo "0 vm_${vmid}_${name} RAM RAM: 0% (VM stopped, ${alloc_h} GB allocated)"
    fi
  else
    echo "0 vm_${vmid}_${name} RAM RAM: not configured (VM stopped)"
  fi

  # DISKS (LVM-thin only, ignore snapshots)
  disks=$(lvs --noheadings -o lv_name,lv_size,data_percent --units g --nosuffix 2>/dev/null | grep "vm-${vmid}-disk-" | grep -v "snap_" || true)

  if [[ -n "$disks" ]]; then
    while read -r lv size pct; do
      # Skip empty values
      if [[ -z "$size" || -z "$pct" || "$pct" == "-" ]]; then
        continue
      fi

      size_gb=$(awk "BEGIN {printf \"%.1f\", $size}")
      pct_int=$(awk "BEGIN {printf \"%d\", $pct}")
      used_gb=$(awk "BEGIN {printf \"%.1f\", $size * $pct / 100}")

      if ((pct_int >= CRIT_DISK)); then
        state=2
      elif ((pct_int >= WARN_DISK)); then
        state=1
      else
        state=0
      fi

      used_bytes=$(awk "BEGIN {printf \"%d\", $used_gb * 1024 * 1024 * 1024}")
      size_bytes=$(awk "BEGIN {printf \"%d\", $size_gb * 1024 * 1024 * 1024}")
      echo "$state vm_${vmid}_${name} Disk | used=$used_bytes;$WARN_DISK;$CRIT_DISK;0;$size_bytes Disk: ${lv} ${pct_int}% (${used_gb} GB / ${size_gb} GB)"
    done <<< "$disks"
  else
    echo "0 vm_${vmid}_${name} Disk Disk: no LVM-thin disks found"
  fi

done

exit 0
