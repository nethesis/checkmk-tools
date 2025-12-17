#!/bin/bash
/usr/bin/env bashset -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"cd "$SCRIPT_DIR"if [[ -f .env ]]; then  set -a  source .env  set +aelse  
echo "├ó┼í┬á├»┬©┬Å  .env non trovato. Copia .env.example in .env e personalizza."  exit 1fiif [[ $EUID -ne 0 ]]; then  
echo "Devi eseguire come root o con sudo."  exit 1fiexport TIMEZONE SSH_PORT PERMIT_ROOT_LOGIN CLIENT_ALIVE_INTERVAL CLIENT_ALIVE_COUNTMAX LOGIN_GRACE_TIME ROOT_PASSWORD OPEN_HTTP_HTTPS LETSENCRYPT_EMAIL LETSENCRYPT_DOMAINS WEBSERVER NTP_SERVERS CHECKMK_ADMIN_PASSWORD CHECKMK_DEB_URLrun(){ 
echo -e "\n===== ESECUZIONE: $1 ====="; bash "$SCRIPT_DIR/scripts/$1"; }run 10-ssh.shrun 15-ntp.shrun 20-packages.shrun 25-postfix.shrun 30-firewall.shrun 40-fail2ban.shrun 50-certbot.shrun 60-checkmk.shrun 80-timeshift.sh
echo -e "\n├ó┼ôÔÇª Bootstrap completato."
