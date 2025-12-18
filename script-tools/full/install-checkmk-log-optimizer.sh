#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage: install-checkmk-log-optimizer.sh [--site SITE]

Installa un set di configurazioni logrotate + cleanup cron per un sito Checkmk/OMD.

Opzioni:
	--site SITE   Nome site OMD (default: monitoring)
USAGE
}

SITE="monitoring"
while [[ $# -gt 0 ]]; do
	case "$1" in
		--site) SITE="${2:-}"; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
	esac
done

if [[ -z "$SITE" ]]; then
	echo "ERROR: --site is empty" >&2
	exit 2
fi

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
	echo "ERROR: run as root" >&2
	exit 1
fi

SITE_PATH="/opt/omd/sites/$SITE"
if [[ ! -d "$SITE_PATH" ]]; then
	echo "ERROR: site path not found: $SITE_PATH" >&2
	echo "Check available sites with: omd sites" >&2
	exit 1
fi

echo
echo "==============================================="
echo "   INSTALLAZIONE LOG OPTIMIZATION PACK"
echo "   Checkmk/OMD - site: $SITE"
echo "==============================================="
echo

mkdir -p "$SITE_PATH/etc/logrotate.d" "$SITE_PATH/local/lib" "$SITE_PATH/etc/cron.d"

echo "Configuro logrotate per Nagios (core)..."
cat >"$SITE_PATH/etc/logrotate.d/nagios" <<EOF
$SITE_PATH/var/nagios/nagios.log {
		daily
		rotate 14
		size 100M
		compress
		delaycompress
		missingok
		notifempty
		create 640 $SITE $SITE
		sharedscripts
		postrotate
				$SITE_PATH/bin/omd reload $SITE >/dev/null 2>&1 || true
		endscript
}
EOF

echo "Configuro logrotate per Apache interno del site..."
cat >"$SITE_PATH/etc/logrotate.d/apache" <<EOF
$SITE_PATH/var/log/apache/*log* {
		daily
		rotate 14
		size 50M
		compress
		delaycompress
		missingok
		notifempty
		create 640 $SITE $SITE
		sharedscripts
		postrotate
				$SITE_PATH/bin/apache reload $SITE >/dev/null 2>&1 || true
		endscript
}
EOF

echo "Configuro logrotate per log OMD (var/log/*.log)..."
cat >"$SITE_PATH/etc/logrotate.d/omd" <<EOF
$SITE_PATH/var/log/*.log {
		daily
		rotate 14
		size 50M
		compress
		delaycompress
		missingok
		notifempty
		create 640 $SITE $SITE
}
EOF

echo "Configuro logrotate per Event Console (mkeventd.log)..."
cat >"$SITE_PATH/etc/logrotate.d/mkeventd" <<EOF
$SITE_PATH/var/log/mkeventd.log {
		weekly
		rotate 8
		size 20M
		compress
		delaycompress
		missingok
		notifempty
}
EOF

chown root:root "$SITE_PATH/etc/logrotate.d/nagios" "$SITE_PATH/etc/logrotate.d/apache" "$SITE_PATH/etc/logrotate.d/omd" "$SITE_PATH/etc/logrotate.d/mkeventd"
chmod 0644 "$SITE_PATH/etc/logrotate.d/nagios" "$SITE_PATH/etc/logrotate.d/apache" "$SITE_PATH/etc/logrotate.d/omd" "$SITE_PATH/etc/logrotate.d/mkeventd"

echo "Installo cleanup piggyback (+cron)..."
cat >"$SITE_PATH/local/lib/cleanup-piggyback.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
find "$SITE_PATH/var/piggyback" -type f -mtime +3 -delete
find "$SITE_PATH/var/piggyback" -type d -empty -delete
EOF
chmod +x "$SITE_PATH/local/lib/cleanup-piggyback.sh"

cat >"$SITE_PATH/etc/cron.d/cleanup-piggyback" <<EOF
0 3 * * * $SITE $SITE_PATH/local/lib/cleanup-piggyback.sh
EOF
chown "$SITE:$SITE" "$SITE_PATH/etc/cron.d/cleanup-piggyback"
chmod 0644 "$SITE_PATH/etc/cron.d/cleanup-piggyback"

echo "Installo cleanup crash dump (+cron)..."
cat >"$SITE_PATH/local/lib/cleanup-crash.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
find "$SITE_PATH/var/check_mk/crash" -type f -mtime +7 -delete
EOF
chmod +x "$SITE_PATH/local/lib/cleanup-crash.sh"

cat >"$SITE_PATH/etc/cron.d/cleanup-crash" <<EOF
10 3 * * * $SITE $SITE_PATH/local/lib/cleanup-crash.sh
EOF
chown "$SITE:$SITE" "$SITE_PATH/etc/cron.d/cleanup-crash"
chmod 0644 "$SITE_PATH/etc/cron.d/cleanup-crash"

echo "Installo cleanup notify logs (+cron)..."
cat >"$SITE_PATH/local/lib/cleanup-notify.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
[[ -d "$SITE_PATH/var/log/notify" ]] || exit 0
find "$SITE_PATH/var/log/notify" -type f -mtime +5 -delete
EOF
chmod +x "$SITE_PATH/local/lib/cleanup-notify.sh"

cat >"$SITE_PATH/etc/cron.d/cleanup-notify" <<EOF
20 3 * * * $SITE $SITE_PATH/local/lib/cleanup-notify.sh
EOF
chown "$SITE:$SITE" "$SITE_PATH/etc/cron.d/cleanup-notify"
chmod 0644 "$SITE_PATH/etc/cron.d/cleanup-notify"

echo
echo "==============================================="
echo "   INSTALLAZIONE COMPLETATA"
echo "==============================================="
echo "File creati in:"
echo " - $SITE_PATH/etc/logrotate.d/"
echo " - $SITE_PATH/local/lib/"
echo " - $SITE_PATH/etc/cron.d/"
echo
echo "Test veloce (esempio):"
echo "  logrotate -vf $SITE_PATH/etc/logrotate.d/apache"
echo
