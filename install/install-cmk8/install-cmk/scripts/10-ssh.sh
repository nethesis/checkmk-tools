#!/usr/bin/env bash
set -euo pipefail

echo "ERROR: this script was quarantined because it was syntactically broken." >&2
echo "A copy of the previous content was saved next to this file." >&2
exit 1

: <<'CORRUPTED_6cb933c2a5334c8f8d221baac9cddc19'
#!/bin/bash
/usr/bin/env bashset -euo pipefail
# Timezone
if [[ -n "${TIMEZONE:-}" ]]; then  timedatectl set-timezone "$TIMEZONE" || true
fi
# Install openssh-server if missing
if ! dpkg -s openssh-server >/dev/null 2>&1; then  apt-get update -y  apt-get install -y openssh-serverfimkdir -p /etc/ssh/sshd_config.d
DROPIN="/etc/ssh/sshd_config.d/99-bootstrap.conf"cat > "$DROPIN" <<EOF
# Managed by bootstrapPort ${SSH_PORT:-22}LoginGraceTime ${LOGIN_GRACE_TIME:-30}ClientAliveInterval ${CLIENT_ALIVE_INTERVAL:-600}ClientAliveCountMax ${CLIENT_ALIVE_COUNTMAX:-2}TCPKeepAlive yesPermitRootLogin ${PERMIT_ROOT_LOGIN:-no}PasswordAuthentication yesEOF
# Change root password if provided
if [[ -n "${ROOT_PASSWORD:-}" ]]; then
    echo "root:${ROOT_PASSWORD}" | chpasswdfisystemctl enable --now sshsystemctl restart ssh || true
echo "SSH configurato. Porta: ${SSH_PORT:-22}"

CORRUPTED_6cb933c2a5334c8f8d221baac9cddc19

