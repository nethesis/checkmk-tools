#!/usr/bin/env bash

set -euo pipefail

# monitor_podman_events.sh
# Demone che ascolta eventi Podman e registra solo create/start/stop/remove.
# Esclude i container "redis".

LOGFILE="/var/log/podman_events.log"

if ! command -v podman >/dev/null 2>&1; then
    echo "podman not found" >&2
    exit 1
fi

mkdir -p "$(dirname "$LOGFILE")"

podman events \
    --filter type=container \
    --format "{{.Time}} {{.Status}} {{.Name}} ({{.ID}})" \
    | while IFS= read -r event; do
        [[ -z "$event" ]] && continue

        # escludi redis
        if echo "$event" | grep -qi "redis"; then
            continue
        fi

        # prendi solo create/start/stop/remove
        if echo "$event" | grep -Eq "\b(create|start|stop|remove)\b"; then
            echo "$(date '+%F %T') - $event" >> "$LOGFILE"
        fi
    done
