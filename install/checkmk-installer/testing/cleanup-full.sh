#!/usr/bin/env bash
set -euo pipefail

# cleanup-full.sh - Complete cleanup of components installed by this toolkit.
# Invoked by installer menu option 9 (Complete Cleanup).

INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
    printf '%s\n' "$*"
}

warn() {
    printf '%s\n' "[WARN] $*" >&2
}

run_quiet() {
    "$@" >/dev/null 2>&1 || true
}

run() {
    "$@" || true
}

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        warn "This cleanup must run as root"
        exit 1
    fi
}

load_env() {
    local env_file="${INSTALLER_ROOT}/.env"
    if [[ -f "$env_file" ]]; then
        set -a
        # shellcheck disable=SC1091
        source "$env_file"
        set +a
    fi
}

stop_disable_unit() {
    local unit="$1"
    if command -v systemctl >/dev/null 2>&1; then
        run_quiet systemctl stop "$unit"
        run_quiet systemctl disable "$unit"
    fi
}

cleanup_site_user_group() {
    local site_name="$1"
    [[ -n "$site_name" ]] || return 0

    # In Checkmk/OMD, the site name usually matches both the system user and group.
    if command -v getent >/dev/null 2>&1; then
        if getent passwd "$site_name" >/dev/null 2>&1; then
            # -r removes the home directory; OK if it's already gone.
            run_quiet userdel -r "$site_name"
            # Fallback without -r (some distros/policies may block it)
            run_quiet userdel "$site_name"
        fi
        if getent group "$site_name" >/dev/null 2>&1; then
            run_quiet groupdel "$site_name"
        fi
    else
        # Best-effort fallback
        run_quiet userdel -r "$site_name"
        run_quiet userdel "$site_name"
        run_quiet groupdel "$site_name"
    fi
}

cleanup_checkmk_site() {
    local site_name="$1"

    if command -v omd >/dev/null 2>&1; then
        run_quiet omd stop "$site_name"
        if command -v timeout >/dev/null 2>&1; then
            run_quiet timeout 90 omd rm -f "$site_name"
        else
            run_quiet omd rm -f "$site_name"
        fi
    fi

    # Fallback/manual cleanup (handles cases where omd rm hangs)
    local site_dir1="/omd/sites/${site_name}"
    local site_dir2="/opt/omd/sites/${site_name}"

    # Kill only processes that reference this specific site path
    run_quiet pkill -9 -f "/omd/sites/${site_name}" || true

    # Attempt to unmount tmp if it was mounted
    if command -v mountpoint >/dev/null 2>&1; then
        run_quiet mountpoint -q "${site_dir1}/tmp" && run_quiet umount "${site_dir1}/tmp"
        run_quiet mountpoint -q "${site_dir2}/tmp" && run_quiet umount "${site_dir2}/tmp"
    else
        run_quiet umount "${site_dir1}/tmp"
        run_quiet umount "${site_dir2}/tmp"
    fi

    # Remove fstab lines that reference this site (best effort)
    if [[ -w /etc/fstab ]] && grep -q "/omd/sites/${site_name}" /etc/fstab 2>/dev/null; then
        run sed -i "/\/omd\/sites\/${site_name//\//\\/}/d" /etc/fstab
    fi

    run rm -rf "$site_dir1" "$site_dir2"
}

remove_checkmk_packages() {
    if ! command -v apt-get >/dev/null 2>&1; then
        return 0
    fi

    local -a pkgs=()
    if command -v dpkg-query >/dev/null 2>&1; then
        while IFS= read -r pkg; do
            [[ -n "$pkg" ]] || continue
            pkgs+=("$pkg")
        done < <(dpkg-query -W -f='${Package}\n' 2>/dev/null | grep -E '^check-mk-(raw|enterprise|agent)(-|$)' || true)
    fi

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        DEBIAN_FRONTEND=noninteractive run apt-get remove --purge -y "${pkgs[@]}"
    fi

    DEBIAN_FRONTEND=noninteractive run apt-get -f install -y
    DEBIAN_FRONTEND=noninteractive run apt-get autoremove --purge -y
    run apt-get autoclean -y
}

cleanup_ufw_rules() {
    local http_port="$1"
    if ! command -v ufw >/dev/null 2>&1; then
        return 0
    fi

    # Remove rules this installer may have added (do NOT touch SSH)
    local -a ports=(80 443 6556 7000 7500 6557)
    if [[ -n "$http_port" ]]; then
        ports+=("$http_port")
    fi

    local p
    for p in "${ports[@]}"; do
        [[ -n "$p" ]] || continue
        run_quiet ufw --force delete allow "${p}/tcp"
    done
}

main() {
    require_root
    load_env

    local site_name="${CHECKMK_SITE_NAME:-monitoring}"
    local http_port="${CHECKMK_HTTP_PORT:-5000}"

    log "================================================================="
    log "CheckMK Complete Cleanup"
    log "- Site: ${site_name}"
    log "================================================================="

    log "[1/8] Stopping and disabling services"
    stop_disable_unit "check-mk-agent.socket"
    stop_disable_unit "check-mk-agent@.service"
    stop_disable_unit "check-mk-agent-plain.socket"
    stop_disable_unit "check-mk-agent-plain@.service"
    stop_disable_unit "frps.service"
    stop_disable_unit "frpc.service"
    stop_disable_unit "ydea-toolkit.service"
    stop_disable_unit "ydea-toolkit.timer"
    stop_disable_unit "ydea-ticket-monitor.service"
    stop_disable_unit "ydea-ticket-monitor.timer"

    log "[2/8] Cleaning CheckMK site"
    cleanup_checkmk_site "$site_name"

    log "[3/8] Removing CheckMK packages"
    remove_checkmk_packages

	log "[3.5/8] Removing CheckMK site user/group"
	cleanup_site_user_group "$site_name"

    log "[4/8] Removing FRP files"
    run rm -f /etc/systemd/system/frps.service /etc/systemd/system/frpc.service
    run rm -rf /etc/frp
    run rm -f /usr/local/bin/frps /usr/local/bin/frpc

    log "[5/8] Removing Ydea Toolkit"
    run rm -f /etc/systemd/system/ydea-toolkit.service /etc/systemd/system/ydea-toolkit.timer
    run rm -f /etc/systemd/system/ydea-ticket-monitor.service /etc/systemd/system/ydea-ticket-monitor.timer
    run rm -f /etc/ydea-toolkit.env
    run rm -rf /opt/ydea-toolkit
    run rm -f /usr/local/bin/ydea-toolkit

    log "[6/8] Removing monitoring scripts and leftovers"
    run rm -rf /usr/lib/check_mk_agent/local /usr/lib/check_mk_agent/plugins
    run rm -f /usr/local/bin/launcher_remote_* /usr/local/bin/launcher_remote_script.sh

    # Common leftover directories
    run rm -rf /etc/check_mk /var/lib/check_mk_agent /var/lib/cmk-agent

    log "[7/8] Cleaning UFW rules"
    cleanup_ufw_rules "$http_port"

    log "[8/8] Reloading systemd"
    if command -v systemctl >/dev/null 2>&1; then
        run_quiet systemctl daemon-reload
        run_quiet systemctl reset-failed
    fi

    # Remove installer .env to allow a fresh wizard run (repo stays intact)
    run rm -f "${INSTALLER_ROOT}/.env"

    log "================================================================="
    log "Cleanup completed. System ready for fresh installation."
    log "================================================================="
}

main "$@"

