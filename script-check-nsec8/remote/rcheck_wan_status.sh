
#!/bin/bash
/bin/bash
# Launcher remoto per check_wan_status.sh
SCRIPT_PATH="/opt/checkmk-tools/script-check-nsec8/full/check_wan_status.sh"[[ -x "$SCRIPT_PATH" ]] && bash "$SCRIPT_PATH" "$@"
