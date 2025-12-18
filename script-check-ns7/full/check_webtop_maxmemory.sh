#!/usr/bin/env bash

# check_webtop_maxmemory.sh

set -o pipefail

SERVICE="WebTop_maxmemory"

maxmem=$(config show webtop 2>/dev/null | awk -F= 'BEGIN{IGNORECASE=1} /MaxMemory/ {gsub(/[[:space:]]/,"",$2); print $2; exit}' || true)

if [[ -z "$maxmem" ]]; then
    echo "0 $SERVICE - MaxMemory unset"
else
    echo "0 $SERVICE - MaxMemory = ${maxmem}M"
fi