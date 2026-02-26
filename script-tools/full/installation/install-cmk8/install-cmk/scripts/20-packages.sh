#!/bin/bash
# 20-packages.sh - Install required system packages

set -euo pipefail

echo "[20-PACKAGES] Installing required packages..."

# Update package list
apt-get update

# Install essential packages
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    dnsutils \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common

echo "[20-PACKAGES] Packages installed successfully"
