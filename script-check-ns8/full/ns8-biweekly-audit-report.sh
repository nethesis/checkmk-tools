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
    SAMBA_MODULES=$(runagent list-modules 2>/dev/null | grep -E '^samba[0-9]+$' || true)
    WEBTOP_MODULES=$(runagent list-modules 2>/dev/null | grep -E '^webtop[0-9]+$' || true)
    
    if [[ -z "$SAMBA_MODULES" ]]; then
        log_error "Nessun modulo Samba trovato"
        exit 1
    fi
    
    SAMBA_MODULE=$(echo "$SAMBA_MODULES" | head -1)
    log_success "Modulo Samba: $SAMBA_MODULE"
    
    if [[ -z "$WEBTOP_MODULES" ]]; then
        log_warn "Nessun modulo WebTop trovato (report limitato)"
        WEBTOP_MODULE=""
    else
        WEBTOP_MODULE=$(echo "$WEBTOP_MODULES" | head -1)
        log_success "Modulo WebTop: $WEBTOP_MODULE"
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
    
    while IFS= read -r username; do
        [[ -z "$username" ]] && continue
        ((user_count++))
        
        # Ottieni pwdLastSet via ldapsearch
        local pwd_last_set=$(runagent -m "$SAMBA_MODULE" podman exec samba-dc \
            ldapsearch -LLL -b "dc=ad,dc=local" "(sAMAccountName=$username)" pwdLastSet 2>/dev/null \
            | grep "^pwdLastSet:" | awk '{print $2}' || echo "0")
        
        if [[ -z "$pwd_last_set" ]] || [[ "$pwd_last_set" == "0" ]]; then
            log_warn "  $username: pwdLastSet non disponibile"
            echo -e "$username\t0\t0\tN/A\t0\tN/A\tN/A" >> "$output_file"
            continue
        fi
        
        # Conversione FILETIME → Unix epoch
        # Formula: unix = (filetime - 116444736000000000) / 10000000
        local unix_time=$(awk "BEGIN {printf \"%.0f\", ($pwd_last_set - 116444736000000000) / 10000000}")
        
        # Data ISO formattata
        local iso_date=$(date -d "@$unix_time" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")
        
        # Calcola scadenza (pwdLastSet + maxPwdAge)
        local expires_unix=$((unix_time + MAX_PWD_AGE_DAYS * 86400))
        local expires_iso=$(date -d "@$expires_unix" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")
        
        # Giorni rimanenti
        local now=$(date +%s)
        local days_until_expiry=$(( (expires_unix - now) / 86400 ))
        
        echo -e "$username\t$pwd_last_set\t$unix_time\t$iso_date\t$expires_unix\t$expires_iso\t$days_until_expiry" >> "$output_file"
        ((success_count++))
        
    done < "$OUTPUT_DIR/01_users.txt"
    
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
        
        # Raccogli ACL del path (dentro il container)
        local acl_file="$acl_dir/${share_name}.acl"
        if runagent -m "$SAMBA_MODULE" podman exec samba-dc getfacl "$share_path" > "$acl_file" 2>/dev/null; then
            log_success "  $share_name: $share_path [ACL OK]"
            echo -e "$share_name\t$share_path\tYES\t$(basename "$acl_file")" >> "$share_report"
        else
            log_warn "  $share_name: ACL non disponibile per $share_path"
            echo "ERROR: Unable to get ACL for $share_path" > "$acl_file"
            echo -e "$share_name\t$share_path\tNO\t$(basename "$acl_file")" >> "$share_report"
        fi
        
    done < "$share_list"
    
    rm -f "$testparm_output"
    log_success "Share report completato → 03_shares/"
    return 0
}

# Funzione 4: Raccolta condivisioni WebTop
collect_webtop_sharing() {
    log_info "Raccolta condivisioni posta WebTop..."
    
    local output_dir="$OUTPUT_DIR/04_webtop"
    mkdir -p "$output_dir"
    
    if [[ -z "$WEBTOP_MODULE" ]]; then
        log_warn "WebTop non disponibile, skip"
        echo "WebTop module not running on this node" > "$output_dir/status.txt"
        return 0
    fi
    
    # Verifica presenza container Postgres
    local postgres_container=$(runagent -m "$WEBTOP_MODULE" podman ps --format '{{.Names}}' 2>/dev/null | grep -i postgres || true)
    
    if [[ -z "$postgres_container" ]]; then
        log_warn "Container Postgres non trovato in $WEBTOP_MODULE"
        echo "Postgres container not found" > "$output_dir/status.txt"
        return 0
    fi
    
    log_info "Container Postgres: $postgres_container"
    
    # Estrai lista database
    local db_list=$(mktemp)
    if ! runagent -m "$WEBTOP_MODULE" podman exec "$postgres_container" \
        psql -U postgres -t -c '\l' > "$db_list" 2>/dev/null; then
        log_error "Fallita connessione Postgres"
        echo "Unable to connect to Postgres" > "$output_dir/status.txt"
        rm -f "$db_list"
        return 1
    fi
    
    # Cerca database webtop (pattern: webtop, webtop5, etc)
    local webtop_db=$(grep -iE 'webtop' "$db_list" | awk '{print $1}' | head -1 || true)
    rm -f "$db_list"
    
    if [[ -z "$webtop_db" ]]; then
        log_warn "Database WebTop non trovato"
        echo "WebTop database not found" > "$output_dir/status.txt"
        return 0
    fi
    
    log_info "Database WebTop: $webtop_db"
    
    # Query tabelle rilevanti
    local tables_file="$output_dir/tables.txt"
    runagent -m "$WEBTOP_MODULE" podman exec "$postgres_container" \
        psql -U postgres -d "$webtop_db" -t -c "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;" \
        > "$tables_file" 2>/dev/null || true
    
    # Cerca tabelle sharing/delegation
    local sharing_tables=$(grep -iE '(shar|deleg|grant|permiss)' "$tables_file" || echo "No sharing tables found")
    echo "$sharing_tables" > "$output_dir/sharing_tables.txt"
    
    # Estrai identità mail (tabella core.identities se esiste)
    if grep -q "core.identities" "$tables_file" 2>/dev/null; then
        log_info "Estrazione identità mail..."
        runagent -m "$WEBTOP_MODULE" podman exec "$postgres_container" \
            psql -U postgres -d "$webtop_db" -c "SELECT * FROM core.identities LIMIT 100;" \
            > "$output_dir/identities.txt" 2>/dev/null || echo "Query failed" > "$output_dir/identities.txt"
    fi
    
    log_success "WebTop data raccolti → 04_webtop/"
    return 0
}

# Funzione analisi e report finale
generate_summary_report() {
    log_info "Generazione report riepilogativo..."
    
    local summary_file="$OUTPUT_DIR/REPORT_SUMMARY.txt"
    
    cat > "$summary_file" << EOF
================================================================================
NS8 BIWEEKLY AUDIT REPORT
================================================================================
Generated: $(date +"%Y-%m-%d %H:%M:%S")
Node: $(hostname)
Output Directory: $OUTPUT_DIR

================================================================================
1. ACTIVE DIRECTORY USERS
================================================================================
EOF
    
    # Analisi utenti
    if [[ -f "$OUTPUT_DIR/01_users.txt" ]]; then
        local user_count=$(grep -v "^ERROR" "$OUTPUT_DIR/01_users.txt" | wc -l)
        echo "Total AD Users: $user_count" >> "$summary_file"
        echo "" >> "$summary_file"
        echo "User List:" >> "$summary_file"
        cat "$OUTPUT_DIR/01_users.txt" >> "$summary_file"
    else
        echo "ERROR: User data not available" >> "$summary_file"
    fi
    
    cat >> "$summary_file" << EOF

================================================================================
2. PASSWORD EXPIRY STATUS
================================================================================
EOF
    
    # Analisi scadenze password
    if [[ -f "$OUTPUT_DIR/02_password_expiry.tsv" ]]; then
        local total_users=$(tail -n +2 "$OUTPUT_DIR/02_password_expiry.tsv" | wc -l)
        local expiring_soon=$(tail -n +2 "$OUTPUT_DIR/02_password_expiry.tsv" | awk -F'\t' '$7 != "N/A" && $7 < 7 {count++} END {print count+0}')
        local expired=$(tail -n +2 "$OUTPUT_DIR/02_password_expiry.tsv" | awk -F'\t' '$7 != "N/A" && $7 < 0 {count++} END {print count+0}')
        
        echo "Total Users Analyzed: $total_users" >> "$summary_file"
        echo "Passwords Expiring Soon (<7 days): $expiring_soon" >> "$summary_file"
        echo "Passwords Already Expired: $expired" >> "$summary_file"
        echo "Max Password Age Policy: $MAX_PWD_AGE_DAYS days" >> "$summary_file"
        echo "" >> "$summary_file"
        
        if [[ $expiring_soon -gt 0 ]] || [[ $expired -gt 0 ]]; then
            echo "ATTENTION REQUIRED - Users with expiring/expired passwords:" >> "$summary_file"
            tail -n +2 "$OUTPUT_DIR/02_password_expiry.tsv" | awk -F'\t' '$7 != "N/A" && $7 < 7 {print "  " $1 " - expires in " $7 " days (" $6 ")"}' >> "$summary_file"
        fi
    else
        echo "ERROR: Password expiry data not available" >> "$summary_file"
    fi
    
    cat >> "$summary_file" << EOF

================================================================================
3. SAMBA SHARES AND PERMISSIONS
================================================================================
EOF
    
    # Analisi share
    if [[ -f "$OUTPUT_DIR/03_shares/shares_report.tsv" ]]; then
        local share_count=$(tail -n +2 "$OUTPUT_DIR/03_shares/shares_report.tsv" | wc -l)
        local acl_collected=$(tail -n +2 "$OUTPUT_DIR/03_shares/shares_report.tsv" | awk -F'\t' '$3 == "YES" {count++} END {print count+0}')
        
        echo "Total Shares: $share_count" >> "$summary_file"
        echo "ACLs Collected: $acl_collected/$share_count" >> "$summary_file"
        echo "" >> "$summary_file"
        echo "Share Details:" >> "$summary_file"
        column -t -s$'\t' "$OUTPUT_DIR/03_shares/shares_report.tsv" >> "$summary_file"
    else
        echo "ERROR: Share data not available" >> "$summary_file"
    fi
    
    cat >> "$summary_file" << EOF

================================================================================
4. WEBTOP MAIL SHARING
================================================================================
EOF
    
    # Analisi WebTop
    if [[ -f "$OUTPUT_DIR/04_webtop/status.txt" ]]; then
        cat "$OUTPUT_DIR/04_webtop/status.txt" >> "$summary_file"
    elif [[ -f "$OUTPUT_DIR/04_webtop/sharing_tables.txt" ]]; then
        echo "WebTop module active, data collected:" >> "$summary_file"
        echo "Database tables found:" >> "$summary_file"
        cat "$OUTPUT_DIR/04_webtop/sharing_tables.txt" >> "$summary_file"
    else
        echo "WebTop: No data available" >> "$summary_file"
    fi
    
    cat >> "$summary_file" << EOF

================================================================================
END OF REPORT
================================================================================
For detailed data, see individual files in: $OUTPUT_DIR
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
