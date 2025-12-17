
#!/bin/bash
/bin/bash
# Launcher remoto per check_uptime.sh
SCRIPT_PATH="/opt/checkmk-tools/script-check-nsec8/full/check_uptime.sh"[[ -x "$SCRIPT_PATH" ]] && bash "$SCRIPT_PATH" "$@"
