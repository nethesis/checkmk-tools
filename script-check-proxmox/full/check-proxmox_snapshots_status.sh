#!/usr/bin/env bash
set -euo pipefail

PVE_TIMEOUT=30

echo "<<<local>>>"

WARN_DAYS=14
CRIT_DAYS=30

now_epoch="$(date +%s)"

sanitize() {
  echo "$1" | tr ' /' '__' | tr -cd 'A-Za-z0-9_.:-'
}

# --- QEMU snapshots ---
if command -v qm >/dev/null 2>&1; then
  total_vm=0
  total_snaps=0

  timeout "${PVE_TIMEOUT}" qm list 2>/dev/null | awk 'NR>1{print $1}' | while read -r vmid; do
    total_vm=$((total_vm+1)) || true

    name="$(timeout "${PVE_TIMEOUT}" qm config "$vmid" 2>/dev/null | awk -F': ' '/^name: /{print $2; exit}')"
    [[ -z "${name:-}" ]] && name="vm${vmid}"
    svc_base="PVE_QEMU_Snapshots_${vmid}_$(sanitize "$name")"

    # Count snapshots (skip header). Output can be empty if none.
    snap_lines="$(timeout "${PVE_TIMEOUT}" qm listsnapshot "$vmid" 2>/dev/null | awk 'NR>1 && NF>0{print}')"
    snap_count="$(echo "$snap_lines" | grep -c . 2>/dev/null || true)"
    [[ -z "${snap_count:-}" ]] && snap_count=0
    total_snaps=$((total_snaps + snap_count)) || true

    # Try to compute oldest snapshot age if snapshot names include timestamps is not guaranteed.
    # Proxmox stores snapshot config under /etc/pve/qemu-server/<vmid>.conf with "snapshot:" sections,
    # but not all have timestamps. We do a best-effort using file mtime of snapshot config blocks is not possible.
    # Therefore: provide count always; age only if we can parse "snaptime" from config (if present).
    snaptime_min=""
    conf="/etc/pve/qemu-server/${vmid}.conf"
    if [[ -r "$conf" ]]; then
      # Some configs include lines like: snaptime: 1695732000
      snaptime_min="$(awk '/^snaptime: /{print $2}' "$conf" 2>/dev/null | sort -n | head -n 1 || true)"
    fi

    if [[ "$snap_count" -eq 0 ]]; then
      echo "0 ${svc_base}_Count count=0 OK - 0 snapshots"
      continue
    fi

    echo "0 ${svc_base}_Count count=${snap_count} OK - ${snap_count} snapshots"

    if [[ -n "${snaptime_min:-}" && "$snaptime_min" =~ ^[0-9]+$ ]]; then
      age_sec=$(( now_epoch - snaptime_min ))
      age_days=$(( age_sec / 86400 ))
      st=0
      if (( age_days >= CRIT_DAYS )); then st=2
      elif (( age_days >= WARN_DAYS )); then st=1
      fi
      echo "${st} ${svc_base}_OldestAge age_days=${age_days};${WARN_DAYS};${CRIT_DAYS} - oldest snapshot ${age_days} days"
    fi
  done

  # NOTE: totals inside while subshell won’t persist in POSIX pipelines; keep summary minimal below.
  # We'll emit a simple global summary by recounting quickly:
  vm_total="$(qm list 2>/dev/null | awk 'NR>1{c++} END{print c+0}')"
  snaps_total="$(for v in $(qm list 2>/dev/null | awk 'NR>1{print $1}'); do qm listsnapshot "$v" 2>/dev/null | awk 'NR>1 && NF>0{c++} END{print c+0}'; done | awk '{s+=$1} END{print s+0}')"
  echo "0 PVE_QEMU_Snapshots_Summary vms=${vm_total} snapshots=${snaps_total} OK - ${snaps_total} snapshots across ${vm_total} VMs"
fi

# --- LXC snapshots ---
if command -v pct >/dev/null 2>&1; then
  ct_total="$(pct list 2>/dev/null | awk 'NR>1{c++} END{print c+0}')"
  snaps_total="$(for c in $(pct list 2>/dev/null | awk 'NR>1{print $1}'); do pct listsnapshot "$c" 2>/dev/null | awk 'NR>1 && NF>0{c++} END{print c+0}'; done | awk '{s+=$1} END{print s+0}')"
  echo "0 PVE_LXC_Snapshots_Summary cts=${ct_total} snapshots=${snaps_total} OK - ${snaps_total} snapshots across ${ct_total} CTs"

  pct list 2>/dev/null | awk 'NR>1{print $1}' | while read -r ctid; do
    name="$(pct config "$ctid" 2>/dev/null | awk -F': ' '/^hostname: /{print $2; exit}')"
    [[ -z "${name:-}" ]] && name="ct${ctid}"
    svc_base="PVE_LXC_Snapshots_${ctid}_$(sanitize "$name")"

    snap_count="$(pct listsnapshot "$ctid" 2>/dev/null | awk 'NR>1 && NF>0{c++} END{print c+0}')"
    echo "0 ${svc_base}_Count count=${snap_count} OK - ${snap_count} snapshots"
  done
fi

exit 0
