#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/ydea-toolkit.sh"

usage() {
	cat >&2 <<'USAGE'
Usage:
	create-ticket-ita.sh <TITLE> <DESCRIPTION> [PRIORITY_ITA]

PRIORITY_ITA:
	bassa | media | alta | critica

Example:
	./create-ticket-ita.sh "Test" "Descrizione" "alta"
USAGE
}

title="${1:-}"; shift || true
description="${1:-}"; shift || true
priority_ita="${1:-media}"

if [[ -z "$title" || -z "$description" ]]; then
	usage
	exit 2
fi

case "${priority_ita,,}" in
	bassa) priority="low" ;;
	media) priority="normal" ;;
	alta) priority="high" ;;
	critica) priority="critical" ;;
	*) priority="normal" ;;
esac

log_info "Creating ticket (priority: $priority_ita -> $priority)"

body="$(jq -n \
	--arg titolo "$title" \
	--arg descrizione "$description" \
	--arg prio "$priority" \
	'{titolo:$titolo, descrizione:$descrizione, priorita:$prio}')"

resp="$(ydea_api POST "/ticket" "$body")" || {
	log_error "Ticket creation failed"
	printf '%s\n' "$resp" | jq . 2>/dev/null || printf '%s\n' "$resp" >&2
	exit 1
}

printf '%s\n' "$resp" | jq .
exit 0

: <<'CORRUPTED_09ae541821ee43b69655c2e406fa650d'
#!/bin/bashsource .env
TITLE="$1"
DESCRIPTION="$2"
PRIORITY_ITA="$3"
# Converti priorit├á italiana in inglesecase "${PRIORITY_ITA,,}" in  bassa)    
PRIORITY="low" ;;  media)    
PRIORITY="normal" ;;  alta)     
PRIORITY="high" ;;  critica)  
PRIORITY="critical" ;;  *)        
PRIORITY="normal" ;;esac
echo "­ƒÄ½ Creazione ticket con priorit├á: $PRIORITY_ITA ÔåÆ $PRIORITY"
echo ""./ydea-toolkit.sh create "$TITLE" "$DESCRIPTION" "$PRIORITY"

CORRUPTED_09ae541821ee43b69655c2e406fa650d

