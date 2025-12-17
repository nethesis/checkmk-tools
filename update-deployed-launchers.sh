#!/bin/bash
# Script per aggiornare tutti i launcher sul server con quelli nuovi dal repo
echo "­ƒöä Aggiornamento launcher sul server..."
echo ""
REPO_DIR="/opt/checkmk-tools"updated=0errors=0
# Verifica che il repo esista
if [[ ! -d "$REPO_DIR" ]]; then
    echo "ÔØî ERRORE: Directory repo non trovata: $REPO_DIR"
    exit 1
fi # Trova tutti i launcher nel repowhile 
IFS= read -r repo_launcher; do  launcher_name=$(basename "$repo_launcher")    
# Cerca dove ├¿ deployato questo launcher sul sistema  deployed_locations=$(find /opt /usr/local -name "$launcher_name" -type f 2>/dev/null | grep -v "$REPO_DIR")    if [[ -z "$deployed_locations" ]]; then
    echo "ÔÅ¡´©Å  $launcher_name - non deployato sul sistema"    continue  fi    
# Aggiorna ogni location trovata  while 
IFS= read -r deployed_path; do    if [[ -z "$deployed_path" ]]; then continue; fi        
# Verifica se ├¿ diverso    if cmp -s "$repo_launcher" "$deployed_path" 2>/dev/null; then
    echo "Ô£ô $launcher_name ÔåÆ $deployed_path (gi├á aggiornato)"    else      
# Backup del vecchio      cp "$deployed_path" "${deployed_path}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null            
# Copia il nuovo      if cp "$repo_launcher" "$deployed_path" 2>/dev/null; then        chmod +x "$deployed_path"        
echo "Ô£à Aggiornato: $launcher_name ÔåÆ $deployed_path"        ((updated++))      else        
echo "ÔØî ERRORE: impossibile aggiornare $deployed_path"        ((errors++))      fi    fi  done <<< "$deployed_locations"  done < <(find "$REPO_DIR" -path "*/remote/r*.sh" -type f)
echo ""
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "Ô£à Completato!"
echo "   ­ƒôØ $updated launcher aggiornati"
if [[ $errors -gt 0 ]]; then
    echo "   ÔØî $errors errori"
fi
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
