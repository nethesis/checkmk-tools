# install-checkmk-agent-debtools-frp-nsec8c-rocksolid.sh
> **Categoria:** Operativo

## Descrizione

Script di installazione ROCKSOLID per CheckMK Agent e FRP Client su sistemi NethSecurity/OpenWrt. 

**ROCKSOLID Edition**: Garantisce la sopravvivenza e il ripristino automatico dei servizi dopo major upgrade del sistema operativo.

---

## Caratteristiche

- **Auto-recovery**: Ripristino automatico servizi dopo major upgrade
- **Protezione filesystem**: File critici preservati in `/etc/sysupgrade.conf`
- **Backup binari**: Binari essenziali (`tar`, `ar`, `gzip`) salvati e ripristinati
- **Autocheck boot**: Verifica e riavvio automatico servizi ad ogni boot
- **Curl-based execution**: Script autocheck eseguito da GitHub (mai corrotto)
- **Repository cleanup**: Rimozione automatica repository conflittuali
- **Zero configuration**: Rileva automaticamente versione CheckMK server
- **FRP tunnel**: Configurazione opzionale tunnel reverse proxy

---

## Requisiti

### Sistema Operativo
- NethSecurity 8.x
- OpenWrt 23.05.x o superiore
- Architettura: x86_64

### Network
- Connessione internet attiva
- Accesso al CheckMK server (configurabile)
- (Opzionale) Accesso al server FRP per tunnel

### Permessi
- Esecuzione come `root`

---

## Installazione

### Installazione Standard

```bash
# Download e installazione in un comando
curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/installation/install-checkmk-agent-persistent-nsec8.sh -o /tmp/install-rocksolid.sh
bash /tmp/install-rocksolid.sh
```

### Installazione con Configurazione Custom

```bash
# Specifica server CheckMK custom
export CMK_SERVER="monitor.example.com"
export CMK_SITE="production"
export CMK_PROTOCOL="https"

bash install-checkmk-agent-debtools-frp-nsec8c-rocksolid.sh
```

### Disinstallazione

```bash
bash install-checkmk-agent-debtools-frp-nsec8c-rocksolid.sh --uninstall
```

---

## Variabili d'Ambiente

| Variabile | Default | Descrizione |
|-----------|---------|-------------|
| `CMK_SERVER` | `monitor.nethlab.it` | Hostname CheckMK server |
| `CMK_SITE` | `monitoring` | Nome site CheckMK |
| `CMK_PROTOCOL` | `https` | Protocollo (http/https) |
| `DEB_URL` | (auto-detect) | URL diretto al .deb agent |
| `FRP_VER` | `0.64.0` | Versione FRP client |
| `FRPC_BIN` | `/usr/local/bin/frpc` | Path binario FRP |
| `FRPC_CONF` | `/etc/frp/frpc.toml` | Path config FRP |
| `NON_INTERACTIVE` | `0` | Modalità non interattiva (1=disabilita prompt) |

---

## Workflow Installazione

### Fase 1: CheckMK Agent

1. **Installazione prerequisiti**
   - Aggiunge repository OpenWrt (base, packages)
   - Installa: `ca-bundle`, `ca-certificates`, `wget-ssl`, `socat`, `netcat`, `coreutils-realpath`
   - Installa binari dpkg: `tar`, `ar`, `gzip`

2. **Backup binari critici**
   - Salva `tar`, `ar`, `gzip` in `/opt/checkmk-tools/BACKUP-BINARIES/`
   - Necessari per reinstallazione post-upgrade

3. **Download e installazione agent**
   - Rileva automaticamente versione CheckMK da server
   - Scarica `.deb` corretto per architettura
   - Estrae e installa con `dpkg`
   - Copia agent in `/usr/bin/check_mk_agent`

4. **Configurazione servizio**
   - Crea init script procd in `/etc/init.d/check_mk_agent`
   - Configura `socat` per TCP-LISTEN:6556
   - Abilita e avvia servizio
   - Verifica connettività con `nc 127.0.0.1 6556`

5. **Protezione ROCKSOLID**
   - Aggiunge file a `/etc/sysupgrade.conf`:
     ```
     /opt/checkmk-tools/BACKUP-BINARIES/tar
     /opt/checkmk-tools/BACKUP-BINARIES/ar
     /opt/checkmk-tools/BACKUP-BINARIES/gzip
     /etc/checkmk-post-upgrade.sh
     ```

### Fase 2: FRP Client (Opzionale)

