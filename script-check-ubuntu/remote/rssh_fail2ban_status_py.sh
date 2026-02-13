#!/usr/bin/env bash
# Remote launcher per check_fail2ban_status.py
# Scarica e esegue la versione Python completa da repository

REPO_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-ubuntu/full/check_fail2ban_status.py"

# Exec sostituisce il processo corrente, output immediato senza buffering
exec python3 <(curl -fsSL "$REPO_URL") "$@"
