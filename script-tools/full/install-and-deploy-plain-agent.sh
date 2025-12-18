#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage: install-and-deploy-plain-agent.sh [options]

Installa Checkmk Agent su host remoti via SSH e abilita il "plain agent" su TCP (default 6556).

Opzioni:
	--hosts "h1 h2"   Lista host separati da spazi (se omesso, chiede input)
	--user USER       Utente SSH (default: root)
	--deb-url URL     URL pacchetto DEB (Debian/Ubuntu)
	--rpm-url URL     URL pacchetto RPM (RHEL/Rocky/CentOS)
	--force           Sovrascrive unit file già presenti
	--port PORT       Porta TCP (default: 6556)

Puoi anche usare variabili d'ambiente: DEB_URL, RPM_URL.
USAGE
}

SSH_USER="root"
HOSTS=""
DEB_URL="${DEB_URL:-}"
RPM_URL="${RPM_URL:-}"
FORCE=0
PORT=6556

while [[ $# -gt 0 ]]; do
	case "$1" in
		--hosts) HOSTS="${2:-}"; shift 2 ;;
		--user) SSH_USER="${2:-}"; shift 2 ;;
		--deb-url) DEB_URL="${2:-}"; shift 2 ;;
		--rpm-url) RPM_URL="${2:-}"; shift 2 ;;
		--force) FORCE=1; shift 1 ;;
		--port) PORT="${2:-}"; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
	esac
done

if [[ -z "$HOSTS" ]]; then
	read -r -p "Inserisci uno o più host separati da spazi: " HOSTS
fi

if [[ -z "$HOSTS" ]]; then
	echo "ERROR: no hosts provided" >&2
	exit 2
fi

if [[ -z "$DEB_URL" && -z "$RPM_URL" ]]; then
	echo "ERROR: provide at least one of --deb-url/--rpm-url (or env DEB_URL/RPM_URL)" >&2
	exit 2
fi

REMOTE_SCRIPT=$(cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

DEB_URL="${DEB_URL:-}"
RPM_URL="${RPM_URL:-}"
FORCE="${FORCE:-0}"
PORT="${PORT:-6556}"

SOCKET_FILE="/etc/systemd/system/check-mk-agent-plain.socket"
SERVICE_FILE="/etc/systemd/system/check-mk-agent-plain@.service"

fetch() {
	local url="$1" out="$2"
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL "$url" -o "$out"
		return 0
	fi
	if command -v wget >/dev/null 2>&1; then
		wget -qO "$out" "$url"
		return 0
	fi
	echo "ERROR: neither curl nor wget available" >&2
	exit 1
}

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
	echo "ERROR: run as root (remote)" >&2
	exit 1
fi

command -v systemctl >/dev/null 2>&1 || { echo "ERROR: systemd required" >&2; exit 1; }

pkg=""
if command -v dpkg >/dev/null 2>&1; then
	pkg="deb"
elif command -v rpm >/dev/null 2>&1; then
	pkg="rpm"
fi

case "$pkg" in
	deb)
		[[ -n "$DEB_URL" ]] || { echo "ERROR: DEB_URL not provided" >&2; exit 2; }
		echo "Installing Checkmk Agent (DEB)..."
		tmp="/tmp/check-mk-agent.deb"
		fetch "$DEB_URL" "$tmp"
		dpkg -i "$tmp" || (command -v apt-get >/dev/null 2>&1 && apt-get -y -f install)
		rm -f "$tmp" || true
		;;
	rpm)
		[[ -n "$RPM_URL" ]] || { echo "ERROR: RPM_URL not provided" >&2; exit 2; }
		echo "Installing Checkmk Agent (RPM)..."
		tmp="/tmp/check-mk-agent.rpm"
		fetch "$RPM_URL" "$tmp"
		rpm -Uvh --replacepkgs "$tmp"
		rm -f "$tmp" || true
		;;
	*)
		echo "ERROR: unsupported host (no dpkg/rpm found)" >&2
		exit 1
		;;
esac

echo "Disabling TLS agent controller (cmk-agent-ctl-daemon)..."
systemctl stop cmk-agent-ctl-daemon 2>/dev/null || true
systemctl disable cmk-agent-ctl-daemon 2>/dev/null || true

echo "Disabling default systemd socket (check-mk-agent.socket)..."
systemctl stop check-mk-agent.socket 2>/dev/null || true
systemctl disable check-mk-agent.socket 2>/dev/null || true

if [[ "$FORCE" != "1" ]] && { [[ -f "$SOCKET_FILE" ]] || [[ -f "$SERVICE_FILE" ]]; }; then
	echo "Plain unit already present; skipping (use --force to overwrite)."
	exit 0
fi

