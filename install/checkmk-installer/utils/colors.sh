
#!/bin/bash
/usr/bin/env bash
# colors.sh - Color definitions and symbols for terminal output
# Color codesexport 
RED='\033[0;31m'export 
GREEN='\033[0;32m'export 
YELLOW='\033[1;33m'export 
BLUE='\033[0;34m'export 
MAGENTA='\033[0;35m'export 
CYAN='\033[0;36m'export 
WHITE='\033[1;37m'export 
GRAY='\033[0;90m'export 
NC='\033[0m' 
# No Color
# Background colorsexport 
BG_RED='\033[41m'export 
BG_GREEN='\033[42m'export 
BG_YELLOW='\033[43m'export 
BG_BLUE='\033[44m'export 
BG_MAGENTA='\033[45m'export 
BG_CYAN='\033[46m'export 
BG_WHITE='\033[47m'
# Text stylesexport 
BOLD='\033[1m'export 
DIM='\033[2m'export 
UNDERLINE='\033[4m'export 
BLINK='\033[5m'export 
REVERSE='\033[7m'export 
HIDDEN='\033[8m'
# Symbolsexport 
SYMBOL_SUCCESS="Ô£à"export 
SYMBOL_ERROR="ÔØî"export 
SYMBOL_WARNING="ÔÜá´©Å "export 
SYMBOL_INFO="Ôä╣´©Å "export 
SYMBOL_QUESTION="ÔØô"export 
SYMBOL_ARROW="Ô×£"export 
SYMBOL_BULLET="ÔÇó"export 
SYMBOL_CHECK="Ô£ô"export 
SYMBOL_CROSS="Ô£ù"export 
SYMBOL_STAR="Ôÿà"export 
SYMBOL_HEART="ÔÖÑ"export 
SYMBOL_GEAR="ÔÜÖ´©Å "export 
SYMBOL_ROCKET="­ƒÜÇ"export 
SYMBOL_PACKAGE="­ƒôª"export 
SYMBOL_FOLDER="­ƒôü"export 
SYMBOL_FILE="­ƒôä"export 
SYMBOL_LOCK="­ƒöÆ"export 
SYMBOL_KEY="­ƒöæ"export 
SYMBOL_CLOUD="Ôÿü´©Å "export 
SYMBOL_SERVER="­ƒûÑ´©Å "export 
SYMBOL_CLIENT="­ƒÆ╗"export 
SYMBOL_NETWORK="­ƒîÉ"export 
SYMBOL_DOWNLOAD="Ô¼ç´©Å "export 
SYMBOL_UPLOAD="Ô¼å´©Å "export 
SYMBOL_REFRESH="­ƒöä"export 
SYMBOL_CLOCK="­ƒòÉ"export 
SYMBOL_FIRE="­ƒöÑ"export 
SYMBOL_WRENCH="­ƒöº"export 
SYMBOL_HAMMER="­ƒö¿"export 
SYMBOL_SCRIPT="­ƒô£"export 
SYMBOL_TICKET="­ƒÄ½"
# Box drawing charactersexport 
BOX_TL="Ôòö"  
# Top Leftexport 
BOX_TR="Ôòù"  
# Top Rightexport 
BOX_BL="ÔòÜ"  
# Bottom Leftexport 
BOX_BR="ÔòØ"  
# Bottom Rightexport 
BOX_H="ÔòÉ"   
# Horizontalexport 
BOX_V="Ôòæ"   
# Verticalexport 
BOX_VL="Ôòú"  
# Vertical Leftexport 
BOX_VR="Ôòá"  
# Vertical Rightexport 
BOX_HT="Ôòª"  
# Horizontal Topexport 
BOX_HB="Ôò®"  
# Horizontal Bottomexport 
BOX_C="Ôò¼"   
# Cross
# Helper functionsprint_color() {  local color="$1"  shift  
echo -e "${color}$*${NC}"}print_success() { 
echo -e "${GREEN}${SYMBOL_SUCCESS} $*${NC}"; }print_error() { 
echo -e "${RED}${SYMBOL_ERROR} $*${NC}" >&2; }print_warning() { 
echo -e "${YELLOW}${SYMBOL_WARNING}$*${NC}"; }print_info() { 
echo -e "${CYAN}${SYMBOL_INFO}$*${NC}"; }print_question() { 
echo -e "${MAGENTA}${SYMBOL_QUESTION} $*${NC}"; }print_header() {  local text="$1"  local width=60  local padding=$(( (width - ${
#text} - 2) / 2 ))    
echo ""  
echo -e "${CYAN}${BOX_TL}$(printf "${BOX_H}%.0s" $(seq 1 $width))${BOX_TR}${NC}"  printf "${CYAN}${BOX_V}${NC}%${padding}s${BOLD}${WHITE} %s ${NC}%${padding}s${CYAN}${BOX_V}${NC}\n" "" "$text" ""  
echo -e "${CYAN}${BOX_BL}$(printf "${BOX_H}%.0s" $(seq 1 $width))${BOX_BR}${NC}"  
echo ""}print_box() {  local text="$1"  local width=60    
echo -e "${CYAN}${BOX_TL}$(printf "${BOX_H}%.0s" $(seq 1 $width))${BOX_TR}${NC}"  
echo -e "${CYAN}${BOX_V}${NC} ${WHITE}$text${NC}$(printf ' %.0s' $(seq 1 $((width - ${
#text} - 1))))${CYAN}${BOX_V}${NC}"  
echo -e "${CYAN}${BOX_BL}$(printf "${BOX_H}%.0s" $(seq 1 $width))${BOX_BR}${NC}"}print_separator() {  local char="${1:-=}"  local width="${2:-60}"  printf "${GRAY}%${width}s${NC}\n" | tr ' ' "$char"}print_step() {  local step="$1"  local total="$2"  local description="$3"  
echo -e "${BOLD}${BLUE}[${step}/${total}]${NC} ${WHITE}${description}${NC}"}
# Progress barprint_progress() {  local current="$1"  local total="$2"  local width=40  local percentage=$((current * 100 / total))  local completed=$((current * width / total))  local remaining=$((width - completed))    printf "\r${CYAN}["  printf "${GREEN}%${completed}s" | tr ' ' 'Ôûê'  printf "${GRAY}%${remaining}s" | tr ' ' 'Ôûæ'  printf "${CYAN}] ${WHITE}%3d%%${NC}" "$percentage"    [[ $current -eq $total ]] && 
echo ""}
# Spinner animationspinner() {  local pid=$1  local delay=0.1  local spinstr='ÔáïÔáÖÔá╣Ôá©Ôá╝Ôá┤ÔáªÔáºÔáçÔáÅ'    while ps -p $pid > /dev/null 2>&1; do    local temp=${spinstr
#?}    printf " ${CYAN}%c${NC} " "$spinstr"    spinstr=$temp${spinstr%"$temp"}    sleep $delay    printf "\b\b\b\b"  done  printf "    \b\b\b\b"}
