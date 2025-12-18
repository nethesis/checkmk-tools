#!/usr/bin/env bash

# CheckMK plugin - Monitoraggio regole firewall

set -o pipefail

if ! command -v iptables >/dev/null 2>&1; then
    echo "2 Firewall_Rules - CRITICAL: iptables non trovato"
    exit 0
fi

count_chain_rules() {
    local table=${1:-filter}
    local chain=$2

    iptables -t "$table" -L "$chain" -n 2>/dev/null | awk '
        /^[A-Z]/ && $1 != "Chain" && $1 != "target" { c++ }
        END { print c+0 }
    '
}

get_chain_policy() {
    local chain=$1
    iptables -L "$chain" -n 2>/dev/null | awk 'NR==1 {for (i=1;i<=NF;i++) if ($i=="policy") {print $(i+1); exit}}'
}

input_rules=$(count_chain_rules filter INPUT)
forward_rules=$(count_chain_rules filter FORWARD)
output_rules=$(count_chain_rules filter OUTPUT)
nat_rules=$(count_chain_rules nat PREROUTING)

total_rules=$((input_rules + forward_rules + output_rules))

input_policy=$(get_chain_policy INPUT)
forward_policy=$(get_chain_policy FORWARD)

status=0
status_text="OK"

if [[ $total_rules -eq 0 ]]; then
    status=2
    status_text="CRITICAL - Nessuna regola attiva"
elif [[ $total_rules -lt 5 ]]; then
    status=1
    status_text="WARNING - Poche regole attive"
fi

echo "$status Firewall_Rules - INPUT:$input_rules FORWARD:$forward_rules OUTPUT:$output_rules NAT:$nat_rules - Policy: INPUT=$input_policy FORWARD=$forward_policy - $status_text | input=$input_rules forward=$forward_rules output=$output_rules nat=$nat_rules total=$total_rules"
exit 0
