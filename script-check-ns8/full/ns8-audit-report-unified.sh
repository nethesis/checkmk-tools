#!/bin/bash
################################################################################
# NS8 Audit Report - Unified Version (Collector + Viewer)
################################################################################
# Scopo: Report quindicinale completo ambiente NethServer 8
#
# Raccoglie:
#   1) Utenti Active Directory (Samba)
#   2) Scadenze password utenti AD
#   3) Permessi share di rete (Samba)
#   4) Condivisioni account posta WebTop (se disponibile)
#
# Visualizza:
#   - Tabella formattata permessi ACL share
#   - Report riepilogativo completo
#
# Output: Directory /var/tmp/ns8-audit-YYYYMMDD-HHMMSS/
#
# Uso:
#  ./ns8-audit-report-unified.sh
#   ./ns8-audit-report-unified.sh --output-dir /custom/path
#   ./ns8-audit-report-unified.sh --no-display  # Skip visualizzazione ACL
#
#  Con password Samba custom (se diversa da default Nethesis,1234):
#   export SAMBA_ADMIN_PASSWORD="YourPassword"
#   ./ns8-audit-report-unified.sh
#
# Requisiti:
#   - NS8 con modulo samba installato
#   - runagent disponibile nel PATH
#   - Permessi di esecuzione su moduli NS8
################################################################################

set -euo pipefail

# Configurazione
REPORT_DATE=$(date +%Y%m%d-%H%M%S)
OUTPUT_BASE="${OUTPUT_DIR:-/var/tmp}"
OUTPUT_DIR="${OUTPUT_BASE}/ns8-audit-${REPORT_DATE}"
MAX_PWD_AGE_DAYS=42
SHOW_ACL_REPORT=1  # Default: mostra report ACL

# Colori output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzioni di logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Verifica prerequisiti
check_prerequisites() {
    log_info "Verifica prerequisiti..."
    
    if ! command -v runagent &>/dev/null; then
        log_error "runagent non trovato nel PATH"
        exit 1
    fi
    
    # Verifica moduli NS8 disponibili
    SAMBA_MODULES=$(runagent --list-modules 2>/dev/null | grep -E '^samba[0-9]+$' || true)
    WEBTOP_MODULES=$(runagent --list-modules 2>/dev/null | grep -E '^webtop[0-9]+$' || true)
    
    if [[ -z "$SAMBA_MODULES" ]]; then
        log_error "Nessun modulo Samba trovato"
        exit 1
    fi
    
    SAMBA_MODULE=$(echo "$SAMBA_MODULES" | head -1)
    log_success "Modulo Samba: $SAMBA_MODULE"
    
    # Cerca il primo modulo WebTop con container Postgres attivo
    if [[ -z "$WEBTOP_MODULES" ]]; then
        log_warn "Nessun modulo WebTop trovato (report limitato)"
        WEBTOP_MODULE=""
    else
        WEBTOP_MODULE=""
        while IFS= read -r webtop_mod; do
            [[ -z "$webtop_mod" ]] && continue
            local postgres_check=$(runagent -m "$webtop_mod" podman ps --format '{{.Names}}' 2>/dev/null | grep -i postgres || true)
            if [[ -n "$postgres_check" ]]; then
                WEBTOP_MODULE="$webtop_mod"
                log_success "Modulo WebTop: $WEBTOP_MODULE (con Postgres attivo)"
                break
            fi
        done <<< "$WEBTOP_MODULES"
        
        if [[ -z "$WEBTOP_MODULE" ]]; then
            log_warn "Nessun modulo WebTop con Postgres attivo trovato (report limitato)"
        fi
    fi
    
    # Crea directory output
    mkdir -p "$OUTPUT_DIR"
    log_success "Directory output: $OUTPUT_DIR"
}

# Funzione 1: Raccolta utenti AD
collect_ad_users() {
    log_info "Raccolta utenti Active Directory..."
    
    local output_file="$OUTPUT_DIR/01_users.txt"
    
    if runagent -m "$SAMBA_MODULE" podman exec samba-dc samba-tool user list > "$output_file" 2>/dev/null; then
        local user_count=$(wc -l < "$output_file")
        log_success "Raccolti $user_count utenti AD → $(basename "$output_file")"
        return 0
    else
        log_error "Fallita raccolta utenti AD"
        echo "ERROR: Unable to collect AD users" > "$output_file"
        return 1
    fi
}

