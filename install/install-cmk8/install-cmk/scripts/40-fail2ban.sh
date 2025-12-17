#!/bin/bash
/usr/bin/env bashset -euo pipefailif ! dpkg -s fail2ban >/dev/null 2>&1; then  apt-get update -y  apt-get install -y fail2banfimkdir -p /etc/fail2ban/jail.dcat > /etc/fail2ban/jail.d/sshd.local <<'EOF'[sshd]enabled = truemaxretry = 5bantime = 1hEOFsystemctl enable --now fail2bansystemctl restart fail2ban || true
echo "Fail2Ban configurato."
