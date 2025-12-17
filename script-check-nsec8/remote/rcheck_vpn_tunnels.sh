
#!/bin/bash
/bin/bash
# Launcher remoto per check_vpn_tunnels.sh
SCRIPT_PATH="/opt/checkmk-tools/script-check-nsec8/full/check_vpn_tunnels.sh"[[ -x "$SCRIPT_PATH" ]] && bash "$SCRIPT_PATH" "$@"
