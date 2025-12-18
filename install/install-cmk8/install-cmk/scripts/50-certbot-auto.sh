#!/usr/bin/env bash
set -euo pipefail

echo "ERROR: this script was quarantined because it was syntactically broken." >&2
echo "A copy of the previous content was saved next to this file." >&2
exit 1

: <<'CORRUPTED_54b3165471864de7b988acdf6b35e8f7'
#!/bin/bash
/usr/bin/env bash
# =====================================================
# Certbot non-interactive + auto-config Apache (optional redirect to site)
# =====================================================
# Usage (example):
#   
WS=apache \
#   
LETSENCRYPT_EMAIL="admin@example.com" \
#   
LETSENCRYPT_DOMAINS="monitor01.example.com,www.monitor01.example.com" \
#   
REDIRECT_TO_SITE=true \
#   
DEFAULT_SITE=monitoring \
#   bash scripts/50-certbot-auto.sh
#
# Notes:
# - Reads .env in current directory if present (key=value lines)
# - Only Apache auto-vhost configuration is implemented; for nginx/standalone
#   the certificate is obtained but vhost configuration is left to the operator.set -euo pipefail
# Load selected variables from .env if present (without overriding CLI env)load_from_env() {  local key="$1"  [[ -f .env ]] || return 0  
# pick last matching assignment 
KEY=... (allows comments/other lines)  local val  val=$(grep -E "^${key}=" .env | tail -n1 | cut -d= -f2- || true)  if [[ -n "$val" ]] && [[ -z "${!key:-}" ]]; then    
# Trim surrounding quotes and spaces    val="${val%%[[:space:]]}"    val="${val%\r}"    val="${val%\n}"    
# remove optional wrapping quotes    [[ "$val" == '"'*'"' ]] && val="${val:1:${
#val}-2}"    [[ "$val" == "'"*"'" ]] && val="${val:1:${
#val}-2}"    printf -v "$key" '%s' "$val"    export "$key"  fi}
WS=${WS:-}
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:-}
LETSENCRYPT_DOMAINS=${LETSENCRYPT_DOMAINS:-}
REDIRECT_TO_SITE=${REDIRECT_TO_SITE:-}
DEFAULT_SITE=${DEFAULT_SITE:-}
APACHE_CONF=${APACHE_CONF:-}
NGINX_CONF=${NGINX_CONF:-}
# Load defaults from .env if not setload_from_env WSload_from_env LETSENCRYPT_EMAILload_from_env LETSENCRYPT_DOMAINSload_from_env REDIRECT_TO_SITEload_from_env DEFAULT_SITEload_from_env APACHE_CONFload_from_env NGINX_CONF
# Apply final defaults
WS=${WS:-apache}
REDIRECT_TO_SITE=${REDIRECT_TO_SITE:-true}
DEFAULT_SITE=${DEFAULT_SITE:-monitoring}
APACHE_CONF=${APACHE_CONF:-/etc/apache2/sites-available/checkmk.conf}
NGINX_CONF=${NGINX_CONF:-/etc/nginx/sites-available/checkmk.conf}
# Optional interactive mode: ask all variables every time
ASK_ALL=${ASK_ALL:-}for arg in "$@"; do  if [[ "$arg" == "-i" || "$arg" == "--interactive" ]]; then
    ASK_ALL=true  fidone
if [[ "${ASK_ALL,,}" == "true" ]]; then  read -r -p "Specifica webserver (apache/nginx/standalone) [${WS}]: " _v; 
WS=${_v:-$WS}  read -r -p "Email Let's Encrypt [${LETSENCRYPT_EMAIL}]: " _v; 
LETSENCRYPT_EMAIL=${_v:-$LETSENCRYPT_EMAIL}  read -r -p "Domini separati da virgola [${LETSENCRYPT_DOMAINS}]: " _v; 
LETSENCRYPT_DOMAINS=${_v:-$LETSENCRYPT_DOMAINS}  read -r -p "Redirect root al site? (true/false) [${REDIRECT_TO_SITE}]: " _v; 
REDIRECT_TO_SITE=${_v:-$REDIRECT_TO_SITE}  read -r -p "Nome site CheckMK di default [${DEFAULT_SITE}]: " _v; 
DEFAULT_SITE=${_v:-$DEFAULT_SITE}fi
if [[ -z "$LETSENCRYPT_DOMAINS" ]]; then
    echo "ERROR: LETSENCRYPT_DOMAINS is required (comma-separated)." >&2  exit 1
