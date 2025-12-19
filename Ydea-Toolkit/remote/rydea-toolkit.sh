#!/usr/bin/env bash

# Launcher remoto per ydea-toolkit.sh - scarica ed esegue da GitHub.

set -euo pipefail

# Se invocato senza argomenti, mostra l'help del toolkit.
if [[ $# -eq 0 ]]; then
	set -- help
fi

timestamp="$(date +%s)"
github_raw_url="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/Ydea-Toolkit/full/ydea-toolkit.sh?v=${timestamp}"

temp_script="$(mktemp)"
cleanup() { rm -f "$temp_script"; }
trap cleanup EXIT

if command -v curl >/dev/null 2>&1; then
	if ! curl -fsSL "$github_raw_url" -o "$temp_script"; then
		echo "ERROR: download fallito via curl: $github_raw_url" >&2
		exit 1
	fi
elif command -v wget >/dev/null 2>&1; then
	if ! wget -qO "$temp_script" "$github_raw_url"; then
		echo "ERROR: download fallito via wget: $github_raw_url" >&2
		exit 1
	fi
else
	echo "ERROR: curl o wget non disponibile" >&2
	exit 127
fi

# Preflight: se lo script scaricato è corrotto, fallisce qui con messaggio chiaro.
bash -n "$temp_script"

bash "$temp_script" "$@"
