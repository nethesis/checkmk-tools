#!/bin/bash
# fix-all-launchers.sh - Corregge tutti i launcher remoti (r*.sh)
# Aggiunge shebang mancanti e corregge permessi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== FIX ALL LAUNCHERS ==="
echo "Directory: $SCRIPT_DIR"
echo ""

fixed=0
skipped=0

while IFS= read -r launcher; do
  echo "Checking: $(basename "$launcher")"
  
  # Verifica shebang
  first_line=$(head -n1 "$launcher")
  if [[ "$first_line" != "#!/bin/bash" ]] && [[ "$first_line" != "#!/usr/bin/env bash" ]]; then
    echo "  ⚠️  Shebang mancante o errato, fixing..."
    
    # Backup
    cp "$launcher" "${launcher}.backup"
    
    # Aggiungi shebang
    {
      echo "#!/bin/bash"
      cat "$launcher"
    } > "${launcher}.tmp"
    mv "${launcher}.tmp" "$launcher"
    
    ((fixed++))
  else
    echo "  ✓ OK"
    ((skipped++))
  fi
  
  # Assicura permessi esecuzione
  chmod +x "$launcher"
  
done < <(find "$SCRIPT_DIR" -name "r*.sh" -type f)

echo ""
echo "=== RIEPILOGO ==="
echo "Fixed:   $fixed"
echo "Skipped: $skipped"
