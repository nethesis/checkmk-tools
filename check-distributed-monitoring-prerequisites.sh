#!/usr/bin/env bash
set -euo pipefail

# check-distributed-monitoring-prerequisites.sh
# Verifica prerequisiti per distributed monitoring su una VPS CheckMK

SITE="${1:-monitoring}"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

need_cmd() {
  have_cmd "$1" || {
    echo "ERROR: missing command: $1" >&2
    exit 1
  }
}

need_cmd omd

if ! omd sites | awk '{print $1}' | grep -qx "$SITE"; then
  echo "ERROR: Site '$SITE' not found" >&2
  echo "Available sites:" >&2
  omd sites >&2 || true
  exit 1
fi

run_site() {
  local cmd="$1"
  if have_cmd sudo; then
    sudo -u "$SITE" bash -lc "cd /omd/sites/$SITE; source .profile; $cmd"
  else
    bash -lc "cd /omd/sites/$SITE; source .profile; $cmd"
  fi
}

echo "========================================="
echo "  CheckMK Distributed Monitoring - Prereq"
echo "========================================="
echo
echo "Site: $SITE"

echo
echo "--- Livestatus configuration ---"
run_site "omd config show LIVESTATUS_TCP || true"
run_site "omd config show LIVESTATUS_TCP_PORT || true"
run_site "omd config show LIVESTATUS_TCP_TLS || true"

echo
echo "--- Listening ports ---"
if have_cmd ss; then
  (have_cmd sudo && sudo ss -tlnp || ss -tlnp) | grep -E ':(5000|6557)\b' || echo "WARN: ports 5000/6557 not listening (or ss output filtered)"
else
  echo "WARN: ss not available"
fi

echo
echo "--- Firewall ---"
if have_cmd ufw; then
  (have_cmd sudo && sudo ufw status || ufw status) | grep -E '(6557|Status)' || true
elif have_cmd firewall-cmd; then
  (have_cmd sudo && sudo firewall-cmd --list-ports || firewall-cmd --list-ports) | grep -E '6557' || echo "WARN: port 6557 not listed in firewalld"
else
  echo "WARN: no firewall manager detected (ufw/firewalld)"
fi

echo
echo "--- Apache/HTTPS ---"
if [[ -f /etc/apache2/sites-available/checkmk.conf ]]; then
  echo "OK: Apache vhost found (/etc/apache2/sites-available/checkmk.conf)"
  (have_cmd sudo && sudo grep -E 'SSLCertificate' /etc/apache2/sites-available/checkmk.conf || grep -E 'SSLCertificate' /etc/apache2/sites-available/checkmk.conf) || true
else
  echo "WARN: Apache vhost not found at standard location"
fi
if have_cmd apache2ctl; then
  (have_cmd sudo && sudo apache2ctl -M || apache2ctl -M) | grep -E '(ssl|proxy|rewrite)' || true
fi

echo
echo "--- CheckMK version ---"
run_site "omd version || true"

echo
echo "--- Multisite directory ---"
run_site "test -d etc/check_mk/multisite.d && echo 'OK: etc/check_mk/multisite.d exists' || echo 'WARN: multisite.d missing'"

echo
echo "========================================="
echo "Summary"
echo "========================================="
echo "- If needed: enable Livestatus TCP on port 6557 (with TLS)"
echo "- Ensure firewall allows inbound 6557 (if required by your design)"
echo "- Proceed with distributed monitoring configuration"