echo "Writing systemd units for plain agent on TCP/${PORT}..."
cat >"$SOCKET_FILE" <<UNIT
[Unit]
Description=Checkmk Agent (plain TCP ${PORT})
Documentation=https://docs.checkmk.com/latest/en/agent_linux.html

[Socket]
ListenStream=${PORT}
Accept=yes

[Install]
WantedBy=sockets.target
UNIT

cat >"$SERVICE_FILE" <<'UNIT'
[Unit]
Description=Checkmk Agent (plain TCP) connection
Documentation=https://docs.checkmk.com/latest/en/agent_linux.html

[Service]
ExecStart=/usr/bin/check_mk_agent
StandardInput=socket
StandardOutput=socket
UNIT

systemctl daemon-reload
systemctl enable --now check-mk-agent-plain.socket

echo "Host configured."
EOF
)

for h in $HOSTS; do
	echo "============================"
	echo "Install + configure: ${h}"
	echo "============================"
	ssh -o BatchMode=yes -o ConnectTimeout=10 "${SSH_USER}@${h}" "DEB_URL='$DEB_URL' RPM_URL='$RPM_URL' FORCE='$FORCE' PORT='$PORT' bash -s" <<<"$REMOTE_SCRIPT"
	echo
done

exit 0

# Archived output (previous corrupted content) below:
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# [100%]Preparing...                          
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# [100%]Updating / installing...   1:check-mk-agent-2.4.0p12-1       
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# [100%]Ôö£ÔûæÔö╝┬®├ö├ç├┐├ö├çÔûæ Disabilito TLS e socket systemd standard...Ôö£ÔûæÔö╝┬®├ö├ç├┐├ö├çÔûæ Creo unit systemd per agent plain...Ôö£ÔûæÔö╝┬®├ö├ç├┐├ö├çÔûæ Ricarico systemd...Ôö£ÔûæÔö╝┬®├ö├ç├┐├ö├çÔûæ Abilito e avvio il nuovo socket...Ôö£├│Ôö╝├┤├ö├ç┬¬ Plain agent attivo. Test locale:<<<check_mk>>>Version: 2.4.0p12Hostname: marziodemoAgentOS: linuxUptime: 12345============================Ôö£├│Ôö╝┬ÑÔö¼├¡Ôö£┬╗Ôö¼┬®Ôö¼├à  Installo + configuro proxmox01============================Ôö£ÔûæÔö╝┬®├ö├ç├┐├ö├çÔûæ Host Debian/Ubuntu rilevato, installo DEB...Selecting previously unselected package check-mk-agent.(Reading database ... 123456 files and directories currently installed.)Preparing to unpack .../check-mk-agent_2.4.0p12-1_all.deb ...Unpacking check-mk-agent (2.4.0p12-1) ...Setting up check-mk-agent (2.4.0p12-1) ...Ôö£ÔûæÔö╝┬®├ö├ç├┐├ö├çÔûæ Disabilito TLS e socket systemd standard...Ôö£ÔûæÔö╝┬®├ö├ç├┐├ö├çÔûæ Creo unit systemd per agent plain...Ôö£ÔûæÔö╝┬®├ö├ç├┐├ö├çÔûæ Ricarico systemd...Ôö£ÔûæÔö╝┬®├ö├ç├┐├ö├çÔûæ Abilito e avvio il nuovo socket...Ôö£├│Ôö╝├┤├ö├ç┬¬ Plain agent attivo. Test locale:<<<check_mk>>>Version: 2.4.0p12Hostname: proxmox01AgentOS: linuxUptime: 6789============================Ôö£├│Ôö╝┬ÑÔö¼├¡Ôö£┬╗Ôö¼┬®Ôö¼├à  Installo + configuro rocky01============================Ôö£ÔûæÔö╝┬®├ö├ç├┐├ö├çÔûæ Host RHEL/CentOS/Rocky rilevato, installo RPM...Verifying...                          
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# [100%]Preparing...                          
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# [100%]Updating / installing...   1:check-mk-agent-2.4.0p12-1       
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# [100%]Ôö£ÔûæÔö╝┬®├ö├ç├┐├ö├çÔûæ Disabilito TLS e socket systemd standard...Ôö£ÔûæÔö╝┬®├ö├ç├┐├ö├çÔûæ Creo unit systemd per agent plain...Ôö£ÔûæÔö╝┬®├ö├ç├┐├ö├çÔûæ Ricarico systemd...Ôö£ÔûæÔö╝┬®├ö├ç├┐├ö├çÔûæ Abilito e avvio il nuovo socket...Ôö£├│Ôö╝├┤├ö├ç┬¬ Plain agent attivo. Test locale:<<<check_mk>>>Version: 2.4.0p12Hostname: rocky01AgentOS: linuxUptime: 4321
