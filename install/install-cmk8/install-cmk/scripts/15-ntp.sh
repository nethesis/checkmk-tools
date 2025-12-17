#!/bin/bash
/usr/bin/env bashset -euo pipefail
if dpkg -s chrony >/dev/null 2>&1; then
    echo "chrony installato: salto systemd-timesyncd."
    exit 0
fi if dpkg -s ntp >/dev/null 2>&1; then
    echo "ntp installato: salto systemd-timesyncd."
    exit 0fiapt-get update -yapt-get install -y systemd-timesyncdmkdir -p /etc/systemd/timesyncd.conf.d
SERVERS="${NTP_SERVERS:-0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org}"cat > /etc/systemd/timesyncd.conf.d/99-bootstrap.conf <<EOF[Time]
NTP=${SERVERS}Fallback
NTP=ntp.ubuntu.comEOFsystemctl enable systemd-timesyncdsystemctl restart systemd-timesyncd || truetimedatectl set-ntp true || true
echo "==> Stato timedatectl:"timedatectl status || true
