#!/usr/bin/env bash
set -euo pipefail

PVE_TIMEOUT=30

if ! command -v pvesh >/dev/null 2>&1; then
  echo "3 PVE_Top_Consumers - pvesh not found"
  exit 0
fi

NODE="$(hostname -s)"
TOPN=5

# Parse JSON field without jq
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

# ---- QEMU ----
qemu_running=0
qemu_data_cpu=""
qemu_data_mem=""

qemu_json="$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/qemu" --output-format json 2>/dev/null || echo '[]')"
qemu_ids="$(echo "$qemu_json" | grep -oP '"vmid"\s*:\s*\K[0-9]+' || true)"

if [[ -n "${qemu_ids:-}" ]]; then
  while read -r vmid; do
    [[ -z "$vmid" ]] && continue
    
    st="$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/qemu/${vmid}/status/current" --output-format json 2>/dev/null || true)"
    [[ -z "${st:-}" ]] && continue
    
    status="$(get_json_string "$st" "status" "unknown")"
    [[ "$status" != "running" ]] && continue
    
    qemu_running=$((qemu_running+1))
    
    name="$(get_json_string "$st" "name" "vm${vmid}")"
    cpu="$(get_json_field "$st" "cpu" "0")"
    mem="$(get_json_field "$st" "mem" "0")"
    maxmem="$(get_json_field "$st" "maxmem" "1")"
    
    cpupct="$(awk -v c="$cpu" 'BEGIN{printf "%.0f", c*100}')"
    mempct="$(awk -v m="$mem" -v mm="$maxmem" 'BEGIN{if(mm>0) printf "%.0f", (m/mm)*100; else print 0}')"
    
    qemu_data_cpu="${qemu_data_cpu}${cpupct} ${vmid} ${name} ${mempct}"$'\n'
    qemu_data_mem="${qemu_data_mem}${mempct} ${vmid} ${name} ${cpupct}"$'\n'
  done <<< "$qemu_ids"
fi

qemu_top_cpu="$(echo "$qemu_data_cpu" | sort -rn | head -n $TOPN | awk '{printf "%s %s cpu=%s%% mem=%s%%|", $2, $3, $1, $4}')"
qemu_top_mem="$(echo "$qemu_data_mem" | sort -rn | head -n $TOPN | awk '{printf "%s %s mem=%s%% cpu=%s%%|", $2, $3, $1, $4}')"

# ---- LXC ----
lxc_running=0
lxc_data_cpu=""
lxc_data_mem=""

lxc_json="$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/lxc" --output-format json 2>/dev/null || echo '[]')"
lxc_ids="$(echo "$lxc_json" | grep -oP '"vmid"\s*:\s*\K[0-9]+' || true)"

if [[ -n "${lxc_ids:-}" ]]; then
  while read -r ctid; do
    [[ -z "$ctid" ]] && continue
    
    st="$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/lxc/${ctid}/status/current" --output-format json 2>/dev/null || true)"
    [[ -z "${st:-}" ]] && continue
    
    status="$(get_json_string "$st" "status" "unknown")"
    [[ "$status" != "running" ]] && continue
    
    lxc_running=$((lxc_running+1))
    
    name="$(get_json_string "$st" "name" "ct${ctid}")"
    cpu="$(get_json_field "$st" "cpu" "0")"
    mem="$(get_json_field "$st" "mem" "0")"
    maxmem="$(get_json_field "$st" "maxmem" "1")"
    
    cpupct="$(awk -v c="$cpu" 'BEGIN{printf "%.0f", c*100}')"
    mempct="$(awk -v m="$mem" -v mm="$maxmem" 'BEGIN{if(mm>0) printf "%.0f", (m/mm)*100; else print 0}')"
    
    lxc_data_cpu="${lxc_data_cpu}${cpupct} ${ctid} ${name} ${mempct}"$'\n'
    lxc_data_mem="${lxc_data_mem}${mempct} ${ctid} ${name} ${cpupct}"$'\n'
  done <<< "$lxc_ids"
fi

lxc_top_cpu="$(echo "$lxc_data_cpu" | sort -rn | head -n $TOPN | awk '{printf "%s %s cpu=%s%% mem=%s%%|", $2, $3, $1, $4}')"
lxc_top_mem="$(echo "$lxc_data_mem" | sort -rn | head -n $TOPN | awk '{printf "%s %s mem=%s%% cpu=%s%%|", $2, $3, $1, $4}')"

# Compose message
msg="Node ${NODE}; QEMU running=${qemu_running}; LXC running=${lxc_running}"

# Build multiline but keep within one service output (use '; ' separators)
details=""
if [[ -n "${qemu_top_cpu:-}" ]]; then
  details="${details} QEMU top CPU: $(echo "$qemu_top_cpu" | tr '\n' '|' );"
fi
if [[ -n "${qemu_top_mem:-}" ]]; then
  details="${details} QEMU top MEM: $(echo "$qemu_top_mem" | tr '\n' '|' );"
fi
if [[ -n "${lxc_top_cpu:-}" ]]; then
  details="${details} LXC top CPU: $(echo "$lxc_top_cpu" | tr '\n' '|' );"
fi
if [[ -n "${lxc_top_mem:-}" ]]; then
  details="${details} LXC top MEM: $(echo "$lxc_top_mem" | tr '\n' '|' );"
fi

# Output single local check with perfdata
echo "0 PVE_Top_Consumers - OK - ${msg} - ${details:-no running guests} | qemu_running=${qemu_running};;;; lxc_running=${lxc_running};;;;"

exit 0
