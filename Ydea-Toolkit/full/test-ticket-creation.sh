#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREATE_SCRIPT="${SCRIPT_DIR}/create-monitoring-ticket.sh"

if [[ ! -x "$CREATE_SCRIPT" ]]; then
    echo "ERROR: create-monitoring-ticket.sh not found/executable: $CREATE_SCRIPT" >&2
    exit 1
fi

confirm="${CONFIRM_CREATE_TICKETS:-0}"

declare -A cases
cases[
"NethVoice-CRIT"
]="pbx.example.com|Asterisk Status|CRITICAL|SIP trunk offline"
cases[
"NethSecurity-WARN"
]="firewall.example.com|VPN Status|WARNING|VPN tunnel down"
cases[
"NethService-CRIT"
]="mail.example.com|SMTP|CRITICAL|Connection timeout"
cases[
"Client-WARN"
]="workstation-01|Disk Space|WARNING|Disk C: 90% full"
cases[
"Server-CRIT"
]="server-db01|MySQL Status|CRITICAL|Database connection failed"
cases[
"Network-WARN"
]="switch-core|Port Status|WARNING|Port 24 down"
cases[
"Hypervisor-CRIT"
]="proxmox01|VM Status|CRITICAL|VM web01 not responding"
cases[
"Consulenza-WARN"
]="support-request|Manual Check|WARNING|Richiesta assistenza"

echo "Test ticket creation for ${#cases[@]} cases" >&2
echo "This will create REAL tickets unless CONFIRM_CREATE_TICKETS=1" >&2

if [[ "$confirm" != "1" ]]; then
    echo "Dry-run mode. Set CONFIRM_CREATE_TICKETS=1 to execute." >&2
    for name in "${!cases[@]}"; do
        IFS='|' read -r host service state output <<<"${cases[$name]}"
        echo "- $name -> host=$host service=$service state=$state" >&2
    done
    exit 0
fi

for name in "${!cases[@]}"; do
    IFS='|' read -r host service state output <<<"${cases[$name]}"
    echo "\n=== $name ===" >&2
    "$CREATE_SCRIPT" "$host" "$service" "$state" "$output" "192.168.1.100" || true
    sleep 1
done

echo "Done" >&2
exit 0

: <<'CORRUPTED_a64ac4685a6a4a27bd0205eaec12e38e'
#!/bin/bash
/usr/bin/env bash
# test-ticket-creation.sh - Test creazione ticket per ogni tipologiaset -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "­ƒº¬ Test Creazione Ticket Ydea per CheckMK Monitoring"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "Test con stati CRITICAL e WARNING per verificare priorit├á"
echo ""
# Test cases per ogni tipologia (inclusi WARNING)declare -A 
TEST_CASES=(  ["NethVoice-CRIT"]="pbx.example.com|Asterisk Status|CRITICAL|SIP trunk offline"  ["NethSecurity-WARN"]="firewall.example.com|VPN Status|WARNING|VPN tunnel down"  ["NethService-CRIT"]="mail.example.com|SMTP|CRITICAL|Connection timeout"  ["Client-WARN"]="workstation-01|Disk Space|WARNING|Disk C: 90% full"  ["Server-CRIT"]="server-db01|MySQL Status|CRITICAL|Database connection failed"  ["Network-WARN"]="switch-core|Port Status|WARNING|Port 24 down"  ["Hypervisor-CRIT"]="proxmox01|VM Status|CRITICAL|VM web01 not responding"  ["Consulenza-WARN"]="support-request|Manual Check|WARNING|Richiesta assistenza")
echo "Vuoi eseguire il test? (creer├á 8 ticket di test)"read -p "Procedi? [y/N]: " -n 1 -r
echo ""if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Test annullato"
    exit 0
fi echo ""
echo "­ƒÜÇ Creazione ticket di test..."
echo ""for tipologia in "${!TEST_CASES[@]}"; do  
IFS='|' read -r host service state output <<< "${TEST_CASES[$tipologia]}"    
echo "ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇ"  
echo "­ƒôï Test: $tipologia"  
echo "   Host: $host | Service: $service | State: $state"  
echo ""    "$SCRIPT_DIR/create-monitoring-ticket.sh" \    "$host" \    "$service" \    "$state" \    "$output" \    "192.168.1.100"    
echo ""  sleep 2  
# Pausa tra le creazioni
done
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "Ô£à Test completato!"
echo ""
echo "Controlla i ticket creati su: https://my.ydea.cloud"

CORRUPTED_a64ac4685a6a4a27bd0205eaec12e38e

