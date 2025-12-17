#!/bin/bash
# Launcher per check_ns8_tomcat8.sh (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="/opt/checkmk-tools/script-check-ns8/full/check_ns8_tomcat8.sh"
# Esegue lo script locale
exec "$LOCAL_SCRIPT" "$@"
