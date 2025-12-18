#!/usr/bin/env bash

set -euo pipefail

# CheckMK local check - DHCP leases monitoring (dnsmasq/OpenWrt)

LEASE_FILE="/tmp/dhcp.leases"

if [[ ! -f "$LEASE_FILE" ]]; then
  echo "1 DHCP_Leases - Lease file not found"
  exit 0
fi

current_time=$(date +%s)
active_leases=0
expired_leases=0
total_leases=0

while IFS=' ' read -r expire_time _ _ _ _; do
  total_leases=$((total_leases + 1))

  if [[ "$expire_time" =~ ^[0-9]+$ ]] && (( expire_time > current_time )); then
    active_leases=$((active_leases + 1))
  else
    expired_leases=$((expired_leases + 1))
  fi
done <"$LEASE_FILE"

dhcp_limit=$(uci get dhcp.lan.limit 2>/dev/null || echo 150)
max_leases=$dhcp_limit

if (( max_leases > 0 )); then
  percent=$((active_leases * 100 / max_leases))
else
  percent=0
fi

if [[ $percent -ge 90 ]]; then
  status=2
  status_text="CRITICAL"
elif [[ $percent -ge 80 ]]; then
  status=1
  status_text="WARNING"
else
  status=0
  status_text="OK"
fi

warn=$((max_leases * 80 / 100))
crit=$((max_leases * 90 / 100))

echo "$status DHCP_Leases active=${active_leases};${warn};${crit};0;${max_leases} Active leases: $active_leases/$max_leases (${percent}%) - $status_text | active=$active_leases expired=$expired_leases total=$total_leases max=$max_leases percent=$percent"
