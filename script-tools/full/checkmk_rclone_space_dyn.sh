#!/usr/bin/env bash
set -euo pipefail

# checkmk_cloud_backup_push.sh
# Usage:
#   checkmk_cloud_backup_push.sh setup
#   checkmk_cloud_backup_push.sh run <site>
#   checkmk_cloud_backup_push.sh remove <site>
#
# Notes:
# - Designed for OMD/Checkmk sites under /opt/omd/sites/<site>
# - Pushes the newest backup archive file from local backup dir to rclone remote
# - Uses systemd templated service + optional timer

SCRIPT_NAME="$(basename "$0")"
SITES_BASE="/opt/omd/sites"
SYSTEMD_DIR="/etc/systemd/system"
WRAPPER_PATH="/usr/local/sbin/checkmk_cloud_backup_push_run.sh"

log() { echo "[$(date '+%F %T')] $*"; }
err() { echo "[$(date '+%F %T')] ERROR: $*" >&2; }
die() { err "$*"; exit 1; }

need_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run as root."
}

list_sites() {
  if [[ -d "$SITES_BASE" ]]; then
    find "$SITES_BASE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
  else
    return 1
  fi
}

pick_site_interactive() {
  local sites
  mapfile -t sites < <(list_sites || true)
  [[ "${#sites[@]}" -gt 0 ]] || die "No OMD sites found in $SITES_BASE"

  log "Available OMD sites:"
  local i=1
  for s in "${sites[@]}"; do
    echo "  $i) $s"
    i=$((i+1))
  done

  local choice
  read -r -p "Select site number: " choice
  [[ "$choice" =~ ^[0-9]+$ ]] || die "Invalid selection."
  (( choice >= 1 && choice <= ${#sites[@]} )) || die "Out of range."
  echo "${sites[$((choice-1))]}"
}

write_wrapper() {
  cat > "$WRAPPER_PATH" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Wrapper invoked by systemd service:
#   checkmk_cloud_backup_push_run.sh <site> <remote> <remote_prefix> <backup_dir> <rclone_conf> <retries> <bwlimit>

SITE="${1:?missing site}"
REMOTE="${2:?missing remote (e.g. do:bucket)}"
REMOTE_PREFIX="${3:?missing remote prefix (e.g. checkmk/site)}"
BACKUP_DIR="${4:?missing backup dir}"
RCLONE_CONF="${5:?missing rclone conf}"
RETRIES="${6:-3}"
BWLIMIT="${7:-0}"

log() { echo "[$(date '+%F %T')] $*"; }
err() { echo "[$(date '+%F %T')] ERROR: $*" >&2; }

SITEHOME="/opt/omd/sites/${SITE}"
LOCKFILE="/run/lock/checkmk-cloud-backup-push-${SITE}.lock"
LOGDIR="/var/log/checkmk-cloud-backup"
mkdir -p "$LOGDIR"

# Ensure we do not run concurrently for the same site
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  err "Another push is running for site=$SITE (lock: $LOCKFILE)."
  exit 2
fi

# Validate environment
[[ -d "$SITEHOME" ]] || { err "Site home not found: $SITEHOME"; exit 3; }
[[ -d "$BACKUP_DIR" ]] || { err "Backup dir not found: $BACKUP_DIR"; exit 4; }
[[ -r "$RCLONE_CONF" ]] || { err "rclone.conf not readable: $RCLONE_CONF"; exit 5; }

# Pick newest backup file (most common formats)
# You can extend patterns if your backups differ.
mapfile -t candidates < <(find "$BACKUP_DIR" -maxdepth 1 -type f \
  \( -name '*.tar.gz' -o -name '*.tgz' -o -name '*.tar' -o -name '*.mkbackup' -o -name '*.zip' \) \
  -printf '%T@ %p\n' 2>/dev/null | sort -nr)

if [[ "${#candidates[@]}" -eq 0 ]]; then
  err "No backup archives found in $BACKUP_DIR"
  exit 6
fi

NEWEST_PATH="$(echo "${candidates[0]}" | cut -d' ' -f2-)"
NEWEST_FILE="$(basename "$NEWEST_PATH")"

DEST="${REMOTE%/}/${REMOTE_PREFIX%/}/"
[[ "$REMOTE_PREFIX" == "." || -z "$REMOTE_PREFIX" ]] && DEST="${REMOTE%/}/"

log "Selected newest backup: $NEWEST_PATH"
log "Destination: ${DEST}${SITE}/"
log "Using rclone config: $RCLONE_CONF"
log "Retries: $RETRIES"

# rclone options
COMMON_OPTS=(
  "--config=$RCLONE_CONF"
  "--log-file=${LOGDIR}/push-${SITE}.log"
  "--log-level=INFO"
  "--retries=$RETRIES"
  "--retries-sleep=10s"
  "--low-level-retries=10"
  "--stats=30s"
  "--stats-one-line"
  "--checksum"
)

if [[ "$BWLIMIT" != "0" ]]; then
  COMMON_OPTS+=("--bwlimit=$BWLIMIT")
fi

# Push only the selected file (atomic-ish: copy into a temp name then move, where supported)
TMP_NAME=".${NEWEST_FILE}.partial"
REMOTE_SITE_PATH="${DEST}${SITE}"
REMOTE_TMP="${REMOTE_SITE_PATH}/${TMP_NAME}"
REMOTE_FINAL="${REMOTE_SITE_PATH}/${NEWEST_FILE}"

# Ensure remote path exists (rclone mkdir works for many backends)
log "Ensuring remote directory exists: $REMOTE_SITE_PATH"
rclone mkdir "$REMOTE_SITE_PATH" "${COMMON_OPTS[@]}"

# Copy to temp name
log "Copying to remote temp: $REMOTE_TMP"
rclone copyto "$NEWEST_PATH" "$REMOTE_TMP" "${COMMON_OPTS[@]}"

# Move into final name (server-side move if possible)
log "Moving temp to final: $REMOTE_FINAL"
rclone moveto "$REMOTE_TMP" "$REMOTE_FINAL" "${COMMON_OPTS[@]}"

# Optional: list remote file metadata for quick sanity check
log "Remote file info:"
rclone lsjson "$REMOTE_SITE_PATH" --files-only "${COMMON_OPTS[@]}" | tail -n 5 || true

log "Push completed successfully."
EOF

  chmod 0755 "$WRAPPER_PATH"
}

write_systemd_units() {
  # Service template
  cat > "${SYSTEMD_DIR}/checkmk-cloud-backup-push@.service" <<'EOF'
[Unit]
Description=Checkmk Cloud Backup Push (rclone) for site %i
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=root
Group=root

# Defaults can be overridden via:
#   /etc/default/checkmk-cloud-backup-push-%i
EnvironmentFile=-/etc/default/checkmk-cloud-backup-push-%i

# Sensible defaults
Environment=REMOTE=do:testmonbck
Environment=REMOTE_PREFIX=checkmk-backups
Environment=BACKUP_DIR=/opt/omd/sites/%i/var/check_mk/backup
Environment=RCLONE_CONF=/opt/omd/sites/%i/.config/rclone/rclone.conf
Environment=RETRIES=3
Environment=BWLIMIT=0

ExecStart=/usr/local/sbin/checkmk_cloud_backup_push_run.sh %i "${REMOTE}" "${REMOTE_PREFIX}" "${BACKUP_DIR}" "${RCLONE_CONF}" "${RETRIES}" "${BWLIMIT}"

TimeoutStartSec=0
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7

[Install]
WantedBy=multi-user.target
EOF

  # Optional timer template
  cat > "${SYSTEMD_DIR}/checkmk-cloud-backup-push@.timer" <<'EOF'
[Unit]
Description=Timer for Checkmk Cloud Backup Push (rclone) for site %i

[Timer]
# Default schedule: daily at 02:30
OnCalendar=*-*-* 02:30:00
Persistent=true
Unit=checkmk-cloud-backup-push@%i.service

[Install]
WantedBy=timers.target
EOF
}

write_defaults_file() {
  local site="$1"
  local defaults="/etc/default/checkmk-cloud-backup-push-${site}"
  if [[ -f "$defaults" ]]; then
    log "Defaults file already exists: $defaults (not overwriting)"
    return 0
  fi

  cat > "$defaults" <<EOF
# Overrides for site ${site}
# Example:
# REMOTE=do:testmonbck
# REMOTE_PREFIX=checkmk-backups
# BACKUP_DIR=/opt/omd/sites/${site}/var/check_mk/backup
# RCLONE_CONF=/opt/omd/sites/${site}/.config/rclone/rclone.conf
# RETRIES=3
# BWLIMIT=0

REMOTE=do:testmonbck
REMOTE_PREFIX=checkmk-backups
BACKUP_DIR=/opt/omd/sites/${site}/var/check_mk/backup
RCLONE_CONF=/opt/omd/sites/${site}/.config/rclone/rclone.conf
RETRIES=3
BWLIMIT=0
EOF

  chmod 0644 "$defaults"
  log "Created defaults file: $defaults"
}

setup() {
  need_root
  write_wrapper
  write_systemd_units
  systemctl daemon-reload
  log "Installed:"
  log "  - $WRAPPER_PATH"
  log "  - ${SYSTEMD_DIR}/checkmk-cloud-backup-push@.service"
  log "  - ${SYSTEMD_DIR}/checkmk-cloud-backup-push@.timer"
  log ""
  log "Next:"
  log "  1) Run:   $SCRIPT_NAME run <site>"
  log "  2) Enable timer (optional): systemctl enable --now checkmk-cloud-backup-push@<site>.timer"
}

run_site() {
  need_root
  local site="${1:-}"
  [[ -n "$site" ]] || site="$(pick_site_interactive)"
  [[ -d "${SITES_BASE}/${site}" ]] || die "Site not found: ${site}"

  write_defaults_file "$site"

  log "Starting push service for site=${site}"
  systemctl start "checkmk-cloud-backup-push@${site}.service"
  log "Done. Check logs:"
  log "  journalctl -u checkmk-cloud-backup-push@${site}.service --no-pager -n 200"
  log "  /var/log/checkmk-cloud-backup/push-${site}.log"
}

remove_site() {
  need_root
  local site="${1:-}"
  [[ -n "$site" ]] || site="$(pick_site_interactive)"

  # Stop/disable timer if present
  systemctl disable --now "checkmk-cloud-backup-push@${site}.timer" >/dev/null 2>&1 || true
  systemctl stop "checkmk-cloud-backup-push@${site}.service" >/dev/null 2>&1 || true

  rm -f "/etc/default/checkmk-cloud-backup-push-${site}"
  log "Removed defaults: /etc/default/checkmk-cloud-backup-push-${site}"

  log "Units remain installed (shared templates). If you want full uninstall, remove:"
  log "  ${SYSTEMD_DIR}/checkmk-cloud-backup-push@.service"
  log "  ${SYSTEMD_DIR}/checkmk-cloud-backup-push@.timer"
  log "  ${WRAPPER_PATH}"
  log "then: systemctl daemon-reload"
}

usage() {
  cat <<EOF
Usage:
  $SCRIPT_NAME setup
  $SCRIPT_NAME run <site>
  $SCRIPT_NAME remove <site>

Examples:
  $SCRIPT_NAME setup
  $SCRIPT_NAME run monitoring
  systemctl enable --now checkmk-cloud-backup-push@monitoring.timer

Defaults override file:
  /etc/default/checkmk-cloud-backup-push-<site>
EOF
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    setup) setup ;;
    run) shift; run_site "${1:-}" ;;
    remove) shift; remove_site "${1:-}" ;;
    -h|--help|help|"") usage ;;
    *) die "Unknown command: $cmd" ;;
  esac
}

main "$@"
