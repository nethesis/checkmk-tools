#!/bin/bash
# Script per fixare tutti i launcher remote per usare script locali invece di GitHub
echo "­ƒöº Fix di tutti i launcher remote..."
echo ""fixed=0errors=0
# Trova tutti i launcher (r*.sh) nelle cartelle remote/while 
IFS= read -r launcher; do  
# Estrai il nome dello script (senza la 'r')  launcher_name=$(basename "$launcher")  script_name="${launcher_name
#r}"  
# rimuove 'r' iniziale    
# Determina il path dello script full corrispondente  dir=$(dirname "$launcher")  full_dir="${dir/\/remote/\/full}"  full_script="$full_dir/$script_name"    
# Verifica che lo script full esista  if [[ ! -f "$full_script" ]]; then    
echo "ÔÜá´©Å  Skip $launcher_name - script full non trovato: $full_script"    continue  fi    
# Leggi il launcher attuale  if ! grep -q "curl.*githubusercontent" "$launcher" 2>/dev/null; then    
echo "Ô£ô $launcher_name - gi├á fixato o non usa GitHub"    continue  fi    
# Genera path relativo per /opt/checkmk-tools/  relative_path="${full_script
#$(pwd)/}"  deployed_path="/opt/checkmk-tools/$relative_path"    
# Crea nuovo launcher  cat > "$launcher" << EOF
#!/bin/bash
# Launcher per $script_name (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="$deployed_path"
# Esegue lo script localeexec "\$LOCAL_SCRIPT" "\$@"EOF    chmod +x "$launcher"  
echo "Ô£à Fixed: $launcher_name ÔåÆ $deployed_path"  ((fixed++))  done < <(find . -path "*/remote/r*.sh" -type f)
echo ""
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "Ô£à Completato! $fixed launcher fixati"
if [[ $errors -gt 0 ]]; then  
echo "ÔÜá´©Å  $errors errori riscontrati"
fi echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
