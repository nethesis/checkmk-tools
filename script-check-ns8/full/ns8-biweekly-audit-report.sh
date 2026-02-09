#!/bin/bash
################################################################################
# NS8 Biweekly Audit Report - Monolithic Version
################################################################################
# Scopo: Report quindicinale completo ambiente NethServer 8
#
# Raccoglie:
#   1) Utenti Active Directory (Samba)
#   2) Scadenze password utenti AD
#   3) Permessi share di rete (Samba)
#   4) Condivisioni account posta WebTop (se disponibile)
#
# Output: Directory /var/tmp/ns8-audit-YYYYMMDD-HHMMSS/
#
# Uso:
#   ./ns8-biweekly-audit-report.sh
#   ./ns8-biweekly-audit-report.sh --output-dir /custom/path
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

# Funzione 3: Raccolta share e permessi
collect_samba_shares() {
    log_info "Raccolta share Samba e permessi..."
    
    local output_dir="$OUTPUT_DIR/03_shares"
    local share_list="$output_dir/share_list.txt"
    local share_report="$output_dir/shares_report.tsv"
    local acl_dir="$output_dir/acls"
    
    mkdir -p "$acl_dir"
    
    # Estrai configurazione Samba
    local testparm_output=$(mktemp)
    if ! runagent -m "$SAMBA_MODULE" podman exec samba-dc testparm -s 2>/dev/null > "$testparm_output"; then
        log_error "Fallito testparm -s"
        rm -f "$testparm_output"
        return 1
    fi
    
    # Parse share names (righe tipo [sharename])
    grep -E '^\[.*\]$' "$testparm_output" | tr -d '[]' | grep -vE '^(global|homes|printers)$' > "$share_list" || true
    
    local share_count=$(wc -l < "$share_list")
    
    if [[ $share_count -eq 0 ]]; then
        log_warn "Nessuna share trovata in testparm output"
        echo "No shares found" > "$share_report"
        rm -f "$testparm_output"
        return 0
    fi
    
    log_info "Trovate $share_count share, estrazione path e ACL..."
    
    # Header TSV report
    echo -e "share_name\tpath\tacl_collected\tacl_file" > "$share_report"
    
    while IFS= read -r share_name; do
        [[ -z "$share_name" ]] && continue
        
        # Estrai path della share
        local share_path=$(awk -v share="$share_name" '
            $0 ~ "^\\[" share "\\]$" { found=1; next }
            found && /^\[/ { found=0 }
            found && /^[[:space:]]*path[[:space:]]*=/ { print $3; exit }
        ' "$testparm_output")
        
        if [[ -z "$share_path" ]]; then
            log_warn "  $share_name: path non trovato"
            echo -e "$share_name\tN/A\tNO\tN/A" >> "$share_report"
            continue
        fi
        
        # Raccogli ACL Windows-style (smbcacls) - mostra permessi configurati in NS8 UI
        local smbacl_file="$acl_dir/${share_name}_smbacl.txt"
        local admin_pass="Nethesis,1234"  # Password di default NS8
        
        if runagent -m "$SAMBA_MODULE" podman exec samba-dc smbcacls "//localhost/$share_name" / -U "administrator%$admin_pass" > "$smbacl_file" 2>/dev/null; then
            log_success "  $share_name: $share_path [ACL Windows OK]"
            echo -e "$share_name\t$share_path\tYES\t$(basename "$smbacl_file")" >> "$share_report"
        else
            # Fallback: usa getfacl (ACL filesystem POSIX) se smbcacls fallisce
            local acl_file="$acl_dir/${share_name}.acl"
            if runagent -m "$SAMBA_MODULE" podman exec samba-dc getfacl "$share_path" > "$acl_file" 2>/dev/null; then
                log_success "  $share_name: $share_path [ACL POSIX OK]"
                echo -e "$share_name\t$share_path\tYES\t$(basename "$acl_file")" >> "$share_report"
            else
                log_warn "  $share_name: ACL non disponibile per $share_path"
                echo "ERROR: Unable to get ACL for $share_path" > "$acl_file"
                echo -e "$share_name\t$share_path\tNO\t$(basename "$acl_file")" >> "$share_report"
            fi
        fi
        
    done < "$share_list"
    
    # Espandi membri gruppi trovati negli ACL
    log_info "Espansione gruppi AD in utenti..."
    local group_expansion_file="$output_dir/group_members.map"
    > "$group_expansion_file"  # Crea file vuoto
    
    # Trova tutti i nomi entità negli ACL Windows - salva su file per preservare backslash
    local entities_temp=$(mktemp)
    grep -h "^ACL:" "$acl_dir"/*_smbacl.txt 2>/dev/null | grep -vE "^ACL:(NT AUTHORITY|BUILTIN)" | cut -d: -f2 | sort -u > "$entities_temp"
    
    local entity_count=$(wc -l < "$entities_temp")
    log_info "  Entità trovate: $entity_count"
    
    # Usa while con -r per evitare interpretazione backslash come escape
    while IFS= read -r entity_full; do
        [[ -z "$entity_full" ]] && continue
        
        # Rimuovi dominio (es. "NLABNS8\test1" → "test1") 
        local entity_name=$(echo "$entity_full" | awk -F'\\' '{print $NF}')
        [[ -z "$entity_name" ]] && continue
        [[ "$entity_name" == "Everyone" ]] && continue
        
        log_info "  Verifica $entity_name (da: $entity_full)..."
        
        # Prova a ottenere membri del gruppo (con timeout 10 secondi)
        # CRITICO: stdin < /dev/null previene hang quando chiamato dentro while loop
        local members=$(timeout 10 runagent -m "$SAMBA_MODULE" podman exec samba-dc samba-tool group listmembers "$entity_name" < /dev/null 2>/dev/null || true)
        
        if [[ -n "$members" ]]; then
            # È un gruppo - salva mapping gruppo→utenti
            local member_count=0
            while IFS= read -r member; do
                [[ -z "$member" ]] && continue
                echo "$entity_name:$member" >> "$group_expansion_file"
                ((member_count++))
            done <<< "$members"
            log_info "    → $entity_name: gruppo con $member_count membri"
        else
            log_info "    → $entity_name: non è un gruppo o nessun membro"
        fi
    done < "$entities_temp"
    
    rm -f "$entities_temp"
    
    rm -f "$testparm_output"
    log_success "Share report completato → 03_shares/"
    return 0
}

# Funzione 4: Raccolta condivisioni email
collect_webtop_sharing() {
    log_info "Raccolta condivisioni email (WebTop e Dovecot)..."
    
    local output_dir="$OUTPUT_DIR/04_mail_sharing"
    mkdir -p "$output_dir"
    
    local has_data=0
    
    # === PARTE 1: WebTop (se disponibile) ===
    if [[ -n "$WEBTOP_MODULE" ]]; then
        log_info "  Verifica WebTop..."
        
        # Verifica presenza container Postgres
        local postgres_container=$(runagent -m "$WEBTOP_MODULE" podman ps --format '{{.Names}}' 2>/dev/null | grep -i postgres || true)
        
        if [[ -n "$postgres_container" ]]; then
            log_info "  Container Postgres: $postgres_container"
            
            # Estrai lista database
            local db_list=$(mktemp)
            if runagent -m "$WEBTOP_MODULE" podman exec "$postgres_container" \
                psql -U postgres -t -c '\l' > "$db_list" 2>/dev/null; then
                
                # Cerca database webtop
                local webtop_db=$(grep -iE 'webtop' "$db_list" | awk '{print $1}' | head -1 || true)
                rm -f "$db_list"
                
                if [[ -n "$webtop_db" ]]; then
                    log_info "  Database WebTop: $webtop_db"
                    
                    # Query condivisioni mailbox (con JOIN per ottenere permessi da shares_data)
                    # service_id per mail è tipicamente 'com.sonicle.webtop.mail'
                    # Uso stdin (<<'EOSQL') per evitare problemi di quoting multilivello
                    local webtop_output="$output_dir/webtop_mail_shares.txt"
                    if runagent -m "$WEBTOP_MODULE" podman exec -i "$postgres_container" \
                        psql -U postgres -d "$webtop_db" > "$webtop_output" 2>/dev/null <<'EOSQL'
SELECT s.share_id, s.user_uid AS owner, s.service_id, s.key AS mailbox_path, s.instance, sd.user_uid AS shared_with, sd.value AS permissions FROM core.shares s LEFT JOIN core.shares_data sd ON s.share_id = sd.share_id WHERE s.service_id LIKE '%mail%' ORDER BY s.user_uid, s.share_id, sd.user_uid;
EOSQL
                    then
                        # Verifica se ci sono dati reali (psql output contiene "(0 rows)" se vuoto)
                        if grep -q "(0 rows)" "$webtop_output" 2>/dev/null; then
                            log_warn "  WebTop: Nessuna condivisione mail configurata"
                            echo "No mail sharing configured in WebTop" > "$webtop_output"
                        else
                            local record_count=$(grep -c "^[[:space:]]*[0-9]" "$webtop_output" 2>/dev/null || echo "0")
                            log_success "  WebTop condivisioni raccolte ($record_count records)"
                            has_data=1
                        fi
                    else
                        log_warn "  WebTop: Query fallita"
                        echo "WebTop query failed" > "$webtop_output"
                    fi
                fi
            else
                rm -f "$db_list"
            fi
        else
            log_warn "  WebTop container Postgres non trovato"
            echo "WebTop: Postgres container not found" > "$output_dir/webtop_status.txt"
        fi
    fi
    
    # === PARTE 2: Dovecot Shared Mailboxes ===
    log_info "  Verifica Dovecot shared mailboxes..."
    
    # Cerca moduli mail
    local mail_modules=$(runagent --list-modules 2>/dev/null | grep -E '^mail[0-9]+$' || true)
    
    if [[ -n "$mail_modules" ]]; then
        local mail_module=$(echo "$mail_modules" | head -1)
        log_info "  Modulo Mail: $mail_module"
        
        # Verifica container dovecot
        local dovecot_container=$(runagent -m "$mail_module" podman ps --format '{{.Names}}' 2>/dev/null | grep -i dovecot || true)
        
        if [[ -n "$dovecot_container" ]]; then
            log_info "  Container Dovecot: $dovecot_container"
            
            local dovecot_report="$output_dir/dovecot_shared_mailboxes.txt"
            echo "=== Dovecot Shared Mailboxes Report ===" > "$dovecot_report"
            echo "Generated: $(date)" >> "$dovecot_report"
            echo "" >> "$dovecot_report"
            
            # Trova tutti gli utenti con mailbox
            local vmail_users=$(runagent -m "$mail_module" podman exec "$dovecot_container" \
                ls -1 /var/lib/vmail/ 2>/dev/null | grep -v '^\.' || true)
            
            local share_found=0
            
            while IFS= read -r user; do
                [[ -z "$user" ]] && continue
                
                # Cerca file ACL in tutte le sottodirectory dell'utente
                local acl_files=$(runagent -m "$mail_module" podman exec "$dovecot_container" \
                    find "/var/lib/vmail/$user" -type f -name 'dovecot-acl' 2>/dev/null || true)
                
                if [[ -n "$acl_files" ]]; then
                    while IFS= read -r acl_file; do
                        [[ -z "$acl_file" ]] && continue
                        
                        # Leggi contenuto ACL
                        local acl_content=$(runagent -m "$mail_module" podman exec "$dovecot_container" \
                            cat "$acl_file" 2>/dev/null || true)
                        
                        if [[ -n "$acl_content" ]]; then
                            # Estrai folder name dal path
                            local folder=$(echo "$acl_file" | sed "s|/var/lib/vmail/$user/Maildir/||" | sed 's|/dovecot-acl||')
                            [[ -z "$folder" ]] && folder="INBOX"
                            
                            echo "Mailbox Owner: $user" >> "$dovecot_report"
                            echo "Shared Folder: $folder" >> "$dovecot_report"
                            echo "ACL File: $acl_file" >> "$dovecot_report"
                            echo "Permissions:" >> "$dovecot_report"
                            
                            # Parse ACL lines (format: user=username lrwstipekxa)
                            while IFS= read -r acl_line; do
                                [[ -z "$acl_line" ]] && continue
                                [[ "$acl_line" =~ ^# ]] && continue  # Skip comments
                                
                                local acl_user=$(echo "$acl_line" | awk '{print $1}' | cut -d= -f2)
                                local acl_perms=$(echo "$acl_line" | awk '{print $2}')
                                
                                # Decodifica permessi Dovecot
                                local perm_desc=""
                                [[ "$acl_perms" == *l* ]] && perm_desc="${perm_desc}Lookup "
                                [[ "$acl_perms" == *r* ]] && perm_desc="${perm_desc}Read "
                                [[ "$acl_perms" == *w* ]] && perm_desc="${perm_desc}Write "
                                [[ "$acl_perms" == *s* ]] && perm_desc="${perm_desc}Seen "
                                [[ "$acl_perms" == *t* ]] && perm_desc="${perm_desc}DeleteMsg "
                                [[ "$acl_perms" == *i* ]] && perm_desc="${perm_desc}Insert "
                                [[ "$acl_perms" == *p* ]] && perm_desc="${perm_desc}Post "
                                [[ "$acl_perms" == *e* ]] && perm_desc="${perm_desc}Expunge "
                                [[ "$acl_perms" == *k* ]] && perm_desc="${perm_desc}CreateSubfolder "
                                [[ "$acl_perms" == *x* ]] && perm_desc="${perm_desc}DeleteFolder "
                                [[ "$acl_perms" == *a* ]] && perm_desc="${perm_desc}Admin "
                                
                                echo "  - User: $acl_user" >> "$dovecot_report"
                                echo "    Permissions: $perm_desc($acl_perms)" >> "$dovecot_report"
                                
                            done <<< "$acl_content"
                            
                            echo "" >> "$dovecot_report"
                            share_found=1
                        fi
                    done <<< "$acl_files"
                fi
            done <<< "$vmail_users"
            
            if [[ $share_found -eq 0 ]]; then
                echo "No shared mailboxes found" >> "$dovecot_report"
                log_info "  Nessuna mailbox condivisa trovata"
            else
                log_success "  Dovecot shared mailboxes raccolte"
                has_data=1
            fi
        else
            log_warn "  Container Dovecot non trovato"
            echo "Dovecot: container not found" > "$output_dir/dovecot_status.txt"
        fi
    else
        log_warn "  Nessun modulo mail trovato"
        echo "No mail module found" > "$output_dir/mail_module_status.txt"
    fi
    
    if [[ $has_data -eq 0 ]]; then
        echo "No mail sharing data available (WebTop not active, Dovecot no shares)" > "$output_dir/summary.txt"
    fi
    
    log_success "Raccolta condivisioni email completata → 04_mail_sharing/"
    return 0
}

# Funzione analisi e report finale
generate_summary_report() {
    log_info "Generazione report riepilogativo..."
    
    local summary_file="$OUTPUT_DIR/REPORT_SUMMARY.txt"
    
    cat > "$summary_file" << EOF
╔════════════════════════════════════════════════════════════════════════════╗
║                     REPORT AUDIT QUINDICINALE NS8                          ║
╚════════════════════════════════════════════════════════════════════════════╝

Data generazione: $(date +"%d/%m/%Y alle %H:%M")
Server: $(hostname)
Cartella dati completi: $OUTPUT_DIR

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 UTENTI DEL DOMINIO (Active Directory)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    
    # Analisi utenti
    if [[ -f "$OUTPUT_DIR/01_users.txt" ]]; then
        local user_count=$(grep -v "^ERROR" "$OUTPUT_DIR/01_users.txt" | wc -l)
        echo "Numero totale utenti: $user_count" >> "$summary_file"
        echo "" >> "$summary_file"
        echo "Elenco utenti:" >> "$summary_file"
        grep -v "^ERROR" "$OUTPUT_DIR/01_users.txt" | sed 's/^/  • /' >> "$summary_file"
    else
        echo "⚠️  Dati utenti non disponibili" >> "$summary_file"
    fi
    
    cat >> "$summary_file" << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔐 SCADENZA PASSWORD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    
    # Analisi scadenze password
    if [[ -f "$OUTPUT_DIR/02_password_expiry.tsv" ]]; then
        local total_users=$(tail -n +2 "$OUTPUT_DIR/02_password_expiry.tsv" | wc -l)
        local expiring_soon=$(tail -n +2 "$OUTPUT_DIR/02_password_expiry.tsv" | awk -F'\t' '$7 != "N/A" && $7 < 7 {count++} END {print count+0}')
        local expired=$(tail -n +2 "$OUTPUT_DIR/02_password_expiry.tsv" | awk -F'\t' '$7 != "N/A" && $7 < 0 {count++} END {print count+0}')
        
        echo "Utenti analizzati: $total_users" >> "$summary_file"
        echo "Password in scadenza (< 7 giorni): $expiring_soon" >> "$summary_file"
        echo "Password già scadute: $expired" >> "$summary_file"
        echo "Durata massima password (policy dominio): $MAX_PWD_AGE_DAYS giorni" >> "$summary_file"
        echo "" >> "$summary_file"
        
        if [[ $expiring_soon -gt 0 ]] || [[ $expired -gt 0 ]]; then
            echo "⚠️  ATTENZIONE - Utenti con password in scadenza o scadute:" >> "$summary_file"
            echo "" >> "$summary_file"
            tail -n +2 "$OUTPUT_DIR/02_password_expiry.tsv" | awk -F'\t' '$7 != "N/A" && $7 < 7 {
                split($6, date_parts, " ");
                split(date_parts[1], ymd, "-");
                italian_date = ymd[3]"/"ymd[2]"/"ymd[1];
                if ($7 < 0) {
                    days = -$7;
                    printf "  • %s - SCADUTA da %d giorni (il %s)\n", $1, days, italian_date
                } else if ($7 == 0) {
                    printf "  • %s - SCADE OGGI (il %s)\n", $1, italian_date
                } else {
                    printf "  • %s - scade tra %d giorni (il %s)\n", $1, $7, italian_date
                }
            }' >> "$summary_file"
        else
            echo "✅ Tutte le password sono valide" >> "$summary_file"
        fi
    else
        echo "⚠️  Dati scadenze password non disponibili" >> "$summary_file"
    fi
    
    cat >> "$summary_file" << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 CARTELLE CONDIVISE E PERMESSI
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    
    # Analisi share
    if [[ -f "$OUTPUT_DIR/03_shares/shares_report.tsv" ]]; then
        local share_count=$(tail -n +2 "$OUTPUT_DIR/03_shares/shares_report.tsv" | wc -l)
        local acl_collected=$(tail -n +2 "$OUTPUT_DIR/03_shares/shares_report.tsv" | awk -F'\t' '$3 == "YES" {count++} END {print count+0}')
        
        echo "Numero cartelle condivise: $share_count" >> "$summary_file"
        echo "Permessi raccolti: $acl_collected/$share_count" >> "$summary_file"
        echo "" >> "$summary_file"
        echo "Riepilogo cartelle:" >> "$summary_file"
        echo "" >> "$summary_file"
        tail -n +2 "$OUTPUT_DIR/03_shares/shares_report.tsv" | while IFS=$'\t' read -r name path acl file; do
            echo "  📂 $name" >> "$summary_file"
            echo "     Percorso: $path" >> "$summary_file"
            [[ "$acl" == "YES" ]] && echo "     ✅ Permessi dettagliati disponibili" >> "$summary_file" || echo "     ⚠️  Permessi non disponibili" >> "$summary_file"
            echo "" >> "$summary_file"
        done
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$summary_file"
        echo "DETTAGLIO PERMESSI PER OGNI CARTELLA" >> "$summary_file"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$summary_file"
        echo "" >> "$summary_file"
        
        # Analizza ACL per ogni share
        while IFS=$'\t' read -r share_name path acl_collected acl_file; do
            [[ "$share_name" == "share_name" ]] && continue  # Skip header
            [[ "$acl_collected" != "YES" ]] && continue
            
            echo "📂 CARTELLA: $share_name" >> "$summary_file"
            echo "   Percorso: $path" >> "$summary_file"
            echo "" >> "$summary_file"
            
            # Prova prima con ACL Windows-style (smbcacls)
            local smbacl_path="$OUTPUT_DIR/03_shares/acls/${share_name}_smbacl.txt"
            local acl_path="$OUTPUT_DIR/03_shares/acls/$acl_file"
            
            if [[ -f "$smbacl_path" ]]; then
                # Parse ACL Windows (formato: ACL:DOMAIN\username:ALLOWED/flags/permissions)
                local user_acls=$(grep "^ACL:" "$smbacl_path" | grep -vE "^ACL:(NT AUTHORITY|BUILTIN)")
                
                if [[ -n "$user_acls" ]]; then
                    echo "   Permessi configurati:" >> "$summary_file"
                    while IFS= read -r acl_line; do
                        # Format: ACL:DOMAIN\username:ALLOWED/OI|CI/PERMS
                        local entity_name=$(echo "$acl_line" | cut -d: -f2 | sed 's/.*\\//')
                        local perms=$(echo "$acl_line" | cut -d/ -f3)
                        
                        local perm_desc=""
                        case "$perms" in
                            FULL) perm_desc="Controllo Totale" ;;
                            RWXD) perm_desc="Lettura e Scrittura" ;;
                            READ) perm_desc="Solo Lettura" ;;
                            RWX) perm_desc="Lettura, Scrittura ed Esecuzione" ;;
                            RX) perm_desc="Solo Lettura" ;;
                            *) perm_desc="$perms" ;;
                        esac
                        
                        # Verifica se è un gruppo usando file precompilato
                        local group_map_file="$OUTPUT_DIR/03_shares/group_members.map"
                        local group_members=""
                        
                        if [[ -f "$group_map_file" ]]; then
                            group_members=$(grep "^${entity_name}:" "$group_map_file" | cut -d: -f2)
                        fi
                        
                        if [[ -n "$group_members" ]]; then
                            # È un gruppo - mostra membri
                            while IFS= read -r member; do
                                [[ -z "$member" ]] && continue
                                echo "      • $member: $perm_desc" >> "$summary_file"
                            done <<< "$group_members"
                        else
                            # Non è un gruppo (o è utente singolo)
                            echo "      • $entity_name: $perm_desc" >> "$summary_file"
                        fi
                    done <<< "$user_acls"
                else
                    echo "   ⚠️  Solo permessi di sistema configurati (Everyone/Administrators)" >> "$summary_file"
                fi
                
            elif [[ -f "$acl_path" ]]; then
                # Fallback: ACL POSIX (getfacl)
                local user_acls=$(grep "^user:" "$acl_path" | grep -v "^user::") 
                
                if [[ -n "$user_acls" ]]; then
                    echo "   Permessi specifici per utente:" >> "$summary_file"
                    while IFS= read -r acl_line; do
                        local username=$(echo "$acl_line" | cut -d: -f2 | sed 's/BUILTIN\\\\administrators/Amministratori/; s/BUILTIN\\\\server\\040operators/Operatori Server/; s/NT\\040Authority\\\\system/SYSTEM/; s/NT\\040Authority\\\\authenticated\\040users/Utenti Autenticati/')
                        local perms=$(echo "$acl_line" | cut -d: -f3)
                        local perm_desc=""
                        [[ "$perms" == "rwx" ]] && perm_desc="Lettura, Scrittura ed Esecuzione"
                        [[ "$perms" == "rw-" ]] && perm_desc="Lettura e Scrittura"
                        [[ "$perms" == "r-x" ]] && perm_desc="Solo Lettura"
                        [[ "$perms" == "r--" ]] && perm_desc="Solo Lettura"
                        [[ -z "$perm_desc" ]] && perm_desc=$(echo "$perms" | sed 's/r/Lettura /g; s/w/Scrittura /g; s/x/Esecuzione /g; s/-//g' | sed 's/  */ /g')
                        echo "      • $username: $perm_desc" >> "$summary_file"
                    done <<< "$user_acls"
                else
                    # Mostra permessi base gruppo
                    local group=$(grep "^# group:" "$acl_path" | cut -d: -f2 | head -1 | xargs)
                    local group_perms=$(grep "^group::" "$acl_path" | head -1 | cut -d: -f3)
                    
                    echo "   ⚠️  Nessun permesso specifico per utente configurato" >> "$summary_file"
                    echo "   Tutti gli utenti del gruppo '$group' hanno: " >> "$summary_file"
                    
                    local perm_desc=""
                    [[ "$group_perms" == "rwx" ]] && perm_desc="Lettura, Scrittura ed Esecuzione"
                    [[ "$group_perms" == "rw-" ]] && perm_desc="Lettura e Scrittura"
                    [[ "$group_perms" == "r-x" ]] && perm_desc="Solo Lettura"
                    
                    echo "      → $perm_desc" >> "$summary_file"
                fi
            else
                echo "   ⚠️  File permessi non trovato" >> "$summary_file"
            fi
            echo "" >> "$summary_file"
            echo "  ────────────────────────────────────────────────────────────────────────────" >> "$summary_file"
            echo "" >> "$summary_file"
        done < "$OUTPUT_DIR/03_shares/shares_report.tsv"
    else
        echo "⚠️  Dati cartelle condivise non disponibili" >> "$summary_file"
    fi
    
    cat >> "$summary_file" << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📧 CONDIVISIONI CASELLE EMAIL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    
    # Analisi condivisioni email
    if [[ -d "$OUTPUT_DIR/04_mail_sharing" ]]; then
        local webtop_shares="$OUTPUT_DIR/04_mail_sharing/webtop_mail_shares.txt"
        local dovecot_shares="$OUTPUT_DIR/04_mail_sharing/dovecot_shared_mailboxes.txt"
        
        # WebTop shares
        if [[ -f "$webtop_shares" ]] && ! grep -q "(0 rows)" "$webtop_shares" 2>/dev/null; then
            echo "Condivisioni WebTop trovate:" >> "$summary_file"
            echo "" >> "$summary_file"
            # Parse output psql e rendi user-friendly
            tail -n +3 "$webtop_shares" | grep -v "^(" | grep -v "^--" | while IFS='|' read -r id owner service path inst shared perms; do
                [[ -z "$owner" ]] && continue
                owner=$(echo "$owner" | xargs)
                shared=$(echo "$shared" | xargs)
                path=$(echo "$path" | xargs)
                perms=$(echo "$perms" | xargs)
                echo "  📬 Casella di: $owner" >> "$summary_file"
                [[ -n "$path" ]] && echo "     Cartella: $path" >> "$summary_file"
                [[ -n "$shared" ]] && echo "     Condivisa con: $shared" >> "$summary_file"
                [[ -n "$perms" ]] && echo "     Permessi: $perms" >> "$summary_file"
                echo "" >> "$summary_file"
            done
        else
            echo "Nessuna casella email condivisa tramite WebTop" >> "$summary_file"
        fi
        
        echo "" >> "$summary_file"
        
        # Dovecot shared mailboxes
        if [[ -f "$dovecot_shares" ]]; then
            local share_count=$(grep -c "^Mailbox Owner:" "$dovecot_shares" 2>/dev/null || true)
            [[ -z "$share_count" ]] && share_count=0
            
            if [[ $share_count -gt 0 ]]; then
                echo "Condivisioni account Webtop trovate:" >> "$summary_file"
                echo "" >> "$summary_file"
                
                # Estrai lista owner→user e rimuovi duplicati
                local temp_mapping=$(mktemp)
                local current_owner=""
                
                while IFS= read -r line; do
                    if [[ "$line" =~ ^Mailbox\ Owner: ]]; then
                        current_owner="${line#Mailbox Owner: }"
                        current_owner=$(echo "$current_owner" | xargs)
                    elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]*User: ]]; then
                        local shared_user=$(echo "$line" | sed 's/.*User: //' | xargs)
                        if [[ -n "$current_owner" ]] && [[ -n "$shared_user" ]]; then
                            echo "$current_owner|$shared_user" >> "$temp_mapping"
                        fi
                    fi
                done < "$dovecot_shares"
                
                # Rimuovi duplicati e raggruppa per owner
                if [[ -s "$temp_mapping" ]]; then
                    sort -u "$temp_mapping" | awk -F'|' '{
                        if (owner != $1 && owner != "") {
                            printf "  📬 %s → condiviso con %s\n", owner, users
                            users = ""
                        }
                        owner = $1
                        if (users == "") {
                            users = $2
                        } else {
                            users = users ", " $2
                        }
                    } END {
                        if (owner != "") {
                            printf "  📬 %s → condiviso con %s\n", owner, users
                        }
                    }' >> "$summary_file"
                fi
                
                rm -f "$temp_mapping"
                echo "" >> "$summary_file"
            else
                echo "Nessuna casella email condivisa" >> "$summary_file"
            fi
        fi
        
        # Summary generale
        if [[ -f "$OUTPUT_DIR/04_mail_sharing/summary.txt" ]]; then
            echo "" >> "$summary_file"
            cat "$OUTPUT_DIR/04_mail_sharing/summary.txt" >> "$summary_file"
        fi
    else
        echo "⚠️  Dati condivisioni email non disponibili" >> "$summary_file"
    fi
    
    cat >> "$summary_file" << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Report completato con successo

Per i dati tecnici dettagliati, consultare i file nella cartella:
$OUTPUT_DIR

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    
    log_success "Report riepilogativo generato → REPORT_SUMMARY.txt"
    
    # Mostra summary su stdout
    echo ""
    echo "================================================================================"
    cat "$summary_file"
    echo "================================================================================"
}

# Main execution
main() {
    echo "================================================================================"
    echo "NS8 Biweekly Audit Report - Collector & Analyzer"
    echo "================================================================================"
    echo ""
    
    check_prerequisites
    echo ""
    
    # Raccolta dati
    collect_ad_users
    collect_password_expiry
    collect_samba_shares
    collect_webtop_sharing
    
    echo ""
    
    # Genera report finale
    generate_summary_report
    
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
        --help)
            echo "Uso: $0 [--output-dir /custom/path]"
            exit 0
            ;;
        *)
            log_error "Opzione sconosciuta: $1"
            exit 1
            ;;
    esac
done

# Run
main "$@"
