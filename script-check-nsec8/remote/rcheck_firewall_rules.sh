
#!/bin/bash
/bin/bash
# Launcher remoto per check_firewall_rules.sh
SCRIPT_PATH="/opt/checkmk-tools/script-check-nsec8/full/check_firewall_rules.sh"[[ -x "$SCRIPT_PATH" ]] && bash "$SCRIPT_PATH" "$@"
