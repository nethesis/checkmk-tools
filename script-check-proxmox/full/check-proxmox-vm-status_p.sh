#!/usr/bin/env bash
# Proxmox VM Status Check - pvesh version
# Monitora stato e uptime VM e container usando pvesh API

set -euo pipefail

PVE_TIMEOUT=30
NODE="$(hostname -s)"

if ! command -v pvesh >/dev/null 2>&1; then
  echo "3 PVE_Status - pvesh not found"
  exit 0
fi

# Helper functions for JSON parsing
get_json_field() {
  local json="$1"
  local field="$2"
  local default="${3:-}"
  echo "$json" | grep -oP "\"${field}\"\s*:\s*\K[^,}\"]+" | head -1 || echo "$default"
}

get_json_string() {
  local json="$1"
  local field="$2"
  local default="${3:-}"
  echo "$json" | grep -oP "\"${field}\"\s*:\s*\"\K[^\"]*" | head -1 || echo "$default"
}

format_uptime() {
  local seconds="$1"
  local days=$((seconds / 86400))
  local hours=$(( (seconds % 86400) / 3600 ))
  local mins=$(( (seconds % 3600) / 60 ))
  local secs=$((seconds % 60))
  
  if [[ $days -gt 0 ]]; then
    echo "${days}d ${hours}h ${mins}m ${secs}s"
  elif [[ $hours -gt 0 ]]; then
    echo "${hours}h ${mins}m ${secs}s"
  elif [[ $mins -gt 0 ]]; then
    echo "${mins}m ${secs}s"
  else
    echo "${secs}s"
  fi
}

# --- QEMU VMs ---
qemu_list=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/qemu" --output-format json 2>/dev/null || echo '[]')
qemu_ids=$(echo "$qemu_list" | grep -oP '"vmid"\s*:\s*\K[0-9]+' || true)

if [[ -n "$qemu_ids" ]]; then
  while read -r vmid; do
    [[ -z "$vmid" ]] && continue
    
    st=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/qemu/${vmid}/status/current" --output-format json 2>/dev/null || true)
    [[ -z "$st" ]] && continue
    
    name=$(get_json_string "$st" "name" "vm${vmid}")
    status=$(get_json_string "$st" "status" "unknown")
    uptime=$(get_json_field "$st" "uptime" "0")
    
    name_upper=$(echo "$name" | tr '[:lower:]' '[:upper:]')
    
    if [[ "$status" == "running" ]]; then
      uptime_fmt=$(format_uptime "$uptime")
      echo "0 STATUS_VM_${vmid}_${name_upper} - Running (Uptime: ${uptime_fmt})"
    else
      echo "2 STATUS_VM_${vmid}_${name_upper} - ${status}"
    fi
  done <<< "$qemu_ids"
fi

# --- LXC Containers ---
lxc_list=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/lxc" --output-format json 2>/dev/null || echo '[]')
lxc_ids=$(echo "$lxc_list" | grep -oP '"vmid"\s*:\s*\K[0-9]+' || true)

if [[ -n "$lxc_ids" ]]; then
  while read -r ctid; do
    [[ -z "$ctid" ]] && continue
    
    st=$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/lxc/${ctid}/status/current" --output-format json 2>/dev/null || true)
    [[ -z "$st" ]] && continue
    
    name=$(get_json_string "$st" "name" "ct${ctid}")
    status=$(get_json_string "$st" "status" "unknown")
    uptime=$(get_json_field "$st" "uptime" "0")
    
    name_upper=$(echo "$name" | tr '[:lower:]' '[:upper:]')
    
    if [[ "$status" == "running" ]]; then
      uptime_fmt=$(format_uptime "$uptime")
      echo "0 STATUS_CT_${ctid}_${name_upper} - Running (Uptime: ${uptime_fmt})"
    else
      echo "2 STATUS_CT_${ctid}_${name_upper} - ${status}"
    fi
  done <<< "$lxc_ids"
fi

exit 0
