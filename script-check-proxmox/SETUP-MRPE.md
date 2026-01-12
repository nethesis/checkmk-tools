# Setup MRPE per Proxmox Checks

## Problema Risolto
Gli script in `full/` causavano **122 local checks** che venivano eseguiti tutti insieme dall'agente CheckMK, superando il timeout di 60 secondi.

## Soluzione: MRPE (MK's Remote Plugin Executor)
Gli script vengono eseguiti **via SSH dal server CheckMK** con timeout individuali invece che dall'agente locale.

## Passaggi di Configurazione

### 1. Disabilitare gli script in full/

Sul server Proxmox:

```bash
cd /opt/checkmk-tools/script-check-proxmox
# Sposta gli script in una cartella disabilitata
mkdir -p full-disabled
mv full/check-*.sh full-disabled/
```

Oppure aggiungi al file `/etc/check_mk/checkmk_agent.cfg`:

```ini
[agent]
# Disabilita esecuzione local checks da questa cartella
localchecks_disabled = /opt/checkmk-tools/script-check-proxmox/full
```

### 2. Configurare MRPE

Sul server Proxmox, crea/modifica il file `/etc/check_mk/mrpe.cfg`:

```bash
sudo nano /etc/check_mk/mrpe.cfg
```

Incolla il contenuto del file `mrpe-proxmox-checks.cfg`:

```bash
# Copia la configurazione
cat /opt/checkmk-tools/script-check-proxmox/mrpe-proxmox-checks.cfg | sudo tee -a /etc/check_mk/mrpe.cfg
```

### 3. Verifica permessi degli script

```bash
cd /opt/checkmk-tools/script-check-proxmox/remote
chmod +x *.sh
```

### 4. Test manuale MRPE

Sul server Proxmox:

```bash
# Test singolo check
check_mk_agent | grep -A 5 "<<<mrpe>>>"

# Oppure test diretto
/opt/checkmk-tools/script-check-proxmox/remote/rcheck-proxmox_backup_status.sh
```

### 5. Discovery su CheckMK

Sul server CheckMK:

```bash
su - monitoring
cmk -II proxmox-test.nethlab.it
```

Dovresti vedere:
- **122 local checks** rimossi
- **15 nuovi MRPE checks** aggiunti
- Tempo di discovery molto più veloce

### 6. Configurazione timeout (opzionale)

Se alcuni check necessitano più tempo, modifica `/etc/check_mk/mrpe.cfg`:

```ini
# Sintassi con timeout personalizzato (secondi)
(timeout=30) Proxmox_QEMU_Runtime /opt/checkmk-tools/script-check-proxmox/remote/rcheck-proxmox_qemu_runtime.sh
```

## Vantaggi di MRPE

| Local Checks | MRPE Checks |
|--------------|-------------|
| Timeout globale 60s per TUTTI | Timeout individuale per check |
| Eseguiti dall'agente locale | Eseguiti via SSH dal server |
| Bloccano tutto se uno si blocca | Esecuzione indipendente |
| 122 check → timeout! | 15 check → veloce |

## Verifica Finale

```bash
# Sul server CheckMK
su - monitoring

# Rediscovery completo
cmk -IIv proxmox-test.nethlab.it

# Verifica servizi MRPE
cmk -d proxmox-test.nethlab.it | grep MRPE
```

## Note

- Gli script **full/** rimangono nel repository per reference
- I launcher **remote/** puntano agli script in full/ via auto-git-sync
- Gli script hanno timeout di 5 secondi sui comandi Proxmox API
- Per debug: `cmk -d proxmox-test.nethlab.it` mostra l'output dettagliato