**NOTA**: FRP è completamente **OPZIONALE**. Se non necessiti di tunnel reverse proxy:
- Rispondi **NO** al prompt "Vuoi configurare FRP?"
- Lo script completerà l'installazione solo con CheckMK Agent
- Nessun marker `/opt/checkmk-tools/.frp-installed` verrà creato
- Autocheck non tenterà mai di avviare FRP
- Sistema pienamente funzionante senza FRP

1. **Configurazione interattiva**
   - Prompt per abilitazione FRP
   - Se **NO**: salta tutta la fase FRP
   - Se **SI**: richiede token autenticazione, porta remota, nome proxy

2. **Download binario**
   - Scarica `frp_${FRP_VER}_linux_amd64.tar.gz`
   - Estrae in `/usr/local/bin/frpc`
   - Imposta permessi esecuzione

3. **Generazione configurazione**
   - Crea `/etc/frp/frpc.toml` con token
   - Formato config v0.x (sezione `[common]`)
   - Configurazione proxy TCP:
     ```toml
     [common]
     serverAddr = "SERVER"
     serverPort = 7000
     auth.method = "token"
     auth.token = "TOKEN"
     
     [[proxies]]
     name = "PROXY_NAME"
     type = "tcp"
     localIP = "127.0.0.1"
     localPort = 6556
     remotePort = REMOTE_PORT
     ```

4. **Init script procd**
   - Crea `/etc/init.d/frpc`
   - Abilita avvio automatico
   - Avvia servizio
   - Verifica processo attivo

5. **Protezione ROCKSOLID**
   - Aggiunge a sysupgrade.conf:
     ```
     /usr/local/bin/frpc
     /etc/frp/frpc.toml
     /etc/init.d/frpc
     /opt/checkmk-tools/.frp-installed
     ```
   - Crea marker file `/opt/checkmk-tools/.frp-installed`

### Fase 3: Autocheck Boot

1. **Script autocheck**
   - NON copia file locale (si corromperebbe)
   - Configura `/etc/rc.local` per eseguire da GitHub:
     ```bash
   curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/upgrade_maintenance/rocksolid-startup-check.sh | bash
     ```

2. **Protezione rc.local**
   - Aggiunge `/etc/rc.local` a sysupgrade.conf
   - Garantisce esecuzione autocheck ad ogni boot

---

## Post-Upgrade: Auto-Recovery

Dopo un major upgrade, il sistema esegue automaticamente:

### 1. Boot e rc.local

```
Sistema riavvia
    |
    v
/etc/rc.local eseguito
    |
    v
curl scarica rocksolid-startup-check.sh da GitHub
    |
    v
Script autocheck eseguito
```

### 2. Autocheck Workflow

```
Verifica CheckMK Agent (porta 6556)
    |
    +-- Se attivo: OK
    |
    +-- Se NON attivo:
        |
        +-- Ripristina tar/ar/gzip da backup
        +-- Reinstalla agent da .deb
        +-- Configura socat
        +-- Avvia servizio
        
Verifica marker FRP (.frp-installed)
    |
    +-- Se NON esiste: Skip FRP
    |
    +-- Se esiste:
        |
        +-- Verifica binario frpc
        +-- Verifica config frpc.toml
        +-- Verifica processo frpc
        +-- Se NON attivo: /etc/init.d/frpc restart

Pulizia repository custom
    |
    +-- Verifica /etc/opkg/customfeeds.conf
    +-- Se contiene repo OpenWrt non autorizzati:
        |
        +-- Crea backup .backup
        +-- Svuota file (header only)
        +-- Previene conflitti futuri
```

### 3. Risultato

- **Tempo recovery**: 20-30 secondi dal boot
- **CheckMK Agent**: Operativo
- **FRP Client**: Operativo (se configurato)
- **Repository**: Puliti (no conflitti)
- **Log**: `/var/log/rocksolid-startup.log`

---

## File Protetti in sysupgrade.conf

Lo script aggiunge automaticamente questi file per sopravvivere ai major upgrade:

### CheckMK Agent
```
/opt/checkmk-tools/BACKUP-BINARIES/tar
/opt/checkmk-tools/BACKUP-BINARIES/ar
/opt/checkmk-tools/BACKUP-BINARIES/gzip
/opt/checkmk-tools/BACKUP-BINARIES/check-mk-agent.deb
/etc/checkmk-post-upgrade.sh
```

