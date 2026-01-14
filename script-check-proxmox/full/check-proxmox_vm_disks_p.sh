#!/usr/bin/env bash
# Proxmox VM Disks Check - pvesh version
# Monitora configurazione dischi VM e container usando pvesh API

set -euo pipefail

PVE_TIMEOUT=30
NODE="$(hostname -s)"

if ! command -v pvesh >/dev/null 2>&1; then
  echo "3 PVE_Disks - pvesh not found"
  exit 0
fi

# Helper functions for JSON parsing
get_json_string() {
  local json="$1"
  local field="$2"
  local default="${3:-}"
  echo "$json" | grep -oP "\"${field}\"\s*:\s*\"\K[^\"]*" | head -1 || echo "$default"
}

# --- QEMU VMs ---
qemu_list=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/qemu" --output-format json 2>/dev/null || echo '[]')
qemu_ids=$(echo "$qemu_list" | grep -oP '"vmid"\s*:\s*\K[0-9]+' || true)

if [[ -n "$qemu_ids" ]]; then
  while read -r vmid; do
    [[ -z "$vmid" ]] && continue
    
    config=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/qemu/${vmid}/config" --output-format json 2>/dev/null || true)
    [[ -z "$config" ]] && continue
    
    name=$(get_json_string "$config" "name" "vm${vmid}")
    name_upper=$(echo "$name" | tr '[:lower:]' '[:upper:]')
    
    # Count disks (scsi, virtio, ide, sata)
    disk_count=0
    total_size=0
    
    for prefix in scsi virtio ide sata; do
      for i in {0..30}; do
        disk_line=$(echo "$config" | grep -oP "\"${prefix}${i}\"\s*:\s*\"[^\"]*\"" || true)
        [[ -z "$disk_line" ]] && continue
        
        disk_count=$((disk_count + 1))
        
        # Extract size
        size=$(echo "$disk_line" | grep -oP 'size=\K[0-9]+[GMK]' || echo "")
        if [[ -n "$size" ]]; then
          if [[ "$size" =~ ^([0-9]+)G$ ]]; then
            total_size=$((total_size + ${BASH_REMATCH[1]}))
          elif [[ "$size" =~ ^([0-9]+)M$ ]]; then
            total_size=$((total_size + ${BASH_REMATCH[1]} / 1024))
          elif [[ "$size" =~ ^([0-9]+)K$ ]]; then
            total_size=$((total_size + ${BASH_REMATCH[1]} / 1048576))
          fi
        fi
      done
    done
    
    if [[ $disk_count -gt 0 ]]; then
      echo "0 DISKS_VM_${vmid}_${name_upper} - $disk_count disks, Total: ${total_size}GB | disks=$disk_count size_gb=$total_size"
    fi
  done <<< "$qemu_ids"
fi

# --- LXC Containers ---
lxc_list=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/lxc" --output-format json 2>/dev/null || echo '[]')
lxc_ids=$(echo "$lxc_list" | grep -oP '"vmid"\s*:\s*\K[0-9]+' || true)

if [[ -n "$lxc_ids" ]]; then
  while read -r ctid; do
    [[ -z "$ctid" ]] && continue
    
    config=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/lxc/${ctid}/config" --output-format json 2>/dev/null || true)
    [[ -z "$config" ]] && continue
    
    hostname=$(get_json_string "$config" "hostname" "ct${ctid}")
    name_upper=$(echo "$hostname" | tr '[:lower:]' '[:upper:]')
    
    # Extract rootfs size
    rootfs=$(echo "$config" | grep -oP '"rootfs"\s*:\s*"[^"]*"' || true)
    size=$(echo "$rootfs" | grep -oP 'size=\K[0-9]+[GMK]' || echo "0G")
    
    size_gb=0
    if [[ "$size" =~ ^([0-9]+)G$ ]]; then
      size_gb=${BASH_REMATCH[1]}
    elif [[ "$size" =~ ^([0-9]+)M$ ]]; then
      size_gb=$((${BASH_REMATCH[1]} / 1024))
    fi
    
    echo "0 DISKS_CT_${ctid}_${name_upper} - RootFS: ${size_gb}GB | size_gb=$size_gb"
  done <<< "$lxc_ids"
fi

exit 0
