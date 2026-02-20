## OBIETTIVO_TECNICO
Portare a stato production-ready il workflow local-checks CheckMK su Proxmox con queste condizioni: 1) trigger server con gestione `vanished` affidabile, 2) installazione host-part su nodi Proxmox target, 3) conferma discovery/collezione dati in dashboard, 4) consegna handover riutilizzabile da altro agente senza ricostruzione contesto.

## AMBIENTE
- Workspace: checkmk-tools (Windows host, VS Code, PowerShell + WSL).
- Repository principale: `main` su `github.com/Coverup20/checkmk-tools`.
- Server CheckMK usati: `checkmk-vps-01` (monitor.nethlab.it), `checkmk-vps-02` (monitor01.nethlab.it).
- Host Proxmox coinvolti:
  - `pve03` = 10.155.100.70, root, 22
  - `pve` = 10.155.100.20, root, 22
  - host monitorato in CheckMK: `proxmox-test.nethlab.it`, `pve03.nethlab.it`
- Script principali:
  - `script-tools/full/sync_update/cmk-local-discovery-trigger.py`
  - `script-tools/full/sync_update/install-python-full-sync.py`
  - `script-tools/full/sync_update/sync-python-full-checks.py`
- Config locale aggiornata: `~/.ssh/config` (WSL) con alias `pve03` e `pve`.
- Policy operativa sessione: no forzature su file di sistema remoti durante test (vincolo utente).

## STATO_ATTUALE
- CHECKPOINT CODICE: `cmk-local-discovery-trigger.py` è aggiornato e pushato con:
  - discovery forzata se esistono `vanished` anche con hash invariato;
  - summary finale: `changed, vanished, discovery_ok, unchanged`;
  - apply gestito separatamente.
- Commit rilevanti eseguiti in sessione:
  - `0a652a5` (force apply su vanished rilevati)
  - `bf26c3e` (force discovery quando vanished con hash invariato)
  - `daf5861` (aggiunta `vanished` nel log `Completato`)
- CHECKPOINT SERVER-SIDE:
  - `checkmk-vps-02`: formato log finale confermato (`changed, vanished, discovery_ok, unchanged`).
  - `checkmk-vps-01`: run dedicati con lock separato eseguiti; verificata discovery su `pve03.nethlab.it`.
- CHECKPOINT HOST-PART PROXMOX:
  - `pve03`: `install-python-full-sync.py` OK, timer/service presenti.
  - `pve`: `install-python-full-sync.py` OK, timer/service presenti.
  - sync manuale su entrambi con `sync-python-full-checks.py` OK (`script-check-proxmox`).
  - verificata creazione sottocartelle `local` a intervallo:
    - `pve`: presenti `60/300/900`;
    - `pve03`: inizialmente `60/300`, poi `900` creata dopo sync forzato con `--auto-tier-by-runtime`.
- CHECKPOINT AGENT VERSION:
  - `pve`: upgrade completato da `2.4.0p18` a `2.4.0p21`.
  - `pve03`: upgrade completato da `2.4.0p20` a `2.4.0p21`.
  - verifica finale: `check_mk_agent` riporta `Version: 2.4.0p21` su entrambi.
- CHECKPOINT FUNZIONALE: utente conferma servizi nuovi presenti in dashboard e già con dati raccolti.

## PROBLEMI_EMERSI
- Edge case funzionale: vanished rilevati ma hash invariato => prima non partiva discovery/apply.
- Lock contention su trigger (`/tmp/cmk-local-discovery-trigger.lock`) durante test concorrenti.
- Errori di quoting/comandi da PowerShell verso SSH/awk/sed/perl (più tentativi falliti).
- `cmk -d proxmox-test.nethlab.it` con timeout (rc=124) in run intermedi (stato poi superato lato dashboard secondo conferma utente).
- Iniziale mancata risoluzione DNS SSH per host Proxmox nominativi (`pve03.nethlab.it`, `proxmox-test.nethlab.it`) dal client locale.
- `.copilot-preferences.md` non committabile perché ignorato da `.gitignore`.
- Benchmark runtime post-upgrade non eseguito in modo robusto in sessione per problemi di quoting PowerShell->SSH su comandi complessi; non impatta il risultato funzionale confermato dall’utente.

## TENTATIVI_ESEGUITI
- Refactor trigger:
  - separata `apply_changes()`;
  - rimozione apply inline da `discover_hosts()`;
  - forzatura apply quando vanished rilevati;
  - fix successivo: vanished con hash invariato => append a `pending_discovery`.
- Test regressione su `checkmk-vps-02`:
  - run standard, run con stato manipolato per simulare vanished (test controllato).
- Verifiche e deploy:
  - `git pull --ff-only` su server;
  - esecuzioni trigger con `--debug` e lock dedicati.
- Installazione host Proxmox:
  - `install-python-full-sync.py` su `pve03` e `pve` (password interattiva).
  - `sync-python-full-checks.py` manuale su entrambi.
- Pulizia:
  - rimossi lock file temporanei di test su `checkmk-vps-01`;
  - mantenuti lock di servizio standard.
- Tentativi falliti/interrotti da includere:
  - comandi SSH/awk/sed/perl con escaping errato;
  - alcune esecuzioni terminate con `^C`;
  - query aggregate server-side appese/abortite.
- Evidenza di stato operativo finale:
  - test su `pve03.nethlab.it` con `local_count` alto e discovery OK;
  - conferma utente che i servizi nuovi hanno già raccolto metriche.

## DECISIONI_PRESE
- Nessuna forzatura su file di sistema remoti per test successivi (vincolo esplicito utente).
- Verifiche server-side eseguite host-per-host con lock custom per evitare collisioni.
- Aggiornamento whitelist host accessibili anche nelle preferenze locali (operativo, non versionato).
- Installazione host part effettuata direttamente sui due nodi Proxmox forniti dall’utente.
- Handover orientato a ripartenza AI: privilegiare comandi read-only e validazioni minime prima di nuove modifiche.

## RISCHI_NOTI
- `proxmox-test.nethlab.it` ha mostrato timeout intermittenti in sessione: possibile instabilità datasource/trasporto agent (da considerare risolto solo se confermato in almeno 2-3 cicli successivi).
- I test manuali concorrenti possono falsare esiti per lock contention se non isolati (`--lock-file` dedicato).
- Config SSH alias è locale a WSL e non è versionata nel repo.
- `.copilot-preferences.md` modificata localmente ma esclusa da git: rischio divergenza tra ambienti.

## PROSSIMI_PASSI
- Monitorare 24h i due host dopo upgrade `p21` per intercettare eventuali timeout intermittenti residui su `pve`.
- Confermare nel prossimo ciclo schedulato server-side che il summary `Completato` mantenga `vanished` valorizzato correttamente.
- Se riappaiono timeout su `proxmox-test.nethlab.it`, fare diagnosi read-only prima di modifiche host.
- Decidere esplicitamente se versionare `.copilot-preferences.md` (oggi è ignore).

## NEXT_ACTION_FOR_AI
Esegui una validazione read-only leggera su `checkmk-vps-01` (1 run sequenziale) del trigger per `proxmox-test.nethlab.it` e `pve03.nethlab.it` con lock dedicato; poi estrai dal log `/var/log/checkmk_server_autoheal.log` le ultime righe e restituisci tabella con: `host`, `probe_rc`, `timeout_yes/no`, `local_count`, `discovery_ok`, `vanished`, `changed`. In parallelo, esegui un controllo rapido `check_mk_agent | grep '^Version:'` su `pve` e `pve03` per confermare persistenza `2.4.0p21`.