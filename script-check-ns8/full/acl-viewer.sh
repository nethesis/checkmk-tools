#!/bin/bash
#
# acl-viewer.sh - Visualizzatore semplice ACL Samba Share NS8
# 
# Legge i file *_smbacl.txt generati da ns8-biweekly-audit-report.sh
# e mostra i permessi in formato leggibile italiano
#
# Usage: ./acl-viewer.sh [audit_directory]
#
# Se non specificato, usa l'audit più recente in /var/tmp/ns8-audit-*

set -uo pipefail

# Funzioni helper
log() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
die() { echo "[ERR] $*" >&2; exit 1; }

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
            echo "Permessi Personalizzati ($perms)"
            ;;
    esac
}

# Espandi gruppo AD (se possibile)
# Ritorna lista membri separati da newline, oppure stringa vuota se non è un gruppo
expand_group_safe() {
    local entity="$1"
    local samba_module="${2:-samba1}"
    
    # Prova a espandere come gruppo (timeout 3s per sicurezza)
    local members=""
    members=$(timeout 3 runagent -m "$samba_module" podman exec samba-dc \
        samba-tool group listmembers "$entity" 2>/dev/null || echo "")
    
    # Se vuoto o errore, non è un gruppo
    if [ -z "$members" ]; then
        return 1
    fi
    
    echo "$members"
    return 0
}

# Main
main() {
    local audit_dir="${1:-}"
    
    # Se non specificato, trova l'audit più recente
    if [ -z "$audit_dir" ]; then
        audit_dir=$(find /var/tmp -maxdepth 1 -type d -name "ns8-audit-*" 2>/dev/null | sort -r | head -1)
        if [ -z "$audit_dir" ]; then
            die "Nessuna directory audit trovata in /var/tmp/ns8-audit-*"
        fi
        log "Uso audit directory: $audit_dir"
    fi
    
    local acl_dir="$audit_dir/03_shares/acls"
    
    if [ ! -d "$acl_dir" ]; then
        die "Directory ACL non trovata: $acl_dir"
    fi
    
    # Header
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           VISUALIZZATORE PERMESSI SHARE NS8                  ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Directory audit: $audit_dir"
    echo ""
    
    # Rileva modulo Samba
    local samba_module="samba1"
    if command -v runagent >/dev/null 2>&1; then
        # Verifica modulo disponibile
        if ! runagent -m "$samba_module" echo "test" >/dev/null 2>&1; then
            warn "Modulo $samba_module non disponibile - skip espansione gruppi"
            samba_module=""
        fi
    else
        warn "runagent non disponibile - skip espansione gruppi"
        samba_module=""
    fi
    
    # Conta share
    local share_count=0
    
    # Itera su tutti i file ACL (usa array per evitare while loop problematici)
    local acl_files=()
    while IFS= read -r -d '' file; do
        acl_files+=("$file")
    done < <(find "$acl_dir" -name "*_smbacl.txt" -print0 | sort -z) || true
    
    if [ "${#acl_files[@]}" -eq 0 ]; then
        warn "Nessun file ACL trovato in $acl_dir"
        exit 0
    fi
    
    # Processa ogni share
    for acl_file in "${acl_files[@]}"; do
        local share_name=$(basename "$acl_file" _smbacl.txt)
        ((share_count++))
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📂 SHARE: $share_name"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Leggi path dalla shares_report.tsv
        local shares_report="$audit_dir/03_shares/shares_report.tsv"
        if [ -f "$shares_report" ]; then
            local share_path=$(grep "^$share_name	" "$shares_report" | cut -f2)
            if [ -n "$share_path" ]; then
                echo "Percorso: $share_path"
                echo ""
            fi
        fi
        
        # Estrai ACL (evita while loop - usa array)
        local acl_lines=()
        while IFS= read -r line; do
            acl_lines+=("$line")
        done < <(grep "^ACL:" "$acl_file" | grep -vE "^ACL:(NT AUTHORITY|BUILTIN)") || true
        
        if [ "${#acl_lines[@]}" -eq 0 ]; then
            echo "⚠️  Solo permessi di sistema configurati (Everyone/Administrators)"
            echo ""
            continue
        fi
        
        echo "Permessi configurati:"
        echo ""
        
        # Processa ogni ACL
        for acl_line in "${acl_lines[@]}"; do
            # Parse ACL: ACL:DOMAIN\entity:ALLOWED/flags/perms
            local entity=$(echo "$acl_line" | cut -d: -f2)
            local perms=$(echo "$acl_line" | cut -d: -f4 | cut -d/ -f3)
            
            # Traduzione permessi
            local perms_italian=$(translate_permissions "$perms")
            
            # Prova espansione gruppo (solo se runagent disponibile)
            if [ -n "$samba_module" ]; then
                # Estrai solo nome entità (rimuovi DOMAIN\)
                local entity_name="${entity##*\\}"
                
                # Prova espansione
                local members=""
                if members=$(expand_group_safe "$entity_name" "$samba_module" 2>/dev/null); then
                    # È un gruppo - mostra gruppo e membri
                    echo "  🔷 GRUPPO: $entity → $perms_italian"
                    echo "     Membri:"
                    while IFS= read -r member; do
                        [ -n "$member" ] && echo "       • $member"
                    done <<< "$members" || true
                    echo ""
                else
                    # Non è un gruppo (o errore espansione) - mostra direttamente
                    echo "  • $entity → $perms_italian"
                fi
            else
                # Runagent non disponibile - mostra solo entità
                echo "  • $entity → $perms_italian"
            fi
        done
        
        echo ""
    done
    
    # Footer
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Totale share analizzate: $share_count"
    echo ""
}

# Esegui
main "$@"
