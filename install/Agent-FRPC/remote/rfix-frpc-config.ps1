# Launcher per eseguire fix-frpc-config.ps1 remoto dal repo GitHub
# Script fix configurazione FRPC su Windows

$SCRIPT_URL = "https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/Install/Agent-FRPC/full/fix-frpc-config.ps1"

# Esegue lo script remoto
Invoke-Expression (Invoke-WebRequest -Uri $SCRIPT_URL -UseBasicParsing).Content
