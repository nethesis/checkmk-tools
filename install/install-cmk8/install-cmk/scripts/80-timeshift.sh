#!/bin/bash
# 80-timeshift.sh - Install Timeshift for system snapshots

set -euo pipefail

echo "[80-TIMESHIFT] Installing Timeshift..."

# Add repository
add-apt-repository -y ppa:teejee2008/timeshift

# Update and install
apt-get update
apt-get install -y timeshift

# Configure for RSYNC snapshots
timeshift --create --comments "Initial snapshot after CheckMK installation" --tags D

echo "[80-TIMESHIFT] Timeshift installed and initial snapshot created"
