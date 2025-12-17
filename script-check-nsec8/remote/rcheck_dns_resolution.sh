
#!/bin/bash
/bin/bash
# Launcher remoto per check_dns_resolution.sh
SCRIPT_PATH="/opt/checkmk-tools/script-check-nsec8/full/check_dns_resolution.sh"[[ -x "$SCRIPT_PATH" ]] && bash "$SCRIPT_PATH" "$@"
