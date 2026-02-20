# Fix Scripts - Completi (Full)

Script completi per fix e troubleshooting di CheckMK e componenti correlati.

## Script Disponibili

### CheckMK Fixes
- `force-update-checkmk.sh` - Forza aggiornamento CheckMK risolvendo problemi comuni
- `fix-frp-checkmk-host.sh` - Fix configurazione FRP per host CheckMK

### Git & Credentials
- `fix-gitlab-credentials.ps1` - Fix credenziali GitLab (Windows)

### Windows Fixes
- `fix-frp-compression-ws2022ad.ps1` - Fix compressione FRP su Windows Server 2022 AD

### Ransomware Protection
- `fix-ransomware-config.ps1` - Fix configurazione anti-ransomware (v1)
- `fix-ransomware-config-v2.ps1` - Fix configurazione anti-ransomware (v2)
- `fix-ransomware-cache.ps1` - Fix cache anti-ransomware (v1)
- `fix-ransomware-cache-v2.ps1` - Fix cache anti-ransomware (v2)

## Uso

```bash
# Linux
chmod +x force-update-checkmk.sh
sudo ./force-update-checkmk.sh

# Windows (PowerShell as Admin)
.\fix-frp-compression-ws2022ad.ps1
```

## Uso diretto da repository (Consigliato)

```bash
curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/fix/full/force-update-checkmk.sh | bash
```

---

🚀 **Nota**: I launcher `remote/` sono stati rimossi. Usare gli script completi in `../full/`.
