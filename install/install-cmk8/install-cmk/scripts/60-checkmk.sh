#!/usr/bin/env bash
set -euo pipefail

echo "ERROR: this script was quarantined because it was syntactically broken." >&2
echo "A copy of the previous content was saved next to this file." >&2
exit 1

: <<'CORRUPTED_52ab31fb55ba49f894cacef480369cdb'
#!/bin/bash
/usr/bin/env bashset -euo pipefail
# Installa Checkmk Raw chieden
do interattivamente l'URL del .deb e crea/avvia il site "monitoring".
# Variabili opzionali (.env):
#   
CHECKMK_ADMIN_PASSWORD=   
# se valorizzata, imposta la password di cmkadmin
#   
CHECKMK_DEB_URL=          
# se gi├â┬á valorizzata, non chiede nulla e usa questo 
URLSITE="monitoring"
DEB_PATH="/tmp/checkmk.deb"
# Chiedi l'URL se non presente
if [[ -z "${CHECKMK_DEB_URL:-}" ]]; then  read -rp "├░┼©ÔÇÿÔÇ░ Inserisci l'URL completo del pacchetto Checkmk (.deb): " CHECKMK_DEB_URLfi
if [[ -z "${CHECKMK_DEB_URL:-}" ]]; then
    echo "├ó┬Ø┼Æ Nessun URL fornito. Interrompo."
    exit 1
fi echo "==> Scarico da: $CHECKMK_DEB_URL"wget -O "$DEB_PATH" "$CHECKMK_DEB_URL"
echo "==> Installo $DEB_PATH"apt-get update -y
if ! apt-get install -y "$DEB_PATH"; then
    echo "==> Risolvo dipendenze (apt -f install)"  apt-get -f install -y  apt-get install -y "$DEB_PATH"
fi # Crea il site se non esiste
if ! omd sites | awk '{print $1}' | grep -qx "$SITE"; then
    echo "==> Creo il site '${SITE}'"  omd create "$SITE"
fi # Avvia il siteomd start "$SITE" || true
# Password admin opzionale
if [[ -n "${CHECKMK_ADMIN_PASSWORD:-}" ]]; then
    echo "==> Imposto password cmkadmin per '${SITE}'"  omd su "${SITE}" -c "htpasswd -b etc/htpasswd cmkadmin '${CHECKMK_ADMIN_PASSWORD}'"  omd su "${SITE}" -c "omd reload apache" || true
fi
IP="$(hostname -I | awk '{print $1}')"
echo ""
echo "├ó┼ôÔÇª Checkmk installato e site avviato."
echo "   Site: ${SITE}"
echo "   URL:  http://${IP}/${SITE}/  (se 80 ├â┬¿ aperta)"
echo "         https://<tuo-dominio>/${SITE}/  (se hai certificato e 443 aperta)"
echo ""

CORRUPTED_52ab31fb55ba49f894cacef480369cdb

