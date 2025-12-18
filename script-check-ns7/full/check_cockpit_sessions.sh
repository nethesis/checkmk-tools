#!/usr/bin/env bash

# check_cockpit_sessions.sh
# Notifica login/logout Cockpit leggendo /var/log/messages
# e mostra quante sessioni sono attive

set -o pipefail

SERVICE="Cockpit_sessions"
STATEFILE="/var/lib/check_mk_agent/cockpit_sessions.state"
LOGFILE="/var/log/messages"
STATEDIR=${STATEFILE%/*}
SEVFILE="$STATEDIR/cockpit_sessions.sev"

NOW=$(date +"%Y-%m-%d %H:%M:%S")

mkdir -p "$STATEDIR" 2>/dev/null || true

if [[ ! -r "$LOGFILE" ]]; then
	echo "2 $SERVICE - $NOW $LOGFILE non leggibile"
	exit 0
fi

last_line=0
if [[ -f "$STATEFILE" ]]; then
	last_line=$(<"$STATEFILE")
fi

new_lines=$(awk -v last="$last_line" 'NR>last && /cockpit-ws:/ {print NR " " $0}' "$LOGFILE" 2>/dev/null || true)

if [[ -n "$new_lines" ]]; then
	new_last=$(printf '%s\n' "$new_lines" | tail -n 1 | awk '{print $1}')
	printf '%s\n' "$new_last" >"$STATEFILE" 2>/dev/null || true

	while IFS= read -r entry; do
		[[ -z "$entry" ]] && continue

		line=${entry#* }

		if [[ "$line" == *"New connection to session from"* ]]; then
			ip=$(printf '%s\n' "$line" | sed -n 's/.*from \([0-9.]\+\).*/\1/p')
			if [[ -n "$ip" ]]; then
				sev=1
				if [[ -f "$SEVFILE" ]]; then
					sev=$(<"$SEVFILE")
				fi
				case "$sev" in
					2)
						echo "2 $SERVICE - $NOW cockpit login from $ip"
						next_sev=1
						;;
					*)
						echo "1 $SERVICE - $NOW cockpit login from $ip"
						next_sev=2
						;;
				esac
				printf '%s\n' "$next_sev" >"$SEVFILE" 2>/dev/null || true
			fi
		elif [[ "$line" == *"for session closed"* ]]; then
			ip=$(printf '%s\n' "$line" | sed -n 's/.*from \([0-9.]\+\).*/\1/p')
			if [[ -n "$ip" ]]; then
				echo "0 $SERVICE - $NOW cockpit logout from $ip"
			fi
		fi
	done <<<"$new_lines"

	exit 0
fi

# info di stato (non notifica perché rimane 0)
active=0
if command -v ss >/dev/null 2>&1; then
	active=$(ss -tnp 2>/dev/null | grep -c 'cockpit-ws' || true)
fi

echo "0 $SERVICE - $active cockpit session(s) active"
exit 0