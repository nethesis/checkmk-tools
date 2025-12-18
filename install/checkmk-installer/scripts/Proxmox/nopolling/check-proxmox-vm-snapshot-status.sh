#!/usr/bin/env bash

set -euo pipefail

# check-proxmox-vm-snapshot-status.sh
# Monitor Proxmox VM/LXC snapshots

to_title_case() {
  echo "$1" | sed 's/.*/\L&/' | sed 's/[a-z]*/\u&/g'
}

check_vm_snapshots() {
  qm list | awk 'NR>1 {print $1, $2}' | while read -r vmid name; do
    output=$(qm listsnapshot "$vmid" 2>/dev/null || true)
    snapshot_list=$(echo "$output" | awk 'NR>1 {for(i=1;i<=NF;i++) if ($i !~ /^[-`>|]/) {print $i; break}}' || true)
    snapshot_count=$(echo "$snapshot_list" | grep -c . || echo 0)
    running_snapshot=$(echo "$output" | grep -iE "state.*prepare|state.*running" || true)

    vm_name_upper="SNAPSHOT_VM_${vmid}_$(echo "$name" | tr '[:lower:]' '[:upper:]')"
    details=$(echo "$snapshot_list" | tr '\n' ',' | sed 's/,$//')

    if [[ -n "$running_snapshot" ]]; then
      echo "1 $vm_name_upper - Snapshot in progress: $(to_title_case "$details")"
    elif [[ "$snapshot_count" -eq 0 ]]; then
      echo "2 $vm_name_upper - No snapshots"
    else
      echo "0 $vm_name_upper - $snapshot_count snapshots: $(to_title_case "$details")"
    fi
  done
}

check_lxc_snapshots() {
  pct list | awk 'NR>1 {print $1, $2}' | while read -r ctid name; do
    output=$(pct listsnapshot "$ctid" 2>/dev/null || true)
    snapshot_list=$(echo "$output" | awk 'NR>1 {for(i=1;i<=NF;i++) if ($i !~ /^[-`>|]/) {print $i; break}}' || true)
    snapshot_count=$(echo "$snapshot_list" | grep -c . || echo 0)
    running_snapshot=$(echo "$output" | grep -iE "state.*prepare|state.*running" || true)

    lxc_name_upper="SNAPSHOT_CT_${ctid}_$(echo "$name" | tr '[:lower:]' '[:upper:]')"
    details=$(echo "$snapshot_list" | tr '\n' ',' | sed 's/,$//')

    if [[ -n "$running_snapshot" ]]; then
      echo "1 $lxc_name_upper - Snapshot in progress: $(to_title_case "$details")"
    elif [[ "$snapshot_count" -eq 0 ]]; then
      echo "2 $lxc_name_upper - No snapshots"
    else
      echo "0 $lxc_name_upper - $snapshot_count snapshots: $(to_title_case "$details")"
    fi
  done
}

check_vm_snapshots
check_lxc_snapshots

exit 0
