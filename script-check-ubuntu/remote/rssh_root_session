#!/usr/bin/env bash
# Remote launcher per check_ssh_root_sessions.sh
# Scarica e esegue la versione completa da repository

REPO_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-ubuntu/full/check_ssh_root_sessions.sh"

# Exec sostituisce il processo corrente, output immediato senza buffering
exec bash <(curl -fsSL "$REPO_URL") "$@"
