#!/usr/bin/env bash
set -euo pipefail

echo "ERROR: this script was quarantined because it was syntactically broken." >&2
echo "A copy of the previous content was saved next to this file." >&2
exit 1

: <<'CORRUPTED_98b685028b2a436681e87c7eb022fa8d'
#!/bin/bash
/usr/bin/env bashset -euo pipefail
if ! dpkg -s fail2ban >/dev/null 2>&1; then  apt-get update -y  apt-get install -y fail2banfimkdir -p /etc/fail2ban/jail.dcat > /etc/fail2ban/jail.d/sshd.local <<'EOF'[sshd]enabled = truemaxretry = 5bantime = 1hEOFsystemctl enable --now fail2bansystemctl restart fail2ban || true
echo "Fail2Ban configurato."

CORRUPTED_98b685028b2a436681e87c7eb022fa8d

