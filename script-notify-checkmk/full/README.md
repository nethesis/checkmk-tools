# CheckMK Notification Scripts - Completi (Full)

Script completi per notifiche CheckMK avanzate.

## Script Disponibili

### Produzione
- `mail_realip` - Notifica email con risoluzione real IP
- `telegram_realip` - Notifica Telegram con real IP
- `ydea_realip` - Notifica Ydea con creazione automatica ticket

### Backup & Deploy
- `backup_and_deploy.sh` - Script per backup e deploy automatico notifiche

### Documentazione
Vedi file dedicati:
- `TESTING_GUIDE.md` - Guida test notifiche
- `CHANGELOG_v1.9.md` - Changelog versione 1.9
- `FIX_404_TICKETS.md` - Fix errori 404 ticket
- `CACHE_TTL_UPDATE.md` - Aggiornamento cache TTL

## Caratteristiche

### mail_realip
- Invio email con formattazione HTML/plain
- Risoluzione automatica real IP tramite cache locale
- Template personalizzabili

### telegram_realip  
- Notifiche Telegram con formattazione Markdown
- Supporto emoji e formatting avanzato
- Rate limiting integrato

### ydea_realip
- Creazione automatica ticket su Ydea
- Sincronizzazione stato host/service
- Cache intelligente per evitare duplicati
- Formattazione ticket user-friendly
- Gestione priorità basata su severity
- Aggregazione per host (un ticket per host con note per i servizi)
- Fallback API: se la cache non esiste/è vuota, ricerca un ticket aperto esistente su Ydea per lo stesso host/IP e aggiunge una nota invece di creare un nuovo ticket

## Configurazione

```bash
# Variabili richieste (set in CheckMK)
NOTIFY_HOSTNAME
NOTIFY_HOSTSTATE
NOTIFY_SERVICEDESC
NOTIFY_SERVICESTATE
NOTIFY_CONTACTEMAIL / NOTIFY_CONTACT_TELEGRAM / YDEA_API_*

# Opzioni (facoltative)
# Imposta a 0 per tornare a 1 ticket per servizio
AGGREGATE_BY_HOST=1
# Se aggregato per host, non chiudere su OK di singolo servizio (default 0)
RESOLVE_ON_SERVICE_OK=0

# Il fallback API è automatico quando AGGREGATE_BY_HOST=1: alla prima notifica CRITICAL senza cache preesistente,
# lo script cerca su Ydea un ticket aperto per `NOTIFY_HOSTNAME` o `NOTIFY_HOSTADDRESS` e, se trovato, aggiunge una nota.
```

## Installazione

```bash
# Copia in directory CheckMK
cp ydea_realip /omd/sites/SITE/local/share/check_mk/notifications/
chmod +x /omd/sites/SITE/local/share/check_mk/notifications/ydea_realip

# Test
su - SITE
./local/share/check_mk/notifications/ydea_realip
```

## Uso Remoto (Consigliato)

```bash
curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-notify-checkmk/remote/rydea_realip | bash
```

---

🚀 **Launcher remoti**: Vedi `../remote/`
