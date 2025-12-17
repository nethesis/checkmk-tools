#!/bin/bash
/usr/bin/env bash
# =====================================================
# Installazione e Configurazione Certbot (interattiva)
# =====================================================set -euo pipefail
echo ">>> Aggiornamento repository..."apt-get update -y >/dev/null
echo ">>> Installazione base di Certbot..."apt-get install -y certbot >/dev/null
# Determina il webserverread -r -p "Specifica webserver (apache/nginx/standalone) [apache]: " 
WSWS="${WS:-apache}"case "$WS" in  apache)    
echo ">>> Installazione plugin Apache..."    apt-get install -y apache2 python3-certbot-apache >/dev/null    ;;  nginx)    
echo ">>> Installazione plugin Nginx..."    apt-get install -y nginx python3-certbot-nginx >/dev/null    ;;  standalone)    
echo ">>> Modalit├â┬á standalone selezionata (nessun webserver installato)."    ;;  *)    
echo "ERRORE: Valore WEBSERVER non vali
do: $WS"    exit 1    ;;esac
# Dati utenteread -r -p "Inserisci email Let's Encrypt (lascia vuoto per nessuna): " LETSENCRYPT_EMAILread -r -p "Inserisci domini separati da virgola (es. example.com,www.example.com): " LETSENCRYPT_DOMAINSmkdir -p /etc/letsencrypt
CLI_INI="/etc/letsencrypt/cli.ini"
echo ">>> Creazione configurazione globale in $CLI_INI"{  [[ -n "$LETSENCRYPT_EMAIL" ]] && 
echo "email = $LETSENCRYPT_EMAIL"  
echo "agree-tos = true"  
echo "non-interactive = true"  
echo "quiet = true"} > "$CLI_INI"
echo ">>> Certbot installato e configurato."
# Esecuzione challenge opzionaleread -r -p "Vuoi eseguire subito la challenge Let's Encrypt per ottenere il certificato? (s/n): " RUN_CHALLENGE
if [[ "$RUN_CHALLENGE" =~ ^[sS]$ ]]; then  if [[ -z "$LETSENCRYPT_DOMAINS" ]]; then    
echo "ERRORE: Nessun dominio specificato. Impossibile procedere con la challenge."    exit 1  fi
echo ">>> Avvio richiesta certificato..."  
IFS=',' read -r -a DOM_ARRAY <<< "$LETSENCRYPT_DOMAINS"  
DOMAIN_ARGS=()  for D in "${DOM_ARRAY[@]}"; do    DOMAIN_ARGS+=("-d" "$D")  done  certbot certonly --"$WS" "${DOMAIN_ARGS[@]}"  
echo ">>> Challenge completata (se non ci sono errori sopra)."    
# Configurazione Apache con il certificato Let's Encrypt  if [[ "$WS" == "apache" ]] && [[ -n "${DOM_ARRAY[0]}" ]]; then    
MAIN_DOMAIN="${DOM_ARRAY[0]}"    
APACHE_CONF="/etc/apache2/sites-available/checkmk.conf"    if [[ -f "$APACHE_CONF" ]]; then      
echo ">>> Aggiornamento configurazione Apache per usare il certificato Let's Encrypt..."      
# Backup della configurazione esistente      
BACKUP_FILE="${APACHE_CONF}.backup-$(date +%Y%m%d-%H%M%S)"      cp "$APACHE_CONF" "$BACKUP_FILE"      
# Opzione: redirect root -> site di default (es. monitoring)      read -r -p "Vuoi che https://$MAIN_DOMAIN/ apra direttamente un site CheckMK (es. monitoring)? (s/n) [s]: " REDIR_TO_SITE      
REDIR_TO_SITE="${REDIR_TO_SITE:-s}"      if [[ "$REDIR_TO_SITE" =~ ^[sS]$ ]]; then        read -r -p "Nome site CheckMK di default [monitoring]: " DEFAULT_SITE        
DEFAULT_SITE="${DEFAULT_SITE:-monitoring}"        cat > "$APACHE_CONF" << EOF<VirtualHost *:80>    ServerName $MAIN_DOMAIN    
# Redirect HTTP to HTTPS e root -> site    RewriteEngine On    RewriteCond %{HTTPS} off    RewriteRule ^(.*)$ https://%{HTTP_HOST}\$1 [
R=301,L]    RewriteRule ^/?$ /$DEFAULT_SITE/ [
R=301,L]</VirtualHost><VirtualHost *:443>    ServerName $MAIN_DOMAIN    
# SSL Configuration (Let's Encrypt)    SSLEngine on    SSLCertificateFile /etc/letsencrypt/live/$MAIN_DOMAIN/fullchain.pem    SSLCertificateKeyFile /etc/letsencrypt/live/$MAIN_DOMAIN/privkey.pem    
# Proxy solo per il site di default    ProxyPreserveHost On    ProxyPass /$DEFAULT_SITE/ http://127.0.0.1:5000/$DEFAULT_SITE/    ProxyPassReverse /$DEFAULT_SITE/ http://127.0.0.1:5000/$DEFAULT_SITE/      
# Redirect root anche su HTTPS      RewriteEngine On      RewriteRule ^/?$ /$DEFAULT_SITE/ [
R=301,L]      
# WebSocket support per il site    RewriteCond %{HTTP:Upgrade} websocket [NC]    RewriteCond %{HTTP:Connection} upgrade [NC]    RewriteRule ^/$DEFAULT_SITE/(.*) "ws://127.0.0.1:5000/$DEFAULT_SITE/\$1" [P,L]    
# Security headers    Header always set Strict-Transport-Security "max-age=31536000"    Header always set X-Frame-Options "SAMEORIGIN"    Header always set X-Content-Type-Options "nosniff"</VirtualHost>EOF      else        
# Configurazione generica (proxy root)        cat > "$APACHE_CONF" << EOF<VirtualHost *:80>    ServerName $MAIN_DOMAIN    
# Redirect HTTP to HTTPS    RewriteEngine On    RewriteCond %{HTTPS} off    RewriteRule ^(.*)$ https://%{HTTP_HOST}\$1 [
R=301,L]</VirtualHost><VirtualHost *:443>    ServerName $MAIN_DOMAIN    
# SSL Configuration (Let's Encrypt)    SSLEngine on    SSLCertificateFile /etc/letsencrypt/live/$MAIN_DOMAIN/fullchain.pem    SSLCertificateKeyFile /etc/letsencrypt/live/$MAIN_DOMAIN/privkey.pem    
# Proxy to CheckMK on port 5000    ProxyPreserveHost On    ProxyPass / http://127.0.0.1:5000/    ProxyPassReverse / http://127.0.0.1:5000/    
# WebSocket support for CheckMK    RewriteEngine On    RewriteCond %{HTTP:Upgrade} websocket [NC]    RewriteCond %{HTTP:Connection} upgrade [NC]    RewriteRule ^/?(.*) "ws://127.0.0.1:5000/\$1" [P,L]    
# Security headers    Header always set Strict-Transport-Security "max-age=31536000"    Header always set X-Frame-Options "SAMEORIGIN"    Header always set X-Content-Type-Options "nosniff"</VirtualHost>EOF      fi      
# Abilita vhost e disabilita default, verifica e riavvia Apache      a2ensite "$(basename "$APACHE_CONF")" >/dev/null 2>&1 || true      a2dissite 000-default.conf >/dev/null 2>&1 || true            if apache2ctl configtest 2>/dev/null; then        systemctl restart apache2        
echo ">>> Apache riavviato con il nuovo certificato Let's Encrypt."        
echo ">>> Certificato configurato per: $MAIN_DOMAIN"      else        
echo "ERRORE: Configurazione Apache non valida. Ripristino backup..."        mv "$BACKUP_FILE" "$APACHE_CONF" 2>/dev/null || true      fi    else      
echo ">>> File $APACHE_CONF non trovato. Configurazione Apache da fare manualmente."    fi  fi
else  
echo ">>> Challenge non eseguita. Potrai lanciarla manualmente in seguito, es.:"  
echo "    certbot certonly --$WS -d dominio.it"
fi
echo ">>> Installazione Certbot completata."