fi echo ">>> Updating apt cache..."apt-get update -y >/dev/null
echo ">>> Installing Certbot..."apt-get install -y certbot >/dev/nullcase "$WS" in  apache)    
echo ">>> Installing Apache + plugin ..."    apt-get install -y apache2 python3-certbot-apache >/dev/null    ;;  nginx)    
echo ">>> Installing Nginx + plugin ..."    apt-get install -y nginx python3-certbot-nginx >/dev/null    ;;  standalone)    
echo ">>> Standalone mode selected."    ;;  *)    
echo "ERROR: Invalid WS value: $WS" >&2    exit 1    ;; esacmkdir -p /etc/letsencrypt
CLI_INI="/etc/letsencrypt/cli.ini"{  [[ -n "$LETSENCRYPT_EMAIL" ]] && 
echo "email = $LETSENCRYPT_EMAIL"  
echo "agree-tos = true"  
echo "non-interactive = true"  
echo "quiet = true"} > "$CLI_INI"
IFS=',' read -r -a DOM_ARRAY <<< "$LETSENCRYPT_DOMAINS"
DOMAIN_ARGS=()
for D in "${DOM_ARRAY[@]}"; do  DOMAIN_ARGS+=("-d" "$D")done
MAIN_DOMAIN="${DOM_ARRAY[0]}"
echo ">>> Requesting certificate for: $LETSENCRYPT_DOMAINS (
WS=$WS)"certbot certonly --"$WS" "${DOMAIN_ARGS[@]}"
echo ">>> Certificate request completed."
# Apache auto-config
if [[ "$WS" == "apache" ]] && [[ -n "$MAIN_DOMAIN" ]] && [[ -f "$APACHE_CONF" ]]; then
    echo ">>> Auto-config Apache vhost: $APACHE_CONF"  
