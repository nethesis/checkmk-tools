# Guida Installazione CMK Local Discovery Trigger

## Obiettivo

Questa guida installa e configura il trigger che:

- legge i local checks da `cmk -d <host>`
- rileva differenze (`new` / `vanished` / hash)
- esegue discovery solo quando serve
- scrive log unificato in `/var/log/checkmk_server_autoheal.log`

Supporta installazione completa lato server e prerequisiti lato host.

## Prerequisiti

- Server CheckMK con repository presente in `/opt/checkmk-tools`
- Python 3 disponibile sul server
- Accesso root o sudo
- Host monitorati già configurati in CheckMK

## Installazione lato server

### Modalità rapida (consigliata)

```bash
# Zero argomenti: auto-detect site/user/group + preset produzione (timer 5 min)
python3 /opt/checkmk-tools/script-tools/full/sync_update/install-cmk-local-discovery-trigger.py

# Variante esplicita preset rapido
python3 /opt/checkmk-tools/script-tools/full/sync_update/install-cmk-local-discovery-trigger.py --quick
```

### 1) Aggiorna repository

```bash
cd /opt/checkmk-tools
git pull
```

### 2) Installa/aggiorna service e timer

```bash
python3 /opt/checkmk-tools/script-tools/full/sync_update/install-cmk-local-discovery-trigger.py \
  --site monitoring \
  --run-as-user monitoring \
  --run-as-group monitoring \
  --interval-min 5 \
  --agent-timeout 90 \
  --log-file /var/log/checkmk_server_autoheal.log

# Opzionale: ingloba installazione git + setup auto sync git
python3 /opt/checkmk-tools/script-tools/full/sync_update/install-cmk-local-discovery-trigger.py \
  --site monitoring \
  --run-as-user monitoring \
  --run-as-group monitoring \
  --interval-min 5 \
  --agent-timeout 90 \
  --log-file /var/log/checkmk_server_autoheal.log \
  --setup-auto-sync-git \
  --auto-sync-interval-sec 60 \
  --repo-dir /opt/checkmk-tools \
  --auto-sync-log-file /var/log/auto-git-sync.log
```

### 3) Riavvia timer e avvia un run

```bash
systemctl restart checkmk-local-discovery-trigger.timer
systemctl start --no-block checkmk-local-discovery-trigger.service
```

### 4) Verifica stato

```bash
systemctl status checkmk-local-discovery-trigger.timer --no-pager -l
systemctl status checkmk-local-discovery-trigger.service --no-pager -l
```

### 5) Verifica log

```bash
tail -n 100 -f /var/log/checkmk_server_autoheal.log
```

## Configurazione lato host

Il trigger lato server funziona solo se gli host espongono local checks validi.

### Installazione lato host (consigliata)

Su ogni host monitorato conviene mantenere aggiornato `/opt/checkmk-tools` con auto sync git.

```bash
cd /opt/checkmk-tools
git pull

# Installer dedicato host per auto sync git repository
python3 /opt/checkmk-tools/script-tools/full/installation/install-auto-git-sync.py

# Verifica servizio auto sync su host
systemctl status auto-git-sync.service --no-pager -l
tail -n 100 /var/log/auto-git-sync.log
```

Se sull'host usi local checks Python da repository, puoi anche installare il sync checks:

```bash
# Zero argomenti: installazione automatica con default safe
python3 /opt/checkmk-tools/script-tools/full/sync_update/install-python-full-sync.py

# Variante esplicita modalità rapida
python3 /opt/checkmk-tools/script-tools/full/sync_update/install-python-full-sync.py --quick

systemctl status checkmk-python-full-sync.timer --no-pager -l
```

Se l'host non usa systemd, l'installer host configura automaticamente fallback cron ogni 5 minuti.

### Requisiti host

- Agent CheckMK raggiungibile dal server
- Script local checks presenti nella cartella corretta host
- Script eseguibili
- Output local check nel formato CheckMK standard

Formato atteso per ogni riga local check:

```text
<STATE> <SERVICE_NAME> - <message>
```

### Path tipici local checks su host Linux

```text
/usr/lib/check_mk_agent/local/
```

### Test rapido host dal server CheckMK

```bash
cmk -d <HOSTNAME>
cmk -D <HOSTNAME>
```

Se `cmk -d` non contiene sezione `<<<local>>>`, il trigger non troverà servizi local su quell'host.

## Integrazione auto sync git (inglobata)

Se usi `--setup-auto-sync-git`, l'installer:

- installa `git` se mancante (apt/dnf/yum)
- crea/aggiorna `auto-git-sync.service`
- abilita e avvia il servizio auto sync
- configura log in `/var/log/auto-git-sync.log`

Verifica rapida:

```bash
systemctl status auto-git-sync.service --no-pager -l
tail -n 100 /var/log/auto-git-sync.log
```

## Cosa vedrai nel log

Esempi utili:

- `Probe OK: <host> (rc=0)`
- `Nuovi servizi local su <host>: ...`
- `Servizi local vanished su <host>: ...`
- `Nessun cambio: <host>`
- `cmk -d timeout ...`
- `Completato: changed=..., discovery_ok=..., unchanged=...`

## Tuning consigliato

Parametri bilanciati (produzione):

- `--interval-min 5`
- `--agent-timeout 90`

Per ambienti molto lenti puoi aumentare `--agent-timeout`.

## Troubleshooting rapido

### Errore di copia comando con parentesi

Se compare errore tipo:

```text
-bash: syntax error near unexpected token `('
```

hai incollato un link markdown invece di un comando shell.

Usa sempre path reale, ad esempio:

```bash
python3 /opt/checkmk-tools/script-tools/full/sync_update/install-cmk-local-discovery-trigger.py --help
```

### Log file assente

```bash
touch /var/log/checkmk_server_autoheal.log
chown monitoring:monitoring /var/log/checkmk_server_autoheal.log
chmod 664 /var/log/checkmk_server_autoheal.log
```

### Servizio sembra "bloccato"

Con `Type=oneshot` è normale vedere `activating` durante il ciclo.

Verifica live:

```bash
journalctl -u checkmk-local-discovery-trigger.service -f
```

## Aggiornamento futuro

Per aggiornare a nuove versioni:

```bash
cd /opt/checkmk-tools
git pull
python3 /opt/checkmk-tools/script-tools/full/sync_update/install-cmk-local-discovery-trigger.py --site monitoring --run-as-user monitoring --run-as-group monitoring --interval-min 5 --agent-timeout 90 --log-file /var/log/checkmk_server_autoheal.log
```
