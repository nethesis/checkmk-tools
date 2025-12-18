#!/usr/bin/env bash

set -euo pipefail

# proxmox_vm_disks.sh - Proxmox VM disk monitoring

echo "<<<local>>>"

vms=$(pvesh get /cluster/resources --type vm --output-format json 2>/dev/null | jq -c '.[] | select(.type=="qemu")' || true)

while IFS= read -r vm; do
  [[ -z "$vm" ]] && continue

  vmid=$(echo "$vm" | jq -r '.vmid')
  name=$(echo "$vm" | jq -r '.name')

  # Get disk info
  disks=$(pvesh get "/nodes/$(hostname)/qemu/${vmid}/config" --output-format json 2>/dev/null | jq -r '. | to_entries[] | select(.key|test("ide|scsi|sata|virtio")) | "\(.key)=\(.value)"' || true)

  while IFS= read -r d; do
    [[ -z "$d" ]] && continue

    dev=$(echo "$d" | cut -d= -f1)
    size=$(echo "$d" | cut -d= -f2 | sed 's/,.*//')
    [[ -z "$size" ]] && size="unknownG"

    # Storage usage (placeholder: 0%)
    used=0
    echo "0 vm_${vmid}_${name} Disk disk_used=${used}%;80;90 disk_alloc=${size} - VM ${vmid} (${name}) disk ${size}"
  done <<< "$disks"
done <<< "$vms"

exit 0
