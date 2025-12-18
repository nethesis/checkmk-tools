#!/usr/bin/env bash

set -euo pipefail

# esempi-ydea.sh - Example script for common Ydea toolkit operations

TOOLKIT="./ydea-toolkit.sh"

# Load credentials
if [[ ! -f .env ]]; then
  echo "ERROR: .env file not found. Copy .env.example to .env and fill credentials."
  exit 1
fi
source .env

echo "=== YDEA TOOLKIT EXAMPLES ==="
echo ""

# Example 1: Daily ticket report
esempio_report_giornaliero() {
  echo "DAILY TICKET REPORT"
  echo "================================"
  echo ""

  # Open tickets
  echo "OPEN Tickets:"
  $TOOLKIT list 100 open 2>/dev/null | jq -r '.data[] | "  #\(.id) - \(.title) [prio: \(.priority)]"' || echo "Error"
  echo ""

  # In progress
  echo "IN PROGRESS Tickets:"
  $TOOLKIT list 100 in_progress 2>/dev/null | jq -r '.data[] | "  #\(.id) - \(.title) [assigned to: \(.assigned_to.name // "none")]"' || echo "Error"
  echo ""

  # Statistics
  echo "STATISTICS:"
  local total_open
  total_open=$($TOOLKIT list 1000 open 2>/dev/null | jq '.total // 0')
  local total_closed
  total_closed=$($TOOLKIT list 1000 closed 2>/dev/null | jq '.total // 0')
  echo "  Open: $total_open"
  echo "  Closed: $total_closed"
}

# Example 2: Create ticket from monitoring alert
esempio_ticket_monitoraggio() {
  echo "CREATE TICKET FROM ALERT"
  echo "================================"
  echo ""

  # Simulate system alert
  local hostname="server-prod-01"
  local alert_type="CPU usage high"
  local current_value="95%"

  local title="[ALERT] $alert_type on $hostname"
  local description="Automatic alert from monitoring system:
Hostname: $hostname
Alert type: $alert_type
Current value: $current_value
Date/time: $(date '+%Y-%m-%d %H:%M:%S')
Required action: Check CPU load and running processes."

  echo "Creating ticket: $title"

  local result
  result=$($TOOLKIT create "$title" "$description" "high" 2>/dev/null || echo '{}')
  local ticket_id
  ticket_id=$(echo "$result" | jq -r '.id // empty')

  if [[ -n "$ticket_id" ]]; then
    echo "✓ Ticket created: #$ticket_id"
    echo "$result" | jq '.'
  else
    echo "ERROR creating ticket"
    echo "$result"
  fi
}

# Example 3: Search and update ticket
esempio_cerca_e_aggiorna() {
  echo "SEARCH AND UPDATE TICKET"
  echo "================================"
  echo ""

  local query="database"
  echo "Searching tickets containing: '$query'"

  local tickets
  tickets=$($TOOLKIT search "$query" 5 2>/dev/null || echo '{}')
  echo "$tickets" | jq -r '.data[]? | "  #\(.id) - \(.title) [\(.status)]"'
  echo ""

  # Get first ticket
  local first_id
  first_id=$(echo "$tickets" | jq -r '.data[0].id // empty')

  if [[ -n "$first_id" ]]; then
    echo ""
    echo "Adding comment to ticket #$first_id"
    $TOOLKIT comment "$first_id" "Ticket reviewed during maintenance"
  fi
}

# Example 4: Complete workflow
esempio_workflow_completo() {
  echo "COMPLETE WORKFLOW"
  echo "================================"
  echo ""

  # 1. Create ticket
  echo "1) Creating ticket..."
  local result
  result=$($TOOLKIT create "Test workflow" "Test ticket for automatic workflow" "normal" 2>/dev/null || echo '{}')
  local ticket_id
  ticket_id=$(echo "$result" | jq -r '.id // empty')

  if [[ -z "$ticket_id" ]]; then
    echo "ERROR creating ticket"
    return 1
  fi

  echo "   ✓ Created ticket #$ticket_id"
  echo ""

  # 2. Get details
  echo "2) Retrieving details..."
  $TOOLKIT get "$ticket_id" 2>/dev/null | jq '{id, title, status, priority, created_at}' || true
  echo ""

  # 3. Add comment
  echo "3) Adding comment..."
  $TOOLKIT comment "$ticket_id" "Starting work on ticket" 2>/dev/null || true
  echo ""

  # 4. Update status
  echo "4) Updating status to 'in progress'..."
  $TOOLKIT update "$ticket_id" '{"status":"in_progress"}' 2>/dev/null || true
  echo ""

  # 5. Final note
  echo "5) Adding final note..."
  $TOOLKIT comment "$ticket_id" "Work completed successfully" 2>/dev/null || true
  echo ""

  # 6. Close ticket
  echo "6) Closing ticket..."
  $TOOLKIT close "$ticket_id" "Test workflow completed" 2>/dev/null || true
  echo ""

  echo "✓ Workflow completed for ticket #$ticket_id"
}

# Example 5: Export tickets to CSV
esempio_export_csv() {
  echo "EXPORT TICKETS TO CSV"
  echo "================================"
  echo ""

  local output_file="tickets_$(date +%Y%m%d_%H%M%S).csv"
  echo "Exporting tickets to $output_file..."

  $TOOLKIT list 1000 2>/dev/null | jq -r '
    ["ID","Title","Status","Priority","Created","Assigned to"] as $headers |
    .data[] as $row |
    [$row.id, $row.title, $row.status, $row.priority, $row.created_at, ($row.assigned_to.name // "N/A")] |
    @csv
  ' > "$output_file"

  echo "✓ Export completed: $output_file"
  echo "First 5 lines:"
  head -5 "$output_file"
}

# Interactive menu
show_menu() {
  echo ""
  echo "Choose an example to run:"
  echo "  1) Daily ticket report"
  echo "  2) Create ticket from monitoring alert"
  echo "  3) Search and update ticket"
  echo "  4) Complete workflow (create → update → close)"
  echo "  5) Export tickets to CSV"
  echo "  0) Exit"
  echo ""

  read -r -p "Choice [0-5]: " choice

  case $choice in
    1) esempio_report_giornaliero ;;
    2) esempio_ticket_monitoraggio ;;
    3) esempio_cerca_e_aggiorna ;;
    4) esempio_workflow_completo ;;
    5) esempio_export_csv ;;
    0) echo "Goodbye!"; exit 0 ;;
    *) echo "Invalid choice"; show_menu ;;
  esac

  echo ""
  read -r -p "Press ENTER to continue..."
  show_menu
}

# Startup
if [[ "${1:-}" == "--menu" ]]; then
  show_menu
else
  echo "Run with --menu for interactive menu"
  echo "Or source and run individual functions:"
  echo "  source $0 && esempio_report_giornaliero"
  echo "  source $0 && esempio_workflow_completo"
fi

exit 0 