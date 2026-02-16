# AI HANDOVER DOCUMENT

## 1. Obiettivo tecnico
- **Sostituzione sistema notifiche**: Eliminazione dei vecchi launcher Python che causavano errori di encoding (`ascii codec`) su `checkmk-vps-01`.
- **Standardizzazione script**: Passaggio a script Bash puri per `mail`, `telegram` e integrazioni `ydea`.
- **Pulizia Server**: Rimozione vecchi file, rinomina script (rimosso prefisso `r`), aggiornamento descrizioni interne.

## 2. Ambiente
- **Server**: `checkmk-vps-01` (10.155.100.22)
- **Path Notifiche**: `/omd/sites/monitoring/local/share/check_mk/notifications/`
- **CheckMK Site**: `monitoring`
- **Repo Locale**: `checkmk-tools` (branch `main`)

## 3. Stato attuale del codice
- **Script Deployati su Server**:
  1. `mail_realip` (Bash, Descrizione: "Mail", Bulk: yes)
  2. `telegram_realip` (Bash, Descrizione: "Telegram")
  3. `telegram_selfmon` (Bash, Descrizione: "Telegram Self-Monitoring")
  4. `ydea_ag` (Bash, Descrizione: "Ydea AG")
  5. `ydea_la` (Bash, Descrizione: "Ydea LA")
- **Modifiche Repository**:
  - Aggiornate shebang e descrizioni in `script-notify-checkmk/full/`.
  - Rimossi riferimenti ai vecchi launcher python.
- **Azioni Completate**:
  - `omd restart` eseguito con successo su `checkmk-vps-01`.
  - Verifica carico server post-restart: OK.

## 4. Problemi emersi
- **Risolto**: Errore `ascii codec cant decode byte 0xe2` nei log di notifica (causato dai vecchi launcher Python).
- **Risolto**: Disallineamento nomi script (`rmail` vs `mail`).

## 5. Prossimi Passi (TODO)
- [ ] Verificare il funzionamento effettivo delle notifiche (attendere primo alert reale o generare test).
- [ ] Controllare se necessario aggiornare regole WATO in CheckMK per riflettere i nuovi nomi degli script (es. se la regola cercava `rmail_realip` ora deve cercare `mail_realip` o il nome visualizzato "Mail").
- [ ] Monitorare `/omd/sites/monitoring/var/log/notify.log` per eventuali errori residui.
