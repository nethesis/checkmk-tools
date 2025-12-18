#!/usr/bin/env bash
set -euo pipefail

# distributed-monitoring-setup.sh
# Setup CheckMK Distributed Monitoring between local central and remote VPS
# Architecture:
# - Local site = central manager (push replication)
# - VPS site   = remote receiver
# Network: local pushes config to VPS via HTTPS:443

VPS_HOST="${VPS_HOST:-monitor01.nethlab.it}"
VPS_SITE="${VPS_SITE:-central}"
LOCAL_SITE="${LOCAL_SITE:-boxlocale}"
VPS_SITE_ALIAS="${VPS_SITE_ALIAS:-central}"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

need_cmd() {
  have_cmd "$1" || {
    echo "ERROR: missing command: $1" >&2
    exit 1
  }
}

need_cmd omd

run_site() {
  local site="$1"
  shift
  local cmd="$*"

  if have_cmd sudo; then
    sudo -u "$site" bash -lc "cd /omd/sites/$site; source .profile; $cmd"
  else
    bash -lc "cd /omd/sites/$site; source .profile; $cmd"
  fi
}

site_exists() {
  local site="$1"
  omd sites | awk '{print $1}' | grep -qx "$site"
}

detect_role() {
  local hostname
  hostname=$(hostname -f 2>/dev/null || hostname)
  if [[ "$hostname" == *"$VPS_HOST"* ]]; then
    echo "vps"
  else
    echo "local"
  fi
}

audit() {
  local site="$1"
  echo "--- Audit ($site) ---"
  run_site "$site" "omd status || true"
  run_site "$site" "omd config show LIVESTATUS_TCP || true"
  run_site "$site" "omd config show LIVESTATUS_TCP_PORT || true"
  run_site "$site" "grep -R --line-number 'wato_enabled' etc/check_mk/multisite* 2>/dev/null || true"
  run_site "$site" "test -f etc/check_mk/multisite.d/wato/distributed_monitoring.mk && echo 'OK: distributed_monitoring.mk present' || echo 'INFO: distributed_monitoring.mk missing'"
}

configure_vps() {
  local site="$VPS_SITE"
  if ! site_exists "$site"; then
    echo "ERROR: VPS site '$site' not found" >&2
    exit 1
  fi

  echo "Configuring VPS site as remote receiver: $site"

  run_site "$site" "mkdir -p var/check_mk/web/automation"
  run_site "$site" "if [[ ! -f var/check_mk/web/automation/automation.secret ]]; then\
    if command -v openssl >/dev/null 2>&1; then\
      secret=\$(openssl rand -base64 24);\
    else\
      secret=\$(date +%s%N);\
    fi;\
    echo \"\$secret\" > var/check_mk/web/automation/automation.secret;\
    chmod 660 var/check_mk/web/automation/automation.secret;\
    echo 'OK: automation.secret created';\
  else\
    echo 'OK: automation.secret already exists';\
  fi"

  run_site "$site" "if ! grep -q 'wato_enabled.*True' etc/check_mk/multisite.mk 2>/dev/null; then echo 'wato_enabled = True' >> etc/check_mk/multisite.mk; fi"
  run_site "$site" "omd restart"

  echo
  echo "VPS automation credentials (use on local site):"
  echo "- Site: $site"
  echo "- URL:  https://$VPS_HOST/$site/check_mk/"
  echo "- User: automation"
  echo "- Secret:"
  run_site "$site" "cat var/check_mk/web/automation/automation.secret"
}

configure_local() {
  local site="$LOCAL_SITE"
  if ! site_exists "$site"; then
    echo "ERROR: Local site '$site' not found" >&2
    exit 1
  fi

  echo "Configuring local site as central manager: $site"
  echo
  echo "On VPS run first (to get secret):"
  echo "  ROLE=vps $0"
  echo
  read -r -p "Enter VPS automation secret: " vps_secret
  if [[ -z "$vps_secret" ]]; then
    echo "ERROR: VPS automation secret is required" >&2
    exit 1
  fi

  run_site "$site" "mkdir -p etc/check_mk/multisite.d/wato"
  run_site "$site" "cat > etc/check_mk/multisite.d/wato/distributed_monitoring.mk <<'PY'
# Local Site: Central Manager
# Pushes configuration to VPS remote site

sites.update({
    '$VPS_SITE_ALIAS': {
        'alias': 'VPS Remote Site',
        'socket': 'local',
        'disable_wato': False,
        'disabled': False,
        'insecure': False,
        'multisiteurl': 'https://$VPS_HOST/$VPS_SITE/check_mk/',
        'persist': False,
        'replicate_ec': True,
        'replicate_mkps': True,
        'replication': 'push',
        'timeout': 10,
        'user_sync': 'all',
        'secret': '$vps_secret',
    }
})
PY"

  run_site "$site" "if ! grep -q 'wato_enabled.*True' etc/check_mk/multisite.mk 2>/dev/null; then echo 'wato_enabled = True' >> etc/check_mk/multisite.mk; fi"
  run_site "$site" "omd restart"

  echo
  echo "OK: local site configured. Next steps:"
  echo "- In Local GUI: Setup -> Hosts -> Bulk operations"
  echo "- Assign hosts to site: $VPS_SITE_ALIAS"
  echo "- Activate changes to push configuration"
}

usage() {
  echo "Usage: ROLE=local|vps $0 [--audit]" >&2
  echo "Env vars: VPS_HOST, VPS_SITE, LOCAL_SITE, VPS_SITE_ALIAS" >&2
}

ROLE="${ROLE:-$(detect_role)}"

if [[ "${1:-}" == "--audit" ]]; then
  if [[ "$ROLE" == "vps" ]]; then
    audit "$VPS_SITE"
  else
    audit "$LOCAL_SITE"
  fi
  exit 0
fi

case "$ROLE" in
  vps) configure_vps ;;
  local) configure_local ;;
  *) usage; exit 1 ;;
esac
