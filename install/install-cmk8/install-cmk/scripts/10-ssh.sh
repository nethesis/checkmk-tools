
#!/bin/bash
/usr/bin/env bashset -euo pipefail
# Timezoneif [[ -n "${TIMEZONE:-}" ]]; then  timedatectl set-timezone "$TIMEZONE" || truefi
# Install openssh-server if missingif ! dpkg -s openssh-server >/dev/null 2>&1; then  apt-get update -y  apt-get install -y openssh-serverfimkdir -p /etc/ssh/sshd_config.d
DROPIN="/etc/ssh/sshd_config.d/99-bootstrap.conf"cat > "$DROPIN" <<EOF
# Managed by bootstrapPort ${SSH_PORT:-22}LoginGraceTime ${LOGIN_GRACE_TIME:-30}ClientAliveInterval ${CLIENT_ALIVE_INTERVAL:-600}ClientAliveCountMax ${CLIENT_ALIVE_COUNTMAX:-2}TCPKeepAlive yesPermitRootLogin ${PERMIT_ROOT_LOGIN:-no}PasswordAuthentication yesEOF
# Change root password if providedif [[ -n "${ROOT_PASSWORD:-}" ]]; then  
echo "root:${ROOT_PASSWORD}" | chpasswdfisystemctl enable --now sshsystemctl restart ssh || true
echo "SSH configurato. Porta: ${SSH_PORT:-22}"
