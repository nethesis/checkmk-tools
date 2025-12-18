#!/usr/bin/env bash
set -euo pipefail

# deploy-from-repo.sh - Script interattivo per deployment da repository
# Automatizza: git pull + copia file nelle destinazioni corrette

REPO_PATH="/omd/sites/monitoring/checkmk-tools"
DEPLOY_USER="monitoring"
SCRIPT_USER="$(whoami)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Formato: "source|destination|needs_sudo(yes/no)|description"
DEPLOY_MAP=(
  "Ydea-Toolkit/ydea-toolkit.sh|/opt/ydea-toolkit/ydea-toolkit.sh|yes|Ydea Toolkit principale"
  "script-notify-checkmk/mail_realip|/usr/local/bin/notify-checkmk/mail_realip|yes|Script notifiche mail CheckMK"
  "script-notify-checkmk/telegram_realip|/usr/local/bin/notify-checkmk/telegram_realip|yes|Script notifiche Telegram"
  "script-notify-checkmk/ydea_la|/usr/local/bin/notify-checkmk/ydea_la|yes|Script notifiche Ydea"
)

have_cmd() { command -v "$1" >/dev/null 2>&1; }

run_maybe_sudo() {
  if have_cmd sudo; then
    sudo "$@"
  else
    "$@"
  fi
}

run_as_deploy_user() {
  if [[ "$SCRIPT_USER" == "$DEPLOY_USER" ]]; then
    bash -lc "$*"
    return
  fi
  if have_cmd sudo; then
    sudo -u "$DEPLOY_USER" bash -lc "$*"
    return
  fi
  echo "ERROR: serve sudo per eseguire come '$DEPLOY_USER'" >&2
  exit 1
}

print_header() {
  echo -e "\n${CYAN}${BOLD}========================================${RESET}"
  echo -e "${CYAN}${BOLD}  $1${RESET}"
  echo -e "${CYAN}${BOLD}========================================${RESET}\n"
}

print_step() { echo -e "${BLUE}*${RESET} $1"; }
print_success() { echo -e "${GREEN}OK${RESET} $1"; }
print_error() { echo -e "${RED}ERR${RESET} $1"; }
print_warning() { echo -e "${YELLOW}WARN${RESET} $1"; }
print_info() { echo -e "${CYAN}INFO${RESET} $1"; }

check_prerequisites() {
  print_step "Verifica prerequisiti..."

  if [[ ! -d "$REPO_PATH" ]]; then
    print_error "Repository non trovato: $REPO_PATH"
    exit 1
  fi
  if ! have_cmd git; then
    print_error "git non installato"
    exit 1
  fi

  print_success "Prerequisiti verificati"
}

update_repository() {
  print_step "Aggiornamento repository..."
  run_as_deploy_user "cd '$REPO_PATH'; git pull"
  print_success "Repository aggiornato"
}

show_available_files() {
  print_header "FILE DISPONIBILI PER DEPLOY"

  local index=1
  for entry in "${DEPLOY_MAP[@]}"; do
    IFS='|' read -r src dest _needs_sudo desc <<<"$entry"

    local full_src="$REPO_PATH/$src"
    if [[ -f "$full_src" ]]; then
      echo -e "${GREEN}[$index]${RESET} ${BOLD}$desc${RESET}"
      echo -e "    Source: $src"
      echo -e "    Dest:   $dest"
      if [[ -f "$dest" ]]; then
        echo -e "    ${YELLOW}File gia presente in destinazione${RESET}"
      fi
    else
      echo -e "${RED}[$index]${RESET} ${BOLD}$desc${RESET} ${RED}(NON TROVATO)${RESET}"
      echo -e "    Source: $src"
    fi
    echo
    ((index++))
  done
}

deploy_file() {
  local entry="$1"
  IFS='|' read -r src dest needs_sudo desc <<<"$entry"

  local full_src="$REPO_PATH/$src"
  local dest_dir
  dest_dir=$(dirname "$dest")

  print_step "Deploy: $desc"

  if [[ ! -f "$full_src" ]]; then
    print_error "File sorgente non trovato: $full_src"
    return 1
  fi

  if [[ ! -d "$dest_dir" ]]; then
    print_info "Creazione directory: $dest_dir"
    if [[ "$needs_sudo" == "yes" ]]; then
      run_maybe_sudo mkdir -p "$dest_dir"
    else
      mkdir -p "$dest_dir"
    fi
  fi

  if [[ -f "$dest" ]]; then
    local backup
    backup="${dest}.backup.$(date +%Y%m%d_%H%M%S)"
    print_info "Backup: $backup"
    if [[ "$needs_sudo" == "yes" ]]; then
      run_maybe_sudo cp "$dest" "$backup"
    else
      cp "$dest" "$backup"
    fi
  fi

  if [[ "$needs_sudo" == "yes" ]]; then
    run_maybe_sudo cp "$full_src" "$dest"
    run_maybe_sudo chmod +x "$dest" 2>/dev/null || true
  else
    cp "$full_src" "$dest"
    chmod +x "$dest" 2>/dev/null || true
  fi

  print_success "Deploy completato: $dest"
}

