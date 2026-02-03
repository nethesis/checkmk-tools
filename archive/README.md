# Archive - Script Obsoleti

Questa directory contiene script deprecati o sostituiti da versioni migliori.

## Script archiviati:

### install-checkmk-agent-debtools-frp-nsec8c.sh
- **Motivo**: Sostituito da `install-checkmk-agent-persistent-nsec8.sh` (versione ROCKSOLID)
- **Data**: 2026-02-03
- **Nota**: Versione base senza persistence e auto-recovery

### install-auto-git-sync-rocksolid.sh
- **Motivo**: Versione systemd non compatibile con NethSec8/OpenWrt (usa procd)
- **Data**: 2026-02-03
- **Nota**: Per sistemi Debian/Ubuntu con systemd

### install-auto-git-sync-openwrt-rocksolid.sh
- **Motivo**: Da valutare se necessario auto-sync del repository
- **Data**: 2026-02-03
- **Nota**: Versione cron per OpenWrt/NethSec8

---

**Gli script in questa directory NON sono versionati su git** (ignorati da `.gitignore`).
