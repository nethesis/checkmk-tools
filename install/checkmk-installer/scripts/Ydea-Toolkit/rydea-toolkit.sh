#!/usr/bin/env bash

# Launcher remoto per ydea-toolkit.sh - scarica ed esegue da GitHub.

set -euo pipefail

timestamp="$(date +%s)"
github_raw_url="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/Ydea-Toolkit/full/ydea-toolkit.sh?v=${timestamp}"

temp_script="$(mktemp)"
cleanup() { rm -f "$temp_script"; }
trap cleanup EXIT

if command -v curl >/dev/null 2>&1; then
	curl -fsSL "$github_raw_url" -o "$temp_script"
elif command -v wget >/dev/null 2>&1; then
	wget -qO "$temp_script" "$github_raw_url"
else
	echo "ERROR: curl o wget non disponibile" >&2
	exit 127
fi

bash -n "$temp_script"
bash "$temp_script" "$@"
