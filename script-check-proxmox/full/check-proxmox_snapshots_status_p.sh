#!/usr/bin/env bash
# Proxmox Snapshots Status Check - pvesh version
# Monitora snapshot VM e container usando pvesh API

set -euo pipefail

PVE_TIMEOUT=30
NODE="$(hostname -s)"
WARN_DAYS=14
CRIT_DAYS=30

if ! command -v pvesh >/dev/null 2>&1; then
  echo "3 PVE_Snapshots - pvesh not found"
  exit 0
fi

now_epoch="$(date +%s)"

# Helper functions
get_json_string() {
  local json="$1"
  local field="$2"
  local default="${3:-}"
  echo "$json" | grep -oP "\"${field}\"\s*:\s*\"\K[^\"]*" | head -1 || echo "$default"
}

get_json_field() {
  local json="$1"
  local field="$2"
  local default="${3:-}"
  echo "$json" | grep -oP "\"${field}\"\s*:\s*\K[^,}\"]+" | head -1 || echo "$default"
}

sanitize() {
  echo "$1" | tr ' /' '__' | tr -cd 'A-Za-z0-9_.:-'
}

# --- QEMU snapshots ---
qemu_list=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/qemu" --output-format json 2>/dev/null || echo '[]')
qemu_ids=$(echo "$qemu_list" | grep -oP '"vmid"\s*:\s*\K[0-9]+' || true)

vm_total=0
snaps_total=0

if [[ -n "$qemu_ids" ]]; then
  while read -r vmid; do
    [[ -z "$vmid" ]] && continue
    vm_total=$((vm_total + 1))
    
    snaps=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/qemu/${vmid}/snapshot" --output-format json 2>/dev/null || echo '[]')
    snap_count=$(echo "$snaps" | grep -c '"name"' || echo 0)
    
    # Exclude 'current' pseudo-snapshot
    if echo "$snaps" | grep -q '"name"\s*:\s*"current"'; then
      snap_count=$((snap_count - 1))
    fi
    
    snaps_total=$((snaps_total + snap_count))
  done <<< "$qemu_ids"
fi

echo "0 PVE_QEMU_Snapshots_Summary vms=${vm_total} snapshots=${snaps_total} OK - ${snaps_total} snapshots across ${vm_total} VMs"

# Per-VM snapshot details
if [[ -n "$qemu_ids" ]]; then
  while read -r vmid; do
    [[ -z "$vmid" ]] && continue
    
    config=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/qemu/${vmid}/config" --output-format json 2>/dev/null || true)
    name=$(get_json_string "$config" "name" "vm${vmid}")
    svc_base="PVE_QEMU_Snapshots_${vmid}_$(sanitize "$name")"
    
    snaps=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/qemu/${vmid}/snapshot" --output-format json 2>/dev/null || echo '[]')
    snap_count=$(echo "$snaps" | grep -c '"name"' || echo 0)
    
    # Exclude 'current'
    if echo "$snaps" | grep -q '"name"\s*:\s*"current"'; then
      snap_count=$((snap_count - 1))
    fi
    
    if [[ "$snap_count" -eq 0 ]]; then
      echo "2 ${svc_base}_Count count=0 CRIT - 0 snapshots"
      continue
    elif [[ "$snap_count" -eq 1 ]]; then
      echo "1 ${svc_base}_Count count=1 WARN - 1 snapshot"
    else
      echo "0 ${svc_base}_Count count=${snap_count} OK - ${snap_count} snapshots"
    fi
    
    # Get oldest snapshot age from config file (pvesh doesn't return snaptime reliably)
    conf="/etc/pve/qemu-server/${vmid}.conf"
    if [[ -r "$conf" ]]; then
      snaptime_min="$(awk '/^snaptime: /{print $2}' "$conf" 2>/dev/null | sort -n | head -n 1 || true)"
      
      if [[ -n "${snaptime_min:-}" && "$snaptime_min" =~ ^[0-9]+$ ]]; then
        age_sec=$(( now_epoch - snaptime_min ))
        age_days=$(( age_sec / 86400 ))
        st=0
        if (( age_days >= CRIT_DAYS )); then st=2
        elif (( age_days >= WARN_DAYS )); then st=1
        fi
        echo "${st} ${svc_base}_OldestAge age_days=${age_days};${WARN_DAYS};${CRIT_DAYS} - oldest snapshot ${age_days} days"
      fi
    fi
  done <<< "$qemu_ids"
fi

# --- LXC snapshots ---
lxc_list=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/lxc" --output-format json 2>/dev/null || echo '[]')
lxc_ids=$(echo "$lxc_list" | grep -oP '"vmid"\s*:\s*\K[0-9]+' || true)

ct_total=0
snaps_total=0

if [[ -n "$lxc_ids" ]]; then
  while read -r ctid; do
    [[ -z "$ctid" ]] && continue
    ct_total=$((ct_total + 1))
    
    snaps=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/lxc/${ctid}/snapshot" --output-format json 2>/dev/null || echo '[]')
    snap_count=$(echo "$snaps" | grep -c '"name"' || echo 0)
    
    # Exclude 'current'
    if echo "$snaps" | grep -q '"name"\s*:\s*"current"'; then
      snap_count=$((snap_count - 1))
    fi
    
    snaps_total=$((snaps_total + snap_count))
  done <<< "$lxc_ids"
fi

echo "0 PVE_LXC_Snapshots_Summary cts=${ct_total} snapshots=${snaps_total} OK - ${snaps_total} snapshots across ${ct_total} CTs"

# Per-CT snapshot details
if [[ -n "$lxc_ids" ]]; then
  while read -r ctid; do
    [[ -z "$ctid" ]] && continue
    
    config=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/lxc/${ctid}/config" --output-format json 2>/dev/null || true)
    hostname=$(get_json_string "$config" "hostname" "ct${ctid}")
    svc_base="PVE_LXC_Snapshots_${ctid}_$(sanitize "$hostname")"
    
    snaps=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/lxc/${ctid}/snapshot" --output-format json 2>/dev/null || echo '[]')
    snap_count=$(echo "$snaps" | grep -c '"name"' || echo 0)
    
    # Exclude 'current'
    if echo "$snaps" | grep -q '"name"\s*:\s*"current"'; then
      snap_count=$((snap_count - 1))
    fi
    
    if [[ "$snap_count" -eq 0 ]]; then
      echo "2 ${svc_base}_Count count=0 CRIT - 0 snapshots"
    elif [[ "$snap_count" -eq 1 ]]; then
      echo "1 ${svc_base}_Count count=1 WARN - 1 snapshot"
    else
      echo "0 ${svc_base}_Count count=${snap_count} OK - ${snap_count} snapshots"
    fi
  done <<< "$lxc_ids"
fi

exit 0
