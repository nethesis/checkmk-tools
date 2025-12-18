#!/usr/bin/env bash

set -euo pipefail

# check_ns8_services.sh
# Controllo servizi mail principali leggendo lo stato dei container.
# - Sessioni IMAP attive (dovecot/doveadm)
# - Stato critico se rilevato vsz_limit nei log di Dovecot
# - Warning se VszLimit non impostato

echo "<<<local>>>"
# Numero di righe da controllare nei log (per non scansionare file enormi)
LOG_LINES=500
# Scopro tutte le istanze mail (mail1, mail2, ...)
MAIL_INSTANCES=$(runagent -l | grep '^mail' || true)
# Servizi target = container interni
TARGET_SERVICES=("clamav" "rspamd" "dovecot" "postfix")
for INSTANCE in $MAIL_INSTANCES; do
    # Elenco container e stato dentro l'istanza
    STATS=$(runagent -m "$INSTANCE" podman ps --format "{{.Names}} {{.Status}}" 2>/dev/null || true)

    for SVC in "${TARGET_SERVICES[@]}"; do
        STATUS_LINE=$(echo "$STATS" | grep "^${SVC} " || true)

        if [[ -n "$STATUS_LINE" ]]; then
            STATE=$(echo "$STATUS_LINE" | awk '{print $2}')

            if [[ "$STATE" == "Up" ]]; then
                echo "0 ${INSTANCE}_${SVC} - ${SVC} attivo"

                # Se dovecot, aggiungo controlli extra
                if [[ "$SVC" == "dovecot" ]]; then
                    # Numero sessioni IMAP
                    IMAP_COUNT=$(runagent -m "$INSTANCE" podman exec "$SVC" doveadm who 2>/dev/null | wc -l)
                    if [[ "$IMAP_COUNT" -gt 0 ]]; then
                        echo "0 ${INSTANCE}_imap_sessions - Sessioni IMAP attive: $IMAP_COUNT"
                    else
                        echo "1 ${INSTANCE}_imap_sessions - Nessuna sessione IMAP attiva"
                    fi

                    # Limite configurato tramite config show
                    VSZ=$(runagent -m "$INSTANCE" config show dovecot 2>/dev/null | grep -i VszLimit | awk '{print $2}' || true)

                    # Conteggio errori vsz_limit nelle ultime LOG_LINES righe
                    OCCURRENCES=$(runagent -m "$INSTANCE" podman exec "$SVC" sh -c "tail -n ${LOG_LINES} /var/log/dovecot* 2>/dev/null | grep -c 'Cannot allocate memory due to vsz_limit'" 2>/dev/null || echo 0)

                    if [[ "$OCCURRENCES" -gt 0 ]]; then
                        if [[ -n "$VSZ" ]]; then
                            echo "2 ${INSTANCE}_dovecot_vszlimit - CRIT: rilevato vsz_limit (${OCCURRENCES} occorrenze nelle ultime ${LOG_LINES} righe, limite configurato=${VSZ})"
                        else
                            echo "2 ${INSTANCE}_dovecot_vszlimit - CRIT: rilevato vsz_limit (${OCCURRENCES} occorrenze nelle ultime ${LOG_LINES} righe, limite non impostato)"
                        fi
                    else
                        if [[ -n "$VSZ" ]]; then
                            echo "0 ${INSTANCE}_dovecot_vszlimit - Nessun allarme nei log (limite configurato=${VSZ})"
                        else
                            echo "1 ${INSTANCE}_dovecot_vszlimit - WARNING: Nessun allarme nei log (limite non impostato)"
                        fi
                    fi
                fi
            else
                echo "2 ${INSTANCE}_${SVC} - ${SVC} non attivo"
            fi
        else
            echo "3 ${INSTANCE}_${SVC} - ${SVC} non trovato"
        fi
    done
done