### FRP Client
```
/usr/local/bin/frpc
/etc/frp/frpc.toml
/etc/init.d/frpc
/opt/checkmk-tools/.frp-installed
```

### Sistema
```
/etc/rc.local
```

---

## Log e Verifica

### Verifica Installazione

```bash
# CheckMK Agent
nc 127.0.0.1 6556 | head
pgrep -fa "socat.*6556"

# FRP Client (se configurato)
pgrep -fa frpc
cat /etc/frp/frpc.toml

# Protezioni attive
grep -E "check_mk|frpc" /etc/sysupgrade.conf

# Marker FRP
ls -lh /opt/checkmk-tools/.frp-installed
```

### Log Autocheck

```bash
# Log completo
cat /var/log/rocksolid-startup.log

# Ultimi 30 righe
tail -30 /var/log/rocksolid-startup.log

# Solo errori
grep -i "error\|fail\|warn" /var/log/rocksolid-startup.log
```

### Test CheckMK Agent

```bash
# Test locale
echo "<<<check_mk>>>" | nc 127.0.0.1 6556 -w 3

# Test da CheckMK server
ssh monitoring@checkmk-server "cmk-agent-ctl dump"
```

---

## Troubleshooting

### CheckMK Agent non risponde

```bash
# Verifica processo
pgrep -fa socat

# Se non attivo, riavvia
/etc/init.d/check_mk_agent restart

# Verifica connettività
nc 127.0.0.1 6556

# Log errori
logread | grep -i checkmk
```

### FRP Client non connette

```bash
# Verifica processo
pgrep -fa frpc

# Se non attivo, riavvia
/etc/init.d/frpc restart

# Log FRP
tail -50 /var/log/frpc.log

# Test connettività server
nc -zv FRPC_SERVER 7000

# Verifica config
cat /etc/frp/frpc.toml
```

### Post-upgrade servizi non ripartono

```bash
# Esegui manualmente autocheck
curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-tools/full/upgrade_maintenance/rocksolid-startup-check.sh | bash

# Verifica log
tail -50 /var/log/rocksolid-startup.log

# Esegui script post-upgrade manuale
bash /etc/checkmk-post-upgrade.sh

# Verifica file protetti sopravvissuti
ls -lh /opt/checkmk-tools/BACKUP-BINARIES/
ls -lh /usr/local/bin/frpc
ls -lh /etc/frp/frpc.toml
```

### Binari corrotti dopo upgrade

```bash
# Verifica backup binari
ls -lh /opt/checkmk-tools/BACKUP-BINARIES/

# Ripristina manualmente
cp /opt/checkmk-tools/BACKUP-BINARIES/tar /bin/tar
cp /opt/checkmk-tools/BACKUP-BINARIES/ar /usr/bin/ar
cp /opt/checkmk-tools/BACKUP-BINARIES/gzip /bin/gzip
chmod +x /bin/tar /usr/bin/ar /bin/gzip

# Reinstalla agent
bash /etc/checkmk-post-upgrade.sh
```

---

## Comandi Utili

### Gestione Servizi

```bash
# CheckMK Agent
/etc/init.d/check_mk_agent start|stop|restart|status

# FRP Client
/etc/init.d/frpc start|stop|restart|status

# Verifica processi
ps | grep -E "socat|frpc"
```

### Backup Manuale

```bash
# Backup completo configurazione
tar -czf /tmp/checkmk-backup.tar.gz \
  /opt/checkmk-tools/BACKUP-BINARIES/ \
  /usr/local/bin/frpc \
  /etc/frp/frpc.toml \
  /etc/init.d/frpc \
  /etc/init.d/check_mk_agent \
  /etc/rc.local \
  /etc/sysupgrade.conf

# Copia backup su server remoto
scp /tmp/checkmk-backup.tar.gz user@server:/backup/
```

### Test Major Upgrade

```bash
# 1. Pre-upgrade: verifica stato
echo "=== PRE-UPGRADE ===" > /tmp/pre-upgrade.log
pgrep -fa "socat|frpc" >> /tmp/pre-upgrade.log
grep -c checkmk /etc/sysupgrade.conf >> /tmp/pre-upgrade.log

# 2. Esegui major upgrade via web interface

# 3. Post-upgrade: verifica stato
sleep 60  # Attendi boot completo
echo "=== POST-UPGRADE ===" > /tmp/post-upgrade.log
pgrep -fa "socat|frpc" >> /tmp/post-upgrade.log
tail -30 /var/log/rocksolid-startup.log >> /tmp/post-upgrade.log

# 4. Confronta
cat /tmp/pre-upgrade.log /tmp/post-upgrade.log
```