show_status() {
  print_header "STATO ATTUALE"
  print_step "Repository: $REPO_PATH"
  run_as_deploy_user "cd '$REPO_PATH'; git log -1 --oneline" || true
  echo

  print_step "File deployati:"
  for entry in "${DEPLOY_MAP[@]}"; do
    IFS='|' read -r _src dest _needs_sudo desc <<<"$entry"
    if [[ -f "$dest" ]]; then
      echo -e "  ${GREEN}OK${RESET} $desc"
      echo -e "     $dest"
    else
      echo -e "  ${RED}NO${RESET} $desc"
      echo -e "     $dest (NON PRESENTE)"
    fi
  done
}

interactive_deploy() {
  print_header "DEPLOY INTERATTIVO"

  echo -e "${BOLD}Opzioni:${RESET}"
  echo "  [a] Deploy tutto"
  echo "  [s] Selezione singoli file"
  echo "  [q] Esci"
  echo

  read -r -p "Scegli un'opzione [a/s/q]: " choice
  case "$choice" in
    a|A)
      print_info "Deploy di tutti i file..."
      local success=0
      local failed=0
      for entry in "${DEPLOY_MAP[@]}"; do
        if deploy_file "$entry"; then
          ((success++))
        else
          ((failed++))
        fi
        echo
      done
      echo -e "\n${BOLD}Riepilogo:${RESET}"
      echo -e "  ${GREEN}Successo: $success${RESET}"
      if [[ $failed -gt 0 ]]; then
        echo -e "  ${RED}Falliti: $failed${RESET}"
      fi
      ;;

    s|S)
      show_available_files
      echo -e "${BOLD}Inserisci i numeri dei file da deployare (es: 1 3 4) o 'a' per tutti:${RESET}"
      read -r -p "> " selections

      if [[ "$selections" == "a" || "$selections" == "A" ]]; then
        for entry in "${DEPLOY_MAP[@]}"; do
          deploy_file "$entry"
          echo
        done
        return
      fi

      local total=${#DEPLOY_MAP[@]}
      for num in $selections; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le $total ]]; then
          local index=$((num - 1))
          deploy_file "${DEPLOY_MAP[$index]}"
          echo
        else
          print_warning "Numero non valido: $num"
        fi
      done
      ;;

    q|Q)
      print_info "Uscita..."
      exit 0
      ;;

    *)
      print_error "Opzione non valida"
      exit 1
      ;;
  esac
}

main_menu() {
  print_header "DEPLOY AUTOMATICO DA REPOSITORY"
  echo -e "${BOLD}Cosa vuoi fare?${RESET}"
  echo "  [1] Solo git pull (aggiorna repository)"
  echo "  [2] Git pull + deploy interattivo"
  echo "  [3] Git pull + deploy tutto automatico"
  echo "  [4] Solo deploy (senza git pull)"
  echo "  [5] Mostra stato attuale"
  echo "  [q] Esci"
  echo

  read -r -p "Scegli un'opzione [1-5/q]: " main_choice
  case "$main_choice" in
    1)
      check_prerequisites
      update_repository
      ;;
    2)
      check_prerequisites
      update_repository
      interactive_deploy
      ;;
    3)
      check_prerequisites
      update_repository
      print_info "Deploy automatico di tutti i file..."
      for entry in "${DEPLOY_MAP[@]}"; do
        deploy_file "$entry"
        echo
      done
      ;;
    4)
      check_prerequisites
      interactive_deploy
      ;;
    5)
      show_status
      ;;
    q|Q)
      print_info "Uscita..."
      exit 0
      ;;
    *)
      print_error "Opzione non valida"
      exit 1
      ;;
  esac

  echo
  print_success "Operazione completata!"
}

main() {
  if [[ $# -gt 0 ]]; then
    case "$1" in
      --pull-only)
        check_prerequisites
        update_repository
        ;;
      --deploy-all)
        check_prerequisites
        update_repository
        for entry in "${DEPLOY_MAP[@]}"; do
          deploy_file "$entry"
        done
        ;;
      --status)
        show_status
        ;;
      --help|-h)
        echo "Uso: $0 [opzione]"
        echo
        echo "Opzioni:"
        echo "  --pull-only    Solo git pull"
        echo "  --deploy-all   Git pull + deploy tutto"
        echo "  --status       Mostra stato"
        echo "  --help         Mostra questo help"
        echo
        echo "Senza opzioni: modalita interattiva"
        ;;
      *)
        print_error "Opzione non valida. Usa --help per vedere le opzioni"
        exit 1
        ;;
    esac
    return
  fi

  main_menu
}

main "$@"
