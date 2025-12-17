
#!/bin/bash
/bin/bash
# Launcher base per eseguire qualsiasi script dal repo GitHub senza copia locale
# Uso: bash launcher_remote_script.sh <URL_SCRIPT> [parametri]if [ -z "$1" ]; then    
echo "Usage: $0 <URL_SCRIPT> [parametri]"    exit 1fi
SCRIPT_URL="$1"shift
# Esegue lo script remoto passando eventuali parametribash <(curl -fsSL "$SCRIPT_URL") "$@"
