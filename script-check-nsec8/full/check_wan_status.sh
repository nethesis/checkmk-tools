#!/usr/bin/env bash

set -euo pipefail

# CheckMK local check - WAN status monitoring

get_interface_status() {
  local iface="$1"
  local status_json
  status_json=$(ubus call network.interface."$iface" status 2>/dev/null || echo "")
  if [[ -z "$status_json" ]]; then
    echo "unknown"
    return 1
  fi
  echo "$status_json" | jsonfilter -e '@.up' 2>/dev/null || echo "unknown"
}

check_connectivity() {
  local target="$1"
  local count="${2:-2}"
  ping -c "$count" -W 2 "$target" >/dev/null 2>&1
  return $?
}

get_gateway() {
  local iface="$1"
  local status_json
  status_json=$(ubus call network.interface."$iface" status 2>/dev/null || echo "")
  if [[ -z "$status_json" ]]; then
    echo ""
    return 1
  fi
  echo "$status_json" | jsonfilter -e '@.route[0].nexthop' 2>/dev/null || echo ""
}

find_wan_interfaces() {
  ubus list 2>/dev/null | grep '^network\.interface\.' | sed 's/network\.interface\.//' | grep -E '^(wan|wwan|vwan)' || true
}

echo "<<<wan_status>>>"

wan_interfaces=$(find_wan_interfaces)

if [[ -z "$wan_interfaces" ]]; then
  echo "0 WAN_Status status=ERROR No WAN interfaces found"
  exit 0
fi

overall_status=0
status_messages=()
details=()

for iface in $wan_interfaces; do
  status=$(get_interface_status "$iface")
  gateway=$(get_gateway "$iface")

  if [[ "$status" == "true" ]] || [[ "$status" == "1" ]]; then
    if [[ -n "$gateway" ]]; then
      if check_connectivity "$gateway"; then
        details+=("$iface: UP (gateway $gateway reachable)")
        status_messages+=("$iface=OK")
      else
        details+=("$iface: UP but gateway $gateway unreachable")
        status_messages+=("$iface=DEGRADED")
        overall_status=1
      fi
    else
      if check_connectivity "8.8.8.8" 2>/dev/null || check_connectivity "1.1.1.1" 2>/dev/null; then
        details+=("$iface: UP (internet reachable)")
        status_messages+=("$iface=OK")
      else
        details+=("$iface: UP but no connectivity")
        status_messages+=("$iface=DEGRADED")
        overall_status=1
      fi
    fi
  elif [[ "$status" == "false" ]] || [[ "$status" == "0" ]]; then
    details+=("$iface: DOWN")
    status_messages+=("$iface=DOWN")
    overall_status=2
  else
    details+=("$iface: UNKNOWN")
    status_messages+=("$iface=UNKNOWN")
    overall_status=1
  fi
done

if [[ $overall_status -eq 0 ]]; then
  final_status="OK"
elif [[ $overall_status -eq 1 ]]; then
  final_status="WARNING"
else
  final_status="CRITICAL"
fi

status_line="${status_messages[*]:-}"
detail_line=$(IFS=', '; echo "${details[*]:-}")

echo "$overall_status WAN_Status status=$final_status $status_line - $detail_line"

wan_count=$(echo "$wan_interfaces" | wc -l)
wan_up=$(echo "${status_messages[@]:-}" | grep -o "=OK" | wc -l || echo 0)
wan_down=$(echo "${status_messages[@]:-}" | grep -o "=DOWN" | wc -l || echo 0)
wan_degraded=$(echo "${status_messages[@]:-}" | grep -o "=DEGRADED" | wc -l || echo 0)

echo "<<<wan_metrics>>>"
echo "0 WAN_Metrics - Total=$wan_count Up=$wan_up Down=$wan_down Degraded=$wan_degraded | total=$wan_count up=$wan_up down=$wan_down degraded=$wan_degraded"
