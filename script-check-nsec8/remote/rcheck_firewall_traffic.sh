
#!/bin/bash
/bin/bash
# Launcher remoto per check_firewall_traffic.sh
SCRIPT_PATH="/opt/checkmk-tools/script-check-nsec8/full/check_firewall_traffic.sh"[[ -x "$SCRIPT_PATH" ]] && bash "$SCRIPT_PATH" "$@"
