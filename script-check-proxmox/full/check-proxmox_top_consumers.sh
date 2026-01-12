#!/usr/bin/env bash
set -euo pipefail

PVE_TIMEOUT=15

echo "<<<local>>>"

if ! command -v pvesh >/dev/null 2>&1; then
  echo "3 PVE_Top_Consumers - pvesh not found"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "3 PVE_Top_Consumers - jq not found"
  exit 0
fi

NODE="$(hostname -s)"
TOPN=5

# Helpers
fmt_pct() { awk -v x="$1" 'BEGIN{printf "%.0f", x*100}'; }
sanitize() { echo "$1" | tr ' /' '__' | tr -cd 'A-Za-z0-9_.:-'; }

# ---- QEMU ----
qemu_json="$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/qemu" --output-format json 2>/dev/null || echo '[]')"
qemu_ids="$(echo "$qemu_json" | jq -r '.[].vmid' || true)"

qemu_running=0
qemu_rows="[]"
if [[ -n "${qemu_ids:-}" ]]; then
  while read -r vmid; do
    [[ -z "$vmid" ]] && continue
    st="$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/qemu/${vmid}/status/current" --output-format json 2>/dev/null || true)"
    [[ -z "${st:-}" ]] && continue
    status="$(echo "$st" | jq -r '.status // "unknown"')"
    [[ "$status" != "running" ]] && continue
    qemu_running=$((qemu_running+1))

    name="$(echo "$st" | jq -r '.name // ("vm"+(.vmid|tostring))' 2>/dev/null || echo "vm${vmid}")"
    cpu="$(echo "$st" | jq -r '.cpu // 0')"
    mem="$(echo "$st" | jq -r '.mem // 0')"
    maxmem="$(echo "$st" | jq -r '.maxmem // 0')"

    mempct=0
    if [[ "${maxmem}" -gt 0 ]]; then
      mempct="$(awk -v m="$mem" -v mm="$maxmem" 'BEGIN{printf "%.0f", (m/mm)*100}')"
    fi
    cpupct="$(awk -v c="$cpu" 'BEGIN{printf "%.0f", c*100}')"

    qemu_rows="$(echo "$qemu_rows" | jq --arg vmid "$vmid" --arg name "$name" --argjson cpu "$cpupct" --argjson mem "$mempct" \
      '. + [{"id":$vmid,"name":$name,"cpu_pct":$cpu,"mem_pct":$mem}]')"
  done <<< "$(echo "$qemu_ids")"
fi

qemu_top_cpu="$(echo "$qemu_rows" | jq -r --argjson n "$TOPN" 'sort_by(.cpu_pct) | reverse | .[0:$n] | map("\(.id) \(.name) cpu=\(.cpu_pct)% mem=\(.mem_pct)%") | .[]' || true)"
qemu_top_mem="$(echo "$qemu_rows" | jq -r --argjson n "$TOPN" 'sort_by(.mem_pct) | reverse | .[0:$n] | map("\(.id) \(.name) mem=\(.mem_pct)% cpu=\(.cpu_pct)%") | .[]' || true)"

# ---- LXC ----
lxc_json="$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/lxc" --output-format json 2>/dev/null || echo '[]')"
lxc_ids="$(echo "$lxc_json" | jq -r '.[].vmid' || true)"

lxc_running=0
lxc_rows="[]"
if [[ -n "${lxc_ids:-}" ]]; then
  while read -r ctid; do
    [[ -z "$ctid" ]] && continue
    st="$(timeout "${PVE_TIMEOUT}" pvesh get "/nodes/${NODE}/lxc/${ctid}/status/current" --output-format json 2>/dev/null || true)"
    [[ -z "${st:-}" ]] && continue
    status="$(echo "$st" | jq -r '.status // "unknown"')"
    [[ "$status" != "running" ]] && continue
    lxc_running=$((lxc_running+1))

    name="$(echo "$st" | jq -r '.name // ("ct"+(.vmid|tostring))' 2>/dev/null || echo "ct${ctid}")"
    cpu="$(echo "$st" | jq -r '.cpu // 0')"
    mem="$(echo "$st" | jq -r '.mem // 0')"
    maxmem="$(echo "$st" | jq -r '.maxmem // 0')"

    mempct=0
    if [[ "${maxmem}" -gt 0 ]]; then
      mempct="$(awk -v m="$mem" -v mm="$maxmem" 'BEGIN{printf "%.0f", (m/mm)*100}')"
    fi
    cpupct="$(awk -v c="$cpu" 'BEGIN{printf "%.0f", c*100}')"

    lxc_rows="$(echo "$lxc_rows" | jq --arg id "$ctid" --arg name "$name" --argjson cpu "$cpupct" --argjson mem "$mempct" \
      '. + [{"id":$id,"name":$name,"cpu_pct":$cpu,"mem_pct":$mem}]')"
  done <<< "$(echo "$lxc_ids")"
fi

lxc_top_cpu="$(echo "$lxc_rows" | jq -r --argjson n "$TOPN" 'sort_by(.cpu_pct) | reverse | .[0:$n] | map("\(.id) \(.name) cpu=\(.cpu_pct)% mem=\(.mem_pct)%") | .[]' || true)"
lxc_top_mem="$(echo "$lxc_rows" | jq -r --argjson n "$TOPN" 'sort_by(.mem_pct) | reverse | .[0:$n] | map("\(.id) \(.name) mem=\(.mem_pct)% cpu=\(.cpu_pct)%") | .[]' || true)"

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
