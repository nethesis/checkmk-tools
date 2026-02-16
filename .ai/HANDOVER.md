## OBIETTIVO_TECNICO
Conversione completa degli script Bash della cartella `Ydea-Toolkit` in Python per migliorare manutenibilità, gestione errori e portabilità cross-platform.

## AMBIENTE
- **Repository**: `checkmk-tools` (Branch: `main`)
- **Path Ydea-Toolkit**: `Ydea-Toolkit/full/`
- **Python Version Target**: Python 3.8+
- **Dipendenze**: `requests`, `python-dotenv`

## STATO_ATTUALE
- **Script Già Convertiti**:
  - `ydea-toolkit.py` (1328 righe) - Toolkit principale API Ydea v2 con feature parity completa
- **Script Bash da Convertire** (33 file):
  - Script integrazione CheckMK (`ydea-monitoring-integration.sh`, `create-monitoring-ticket.sh`)
  - Script monitoring (`ydea-health-monitor.sh`, `ydea-ticket-monitor.sh`)
  - Script discovery (`ydea-discover-sla-ids.sh`, `search-sla-in-contracts.sh`)
  - Script installazione (`install-ydea-checkmk-integration.sh`)
  - Script test e utility (27 file)

## PROBLEMI_EMERSI
Nessun problema emerso. Conversione in fase di pianificazione.

## TENTATIVI_ESEGUITI
1. Analisi struttura directory Ydea-Toolkit
2. Identificazione script già convertiti (`ydea-toolkit.py`)
3. Conteggio script Bash rimanenti (33 file)

## DECISIONI_PRESE
- **Toolkit Principale**: `ydea-toolkit.py` è già stato convertito con feature parity completa
- **Approccio Incrementale**: Convertire script per priorità (core → utility → test)
- **Modularità**: Creare moduli Python condivisi per evitare duplicazione codice

## RISCHI_NOTI
- **Compatibilità**: Alcuni script potrebbero dipendere da tool Unix-specific (jq, curl)
- **Testing**: Necessario verificare parità funzionale tra versioni Bash e Python
- **Deployment**: Gestire transizione da script Bash a Python su server produzione

## PROSSIMI_PASSI
- [ ] Identificare script prioritari da convertire (core vs utility)
- [ ] Analizzare dipendenze tra script
- [ ] Creare piano di conversione dettagliato
- [ ] Definire architettura moduli Python condivisi

## NEXT_ACTION_FOR_AI
Analizza gli script Bash per identificare quelli prioritari (core functionality) e crea un piano di conversione dettagliato con priorità, dipendenze e stima complessità.

