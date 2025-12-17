
#!/bin/bash
/bin/bash
# Interactive Launcher - Esegui script remoti dal repository GitHub
# Scansiona tutte le cartelle remote/ e presenta menu interattivoset -euo pipefail
REPO_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAVORITES_FILE="$HOME/.launcher-favorites"
STATS_FILE="$HOME/.launcher-stats"
# Colori per output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' 
# No Color
# Array per memorizzare script trovatideclare -a SCRIPTSdeclare -a SCRIPT_PATHSdeclare -a SCRIPT_DESCRIPTIONSdeclare -A FAVORITESdeclare -A STATS
# Inizializza arrays vuoti per evitare unbound variable
FAVORITES=()
STATS=()
# Carica preferitiload_favorites() {    if [[ -f "$FAVORITES_FILE" ]]; then        while 
IFS= read -r fav; do            FAVORITES["$fav"]=1        done < "$FAVORITES_FILE"    fi}
# Salva preferitisave_favorites() {    > "$FAVORITES_FILE"    for fav in "${!FAVORITES[@]}"; do        
echo "$fav" >> "$FAVORITES_FILE"    done}
# Carica statisticheload_stats() {    if [[ -f "$STATS_FILE" ]]; then        while 
IFS='=' read -r script count; do            STATS["$script"]="$count"        done < "$STATS_FILE"    fi}
# Salva statistichesave_stats() {    > "$STATS_FILE"    for script in "${!STATS[@]}"; do        
echo "$script=${STATS[$script]}" >> "$STATS_FILE"    done}
# Incrementa contatore utilizzoincrement_usage() {    local script="$1"    local count="${STATS[$script]:-0}"    STATS["$script"]=$((count + 1))    save_stats}
# Descrizioni degli script (estratte dai commenti)get_script_description() {    local script_path="$1"    local full_path="$SCRIPT_DIR/$script_path"        if [[ -f "$full_path" ]]; then        
# Cerca commento di descrizione nelle prime 10 righe        local desc=$(head -n 10 "$full_path" | grep -E "^
# (Desc|Description|Purpose):" | sed 's/^
# [^:]*: //')        if [[ -n "$desc" ]]; then            
echo "$desc"        else            
# Fallback: seconda riga (solitamente descrizione)            desc=$(sed -n '2p' "$full_path" | sed 's/^
# //')            
echo "${desc:-Nessuna descrizione disponibile}"        fi    else        
echo "Script non trovato localmente"    fi}print_header() {    
echo -e "${BLUE}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${BLUE}Ôòæ${NC}  ­ƒÜÇ ${GREEN}Interactive Launcher - CheckMK Tools Repository${NC}  ${BLUE}Ôòæ${NC}"    
echo -e "${BLUE}ÔòáÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòú${NC}"    
echo -e "${BLUE}Ôòæ${NC}  ${CYAN}Ô¡É Preferiti: ${
#FAVORITES[@]}${NC}  ${MAGENTA}­ƒôè Script eseguiti: $(get_total_runs)${NC}         ${BLUE}Ôòæ${NC}"    
echo -e "${BLUE}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}"    
echo ""}get_total_runs() {    local total=0    for count in "${STATS[@]}"; do        total=$((total + count))    done    
echo "$total"}
# Scansiona repository locale per trovare tutti gli script remotiscan_remote_scripts() {    
echo -e "${YELLOW}­ƒôé Scansione script remoti in corso...${NC}\n"        local index=1        
# Trova tutti gli script nelle directory remote/    while 
IFS= read -r -d '' script; do        
# Ottieni path relativo        local rel_path="${script
#$SCRIPT_DIR/}"        local category=$(
echo "$rel_path" | cut -d'/' -f1)        local script_name=$(basename "$script" .sh)                
# Rimuovi prefisso 'r' se presente        local display_name="${script_name
#r}"                SCRIPTS[$index]="[$category] $display_name"        SCRIPT_PATHS[$index]="$rel_path"        SCRIPT_DESCRIPTIONS[$index]=$(get_script_description "$rel_path")                ((index++))    done < <(find "$SCRIPT_DIR" -type f -path "*/remote/r*.sh" -print0 | sort -z)        
echo -e "${GREEN}Ô£ô Trovati ${
#SCRIPTS[@]} script remoti${NC}\n"}
# Ricerca script per nome o categoriasearch_scripts() {    local query="$1"    local results=()        for i in "${!SCRIPTS[@]}"; do        if [[ "${SCRIPTS[$i],,}" == *"${query,,}"* ]] || [[ "${SCRIPT_DESCRIPTIONS[$i],,}" == *"${query,,}"* ]]; then            results+=("$i")        fi    done        if [ ${
#results[@]} -eq 0 ]; then        
echo -e "${RED}Ô£ù Nessun risultato trovato per: '$query'${NC}\n"        return 1    fi        
echo -e "${GREEN}­ƒöì Risultati ricerca '$query':${NC}\n"    for idx in "${results[@]}"; do        local star=""        [[ -n "${FAVORITES[$idx]:-}" ]] && star="${YELLOW}Ô¡É${NC} "        printf "  ${BLUE}%3d)${NC} ${star}%s\n" "$idx" "$(
echo "${SCRIPTS[$idx]}" | sed 's/\[.*\] //')"    done    
echo ""}
# Mostra dettagli scriptshow_script_details() {    local idx="$1"        if [ "$idx" -lt 1 ] || [ "$idx" -gt "${
#SCRIPTS[@]}" ]; then        
echo -e "${RED}Ô£ù Script non valido!${NC}\n"        return 1    fi        
echo -e "${CYAN}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${CYAN}Ôòæ${NC}  ­ƒôï ${GREEN}Dettagli Script${NC}                                    ${CYAN}Ôòæ${NC}"    
echo -e "${CYAN}ÔòáÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòú${NC}"    
echo -e "${CYAN}Ôòæ${NC}  ${YELLOW}Nome:${NC} ${SCRIPTS[$idx]}                              "    
echo -e "${CYAN}Ôòæ${NC}  ${YELLOW}Path:${NC} ${SCRIPT_PATHS[$idx]}                         "    
echo -e "${CYAN}Ôòæ${NC}  ${YELLOW}Descrizione:${NC}                                        "    
echo -e "${CYAN}Ôòæ${NC}    ${SCRIPT_DESCRIPTIONS[$idx]}"    
echo -e "${CYAN}Ôòæ${NC}  ${YELLOW}Utilizzi:${NC} ${STATS[$idx]:-0}                               "    [[ -n "${FAVORITES[$idx]:-}" ]] && 
echo -e "${CYAN}Ôòæ${NC}  ${YELLOW}Preferito:${NC} Ô¡É S├¼                                   "    
echo -e "${CYAN}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}\n"}
# Mostra solo preferitishow_favorites() {    if [ ${
#FAVORITES[@]} -eq 0 ]; then        
echo -e "${YELLOW}Ô¡É Nessun preferito salvato${NC}\n"        return    fi        
echo -e "${YELLOW}Ô¡É Script preferiti:${NC}\n"    for idx in "${!FAVORITES[@]}"; do        printf "  ${BLUE}%3d)${NC} %s\n" "$idx" "$(
echo "${SCRIPTS[$idx]}" | sed 's/\[.*\] //')"    done    
echo ""}
# Toggle preferitotoggle_favorite() {    local idx="$1"        if [[ -n "${FAVORITES[$idx]:-}" ]]; then        unset FAVORITES[$idx]        
echo -e "${GREEN}Ô£ô Rimosso dai preferiti${NC}"    else        FAVORITES[$idx]=1        
echo -e "${GREEN}Ô£ô Aggiunto ai preferiti Ô¡É${NC}"    fi    save_favorites}
# Mostra statisticheshow_statistics() {    
echo -e "${MAGENTA}ÔòöÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòù${NC}"    
echo -e "${MAGENTA}Ôòæ${NC}  ­ƒôè ${GREEN}Statistiche di Utilizzo${NC}                          ${MAGENTA}Ôòæ${NC}"    
echo -e "${MAGENTA}ÔòáÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòú${NC}"    
echo -e "${MAGENTA}Ôòæ${NC}  ${YELLOW}Totale esecuzioni:${NC} $(get_total_runs)                       "    
echo -e "${MAGENTA}Ôòæ${NC}  ${YELLOW}Script pi├╣ usati:${NC}                                  "        
# Top 5 script pi├╣ usati    local -a top_scripts=()    for idx in "${!STATS[@]}"; do        top_scripts+=("${STATS[$idx]}:$idx")    done        if [ ${
#top_scripts[@]} -gt 0 ]; then        
IFS=$'\n' sorted=($(sort -rn <<<"${top_scripts[*]}"))        unset IFS                local count=0        for entry in "${sorted[@]}"; do            [[ $count -ge 5 ]] && break            local uses="${entry%%:*}"            local idx="${entry
#
#*:}"            local name=$(
echo "${SCRIPTS[$idx]}" | sed 's/\[.*\] //')            
echo -e "${MAGENTA}Ôòæ${NC}    ${BLUE}$((count+1)).${NC} $name ${CYAN}($uses)${NC}"            ((count++))        done    else        
echo -e "${MAGENTA}Ôòæ${NC}    ${YELLOW}Nessuna statistica disponibile${NC}"    fi        
echo -e "${MAGENTA}ÔòÜÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòØ${NC}\n"}
# Mostra menu con tutti gli script disponibilishow_menu() {    
echo -e "${BLUE}ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ${NC}"    
echo -e "${GREEN}Script disponibili:${NC}"    
echo -e "${CYAN}Comandi: ${YELLOW}s)${NC}Cerca ${YELLOW}f)${NC}Preferiti ${YELLOW}i)${NC}Info ${YELLOW}t)${NC}Stats ${YELLOW}*+)${NC}Aggiungi/Rimuovi Ô¡É${NC}\n"        local current_category=""    for i in "${!SCRIPTS[@]}"; do        
# Estrai categoria        local category=$(
echo "${SCRIPTS[$i]}" | grep -oP '\[\K[^\]]+')                
# Stampa intestazione categoria se cambia        if [ "$category" != "$current_category" ]; then            
echo -e "\n${YELLOW}ÔûÂ $category${NC}"            current_category="$category"        fi                
# Stella se preferito        local star=""        [[ -n "${FAVORITES[$i]:-}" ]] && star="${YELLOW}Ô¡É${NC} "                
# Numero di utilizzi        local uses=""        [[ -n "${STATS[$i]:-}" ]] && uses=" ${CYAN}(${STATS[$i]})${NC}"                
# Stampa script con numerazione        printf "  ${BLUE}%3d)${NC} ${star}%s${uses}\n" "$i" "$(
echo "${SCRIPTS[$i]}" | sed 's/\[.*\] //')"    done        
echo -e "\n${BLUE}ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ${NC}"    
echo -e "  ${RED}0)${NC} Esci  ${YELLOW}s)${NC}Cerca  ${YELLOW}f)${NC}Preferiti  ${YELLOW}i)${NC}Info  ${YELLOW}t)${NC}Stats"    
echo -e "${BLUE}ÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉÔòÉ${NC}\n"}
# Esegui script selezionatoexecute_script() {    local selection=$1        if [ "$selection" -eq 0 ]; then        
echo -e "${GREEN}Arrivederci! ­ƒæï${NC}"        exit 0    fi        if [ "$selection" -lt 1 ] || [ "$selection" -gt "${
#SCRIPTS[@]}" ]; then        
echo -e "${RED}Ô£ù Selezione non valida!${NC}\n"        return 1    fi        local script_path="${SCRIPT_PATHS[$selection]}"    local script_name="${SCRIPTS[$selection]}"    local remote_url="$REPO_URL/$script_path"        
# Incrementa statistiche    increment_usage "$selection"        
echo -e "\n${GREEN}ÔûÂ Esecuzione:${NC} $script_name"    
echo -e "${BLUE}   URL:${NC} $remote_url\n"        
# Chiedi parametri aggiuntivi    
echo -e "${YELLOW}Parametri aggiuntivi (invio per nessuno):${NC}"    read -r params        
echo -e "\n${BLUE}ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü${NC}\n"        
# Esegui script remoto con sudo usando file temporaneo    
TEMP_SCRIPT=$(mktemp)    curl -fsSL "$remote_url" -o "$TEMP_SCRIPT"        if [ -n "$params" ]; then        sudo bash "$TEMP_SCRIPT" $params    else        sudo bash "$TEMP_SCRIPT"    fi        rm -f "$TEMP_SCRIPT"        local exit_code=$?        
echo -e "\n${BLUE}ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü${NC}"        if [ $exit_code -eq 0 ]; then        
echo -e "${GREEN}Ô£ô Script completato con successo${NC}\n"    else        
echo -e "${RED}Ô£ù Script terminato con errore (exit code: $exit_code)${NC}\n"    fi        
# Pausa prima di tornare al menu    
echo -e "${YELLOW}Premi INVIO per continuare...${NC}"    read -r}
# Main loopmain() {    load_favorites    load_stats    print_header    scan_remote_scripts        while true; do        clear        print_header        show_menu                
echo -e "${YELLOW}Seleziona uno script o comando:${NC} "        read -r selection                
# Comandi speciali        case "$selection" in            0)                
echo -e "${GREEN}Arrivederci! ­ƒæï${NC}"                exit 0                ;;            s|S)                
echo -e "${CYAN}­ƒöì Cerca script:${NC} "                read -r query                search_scripts "$query"                
echo -e "${YELLOW}Premi INVIO per continuare...${NC}"                read -r                ;;            f|F)                show_favorites                
echo -e "${YELLOW}Premi INVIO per continuare...${NC}"                read -r                ;;            i|I)                
echo -e "${CYAN}­ƒôï Numero script per info:${NC} "                read -r idx                if [[ "$idx" =~ ^[0-9]+$ ]]; then                    show_script_details "$idx"                else                    
echo -e "${RED}Ô£ù Numero non valido${NC}"                fi                
echo -e "${YELLOW}Premi INVIO per continuare...${NC}"                read -r                ;;            t|T)                show_statistics                
echo -e "${YELLOW}Premi INVIO per continuare...${NC}"                read -r                ;;            *+)                local idx="${selection%+}"                if [[ "$idx" =~ ^[0-9]+$ ]]; then                    toggle_favorite "$idx"                    sleep 1                else                    
echo -e "${RED}Ô£ù Formato: numero+ (es: 57+)${NC}"                    sleep 2                fi                ;;            *)                
# Verifica input numerico                if [[ "$selection" =~ ^[0-9]+$ ]]; then                    execute_script "$selection"                else                    
echo -e "${RED}Ô£ù Comando non riconosciuto!${NC}\n"                    sleep 2                fi                ;;        esac    done}
# Verifica prerequisitiif ! command -v curl &> /dev/null; then    
echo -e "${RED}Ô£ù Errore: curl non trovato. Installalo con: apt install curl${NC}"    exit 1fi
# Avvia launchermain
