#!/usr/bin/env bash
set -euo pipefail

# Script per aggiornare tutti i launcher sul server con quelli nuovi dal repo

REPO_DIR="/opt/checkmk-tools"

echo "Aggiornamento launcher sul server..."
echo

if [[ ! -d "$REPO_DIR" ]]; then
  echo "ERRORE: Directory repo non trovata: $REPO_DIR" >&2
  exit 1
fi

updated=0
errors=0

while IFS= read -r repo_launcher; do
  launcher_name=$(basename "$repo_launcher")

  deployed_locations=$(find /opt /usr/local -name "$launcher_name" -type f 2>/dev/null | grep -v "$REPO_DIR" || true)
  if [[ -z "$deployed_locations" ]]; then
    echo "SKIP: $launcher_name - non deployato sul sistema"
    continue
  fi

  while IFS= read -r deployed_path; do
    [[ -z "$deployed_path" ]] && continue

    if cmp -s "$repo_launcher" "$deployed_path" 2>/dev/null; then
      echo "OK: $launcher_name -> $deployed_path (gia aggiornato)"
      continue
    fi

    cp "$deployed_path" "${deployed_path}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

    if cp "$repo_launcher" "$deployed_path" 2>/dev/null; then
      chmod +x "$deployed_path" 2>/dev/null || true
      echo "UPDATED: $launcher_name -> $deployed_path"
      ((updated++))
    else
      echo "ERROR: impossibile aggiornare $deployed_path" >&2
      ((errors++))
    fi
  done <<< "$deployed_locations"
done < <(find "$REPO_DIR" -path "*/remote/r*.sh" -type f)

echo
echo "Completato"
echo "- $updated launcher aggiornati"
if [[ $errors -gt 0 ]]; then
  echo "- $errors errori" >&2
fi
