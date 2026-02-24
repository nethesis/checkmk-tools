# checkmk (Python)

Re-implementazione in Python di quanto presente in `install-cmk8/install-cmk/` (bootstrap + moduli 10/15/20/...).

## Uso (Ubuntu)

```bash
cd /opt/checkmk-tools/install/install-cmk8/checkmk

# Menu (consigliato)
./installer.py

# Setup guidato: genera .env senza doverlo editare a mano
./installer.py init --interactive

# In alternativa (manuale):
# cp .env.example .env

# Installazione completa (esegui con sudo)
sudo -E ./installer.py bootstrap

# Verifica
sudo -E ./installer.py verify

# Rimozione completa (uninstall)
sudo -E ./installer.py remove-all
```

Nota: `bootstrap`, `certbot` e `verify` richiedono esplicitamente root (`sudo -E`).

Suggerimento: la modalità non-interattiva ha senso se `.env` è già completo.
Per questo usa `./installer.py init --interactive` una sola volta, poi puoi rilanciare `bootstrap` senza prompt.

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