BACKUP_FILE="${APACHE_CONF}.backup-$(date +%Y%m%d-%H%M%S)"  cp "$APACHE_CONF" "$BACKUP_FILE"  if [[ "${REDIRECT_TO_SITE,,}" == "true" ]]; then    cat > "$APACHE_CONF" << EOF<VirtualHost *:80>    ServerName $MAIN_DOMAIN    
# Redirect HTTP to HTTPS and / -> /$DEFAULT_SITE/    RewriteEngine On    RewriteCond %{HTTPS} off    RewriteRule ^(.*)$ https://%{HTTP_HOST}\$1 [
R=301,L]    RewriteRule ^/?$ /$DEFAULT_SITE/ [
R=301,L]</VirtualHost><VirtualHost *:443>    ServerName $MAIN_DOMAIN    SSLEngine on    SSLCertificateFile /etc/letsencrypt/live/$MAIN_DOMAIN/fullchain.pem    SSLCertificateKeyFile /etc/letsencrypt/live/$MAIN_DOMAIN/privkey.pem    
# Redirect root to site also on HTTPS    RewriteEngine On    RewriteRule ^/?$ /$DEFAULT_SITE/ [
R=301,L]    ProxyPreserveHost On    ProxyPass /$DEFAULT_SITE/ http://127.0.0.1:5000/$DEFAULT_SITE/    ProxyPassReverse /$DEFAULT_SITE/ http://127.0.0.1:5000/$DEFAULT_SITE/    RewriteCond %{HTTP:Upgrade} websocket [NC]    RewriteCond %{HTTP:Connection} upgrade [NC]    RewriteRule ^/$DEFAULT_SITE/(.*) "ws://127.0.0.1:5000/$DEFAULT_SITE/\$1" [P,L]    Header always set Strict-Transport-Security "max-age=31536000"    Header always set X-Frame-Options "SAMEORIGIN"    Header always set X-Content-Type-Options "nosniff"</VirtualHost>EOF
else    cat > "$APACHE_CONF" << EOF<VirtualHost *:80>    ServerName $MAIN_DOMAIN    RewriteEngine On    RewriteCond %{HTTPS} off    RewriteRule ^(.*)$ https://%{HTTP_HOST}\$1 [
R=301,L]</VirtualHost><VirtualHost *:443>    ServerName $MAIN_DOMAIN    SSLEngine on    SSLCertificateFile /etc/letsencrypt/live/$MAIN_DOMAIN/fullchain.pem    SSLCertificateKeyFile /etc/letsencrypt/live/$MAIN_DOMAIN/privkey.pem    ProxyPreserveHost On    ProxyPass / http://127.0.0.1:5000/    ProxyPassReverse / http://127.0.0.1:5000/    RewriteEngine On    RewriteCond %{HTTP:Upgrade} websocket [NC]    RewriteCond %{HTTP:Connection} upgrade [NC]    RewriteRule ^/?(.*) "ws://127.0.0.1:5000/\$1" [P,L]    Header always set Strict-Transport-Security "max-age=31536000"    Header always set X-Frame-Options "SAMEORIGIN"    Header always set X-Content-Type-Options "nosniff"</VirtualHost>EOF  fi  
# Ensure site is enabled and default disabled  a2ensite "$(basename "$APACHE_CONF")" >/dev/null 2>&1 || true  a2dissite 000-default.conf >/dev/null 2>&1 || true  if apache2ctl configtest 2>/dev/null; then    systemctl restart apache2    
echo ">>> Apache restarted successfully."
else    
echo "ERROR: Apache config invalid, restoring backup..." >&2    mv "$BACKUP_FILE" "$APACHE_CONF" || true    exit 1  fi
else  
echo ">>> Skipping Apache vhost auto-config (
WS=$WS or vhost file missing)."fi
# Nginx auto-config
if [[ "$WS" == "nginx" ]] && [[ -n "$MAIN_DOMAIN" ]]; then
    echo ">>> Auto-config Nginx vhost: $NGINX_CONF"  mkdir -p "$(dirname "$NGINX_CONF")" /etc/nginx/sites-enabled  if [[ "${REDIRECT_TO_SITE,,}" == "true" ]]; then    cat > "$NGINX_CONF" << EOFserver {    listen 80;    server_name $MAIN_DOMAIN;    return 301 https://\$host\$request_uri;}server {    listen 443 ssl;    server_name $MAIN_DOMAIN;    ssl_certificate     /etc/letsencrypt/live/$MAIN_DOMAIN/fullchain.pem;    ssl_certificate_key /etc/letsencrypt/live/$MAIN_DOMAIN/privkey.pem;    
# Redirect root to site    location = / {        return 301 /$DEFAULT_SITE/;    }    
# Proxy site path    location /$DEFAULT_SITE/ {        proxy_set_header Host \$host;        proxy_set_header X-Real-IP \$remote_addr;        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;        proxy_set_header X-Forwarded-Proto \$scheme;        proxy_http_version 1.1;        proxy_set_header Upgrade \$http_upgrade;        proxy_set_header Connection "upgrade";        proxy_pass http://127.0.0.1:5000/$DEFAULT_SITE/;    }}EOF
else    cat > "$NGINX_CONF" << EOFserver {    listen 80;    server_name $MAIN_DOMAIN;    return 301 https://\$host\$request_uri;}server {    listen 443 ssl;    server_name $MAIN_DOMAIN;    ssl_certificate     /etc/letsencrypt/live/$MAIN_DOMAIN/fullchain.pem;    ssl_certificate_key /etc/letsencrypt/live/$MAIN_DOMAIN/privkey.pem;    location / {        proxy_set_header Host \$host;        proxy_set_header X-Real-IP \$remote_addr;        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;        proxy_set_header X-Forwarded-Proto \$scheme;        proxy_http_version 1.1;        proxy_set_header Upgrade \$http_upgrade;        proxy_set_header Connection "upgrade";        proxy_pass http://127.0.0.1:5000/;    }}EOF  fi  ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/$(basename "$NGINX_CONF")"  if nginx -t; then    systemctl reload nginx    
echo ">>> Nginx reloaded successfully."
else    
echo "ERROR: Nginx config invalid." >&2    exit 1  fi
fi
echo ">>> Done."

CORRUPTED_54b3165471864de7b988acdf6b35e8f7

