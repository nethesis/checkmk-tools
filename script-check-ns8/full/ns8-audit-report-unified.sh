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

# Funzione 3: Raccolta share e permessi
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
        
        # Ottieni ACL tramite smbcacls
        local acl_file="$acls_dir/${share_name}_smbacl.txt"
        
        if runagent -m "$SAMBA_MODULE" podman exec samba-dc \
            smbcacls //localhost/"$share_name" / -N 2>/dev/null > "$acl_file"; then
            log_success "    ACL salvato → $(basename "$acl_file")"
        else
            log_warn "    Impossibile ottenere ACL"
            echo "ERROR: Unable to retrieve ACL for $share_name" > "$acl_file"
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
    
    # TEMPORARY: Skip Postgres query (debugging blocking issue)
    log_warn "Raccolta condivisioni email WebTop temporaneamente disabilitata (debug)"
    local output_file="$OUTPUT_DIR/04_webtop_email_shares.tsv"
    echo -e "owner\tshare_id\tshare_key\tshared_with_user\tpermissions" > "$output_file"
    echo -e "N/A\tN/A\tFEATURE_DISABLED\tN/A\tN/A" >> "$output_file"
    return 0
    
    log_info "Raccolta condivisioni email WebTop..."
    
    local output_file="$OUTPUT_DIR/04_webtop_email_shares.tsv"
    
    # Header TSV
    echo -e "owner\tshare_id\tshare_key\tshared_with_user\tpermissions" > "$output_file"
    
    # Esegui query su Postgres container WebtBop
    local postgres_container=$(runagent -m "$WEBTOP_MODULE" podman ps --format '{{.Names}}' 2>/dev/null | grep -i postgres | head -1)
    
    if [[ -z "$postgres_container" ]]; then
        log_warn "Container Postgres non trovato"
        echo "ERROR: Postgres container not found" >> "$output_file"
        return 1
    fi
    
    log_info "  Container Postgres: $postgres_container"
    
    # Debug: mostra query
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "[DEBUG] Query SQL"
    fi
    
    # Esegui query
    local temp_result=$(mktemp)
    local temp_error=$(mktemp)
    
    # Crea file query temporaneo NEL container
    local query_file="/tmp/webtop_query_$$.sql"
    
    # Scrivi query nel container (senza -i, usa bash -c con echo)
    runagent -m "$WEBTOP_MODULE" podman exec "$postgres_container" bash -c "echo \"SELECT 
    u_owner.user_id as owner,
    s.share_id,
    s.key as share_key,
    u_shared.user_id as shared_user,
    sd.value as permissions
FROM core.shares s
LEFT JOIN core.users u_owner ON s.user_uid = u_owner.user_uid
LEFT JOIN core.shares_data sd ON s.share_id = sd.share_id
LEFT JOIN core.users u_shared ON sd.user_uid = u_shared.user_uid
WHERE s.service_id = 'com.sonicle.webtop.mail'
ORDER BY u_owner.user_id, s.share_id;\" > $query_file"
    
    # Esegui query da file
    if runagent -m "$WEBTOP_MODULE" podman exec "$postgres_container" \
        psql -U postgres -d webtop5 -t -A -F$'\t' -f "$query_file" > "$temp_result" 2>"$temp_error"; then
        
        # Pulisci file query
        runagent -m "$WEBTOP_MODULE" podman exec "$postgres_container" rm -f "$query_file" 2>/dev/null || true
        
        
        # Parse risultati TSV diretti (gestisci NULL come empty string)
        local row_count=0
        while IFS=$'\t' read -r owner share_id share_key shared_user permissions; do
            [[ -z "$owner" ]] && continue
            
            # Converti empty string in N/A
            [[ -z "$share_key" ]] && share_key="N/A"
            [[ -z "$shared_user" ]] && shared_user="N/A"
            [[ -z "$permissions" ]] && permissions="N/A"
            
            # Scrivi riga nel file output
            echo -e "$owner\t$share_id\t$share_key\t$shared_user\t$permissions" >> "$output_file"
            ((row_count++))
            
        done < "$temp_result"
        
        if [[ $row_count -eq 0 ]]; then
            log_warn "Nessuna condivisione email trovata"
            echo "N/A	N/A	N/A	N/A	N/A" >> "$output_file"
        else
            log_success "Raccolte $row_count condivisioni email → $(basename "$output_file")"
        fi
        rm -f "$temp_result" "$temp_error"
        return 0
    else
        log_error "Query Postgres fallita"
        if [[ -s "$temp_error" ]]; then
            echo "[ERROR] Dettaglio errore PostgreSQL:"
            cat "$temp_error"
        else
            echo "[ERROR] Nessun dettaglio errore disponibile (stderr vuoto)"
        fi
        echo "ERROR: Postgres query failed" >> "$output_file"
        rm -f "$temp_result" "$temp_error"
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

Samba File Shares:
  - Share totali:                      $share_count
  - File ACL generati:                 $share_count

WebTop Email Sharing:
  - Condivisioni email totali:         $webtop_share_count

================================================================================
FILE GENERATI
================================================================================

1. Utenti AD:
   → 01_users.txt

2. Scadenze password:
   → 02_password_expiry.tsv

3. Share e permessi:
   → 03_shares/shares_list.txt
   → 03_shares/shares_report.tsv
   → 03_shares/acls/*.txt

4. WebTop email shares:
   → 04_webtop_email_shares.tsv

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

================================================================================

EOF
    
    log_success "Report riepilogativo generato → REPORT_SUMMARY.txt"
    
    # Mostra summary su stdout
    echo ""
    echo "================================================================================"
    cat "$summary_file"
    echo "================================================================================"
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
        
        # Estrai ACL - solo utenti/gruppi (no system)
        local acl_lines=$(grep "^ACL:" "$acl_file" | grep -vE "^ACL:(NT AUTHORITY|BUILTIN)" || true)
        
        if [[ -z "$acl_lines" ]]; then
            # Share senza permessi utente
            printf "%-20s %-35s %-30s %-25s\n" \
                "$share_name" \
                "${share_path:0:35}" \
                "[solo sistema]" \
                "-"
            continue
        fi
        
        # Prima riga con dati share
        local first_line=1
        
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
    collect_samba_shares
    collect_webtop_sharing
    
    echo ""
    
    # Fase 2: Genera report riepilogativo
    generate_summary_report
    
    echo ""
    
    # Fase 3: Visualizza report ACL (se abilitato)
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
