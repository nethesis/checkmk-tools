
#!/bin/bash
/bin/bash
# Launcher remoto per check_dhcp_leases.sh
SCRIPT_PATH="/opt/checkmk-tools/script-check-nsec8/full/check_dhcp_leases.sh"[[ -x "$SCRIPT_PATH" ]] && bash "$SCRIPT_PATH" "$@"