# Funzione 2: Raccolta scadenze password AD
collect_password_expiry() {
    log_info "Raccolta scadenze password AD..."
    
    local output_file="$OUTPUT_DIR/02_password_expiry.tsv"
    local temp_file=$(mktemp)
    
    # Header TSV
    echo -e "user\tpwdLastSet_raw\tpwdLastSet_unix\tpwdLastSet_iso\texpires_unix\texpires_iso\tdays_until_expiry" > "$output_file"
    
    # Leggi lista utenti
    if [[ ! -f "$OUTPUT_DIR/01_users.txt" ]]; then
        log_error "File utenti non trovato, esegui prima collect_ad_users"
        return 1
    fi
    
    local user_count=0
    local success_count=0
    
    # DISABILITA set -e solo per questo loop
    set +e
    
    while IFS= read -r username; do
        [[ -z "$username" ]] && continue
        ((user_count++))
        
        log_info "  Elaborazione: $username"
        
        # Ottieni pwdLastSet via samba-tool user show
        local pwd_last_set=$(runagent -m "$SAMBA_MODULE" podman exec samba-dc \
            samba-tool user show "$username" 2>/dev/null \
            | grep "^pwdLastSet:" | awk '{print $2}' || echo "0")
        
        log_info "    pwdLastSet raw: $pwd_last_set"
        
        if [[ -z "$pwd_last_set" ]] || [[ "$pwd_last_set" == "0" ]]; then
            log_warn "    pwdLastSet non disponibile"
            echo -e "$username\t0\t0\tN/A\t0\tN/A\tN/A" >> "$output_file"
            continue
        fi
        
        # Conversione FILETIME → Unix epoch
        # Formula: unix = (filetime - 116444736000000000) / 10000000
        local unix_time=$(python3 -c "print(int(($pwd_last_set - 116444736000000000) / 10000000))" 2>/dev/null || echo "0")
        
        log_info "    unix_time: $unix_time"
        
        if [[ "$unix_time" == "0" ]]; then
            log_warn "    Conversione fallita"
            echo -e "$username\t$pwd_last_set\t0\tN/A\t0\tN/A\tN/A" >> "$output_file"
            continue
        fi
        
        # Data ISO formattata
        local iso_date=$(date -d "@$unix_time" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")
        
        log_info "    iso_date: $iso_date"
        
        # Calcola scadenza (pwdLastSet + maxPwdAge)
        local expires_unix=$((unix_time + MAX_PWD_AGE_DAYS * 86400))
        local expires_iso=$(date -d "@$expires_unix" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")
        
        # Giorni rimanenti
        local now=$(date +%s)
        local days_until_expiry=$(( (expires_unix - now) / 86400 ))
        
        echo -e "$username\t$pwd_last_set\t$unix_time\t$iso_date\t$expires_unix\t$expires_iso\t$days_until_expiry" >> "$output_file"
        ((success_count++))
        
    done < "$OUTPUT_DIR/01_users.txt"
    
    # Riabilita set -e
    set -e
    
    log_success "Scadenze password elaborate: $success_count/$user_count → $(basename "$output_file")"
    rm -f "$temp_file"
    return 0
}

# Funzione 3: Raccolta gruppi AD e membri
collect_ad_groups() {
    log_info "Raccolta gruppi Active Directory e membri..."
    
    local output_file="$OUTPUT_DIR/05_ad_groups.tsv"
    local temp_groups=$(mktemp)
    
    # Header TSV
    echo -e "group_name\tmembers_count\tmembers_list" > "$output_file"
    
    # Lista gruppi AD
    if ! runagent -m "$SAMBA_MODULE" podman exec samba-dc samba-tool group list > "$temp_groups" 2>/dev/null; then
        log_error "Fallita raccolta gruppi AD"
        echo "ERROR: Unable to collect AD groups" > "$output_file"
        rm -f "$temp_groups"
        return 1
    fi
    
    local group_count=0
    local success_count=0
    
    # DISABILITA set -e solo per questo loop
    set +e
    
    while IFS= read -r groupname; do
        [[ -z "$groupname" ]] && continue
        ((group_count++))
        
        log_info "  Elaborazione gruppo: $groupname"
        
        # Ottieni membri del gruppo
        local members=$(runagent -m "$SAMBA_MODULE" podman exec samba-dc \
            samba-tool group listmembers "$groupname" 2>/dev/null | tr '\n' ',' | sed 's/,$//' || echo "")
        
        local members_count=0
        if [[ -n "$members" ]]; then
            members_count=$(echo "$members" | tr ',' '\n' | wc -l)
        fi
        
        log_info "    Membri: $members_count"
        
        echo -e "$groupname\t$members_count\t$members" >> "$output_file"
        ((success_count++))
        
    done < "$temp_groups"
    
    # Riabilita set -e
    set -e
    
    log_success "Gruppi AD elaborati: $success_count/$group_count → $(basename "$output_file")"
    rm -f "$temp_groups"
    return 0
}

# Funzione 4: Raccolta share e permessi
collect_samba_shares() {
    log_info "Raccolta share Samba e permessi..."
    
    local shares_dir="$OUTPUT_DIR/03_shares"
    local acls_dir="$shares_dir/acls"
    mkdir -p "$acls_dir"
    
    local shares_list="$shares_dir/shares_list.txt"
    local shares_report="$shares_dir/shares_report.tsv"
    
    # Lista share (escludi share di sistema)
    runagent -m "$SAMBA_MODULE" podman exec samba-dc \
        smbclient -L localhost -N 2>/dev/null \
        | grep "Disk" \
        | awk '{print $1}' \
        | grep -vE '^(IPC\$|ADMIN\$|print\$|netlogon|sysvol)$' \
        > "$shares_list" || true
    
    local share_count=$(wc -l < "$shares_list" 2>/dev/null || echo 0)
    
    if [[ $share_count -eq 0 ]]; then
        log_warn "Nessuno share trovato"
        return 0
    fi
    
    log_info "Trovati $share_count share"
    
    # Header TSV report
    echo -e "share_name\tshare_path\tacl_file" > "$shares_report"
    
    # Per ogni share: ottieni path e ACL
    while IFS= read -r share_name; do
        [[ -z "$share_name" ]] && continue
        
        log_info "  Elaborazione share: $share_name"
        
        # Ottieni path share
        local share_path=$(runagent -m "$SAMBA_MODULE" podman exec samba-dc \
            net conf getparm "$share_name" path 2>/dev/null || echo "N/A")
        
        log_info "    Path: $share_path"
        
        # Ottieni ACL tramite smbcacls (Windows-style, mostra permessi configurati in NS8 UI)
        local acl_file="$acls_dir/${share_name}_smbacl.txt"
        
        # Auto-recupero password amministratore Samba (se non già impostata)
        if [[ -z "$SAMBA_ADMIN_PASSWORD" ]]; then
            # Tentativo 1: Da secrets module
            SAMBA_ADMIN_PASSWORD=$(redis-cli HGET "module/$SAMBA_MODULE/srv/secrets" adminpassword 2>/dev/null || echo "")
            
            # Tentativo 2: Da agent.env
            if [[ -z "$SAMBA_ADMIN_PASSWORD" ]]; then
                SAMBA_ADMIN_PASSWORD=$(runagent -m "$SAMBA_MODULE" cat /home/$SAMBA_MODULE/.config/state/agent.env 2>/dev/null | grep -i "ADMIN_PASSWORD\|PROVISION_PASSWORD" | cut -d'=' -f2 | head -1 || echo "")
            fi
            
            # Fallback: Password default NS8
            if [[ -z "$SAMBA_ADMIN_PASSWORD" ]]; then
                SAMBA_ADMIN_PASSWORD="Nethesis,1234"
                log_warn "    Uso password default NS8: Nethesis,1234"
            else
                log_info "    Password recuperata automaticamente dal modulo"
            fi
        fi
        
        runagent -m "$SAMBA_MODULE" podman exec samba-dc \
            smbcacls "//localhost/$share_name" / -U "administrator%${SAMBA_ADMIN_PASSWORD}" > "$acl_file" 2>&1 || true
        
        if grep -q "^ACL:" "$acl_file" 2>/dev/null; then
            log_success "    ACL salvato → $(basename "$acl_file")"
        else
            # Fallback: usa getfacl (ACL filesystem POSIX) se smbcacls fallisce
            log_warn "    smbcacls fallito, provo getfacl..."
            if [[ "$share_path" != "N/A" ]]; then
                runagent -m "$SAMBA_MODULE" podman exec samba-dc \
                    getfacl "$share_path" > "$acl_file" 2>&1
                
                if grep -qE "^(user|group):" "$acl_file" 2>/dev/null; then
                    log_success "    ACL POSIX salvato → $(basename "$acl_file")"
                else
                    log_warn "    Impossibile ottenere ACL"
                    echo "ERROR: Unable to retrieve ACL for $share_name" > "$acl_file"
                fi
            else
                log_warn "    Impossibile ottenere ACL (path non disponibile)"
                echo "ERROR: Unable to retrieve ACL for $share_name" > "$acl_file"
            fi
        fi
        
        # Aggiungi a report TSV
        echo -e "$share_name\t$share_path\t$acl_file" >> "$shares_report"
        
    done < "$shares_list"
    
    log_success "Raccolti $share_count share → $shares_dir/"
    return 0
}

# Funzione 4: Raccolta condivisioni email WebTop
collect_webtop_sharing() {
    if [[ -z "$WEBTOP_MODULE" ]]; then
        log_warn "Modulo WebTop non disponibile - skip raccolta email sharing"
        return 0
    fi
    
    log_info "Raccolta condivisioni email WebTop..."
    
    local output_file="$OUTPUT_DIR/04_webtop_email_shares.tsv"
    
    # Container Postgres
    local postgres_container=$(runagent -m "$WEBTOP_MODULE" podman ps --format '{{.Names}}' 2>/dev/null | grep -i postgres | head -1)
    
    if [[ -z "$postgres_container" ]]; then
        log_warn "Container Postgres non trovato"
        echo -e "owner\tshare_id\tmailbox_path\tshared_with\tpermissions" > "$output_file"
        echo -e "ERROR\tN/A\tPostgres container not found\tN/A\tN/A" >> "$output_file"
        return 1
    fi
    
    log_info "  Container Postgres: $postgres_container"
    
    # Rileva database WebTop
    local db_list=$(mktemp)
    if ! runagent -m "$WEBTOP_MODULE" podman exec "$postgres_container" \
        psql -U postgres -t -c '\l' > "$db_list" 2>/dev/null; then
        log_warn "Impossibile listare database"
        rm -f "$db_list"
        echo -e "owner\tshare_id\tmailbox_path\tshared_with\tpermissions" > "$output_file"
        echo -e "ERROR\tN/A\tDatabase list failed\tN/A\tN/A" >> "$output_file"
        return 1
    fi
    
    local webtop_db=$(grep -iE 'webtop' "$db_list" | awk '{print $1}' | head -1 || true)
    rm -f "$db_list"
    
    if [[ -z "$webtop_db" ]]; then
        log_warn "Database WebTop non trovato"
        echo -e "owner\tshare_id\tmailbox_path\tshared_with\tpermissions" > "$output_file"
        echo -e "ERROR\tN/A\tWebTop database not found\tN/A\tN/A" >> "$output_file"
        return 1
    fi
    
    log_info "  Database WebTop: $webtop_db"
    
    # Esegui query (metodo funzionante da ns8-biweekly-audit-report.sh)
    # Usa echo per passare query via stdin, evitando problemi con heredoc quando script eseguito via curl|bash
    local query="SELECT s.share_id, s.user_uid AS owner, s.service_id, s.key AS mailbox_path, s.instance, sd.user_uid AS shared_with, sd.value AS permissions FROM core.shares s LEFT JOIN core.shares_data sd ON s.share_id = sd.share_id WHERE s.service_id LIKE '%mail%' ORDER BY s.user_uid, s.share_id, sd.user_uid;"
    
    local temp_output="/tmp/webtop_raw_$$.txt"
    
    # Esegui query e post-processa output per ottenere TSV pulito
    if echo "$query" | runagent -m "$WEBTOP_MODULE" podman exec -i "$postgres_container" \
        psql -U postgres -d "$webtop_db" > "$temp_output" 2>/dev/null; then
        
        # Header TSV
        echo -e "share_id\towner\tservice_id\tmailbox_path\tinstance\tshared_with\tpermissions" > "$output_file"
        
        # Pulisci output PostgreSQL: rimuovi header/footer/borders, converti pipe in TAB
        # Filtra solo linee con dati (iniziano con spazio+numero oppure numero)
        if grep -qE "^\s*[0-9]+" "$temp_output" 2>/dev/null; then
            grep -E "^\s*[0-9]+" "$temp_output" | \
                sed 's/|/\t/g' | \
                sed 's/^\s\+//;s/\s\+$//' | \
                awk -F'\t' '{
                    # Trim ogni campo
                    for(i=1; i<=NF; i++) {
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
                    }
                    # Stampa solo se ha abbastanza campi
                    if (NF >= 6) print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$7
                }' >> "$output_file"
            
            local record_count=$(tail -n +2 "$output_file" 2>/dev/null | wc -l || echo "0")
            log_success "Raccolte $record_count condivisioni email → $(basename "$output_file")"
            rm -f "$temp_output"
        else
            log_warn "Nessuna condivisione email configurata"
            rm -f "$temp_output"
        fi
        return 0
    else
        log_error "Query Postgres fallita"
        echo -e "owner\tshare_id\tmailbox_path\tshared_with\tpermissions" > "$output_file"
        echo -e "ERROR\tN/A\tQuery failed\tN/A\tN/A" >> "$output_file"
        return 1
    fi
}

# Funzione 5: Genera report riepilogativo
generate_summary_report() {
    log_info "Generazione report riepilogativo..."
    
    local summary_file="$OUTPUT_DIR/REPORT_SUMMARY.txt"
    
    # Conta dati raccolti
    local user_count=$(wc -l < "$OUTPUT_DIR/01_users.txt" 2>/dev/null || echo 0)
    local pwd_count=$(tail -n +2 "$OUTPUT_DIR/02_password_expiry.tsv" 2>/dev/null | wc -l || echo 0)
    local share_count=$(wc -l < "$OUTPUT_DIR/03_shares/shares_list.txt" 2>/dev/null || echo 0)
    local webtop_share_count=$(tail -n +2 "$OUTPUT_DIR/04_webtop_email_shares.tsv" 2>/dev/null | wc -l || echo 0)
    
    # Password in scadenza (entro 7 giorni)
    local expiring_soon=0
    if [[ -f "$OUTPUT_DIR/02_password_expiry.tsv" ]]; then
        expiring_soon=$(awk -F'\t' '$7 != "N/A" && $7 <= 7 && $7 >= 0 {print}' "$OUTPUT_DIR/02_password_expiry.tsv" 2>/dev/null | wc -l || echo 0)
    fi
    
    # Password scadute
    local expired=0
    if [[ -f "$OUTPUT_DIR/02_password_expiry.tsv" ]]; then
        expired=$(awk -F'\t' '$7 != "N/A" && $7 < 0 {print}' "$OUTPUT_DIR/02_password_expiry.tsv" 2>/dev/null | wc -l || echo 0)
    fi
    
    # Crea summary
        cat > "$summary_file" <<EOF

                                        REPORT AUDIT QUINDICINALE NS8

        Data report:          $(date +"%Y-%m-%d %H:%M:%S")
        Directory output:     $OUTPUT_DIR

        ================================================================================
        RIEPILOGO DATI RACCOLTI
        ================================================================================

        Active Directory:
            - Utenti totali:                    $user_count
            - Utenti con analisi password:      $pwd_count
            - Password in scadenza (≤7 giorni): $expiring_soon
            - Password scadute:                  $expired
            - Gruppi AD totali:                  $(tail -n +2 "$OUTPUT_DIR/05_ad_groups.tsv" 2>/dev/null | wc -l || echo 0)

        Samba File Shares:
            - Share totali:                      $share_count
            - File ACL generati:                 $share_count

        WebTop Email Sharing:
            - Condivisioni email totali:         $webtop_share_count

        ================================================================================
        DETTAGLIO PASSWORD EXPIRY
        ================================================================================

EOF

    # Tabella password expiry
    if [[ -f "$OUTPUT_DIR/02_password_expiry.tsv" ]]; then
        echo "" >> "$summary_file"
        echo "LEGENDA:" >> "$summary_file"
        echo "  • Giorni positivi = password ancora valida" >> "$summary_file"
        echo "  • Giorni negativi = password SCADUTA" >> "$summary_file"
        echo "  • N/A = account senza password o Guest" >> "$summary_file"
    else
        echo "Nessun dato disponibile" >> "$summary_file"
    fi

    cat >> "$summary_file" <<EOF

================================================================================
DETTAGLIO GRUPPI AD E MEMBRI
================================================================================

EOF

    # Tabella gruppi AD (gruppo → utenti)
    if [[ -f "$OUTPUT_DIR/05_ad_groups.tsv" ]]; then
        cat >> "$summary_file" <<'EOF'
GRUPPO                                                      UTENTI PRESENTI NEL GRUPPO
------------------------------------------------------------ --------------------------------------------------------------------------------
EOF
        tail -n +2 "$OUTPUT_DIR/05_ad_groups.tsv" | while IFS=$'\t' read -r groupname count members; do
            [[ -z "$members" ]] && members="N/A"
            printf "%-60s %-80s\n" "$groupname" "$members"
        done >> "$summary_file"
    else
        echo "Nessun dato disponibile" >> "$summary_file"
    fi

    cat >> "$summary_file" <<EOF

================================================================================
DETTAGLIO SHARE SAMBA
================================================================================

EOF

    # Tabella share Samba con utenti RW/RO
    if [[ -f "$OUTPUT_DIR/03_shares/shares_report.tsv" ]]; then
        cat >> "$summary_file" <<'EOF'
NOME SHARE           UTENTI LETTURA/SCRITTURA                 UTENTI SOLA LETTURA
-------------------- ---------------------------------------- ----------------------------------------
EOF
        
        local acls_dir="$OUTPUT_DIR/03_shares/acls"
        
        # Itera su tutte le share
        tail -n +2 "$OUTPUT_DIR/03_shares/shares_report.tsv" | while IFS=$'\t' read -r share_name share_path acl_file; do
            [[ -z "$share_name" ]] && continue
            
            local users_rw=""
            local users_ro=""
            
            # Parse ACL file se esiste
            if [[ -f "$acl_file" ]] && grep -q "^ACL:" "$acl_file" 2>/dev/null; then
                # Leggi ACL Windows-style
                while IFS= read -r acl_line; do
                    [[ ! "$acl_line" =~ ^ACL: ]] && continue
                    
                    # Skip system accounts
                    [[ "$acl_line" =~ (NT\ AUTHORITY|BUILTIN) ]] && continue
                    
                    # Parse: ACL:DOMAIN\entity:ALLOWED/flags/perms
                    local entity=$(echo "$acl_line" | cut -d: -f2)
                    local perms=$(echo "$acl_line" | cut -d: -f3 | cut -d/ -f3)
                    
                    # Determina RW o RO
                    if [[ "$perms" =~ (FULL|RWXD|0x001301bf|0x001f01ff) ]]; then
                        users_rw="${users_rw}${entity}, "
                    elif [[ "$perms" =~ (READ|0x00120089) ]]; then
                        users_ro="${users_ro}${entity}, "
                    fi
                done < <(grep "^ACL:" "$acl_file")
                
                # Rimuovi virgola finale
                users_rw=$(echo "$users_rw" | sed 's/, $//')
                users_ro=$(echo "$users_ro" | sed 's/, $//')
            fi
            
            # Se nessun ACL, mostra N/A
            [[ -z "$users_rw" ]] && users_rw="N/A"
            [[ -z "$users_ro" ]] && users_ro="N/A"
            
            # Stampa riga formattata
            printf "%-20s %-40s %-40s\n" "$share_name" "${users_rw:0:40}" "${users_ro:0:40}" >> "$summary_file"
        done
    else
        echo "Nessun dato disponibile" >> "$summary_file"
    fi

    cat >> "$summary_file" <<EOF

================================================================================
DETTAGLIO CONDIVISIONI EMAIL WEBTOP
================================================================================

EOF

    # Tabella WebTop condivisioni
    local webtop_has_data=$(tail -n +2 "$OUTPUT_DIR/04_webtop_email_shares.tsv" 2>/dev/null | wc -l || echo 0)
    
    if [[ -f "$OUTPUT_DIR/04_webtop_email_shares.tsv" && $webtop_has_data -gt 0 ]]; then
        # Mappa UUID → username
        declare -A uuid_to_user
        
        if [[ -n "$WEBTOP_MODULE" ]]; then
            local postgres_container=$(runagent -m "$WEBTOP_MODULE" podman ps --format '{{.Names}}' 2>/dev/null | grep -i postgres | head -1 || echo "postgres")
            local webtop_db=$(runagent -m "$WEBTOP_MODULE" podman exec "$postgres_container" psql -U postgres -t -c "\l" 2>/dev/null | grep -iE 'webtop' | awk '{print $1}' | head -1 || echo "")
            
            if [[ -n "$webtop_db" ]]; then
                local uuid_map=$(echo "SELECT user_uid, user_id FROM core.users;" | runagent -m "$WEBTOP_MODULE" podman exec -i "$postgres_container" psql -U postgres -d "$webtop_db" -A -t -F $'\t' 2>/dev/null || echo "")
                
                while IFS=$'\t' read -r uuid username; do
                    [[ -n "$uuid" && -n "$username" ]] && uuid_to_user["$uuid"]="$username"
                done <<< "$uuid_map"
            fi
        fi
        
        cat >> "$summary_file" <<'EOF'
    MAILBOX/CARTELLA    PROPRIETARIO              CONDIVISO CON             PERMESSI
    ------------------- ------------------------- ------------------------- -------------------------
EOF
        
        tail -n +2 "$OUTPUT_DIR/04_webtop_email_shares.tsv" | while IFS=$'\t' read -r id owner svc path inst shared perms; do
            # Mappa UUID → username
            local owner_name="${uuid_to_user[$owner]:-${owner:0:12}...}"
            local shared_name="${uuid_to_user[$shared]:-${shared:0:12}...}"
            
            # Clean permissions JSON
            local perms_clean=$(echo "$perms" | sed 's/[{}":]//g' | tr ',' ' ' | cut -c1-25)
            
            printf "%-19s %-25s %-25s %-25s\n" "$path" "$owner_name" "$shared_name" "$perms_clean" >> "$summary_file"
        done
    else
        echo "Nessuna condivisione email configurata" >> "$summary_file"
    fi

    cat >> "$summary_file" <<EOF

================================================================================
FILE DATI ESPORTATI
================================================================================

1. Utenti AD:
   → 01_users.txt

2. Scadenze password (TSV):
   → 02_password_expiry.tsv

3. Share e permessi:
   → 03_shares/shares_list.txt
   → 03_shares/shares_report.tsv
   → 03_shares/acls/*.txt

4. WebTop email shares (TSV):
   → 04_webtop_email_shares.tsv

5. Gruppi AD e membri (TSV):
   → 05_ad_groups.tsv

================================================================================
AZIONI CONSIGLIATE
================================================================================

EOF

    # Aggiungi avvisi password
    if [[ $expired -gt 0 ]]; then
                cat >> "$summary_file" <<EOF
⚠ ATTENZIONE: $expired password SCADUTE!
    → Eseguire reset password immediato

EOF
    fi
    
    if [[ $expiring_soon -gt 0 ]]; then
                cat >> "$summary_file" <<EOF
⚠ ATTENZIONE: $expiring_soon password in scadenza entro 7 giorni
    → Notificare utenti per cambio password

EOF
    fi
    
        cat >> "$summary_file" <<EOF
Verifica permessi share:
    → Eseguire: ./acl-viewer.sh $OUTPUT_DIR
    → Oppure visualizzato automaticamente sotto (se abilitato)

Analisi dettagliata:
    → Aprire file TSV con foglio di calcolo
    → Filtrare/ordinare per priorità

===============================================================================

EOF
    
    log_success "Report riepilogativo generato → REPORT_SUMMARY.txt"
    
    # Mostra summary su stdout
    echo ""
    echo "================================================================================"
    cat "$summary_file"
    echo "================================================================================"
}

# ============================================================================
# VISUALIZZAZIONE TABELLE DETTAGLIATE
# ============================================================================

display_detailed_tables() {
    echo ""
    echo "================================================================================"
    echo "  DETTAGLI COMPLETI AUDIT NS8"
    echo "================================================================================"
    echo ""
    
    log_info "Visualizzazione tabelle dettagliate..."
    
    # ========== TABELLA 1: PASSWORD EXPIRY ==========
    echo "================================================================================"
    echo "DETTAGLIO PASSWORD EXPIRY"
    echo "================================================================================"
    echo ""
    
    if [[ -f "$OUTPUT_DIR/02_password_expiry.tsv" ]]; then
        printf "%-19s %-20s %-20s %10s\n" "UTENTE" "ULTIMA MODIFICA" "SCADE IL" "GIORNI"
        printf "%-19s %-20s %-20s %10s\n" "-------------------" "--------------------" "--------------------" "----------"
        
        tail -n +2 "$OUTPUT_DIR/02_password_expiry.tsv" | while IFS=$'\t' read -r user pwd_raw pwd_unix pwd_iso exp_unix exp_iso days; do
            printf "%-19s %-20s %-20s %10s\n" "$user" "$pwd_iso" "$exp_iso" "$days"
        done
        
        echo ""
        echo "LEGENDA:"
        echo "  • Giorni positivi = password ancora valida"
        echo "  • Giorni negativi = password SCADUTA"
        echo "  • N/A = account senza password o Guest"
    else
        echo "Nessun dato disponibile"
    fi
    
    echo ""
    
    # ========== TABELLA 2: GRUPPI AD ==========
    echo "================================================================================"
    echo "DETTAGLIO GRUPPI AD E MEMBRI"
    echo "================================================================================"
    echo ""
    
    if [[ -f "$OUTPUT_DIR/05_ad_groups.tsv" ]]; then
        printf "%-60s %-70s\n" "GRUPPO" "UTENTI PRESENTI NEL GRUPPO"
        printf "%-60s %-70s\n" "------------------------------------------------------------" "----------------------------------------------------------------------"
        
        tail -n +2 "$OUTPUT_DIR/05_ad_groups.tsv" | while IFS=$'\t' read -r groupname count members; do
            [[ -z "$members" ]] && members="N/A"
            printf "%-60s %-70s\n" "$groupname" "$members"
        done
        
        echo ""
        echo "NOTA: Per lista membri completa vedere file 05_ad_groups.tsv"
    else
        echo "Nessun dato disponibile"
    fi
    
    echo ""
    
    # ========== TABELLA 3: SHARE SAMBA ==========
    echo "================================================================================"
    echo "DETTAGLIO SHARE SAMBA"
    echo "================================================================================"
    echo ""
    
    if [[ -f "$OUTPUT_DIR/03_shares/shares_report.tsv" ]]; then
        printf "%-20s %-40s %-40s\n" "NOME SHARE" "UTENTI LETTURA/SCRITTURA" "UTENTI SOLA LETTURA"
        printf "%-20s %-40s %-40s\n" "--------------------" "----------------------------------------" "----------------------------------------"
        
        local acls_dir="$OUTPUT_DIR/03_shares/acls"
        
        # Itera su tutte le share
        tail -n +2 "$OUTPUT_DIR/03_shares/shares_report.tsv" | while IFS=$'\t' read -r share_name share_path acl_file; do
            [[ -z "$share_name" ]] && continue
            
            local users_rw=""
            local users_ro=""
            
            # Parse ACL file se esiste
            if [[ -f "$acl_file" ]] && grep -q "^ACL:" "$acl_file" 2>/dev/null; then
                # Leggi ACL Windows-style
                while IFS= read -r acl_line; do
                    [[ ! "$acl_line" =~ ^ACL: ]] && continue
                    
                    # Skip system accounts
                    [[ "$acl_line" =~ (NT\ AUTHORITY|BUILTIN) ]] && continue
                    
                    # Parse: ACL:DOMAIN\entity:ALLOWED/flags/perms
                    local entity=$(echo "$acl_line" | cut -d: -f2)
                    local perms=$(echo "$acl_line" | cut -d: -f3 | cut -d/ -f3)
                    
                    # Determina RW o RO
                    if [[ "$perms" =~ (FULL|RWXD|0x001301bf|0x001f01ff) ]]; then
                        users_rw="${users_rw}${entity}, "
                    elif [[ "$perms" =~ (READ|0x00120089) ]]; then
                        users_ro="${users_ro}${entity}, "
                    fi
                done < <(grep "^ACL:" "$acl_file")
                
                # Rimuovi virgola finale
                users_rw=$(echo "$users_rw" | sed 's/, $//')
                users_ro=$(echo "$users_ro" | sed 's/, $//')
            fi
            
            # Se nessun ACL, mostra N/A
            [[ -z "$users_rw" ]] && users_rw="N/A"
            [[ -z "$users_ro" ]] && users_ro="N/A"
            
            # Stampa riga formattata
            printf "%-20s %-40s %-40s\n" "$share_name" "${users_rw:0:40}" "${users_ro:0:40}"
        done
        
        echo ""
        echo "NOTA: Per ACL e permessi POSIX dettagliati vedere sezione 'REPORT PERMESSI SHARE' sotto"
    else
        echo "Nessun dato disponibile"
    fi
    
    echo ""
    
    # ========== TABELLA 4: CONDIVISIONI EMAIL WEBTOP ==========
    echo "================================================================================"
    echo "DETTAGLIO CONDIVISIONI EMAIL WEBTOP"
    echo "================================================================================"
    echo ""
    
    local webtop_share_count=$(tail -n +2 "$OUTPUT_DIR/04_webtop_email_shares.tsv" 2>/dev/null | wc -l || echo 0)
    
    if [[ -f "$OUTPUT_DIR/04_webtop_email_shares.tsv" && $webtop_share_count -gt 0 ]]; then
        # Mappa UUID → username da database WebTop
        declare -A uuid_to_user
        
        if [[ -n "$WEBTOP_MODULE" ]]; then
            local postgres_container=$(runagent -m "$WEBTOP_MODULE" podman ps --format '{{.Names}}' 2>/dev/null | grep -i postgres | head -1 || echo "postgres")
            local webtop_db=$(runagent -m "$WEBTOP_MODULE" podman exec "$postgres_container" psql -U postgres -t -c "\l" 2>/dev/null | grep -iE 'webtop' | awk '{print $1}' | head -1 || echo "")
            
            if [[ -n "$webtop_db" ]]; then
                # Query per mappare user_uid → user_id (username)
                local uuid_map=$(echo "SELECT user_uid, user_id FROM core.users;" | runagent -m "$WEBTOP_MODULE" podman exec -i "$postgres_container" psql -U postgres -d "$webtop_db" -A -t -F $'\t' 2>/dev/null || echo "")
                
                # Popola array associativo
                while IFS=$'\t' read -r uuid username; do
                    [[ -n "$uuid" && -n "$username" ]] && uuid_to_user["$uuid"]="$username"
                done <<< "$uuid_map"
            fi
        fi
        
        printf "%-4s %-19s %-25s %-25s %s\n" "ID" "MAILBOX/CARTELLA" "PROPRIETARIO" "CONDIVISO CON" "PERMESSI"
        printf "%-4s %-19s %-25s %-25s %s\n" "----" "-------------------" "-------------------------" "-------------------------" "-------------------------"
        
        tail -n +2 "$OUTPUT_DIR/04_webtop_email_shares.tsv" | while IFS=$'\t' read -r id owner svc path inst shared perms; do
            # Mappa UUID → username (se disponibile, altrimenti mostra UUID abbreviato)
            local owner_name="${uuid_to_user[$owner]:-${owner:0:8}...}"
            local shared_name="${uuid_to_user[$shared]:-${shared:0:8}...}"
            
            # Estrai info da JSON permissions
            local perms_clean=$(echo "$perms" | sed 's/[{}"]//g' | sed 's/,/ /g' | sed 's/://g' | cut -c1-35)
            
            printf "%-4s %-19s %-25s %-25s %s\n" "$id" "$path" "$owner_name" "$shared_name" "$perms_clean"
        done
        
        echo ""
        echo "NOTA: Username mappati automaticamente da database WebTop"
    else
        echo "Nessuna condivisione email configurata"
    fi
    
    echo ""
}

# ============================================================================
# VISUALIZZAZIONE ACL - Integrato da acl-viewer.sh
# ============================================================================

# Traduzione permessi Windows → Italiano
translate_permissions() {
    local perms="$1"
    case "$perms" in
        *FULL*|*0x001f01ff*)
            echo "Controllo Totale"
            ;;
        *RWXD*|*0x001301bf*)
            echo "Lettura e Scrittura"
            ;;
        *READ*|*0x00120089*)
            echo "Solo Lettura"
            ;;
        *)
            echo "Permessi: $perms"
            ;;
    esac
}

# Visualizzazione report ACL
display_acl_report() {
    if [[ "$SHOW_ACL_REPORT" -eq 0 ]]; then
        log_info "Visualizzazione ACL disabilitata (--no-display)"
        return 0
    fi
    
    log_info "Visualizzazione report ACL permessi share..."
    
    local acl_dir="$OUTPUT_DIR/03_shares/acls"
    
    if [[ ! -d "$acl_dir" ]]; then
        log_warn "Directory ACL non trovata: $acl_dir"
        return 1
    fi
    
    local share_files=$(find "$acl_dir" -name "*_smbacl.txt" -type f 2>/dev/null | wc -l || echo 0)
    
    if [[ $share_files -eq 0 ]]; then
        log_warn "Nessun file ACL trovato"
        return 1
    fi
    
    # Header tabella
    echo ""
    echo "==============================================================================="
    echo "  REPORT PERMESSI SHARE NS8"
    echo "==============================================================================="
    echo ""
    echo "Audit directory: $OUTPUT_DIR"
    echo ""
    
    # Header tabella
    printf "%-20s %-35s %-30s %-25s\n" "SHARE" "PERCORSO" "ENTITA" "PERMESSI"
    printf "%-20s %-35s %-30s %-25s\n" \
        "--------------------" \
        "-----------------------------------" \
        "------------------------------" \
        "-------------------------"
    
    # Conta share
    local share_count=0
    local shares_report="$OUTPUT_DIR/03_shares/shares_report.tsv"
    
    # Itera su tutti i file ACL
    for acl_file in $(find "$acl_dir" -name "*_smbacl.txt" -type f | sort); do
        local share_name=$(basename "$acl_file" _smbacl.txt)
        share_count=$((share_count + 1))
        
        # Leggi path dalla shares_report.tsv
        local share_path=""
        if [[ -f "$shares_report" ]]; then
            share_path=$(grep "^$share_name	" "$shares_report" | cut -f2 || echo "N/A")
        fi
        
        # Detect del tipo di ACL (smbcacls vs getfacl)
        local acl_type="unknown"
        if grep -q "^ACL:" "$acl_file" 2>/dev/null; then
            acl_type="smbacl"
        elif grep -q "^# file:" "$acl_file" 2>/dev/null; then
            acl_type="posix"
        fi
        
        local has_acl=0
        local first_line=1
        
        if [[ "$acl_type" == "smbacl" ]]; then
            # Parse ACL Windows-style (smbcacls)
            local acl_lines=$(grep "^ACL:" "$acl_file" | grep -vE "^ACL:(NT AUTHORITY|BUILTIN)" || true)
            
            if [[ -n "$acl_lines" ]]; then
                has_acl=1
                # Processa ogni ACL
                echo "$acl_lines" | while IFS= read -r acl_line; do
                    [[ -z "$acl_line" ]] && continue
                    
                    # Parse ACL: ACL:DOMAIN\entity:ALLOWED/flags/perms
                    local entity=$(echo "$acl_line" | cut -d: -f2)
                    local perms=$(echo "$acl_line" | cut -d: -f3 | cut -d/ -f3)
                    
                    # Traduzione permessi
                    local perms_italian=$(translate_permissions "$perms")
                    
                    # Prima riga mostra share e path, successive solo entità e permessi
                    if [[ $first_line -eq 1 ]]; then
                        printf "%-20s %-35s %-30s %-25s\n" \
                            "$share_name" \
                            "${share_path:0:35}" \
                            "${entity:0:30}" \
                            "$perms_italian"
                        first_line=0
                    else
                        printf "%-20s %-35s %-30s %-25s\n" \
                            "" \
                            "" \
                            "${entity:0:30}" \
                            "$perms_italian"
                    fi
                done
            fi
            
        elif [[ "$acl_type" == "posix" ]]; then
            # Parse ACL POSIX (getfacl)
            local acl_lines=$(grep -E "^(user|group):[^:]+:" "$acl_file" | grep -v ":---$" || true)
            
            if [[ -n "$acl_lines" ]]; then
                has_acl=1
                # Processa ogni ACL
                echo "$acl_lines" | while IFS= read -r acl_line; do
                    [[ -z "$acl_line" ]] && continue
                    
                    # Parse: user:username:rwx o group:groupname:rwx
                    local type=$(echo "$acl_line" | cut -d: -f1)
                    local entity=$(echo "$acl_line" | cut -d: -f2)
                    local perms=$(echo "$acl_line" | cut -d: -f3)
                    
                    # Skip se entity vuoto (user::rwx sono permessi owner di default)
                    [[ -z "$entity" ]] && continue
                    
                    # Format entity (aggiungi prefisso user/group)
                    if [[ "$type" == "user" ]]; then
                        entity="[user] $entity"
                    else
                        entity="[group] $entity"
                    fi
                    
                    # Prima riga mostra share e path
                    if [[ $first_line -eq 1 ]]; then
                        printf "%-20s %-35s %-30s %-25s\n" \
                            "$share_name" \
                            "${share_path:0:35}" \
                            "${entity:0:30}" \
                            "$perms"
                        first_line=0
                    else
                        printf "%-20s %-35s %-30s %-25s\n" \
                            "" \
                            "" \
                            "${entity:0:30}" \
                            "$perms"
                    fi
                done
            fi
        fi
        
        # Se nessun ACL trovato, mostra "[solo sistema]"
        if [[ $has_acl -eq 0 ]]; then
            printf "%-20s %-35s %-30s %-25s\n" \
                "$share_name" \
                "${share_path:0:35}" \
                "[solo sistema]" \
                "-"
        fi
    done
    
    # Footer
    echo ""
    echo "==============================================================================="
    echo "Totale share analizzate: $share_count"
    echo ""
    echo "NOTE:"
    echo "  - Per vedere i membri di un gruppo AD:"
    echo "    runagent -m $SAMBA_MODULE podman exec samba-dc samba-tool group listmembers NOME_GRUPPO"
    echo ""
    
    log_success "Report ACL visualizzato"
    return 0
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    echo "================================================================================"
    echo "NS8 Audit Report - Unified Version (Collector + Viewer)"
    echo "================================================================================"
    echo ""
    
    check_prerequisites
    echo ""
    
    # Fase 1: Raccolta dati
    collect_ad_users
    collect_password_expiry
    collect_ad_groups
    collect_samba_shares
    collect_webtop_sharing
    
    echo ""
    
    # Fase 2: Genera report riepilogativo
    generate_summary_report
    
    echo ""
    
    # Fase 3: Visualizza tabelle dettagliate
    display_detailed_tables
    
    # Fase 4: Visualizza report ACL (se abilitato)
    display_acl_report
    
    echo ""
    log_success "Report completato!"
    log_info "Output salvato in: $OUTPUT_DIR"
    
    return 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir)
            OUTPUT_BASE="$2"
            shift 2
            ;;
        --no-display)
            SHOW_ACL_REPORT=0
            shift
            ;;
        --help)
            echo "Uso: $0 [opzioni]"
            echo ""
            echo "Opzioni:"
            echo "  --output-dir /path    Directory base output (default: /var/tmp)"
            echo "  --no-display          Disabilita visualizzazione report ACL"
            echo "  --help                Mostra questo help"
            exit 0
            ;;
        *)
            log_error "Opzione sconosciuta: $1"
            echo "Usa --help per vedere le opzioni disponibili"
            exit 1
            ;;
    esac
done

# Run
main "$@"
