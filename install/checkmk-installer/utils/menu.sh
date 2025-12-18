#!/usr/bin/env bash
set -euo pipefail

prompt_input() {
	local prompt="$1"
	local default_value="${2:-}"
	local input
	if [[ -n "$default_value" ]]; then
		read -r -p "$prompt [$default_value]: " input || true
		echo "${input:-$default_value}"
	else
		read -r -p "$prompt: " input || true
		echo "$input"
	fi
}

confirm() {
	local prompt="$1"
	local default_answer="${2:-y}"
	local answer

	if [[ "$default_answer" == "y" ]]; then
		read -r -p "$prompt [Y/n]: " answer || true
		answer="${answer:-y}"
	else
		read -r -p "$prompt [y/N]: " answer || true
		answer="${answer:-n}"
	fi

	case "${answer,,}" in
		y|yes) return 0 ;;
		*) return 1 ;;
	esac
}

multi_select() {
	local title="$1"; shift
	local options=("$@")

	echo "$title"
	for i in "${!options[@]}"; do
		echo "  $i) ${options[$i]}"
	done
	echo ""
	echo "Enter comma-separated indices (e.g. 0,2,3) or blank to cancel."

	local raw
	read -r -p "> " raw || true
	if [[ -z "${raw// }" ]]; then
		echo ""
		return 0
	fi

	raw="${raw// /}"
	local out=""
	IFS=',' read -r -a parts <<<"$raw"
	for p in "${parts[@]}"; do
		if [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 0 && p < ${#options[@]} )); then
			out+="$p "
		fi
	done

	echo "${out% }"
}

show_main_menu() {
	print_header "Main Menu"
	echo "1) Install Full Server"
	echo "2) Install Client Agent"
	echo "3) Deploy Scripts Only"
	echo "4) Install Ydea Toolkit Only"
	echo "5) Custom Install (pick modules)"
	echo "6) Deploy Scripts (rerun module)"
	echo "7) Configuration Wizard"
	echo "8) Show Current Config"
	echo "9) Full Cleanup"
	echo "10) Exit"
	echo ""
	MENU_SELECTION=$(prompt_input "Select an option" "10")
}

: <<'__CORRUPTED_TAIL__'
#!/usr/bin/env bash
set -euo pipefail

prompt_input() {
	local prompt="$1"
	local default_value="${2:-}"
	local input
	if [[ -n "$default_value" ]]; then
		read -r -p "$prompt [$default_value]: " input || true
		echo "${input:-$default_value}"
	else
		read -r -p "$prompt: " input || true
		echo "$input"
	fi
}

confirm() {
	local prompt="$1"
	local default_answer="${2:-y}"
	local answer

	if [[ "$default_answer" == "y" ]]; then
		read -r -p "$prompt [Y/n]: " answer || true
		answer="${answer:-y}"
	else
		read -r -p "$prompt [y/N]: " answer || true
		answer="${answer:-n}"
	fi

	case "${answer,,}" in
		y|yes) return 0 ;;
		*) return 1 ;;
	esac
}

multi_select() {
	local title="$1"; shift
	local options=("$@")

	echo "$title"
	for i in "${!options[@]}"; do
		echo "  $i) ${options[$i]}"
	done
	echo ""
	echo "Enter comma-separated indices (e.g. 0,2,3) or blank to cancel."

	local raw
	read -r -p "> " raw || true
	if [[ -z "${raw// }" ]]; then
		echo ""
		return 0
	fi

	raw="${raw// /}"
	local out=""
	IFS=',' read -r -a parts <<<"$raw"
	for p in "${parts[@]}"; do
		if [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 0 && p < ${#options[@]} )); then
			out+="$p "
		fi
	done

	echo "${out% }"
}

show_main_menu() {
	print_header "Main Menu"
	echo "1) Install Full Server"
	echo "2) Install Client Agent"
	echo "3) Deploy Scripts Only"
	echo "4) Install Ydea Toolkit Only"
	echo "5) Custom Install (pick modules)"
	echo "6) Deploy Scripts (rerun module)"
	echo "7) Configuration Wizard"
	echo "8) Show Current Config"
	echo "9) Full Cleanup"
	echo "10) Exit"
	echo ""
	MENU_SELECTION=$(prompt_input "Select an option" "10")
}
#!/usr/bin/env bash

# menu.sh - Menu and input helpers

# shellcheck source=colors.sh
[[ -z "${GREEN:-}" ]] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

show_menu() {
	echo ""
	echo "=========================================="
	echo "  $1"
	echo "=========================================="
	shift
	local i=1
	for item in "$@"; do
		echo "  $i) $item"
		((i++))
	done
	echo "=========================================="
}

get_selection() {
	local max="$1"
	while true; do
		read -r -p "Select option (1-$max): " MENU_SELECTION
		if [[ "$MENU_SELECTION" =~ ^[0-9]+$ ]] && [[ $MENU_SELECTION -ge 1 ]] && [[ $MENU_SELECTION -le $max ]]; then
			export MENU_SELECTION
			return 0
		fi
		echo "Invalid selection. Try again."
	done
}

confirm() {
	local prompt="$1"
	local default="${2:-n}"
	local response
	while true; do
		if [[ "$default" == "y" ]]; then
			read -r -p "$prompt (Y/n): " response
			response=${response:-y}
		else
			read -r -p "$prompt (y/N): " response
			response=${response:-n}
		fi
		case "$response" in
			[yY]|[yY][eE][sS]) return 0 ;;
			[nN]|[nN][oO]) return 1 ;;
			*) echo "Invalid response. Enter y or n" ;;
		esac
	done
}

