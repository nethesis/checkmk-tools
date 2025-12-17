#!/bin/bash
/usr/bin/env bashset -euo pipefail
echo "===== VERIFICA SISTEMA ====="
echo -e "\n├░┼©ÔÇØÔÇÿ SSH:"if systemctl is-active --quiet ssh; then 
echo "├ó┼ôÔÇØ├»┬©┬Å  SSH attivo"; else 
echo "├ó┬Ø┼Æ SSH non attivo"; fi
PORT="$(grep -h ^Port /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | tail -n1 | awk '{print $2}')"[[ -z "$PORT" ]] && 
PORT=22
echo "Porta configurata: $PORT"ss -tln | grep -E ":$PORT\b" || 
echo "Nota: porta $PORT non in LISTEN (controlla UFW e SSH)."
echo -e "\n├░┼©ÔÇØ┬Ñ Firewall (UFW):"ufw status verbose || true
echo -e "\n├░┼©ÔÇ║┬í├»┬©┬Å  Fail2Ban:"fail2ban-client status sshd || 
echo "Fail2Ban non configurato o jail sshd non attiva"
echo -e "\n├░┼©ÔÇ£┬ª Aggiornamenti automatici:"if systemctl is-active --quiet unattended-upgrades; then 
echo "├ó┼ôÔÇØ├»┬©┬Å  unattended-upgrades attivo"; else 
echo "├ó┬Ø┼Æ non attivo"; fi
echo -e "\n├ó┬Å┬░ NTP / Ora di sistema:"timedatectl status || true
echo "Server NTP in uso: $(timedatectl show-timesync --property=ServerName --value 2>/dev/null || 
echo 'nd')"
echo -e "\n├░┼©ÔÇØ┬Å Certbot:"if command -v certbot >/dev/null 2>&1; then  certbot --version  
echo "Certificati presenti:"  certbot certificates || true
else  
echo "Certbot non installato"
fi echo -e "\n├░┼©ÔÇ£┼á Checkmk site:"if command -v omd >/dev/null 2>&1; then  omd status || true
else  
echo "Checkmk non installato"
fi echo -e "\n===== VERIFICA COMPLETATA ====="
