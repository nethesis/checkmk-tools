# Launcher per eseguire install-agent-interactive.ps1 remoto dal repo GitHub
# Script installazione agent interattivo su Windows

$SCRIPT_URL = "https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/Install/Agent-FRPC/full/install-agent-interactive.ps1"

# Esegue lo script remoto
Invoke-Expression (Invoke-WebRequest -Uri $SCRIPT_URL -UseBasicParsing).Content
