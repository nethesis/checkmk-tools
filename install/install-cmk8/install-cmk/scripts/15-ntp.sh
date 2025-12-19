#!/bin/bash
# 15-ntp.sh - Configure NTP time synchronization

set -euo pipefail

echo "[15-NTP] Configuring NTP..."

# Install chrony
apt-get install -y chrony

# Enable and start
systemctl enable chrony
systemctl start chrony

# Sync time
chronyc makestep

echo "[15-NTP] NTP configured successfully"