---

## FAQ

### Q: Lo script funziona su architetture diverse da x86_64?
**A**: Attualmente supporta solo x86_64. Per ARM/MIPS modificare `REPO_BASE` e `REPO_PACKAGES`.

### Q: Posso usare CheckMK server diverso da monitor.nethlab.it?
**A**: Sì, imposta `export CMK_SERVER="tuo-server.com"` prima dell'esecuzione.

### Q: FRP è obbligatorio?
**A**: No, è completamente opzionale. Durante l'installazione ti verrà chiesto se vuoi configurare FRP. Se rispondi NO:
- Verrà installato solo CheckMK Agent (porta 6556)
- Nessun marker FRP creato
- Autocheck funziona normalmente (verifica solo CheckMK Agent)
- Sistema pienamente operativo senza tunnel
- Puoi sempre installare FRP successivamente rieseguendo lo script

### Q: Cosa succede se disabilito FRP dopo l'installazione?
**A**: Rimuovi il marker: `rm /opt/checkmk-tools/.frp-installed`. Autocheck non tenterà più di riavviarlo.

### Q: Posso reinstallare senza disinstallare?
**A**: Sì, lo script rileva installazioni esistenti e aggiorna i file.

### Q: Come aggiorno la versione FRP?
**A**: Modifica `FRP_VER` e riesegui lo script, oppure scarica manualmente e sostituisci `/usr/local/bin/frpc`.

### Q: Repository custom vengono rimossi ad ogni boot?
**A**: No, solo se contengono repo OpenWrt. Repository NethSecurity ufficiali non vengono toccati.

### Q: Posso eseguire autocheck manualmente?
**A**: Sì: `curl -fsSL https://raw.githubusercontent.com/.../rocksolid-startup-check.sh | bash`

---

## Sicurezza

### Protezione Token FRP

Il token FRP è memorizzato in `/etc/frp/frpc.toml` che è:
- Protetto in sysupgrade.conf (sopravvive a upgrade)
- Leggibile solo da root (chmod 600 consigliato)
- Mai esposto in log o output

### Curl da GitHub

Script autocheck eseguito via curl da GitHub:
- Usa HTTPS (TLS encryption)
- Repository verificato (github.com/Coverup20/checkmk-tools)
- Nessuna esecuzione locale (no file corrotti)

Considerazioni:
- Richiede fiducia nel repository GitHub
- Alternativa: fork privato e modifica URL in rc.local

---

## Architettura Tecnica

### Perché dpkg su OpenWrt?

CheckMK fornisce agent come pacchetto `.deb` (Debian). OpenWrt usa `opkg` (non compatibile con .deb). Soluzione:

1. Installa binari dpkg essenziali: `tar`, `ar`, `gzip`
2. Usa script personalizzato per estrarre .deb
3. Installa contenuto manualmente
4. Bypassa dependency resolution di dpkg

### Perché socat invece di xinetd?

- OpenWrt non include xinetd
- `socat` è più leggero e flessibile
- Configurazione più semplice via procd
- Nessuna dipendenza aggiuntiva

### Perché FRP invece di SSH tunnel?

- FRP più leggero di OpenSSH server
- Configurazione semplificata (un file TOML)
- Supporto multiplex (più tunnel su una connessione)
- Reconnect automatico
- Non richiede account SSH sul firewall

---

## Riferimenti

- **CheckMK**: https://checkmk.com/
- **FRP**: https://github.com/fatedier/frp
- **OpenWrt**: https://openwrt.org/
- **NethSecurity**: https://www.nethsecurity.org/
- **Repository**: https://github.com/Coverup20/checkmk-tools

---

## Licenza

Script parte del progetto checkmk-tools.
Uso interno Nethesis / laboratorio.

---

## Changelog

### v2.0 - ROCKSOLID Edition (2026-01-29)
- Aggiunta protezione file in sysupgrade.conf
- Backup automatico binari critici
- Auto-recovery post-upgrade
- Autocheck eseguito da GitHub (curl-based)
- Pulizia automatica repository conflittuali
- Protezione esplicita file config FRP (frpc.toml)
- Marker-based FRP detection

### v1.0 - Initial Release
- Installazione base CheckMK Agent
- Supporto FRP tunnel
- Configurazione procd/socat
