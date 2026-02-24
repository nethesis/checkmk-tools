# checkmk (Python)

Re-implementazione in Python di quanto presente in `install-cmk8/install-cmk/` (bootstrap + moduli 10/15/20/...).

## Uso (Ubuntu)

```bash
cd /opt/checkmk-tools/install/install-cmk8/checkmk
cp .env.example .env

# Installazione completa (root richiesto)
sudo ./installer.py bootstrap --interactive

# Verifica
./installer.py verify
```

## Certbot

```bash
sudo ./installer.py certbot install
sudo ./installer.py certbot run --domain monitor01.example.com --email admin@example.com --webserver apache
sudo ./installer.py certbot auto
```
