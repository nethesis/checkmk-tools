#!/bin/bash
# Check Proxmox VM Snapshot Status
# Monitora snapshot di VM e container LXC

set -euo pipefail

PVE_TIMEOUT=15

# Funzione per convertire in Title Case
to_title_case() {
    echo "$1" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1'
}

# Check VM snapshots
check_vm_snapshots() {
    timeout "${PVE_TIMEOUT}" qm list 2>/dev/null | awk 'NR>1 {print $1, $2}' | while IFS=' ' read -r vmid name; do
        output=$(timeout "${PVE_TIMEOUT}" qm listsnapshot "$vmid" 2>/dev/null || true)
        
        if [[ -z "$output" ]]; then
            continue
        fi
        
        snapshot_list=$(echo "$output" | awk 'NR>1 {for(i=1;i<=NF;i++) if ($i !~ /^[-`>|]/) {print $i; break}}')
        snapshot_count=$(echo "$snapshot_list" | grep -c . || echo 0)
        running_snapshot=$(echo "$output" | grep -iE "state.*(prepare|running)" || true)
        
        vm_name_upper="SNAPSHOT_VM_${vmid}_$(echo "$name" | tr '[:lower:]' '[:upper:]')"
        details=$(echo "$snapshot_list" | tr '\n' ',' | sed 's/,$//')
        
        if [[ -n "$running_snapshot" ]]; then
            echo "1 $vm_name_upper - Snapshot In Corso: $(to_title_case "$details")"
        elif [[ "$snapshot_count" -eq 0 ]]; then
            echo "2 $vm_name_upper - Nessuno Snapshot Presente"
        else
            echo "0 $vm_name_upper - $snapshot_count Snapshot: $(to_title_case "$details")"
        fi
    done
}

# Check LXC snapshots
check_lxc_snapshots() {
    timeout "${PVE_TIMEOUT}" pct list 2>/dev/null | awk 'NR>1 {print $1, $2}' | while IFS=' ' read -r ctid name; do
        output=$(timeout "${PVE_TIMEOUT}" pct listsnapshot "$ctid" 2>/dev/null || true)
        
        if [[ -z "$output" ]]; then
            continue
        fi
        
        snapshot_list=$(echo "$output" | awk 'NR>1 {for(i=1;i<=NF;i++) if ($i !~ /^[-`>|]/) {print $i; break}}')
        snapshot_count=$(echo "$snapshot_list" | grep -c . || echo 0)
        running_snapshot=$(echo "$output" | grep -iE "state.*(prepare|running)" || true)
        
        lxc_name_upper="SNAPSHOT_CT_${ctid}_$(echo "$name" | tr '[:lower:]' '[:upper:]')"
        details=$(echo "$snapshot_list" | tr '\n' ',' | sed 's/,$//')
        
        if [[ -n "$running_snapshot" ]]; then
            echo "1 $lxc_name_upper - Snapshot In Corso: $(to_title_case "$details")"
        elif [[ "$snapshot_count" -eq 0 ]]; then
            echo "2 $lxc_name_upper - Nessuno Snapshot Presente"
        else
            echo "0 $lxc_name_upper - $snapshot_count Snapshot: $(to_title_case "$details")"
        fi
    done
}

# Output CheckMK
echo "<<<local:sep(0)>>>"
check_vm_snapshots
check_lxc_snapshots
