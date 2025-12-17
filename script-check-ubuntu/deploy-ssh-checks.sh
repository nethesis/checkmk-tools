#!/bin/bash
/usr/bin/env bash

# Deploy SSH monitoring checks directly (no launchers)

# Installa gli script completi invece dei launcher remoti

set -e


LOCALDIR="/usr/lib/check_mk_agent/local"

REPO_BASE="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-ubuntu/full"


echo "Deploying SSH monitoring checks to $LOCALDIR..."


# Download and install full scripts directly
curl -fsSL "$REPO_BASE/check_ssh_root_logins.sh" -o "$LOCALDIR/check_ssh_root_logins" && chmod +x "$LOCALDIR/check_ssh_root_logins"

echo "Ô£ô check_ssh_root_logins installed"

curl -fsSL "$REPO_BASE/check_ssh_root_sessions.sh" -o "$LOCALDIR/check_ssh_root_sessions" && chmod +x "$LOCALDIR/check_ssh_root_sessions"

echo "Ô£ô check_ssh_root_sessions installed"

curl -fsSL "$REPO_BASE/check_ssh_all_sessions.sh" -o "$LOCALDIR/check_ssh_all_sessions" && chmod +x "$LOCALDIR/check_ssh_all_sessions"

echo "Ô£ô check_ssh_all_sessions installed"

curl -fsSL "$REPO_BASE/check_fail2ban_status.sh" -o "$LOCALDIR/check_fail2ban_status" && chmod +x "$LOCALDIR/check_fail2ban_status"

echo "Ô£ô check_fail2ban_status installed"


# Remove old launcher scripts if present
rm -f "$LOCALDIR"/rssh_* 2>/dev/null || true

echo "Ô£ô Old launchers removed"


echo ""

echo "Deployment complete! Installed scripts:"
ls -lh "$LOCALDIR"/check_ssh_* "$LOCALDIR"/check_fail2ban_*


echo ""

echo "Testing output..."
/usr/bin/check_mk_agent | grep -A10 '<<<local:sep(0)>>>'
