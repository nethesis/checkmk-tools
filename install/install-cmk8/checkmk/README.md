# checkmk (Python)

Re-implementazione in Python di quanto presente in `install-cmk8/install-cmk/` (bootstrap + moduli 10/15/20/...).

## Uso (Ubuntu)

```bash
cd /opt/checkmk-tools/install/install-cmk8/checkmk
cp .env.example .env

# Installazione completa (l'installer chiede sudo automaticamente)
./installer.py bootstrap --interactive

# Verifica
./installer.py verify
```

Nota: `bootstrap`, `certbot` e `verify` eseguono auto-escalation via `sudo` quando necessario.

Durante `bootstrap` vengono anche:

- installati `git` e `python3-pip`
- deployati i local checks OS-aware in `/usr/lib/check_mk_agent/local` (via `script-tools/full/deploy/auto-deploy-checks.py`)
- installato e abilitato `auto-git-sync.service` (sync di `/opt/checkmk-tools`)

Per disabilitare:

- `DEPLOY_LOCAL_CHECKS=false`
- `ENABLE_AUTO_GIT_SYNC=false`

## Certbot

```bash
./installer.py certbot install
./installer.py certbot run --domain monitor01.example.com --email admin@example.com --webserver apache
./installer.py certbot auto
```
