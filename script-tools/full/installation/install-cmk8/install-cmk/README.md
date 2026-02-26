# ub-cmk-interactive

Setup base Ubuntu + Checkmk (URL richiesto a runtime).

Contiene:
- SSH: porta, root login, timeout, cambio password root
- NTP: pool globale 0–3.pool.ntp.org
- Pacchetti base + unattended-upgrades
- UFW + Fail2Ban (sshd)
- Certbot (interattivo) + plugin webserver: richiesta certificato, auto-config Apache e opzione di redirect della root al site CheckMK
- Checkmk: installazione con URL richiesto a runtime, creazione e avvio site `monitoring`
- Script di verifica

## Uso
```bash
unzip ub-cmk-interactive.zip -d ~/
cd ~/ub-cmk-interactive
cp .env.example .env   # oppure usa .env già presente
sudo ./bootstrap.sh
./check-verifica.sh
```

## Certbot e configurazione Apache

Per richiedere e configurare automaticamente il certificato Let's Encrypt eseguire:

```bash
sudo bash scripts/50-certbot.sh
```

Lo script chiede:
- Webserver: `apache`/`nginx`/`standalone` (consigliato `apache` se usi il vhost di Checkmk)
- Email e domini (es. `monitor01.example.it`)
- Esecuzione immediata della challenge
- Se `apache`: aggiorna automaticamente il vhost `checkmk.conf` per usare il certificato
- Opzione aggiuntiva: reindirizzare `https://host.dominio/` direttamente al site CheckMK scelto
	- Default site: `monitoring`
	- Effetto: redirect della root a `/<site>/` e proxy solo su quel percorso, con supporto WebSocket

Verifiche utili:
```bash
apache2ctl -S
systemctl status certbot.timer
certbot renew --dry-run
```

### Modalità non interattiva

Disponibile lo script `scripts/50-certbot-auto.sh` che legge variabili d'ambiente (e opzionalmente `.env`) e configura tutto automaticamente (supporto Apache e Nginx).

Variabili supportate:
- `WS` (`apache`|`nginx`|`standalone`) – default `apache`
- `LETSENCRYPT_EMAIL` – email di contatto Let's Encrypt
- `LETSENCRYPT_DOMAINS` – domini separati da virgola, primo usato come `ServerName`
- `REDIRECT_TO_SITE` – `true|false` per redirect `/` → `/<site>/` (default `true`)
- `DEFAULT_SITE` – nome del site CheckMK (default `monitoring`)
- `APACHE_CONF` – path vhost Apache (default `/etc/apache2/sites-available/checkmk.conf`)
- `NGINX_CONF` – path server-block Nginx (default `/etc/nginx/sites-available/checkmk.conf`)

Esempio:
```bash
cd Install/install-cmk8/install-cmk
WS=apache \
LETSENCRYPT_EMAIL="admin@example.com" \
LETSENCRYPT_DOMAINS="monitor01.example.com" \
REDIRECT_TO_SITE=true \
DEFAULT_SITE=monitoring \
sudo bash scripts/50-certbot-auto.sh

# Esempio Nginx
WS=nginx \
LETSENCRYPT_EMAIL="admin@example.com" \
LETSENCRYPT_DOMAINS="monitor01.example.com" \
REDIRECT_TO_SITE=true \
DEFAULT_SITE=monitoring \
sudo bash scripts/50-certbot-auto.sh
```

### Modalità interattiva (chiede tutte le variabili)

Per forzare il prompt di tutte le variabili ad ogni esecuzione dello script automatico:

```bash
sudo bash scripts/50-certbot-auto.sh --interactive
# oppure
ASK_ALL=true sudo bash scripts/50-certbot-auto.sh
```

Wrapper pronto all'uso (consigliato):
```bash
# Esegue automaticamente il flusso interattivo con escalation a root
sudo bash scripts/50-certbot-run.sh

# Con pre-check DNS e porte (opzionale)
sudo bash scripts/50-certbot-run.sh --check
```
