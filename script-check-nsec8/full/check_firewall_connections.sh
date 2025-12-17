#!/usr/bin/env bash

set -euo pipefail

# CheckMK local check - Firewall conntrack monitoring

echo "<<<firewall_connections>>>"

if [[ ! -f /proc/sys/net/netfilter/nf_conntrack_count ]]; then
  echo "2 Firewall_Connections - Conntrack unavailable"
  exit 0
fi

current=$(cat /proc/sys/net/netfilter/nf_conntrack_count)
max=$(cat /proc/sys/net/netfilter/nf_conntrack_max)

percent=$((current * 100 / max))

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

echo "$status Firewall_Connections connections=${current};$((max * 80 / 100));$((max * 90 / 100));0;${max} Active connections: $current/$max (${percent}%) - Status: $status_text | current=$current max=$max percent=$percent"