multi_select() {
	local prompt="$1"; shift
	local items=("$@")
	local selected=()

	echo ""
	echo "$prompt"
	echo "(Enter numbers separated by spaces, or 'all' for all)"
	echo ""

	local i
	for i in "${!items[@]}"; do
		echo "  $((i + 1))) ${items[$i]}"
	done
	echo ""

	while true; do
		local -a selections
		read -r -p "Selections: " -a selections
		if [[ ${#selections[@]} -eq 0 ]]; then
			echo ""
			return 0
		fi
		if [[ "${selections[0],,}" == "all" ]]; then
			for i in "${!items[@]}"; do
				selected+=("$i")
			done
			break
		fi

		local valid=true
		for sel in "${selections[@]}"; do
			if ! [[ "$sel" =~ ^[0-9]+$ ]] || [[ $sel -lt 1 ]] || [[ $sel -gt ${#items[@]} ]]; then
				valid=false
				break
			fi
		done

		if $valid; then
			for sel in "${selections[@]}"; do
				selected+=("$((sel - 1))")
				done
			break
		fi
		echo "Invalid selection"
	done

	echo "${selected[@]}"
}

display_box() {
	local title="$1"; shift
	echo ""
	echo "=========================================="
	echo "  $title"
	echo "=========================================="
	local line
	for line in "$@"; do
		echo "  $line"
	done
	echo "=========================================="
	echo ""
}

input_text() {
	local prompt="$1"
	local default="${2:-}"
	local result
	if [[ -n "$default" ]]; then
		read -r -p "$prompt [$default]: " result
		echo "${result:-$default}"
	else
		read -r -p "$prompt: " result
		echo "$result"
	fi
}

input_password() {
	local prompt="$1"
	local result
	read -r -s -p "$prompt: " result
	echo "" >&2
	echo "$result"
}

input_number() {
	local prompt="$1"
	local default="${2:-}"
	local result
	while true; do
		if [[ -n "$default" ]]; then
			read -r -p "$prompt [$default]: " result
			result="${result:-$default}"
		else
			read -r -p "$prompt: " result
		fi
		if [[ "$result" =~ ^[0-9]+$ ]]; then
			echo "$result"
			return 0
		fi
		echo "Enter a valid number" >&2
	done
}

select_from_list() {
	local prompt="$1"; shift
	local options=("$@")
	local selection

	echo "" >&2
	echo "$prompt" >&2
	echo "" >&2
	local i
	for i in "${!options[@]}"; do
		echo "  $((i + 1))) ${options[$i]}" >&2
	done
	echo "" >&2

	while true; do
		read -r -p "Select (1-${#options[@]}): " selection
		if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#options[@]} ]]; then
			echo "${options[$((selection - 1))]}"
			return 0
		fi
		echo "Invalid selection" >&2
	done
}

press_any_key() {
	local prompt="${1:-Press any key to continue...}"
	read -r -n 1 -s -p "$prompt"
	echo ""
}

show_main_menu() {
	local options=(
		"Complete Server Installation (CheckMK + Scripts + Ydea + FRPS)"
		"Client Agent Installation (CheckMK Agent + FRPC)"
		"Deploy Monitoring Scripts (Scripts only)"
		"Install Ydea Toolkit (Toolkit only)"
		"Custom Installation (Choose modules)"
		"Update Scripts (from local)"
		"Update Scripts (from GitHub)"
		"Configuration Wizard"
		"Show Current Configuration"
		"Complete Cleanup (Remove all installations)"
		"Exit"
	)

	show_menu "CheckMK Installer - Main Menu" "${options[@]}"
	get_selection "${#options[@]}"
}
#!/bin/bash
/usr/bin/env bash
# menu.sh - Complete working version[[ -z "$GREEN" ]] && source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"show_menu() {  
echo ""  
echo "=========================================="  
echo "  $1"  
echo "=========================================="  shift  local i=1  for item in "$@"; do    
echo "  $i) $item"    ((i++))  done
echo "=========================================="}get_selection() {  local max=$1  while true; do    read -r -p "Select option (1-$max): " MENU_SELECTION    if [[ "$MENU_SELECTION" =~ ^[0-9]+$ ]] && [ "$MENU_SELECTION" -ge 1 ] && [ "$MENU_SELECTION" -le "$max" ]; then      export MENU_SELECTION      return 0    fi
echo "Invalid selection. Try again."  done}confirm() {  local prompt="$1"  local default="${2:-n}"    while true; do    if [[ "$default" == "y" ]]; then      read -r -p "$prompt (Y/n): " -r response      response=${response:-y}    else      read -r -p "$prompt (y/N): " -r response      response=${response:-n}    fi        case "$response" in      [yY]|[yY][eE][sS])        return 0        ;;      [nN]|[nN][oO])        return 1        ;;      *)        
echo "Invalid response. Enter y or n"        ;;    esac  done}multi_select() {  local prompt="$1"  shift  local items=("$@")  local selected=()    
echo ""  
echo "$prompt"  
echo "(Enter numbers separated by spaces, or 'all' for all)"  
echo ""    for i in "${!items[@]}"; do    local num=$((i + 1))    
echo "  $num) ${items[$i]}"  done
echo ""    while true; do    read -r -p "Selections: " -r -a selections        if [[ "${selections[0],,}" == "all" ]]; then      for i in "${!items[@]}"; do        selected+=("$i")      done      break    fi        local valid=true    for sel in "${selections[@]}"; do      if ! [[ "$sel" =~ ^[0-9]+$ ]] || [[ $sel -lt 1 ]] || [[ $sel -gt ${
#items[@]} ]]; then
    valid=false        break      fi    done        if $valid; then      for sel in "${selections[@]}"; do        selected+=("$((sel - 1))")      done      break    fi
echo "Invalid selection"  done
echo "${selected[@]}"}display_box() {  local title="$1"  shift    
echo ""  
echo "=========================================="  
echo "  $title"  
echo "=========================================="  for line in "$@"; do    
echo "  $line"  done
echo "=========================================="  
echo ""}input_text() {  local prompt="$1"  local default="$2"  local result    if [[ -n "$default" ]]; then    read -r -p "$prompt [$default]: " result    
echo "${result:-$default}"
else    read -r -p "$prompt: " result    
echo "$result"  fi}input_password() {  local prompt="$1"  local result    read -s -p "$prompt: " result  
echo "" >&2  
echo "$result"}input_number() {  local prompt="$1"  local default="$2"  local result    while true; do    if [[ -n "$default" ]]; then      read -r -p "$prompt [$default]: " result      result="${result:-$default}"
else      read -r -p "$prompt: " result    fi        if [[ "$result" =~ ^[0-9]+$ ]]; then
    echo "$result"      return 0    fi
echo "Enter a valid number" >&2  done}select_from_list() {  local prompt="$1"  shift  local options=("$@")    
echo "" >&2  
echo "$prompt" >&2  
echo "" >&2    for i in "${!options[@]}"; do    local num=$((i + 1))    
echo "  $num) ${options[$i]}" >&2  done
echo "" >&2    while true; do    read -r -p "Select (1-${
#options[@]}): " selection        if [[ "$selection" =~ ^[0-9]+$ ]] && \       [[ $selection -ge 1 ]] && \       [[ $selection -le ${
#options[@]} ]]; then
    echo "${options[$((selection - 1))]}"      return 0    fi
echo "Invalid selection" >&2  done}press_any_key() {  read -n 1 -s -r -p "Press any key to continue..."  
echo ""}show_main_menu() {  local options=(    "Complete Server Installation (CheckMK + Scripts + Ydea + FRPC)"    "Client Agent Installation (CheckMK Agent + FRPC)"    "Deploy Monitoring Scripts (Scripts only)"    "Install Ydea Toolkit (Toolkit only)"    "Custom Installation (Choose modules)"    "Update Scripts (from local)"    "Update Scripts (from GitHub)"    "Configuration Wizard"    "Show Current Configuration"    "Complete Cleanup (Remove all installations)"    "Exit"  )    show_menu "CheckMK Installer v1.0 - Main Menu" "${options[@]}"  get_selection "${
#options[@]}"}

__CORRUPTED_TAIL__
