#!/bin/bash
# ============================================================
#  Checkmk Optimize Script - Versione Bilanciata (Finale)
#  Compatibile con Ubuntu 24.04 + Checkmk Raw 2.4.x
#  Include snapshot Timeshift pre/post ottimizzazione
#  con log dedicato in /var/log/timeshift-rotation.log
#  Autore: NethLab / Marzio Project
# ============================================================
LOGFILE="/var/log/checkmk-optimize.log"
TSLOG="/var/log/timeshift-rotation.log"
BACKUP_DIR="/var/backups/checkmk-optimize"
DATE=$(date +%Y%m%d-%H%M%S)mkdir -p "$BACKUP_DIR"touch "$LOGFILE" "$TSLOG"
echo "=== Checkmk Optimization Script (Bilanciato) ==="
echo "Log principale: $LOGFILE"
echo "Log snapshot: $TSLOG"
echo "Backup: $BACKUP_DIR"
echo "Data: $DATE"echo
# ------------------------------------------------------------
# Funzione di logginglog() { 
echo "[$(date +%F_%T)] $*" | tee -a "$LOGFILE"; }
# ------------------------------------------------------------
# Snapshot Timeshift (Pre-ottimizzazione)if command -v timeshift >/dev/null 2>&1; then  read -p "Vuoi creare uno snapshot Timeshift prima di iniziare? (s/n): " tssnap  if [[ "$tssnap" =~ ^[Ss]$ ]]; then    log "Creazione snapshot Timeshift pre-ottimizzazione..."    
SNAP_COMMENT="Pre-checkmk-optimize $(date +%F_%T) - created by checkmk-optimize"    /usr/bin/timeshift --create --comments "$SNAP_COMMENT" --tags D    if [[ $? -eq 0 ]]; then      log "Snapshot Timeshift pre-ottimizzazione completato."      
echo "[$(date +%F_%T)] Snapshot PRE creato con successo: $SNAP_COMMENT" >> "$TSLOG"    else      log "Errore durante la creazione dello snapshot Timeshift pre-ottimizzazione."      
echo "[$(date +%F_%T)] ERRORE creazione snapshot PRE: $SNAP_COMMENT" >> "$TSLOG"    fi  fi
else  log "Timeshift non installato, nessuno snapshot creato."fi
# ------------------------------------------------------------
# 1. Ottimizzazione SWAP e ZRAMread -p "Ottimizzare SWAP (swappiness, zram)? (s/n): " opt_swapif [[ "$opt_swap" =~ ^[Ss]$ ]]; then  log "Backup sysctl.conf e configurazione zram..."  cp -a /etc/sysctl.conf "$BACKUP_DIR/sysctl.conf.$DATE.bak"  
echo "vm.swappiness = 10" >> /etc/sysctl.d/99-swap.conf  sysctl -w vm.swappiness=10  if ! dpkg -l | grep -q zram-tools; then    apt update && apt install -y zram-tools  fi  log "ZRAM installato e configurato (default Ubuntu)."fi
# ------------------------------------------------------------
# 2. Disabilita servizi inutiliread -p "Disabilitare servizi non essenziali (snapd, apport, motd-news)? (s/n): " opt_servicesif [[ "$opt_services" =~ ^[Ss]$ ]]; then  for svc in snapd.service apport.service motd-news.timer; do    systemctl disable --now $svc 2>/dev/null && log "Disabilitato: $svc"  done
fi
# ------------------------------------------------------------
# 3. Ottimizzazione scheduler I/Oread -p "Impostare scheduler I/O mq-deadline (SSD/VPS)? (s/n): " opt_ioif [[ "$opt_io" =~ ^[Ss]$ ]]; then  
DEV=$(lsblk -n
do NAME,TYPE | awk '$2=="disk"{print $1;exit}')  
echo mq-deadline > /sys/block/$DEV/queue/scheduler  log "Impostato scheduler mq-deadline su /dev/$DEV"fi
# ------------------------------------------------------------
# 4. Ottimizzazione Database (MariaDB o MySQL)read -p "Ottimizzare Database (innodb, cache, log)? (s/n): " opt_dbif [[ "$opt_db" =~ ^[Ss]$ ]]; then  if systemctl list-unit-files | grep -q mariadb.service; then    
DB_CONF="/etc/mysql/mariadb.conf.d/50-server.cnf"    
DB_SERVICE="mariadb"  elif systemctl list-unit-files | grep -q mysql.service; then    
DB_CONF="/etc/mysql/mysql.conf.d/mysqld.cnf"    
DB_SERVICE="mysql"  else    log "Nessun servizio MariaDB/MySQL trovato ÔÇö salto sezione database."    
DB_CONF=""  fi  if [[ -n "$DB_CONF" && -f "$DB_CONF" ]]; then    cp -a "$DB_CONF" "$BACKUP_DIR/$(basename $DB_CONF).$DATE.bak"    log "Backup $DB_CONF completato."    sed -i '/innodb_buffer_pool_size/d' "$DB_CONF"    sed -i '/innodb_log_file_size/d' "$DB_CONF"    sed -i '/query_cache_size/d' "$DB_CONF"    sed -i '/query_cache_type/d' "$DB_CONF"    cat <<EOT >> "$DB_CONF"
# Ottimizzazione Checkmk Bilanciata ($DATE)innodb_buffer_pool_size = 512Minnodb_log_file_size = 128Mquery_cache_size = 32Mquery_cache_type = 1EOT    systemctl restart "$DB_SERVICE" && log "$DB_SERVICE riavviato con configurazione ottimizzata."  else    log "File di configurazione database non trovato, nessuna modifica applicata."  fi
fi
# ------------------------------------------------------------
# 5. Ottimizzazione Apache (OMD Web)read -p "Ottimizzare Apache (limitazioni risorse, file descriptors)? (s/n): " opt_apacheif [[ "$opt_apache" =~ ^[Ss]$ ]]; then  mkdir -p /etc/systemd/system/apache2.service.d/  cat <<EOT > /etc/systemd/system/apache2.service.d/limits.conf[Service]Limit
NOFILE=4096EOT  systemctl daemon-reexec  systemctl daemon-reload  systemctl restart apache2  log "Apache ottimizzato e riavviato."fi
# ------------------------------------------------------------
# 6. Ottimizzazione dell'agent Checkmkread -p "Abilitare caching agent e TTL per local checks? (s/n): " opt_agentif [[ "$opt_agent" =~ ^[Ss]$ ]]; then  
CACHE_DIR="/var/lib/check_mk_agent/cache"  mkdir -p "$CACHE_DIR"  chown root:root "$CACHE_DIR"  chmod 700 "$CACHE_DIR"  log "Cartella cache agent pronta. Usa TTL nei local checks es: '0 NomeServizio <ttl=300>'"fi
# ------------------------------------------------------------
# 7. Ottimizzazione rete e FRPread -p "Disattivare compressione FRP per ridurre carico CPU? (s/n): " opt_frpif [[ "$opt_frp" =~ ^[Ss]$ ]]; then  for f in /etc/frp/frpc.toml /etc/frp/frps.toml; do    if [[ -f "$f" ]]; then      cp -a "$f" "$BACKUP_DIR/$(basename $f).$DATE.bak"      sed -i 's/use_compression *= *true/use_compression = false/g' "$f"      log "Compressione disattivata in $f"    fi  done  systemctl restart frpc 2>/dev/null || true  systemctl restart frps 2>/dev/null || true
fi
# ------------------------------------------------------------
# 8. Suggerimenti WATO (solo output)log "Suggerimento: in WATO > Global Settings imposta: - 'Normal check interval' a 2ÔÇô3 min per servizi non critici - 'Maximum concurrent checks' a 10ÔÇô15 - 'Periodic Service Discovery' giornaliero o disattivato"
# ------------------------------------------------------------
# Snapshot Timeshift (Post-ottimizzazione)if command -v timeshift >/dev/null 2>&1; then  read -p "Creare snapshot Timeshift post-ottimizzazione? (s/n): " postts  if [[ "$postts" =~ ^[Ss]$ ]]; then    log "Creazione snapshot Timeshift post-ottimizzazione..."    
SNAP_COMMENT="Post-checkmk-optimize $(date +%F_%T) - created by checkmk-optimize"    /usr/bin/timeshift --create --comments "$SNAP_COMMENT" --tags D    if [[ $? -eq 0 ]]; then      log "Snapshot Timeshift post-ottimizzazione completato."      
echo "[$(date +%F_%T)] Snapshot POST creato con successo: $SNAP_COMMENT" >> "$TSLOG"    else      log "Errore durante la creazione dello snapshot Timeshift post-ottimizzazione."      
echo "[$(date +%F_%T)] ERRORE creazione snapshot POST: $SNAP_COMMENT" >> "$TSLOG"    fi  fi
fi
# ------------------------------------------------------------
# 9. Pulizia e riepilogolog "Ottimizzazione completata. Backup in $BACKUP_DIR"echo
echo "=== Ottimizzazione completata ==="
echo "Consulta il log dettagliato: $LOGFILE"
echo "Log snapshot Timeshift: $TSLOG"
echo "Backup configurazioni: $BACKUP_DIR"
echo "Modifiche applicate solo dove confermato."echo
