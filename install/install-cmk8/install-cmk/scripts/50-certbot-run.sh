
#!/bin/bash
/usr/bin/env bash
# Wrapper per eseguire il flusso interattivo di certificazione + vhost
# - Escalation a root automatica
# - Preserva eventuali variabili d'ambiente utili
# - Pre-check DNS e porte (opzionale)set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_SCRIPT="$SCRIPT_DIR/50-certbot-auto.sh"if [[ ! -x "$AUTO_SCRIPT" ]]; then  
echo "ERROR: script non trovato: $AUTO_SCRIPT" >&2  exit 1fi
# Pre-check opzionale (solo se richiesto con --check o 
CHECK_PREREQS=true)
CHECK_PREREQS=${CHECK_PREREQS:-false}for arg in "$@"; do  if [[ "$arg" == "--check" ]]; then    
CHECK_PREREQS=true  fidoneif [[ "${CHECK_PREREQS,,}" == "true" ]]; then  
echo ">>> Pre-verifica prerequisiti..."    
# Verifica DNS (se LETSENCRYPT_DOMAINS ├¿ gi├á settato)  if [[ -n "${LETSENCRYPT_DOMAINS:-}" ]]; then    
IFS=',' read -r -a domains <<< "$LETSENCRYPT_DOMAINS"    for domain in "${domains[@]}"; do      domain=$(
echo "$domain" | xargs) 
# trim spaces      
echo -n "  - DNS $domain: "      if host "$domain" >/dev/null 2>&1; then        
echo "OK"      else        
echo "WARNING: risoluzione fallita"      fi    done  fi    
# Verifica porte 80 e 443  
echo -n "  - Porta 80: "  if ss -tulpn | grep -q ':80 '; then    
echo "OK (in ascolto)"  else    
echo "WARNING: nessun processo in ascolto"  fi    
echo -n "  - Porta 443: "  if ss -tulpn | grep -q ':443 '; then    
echo "OK (in ascolto)"  else    
echo "WARNING: nessun processo in ascolto"  fi    
echo ""fiif [[ "$EUID" -ne 0 ]]; then  exec sudo --preserve-env=WS,LETSENCRYPT_EMAIL,LETSENCRYPT_DOMAINS,REDIRECT_TO_SITE,DEFAULT_SITE,CHECK_PREREQS \    bash "$AUTO_SCRIPT" --interactiveelse  exec bash "$AUTO_SCRIPT" --interactivefi
