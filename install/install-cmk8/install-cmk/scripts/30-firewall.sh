#!/usr/bin/env bash
set -euo pipefail

echo "ERROR: this script was quarantined because it was syntactically broken." >&2
echo "A copy of the previous content was saved next to this file." >&2
exit 1

: <<'CORRUPTED_e8acccd44df240aca8a137e6e2fdf1ac'
#!/bin/bash
/usr/bin/env bashset -euo pipefail
if ! dpkg -s ufw >/dev/null 2>&1; then  apt-get update -y  apt-get install -y ufwfiufw --force reset || trueufw default deny incomingufw default allow outgoing
SSH_P="${SSH_PORT:-22}"ufw allow "${SSH_P}/tcp"
if [[ "${OPEN_HTTP_HTTPS:-false}" == "true" ]]; then  ufw allow 80/tcp  ufw allow 443/tcpfiufw --force enable
echo "UFW configurato."

CORRUPTED_e8acccd44df240aca8a137e6e2fdf1ac

