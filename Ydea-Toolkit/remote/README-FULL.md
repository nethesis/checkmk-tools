# Ydea Toolkit - Script Completi (Full)

Script completi per l'integrazione Ydea con CheckMK.

## Script Principali

### Core Tools
- `ydea-toolkit.sh` - Toolkit completo con tutte le funzionalità
- `ydea-monitoring-integration.sh` - Integrazione completa monitoring
- `install-ydea-checkmk-integration.sh` - Installer automatico

### Monitoring
- `ydea-health-monitor.sh` - Monitor salute sistema Ydea
- `ydea-ticket-monitor.sh` - Monitor stato ticket
- `test-ydea-integration.sh` - Test connettività e configurazione

### Utilities
- `ydea-templates.sh` - Template per ticket standardizzati
- `create-ticket-ita.sh` - Creazione ticket in italiano
- `esempi-ydea.sh` - Esempi di utilizzo API

## Configurazione

Tutti gli script richiedono le variabili d'ambiente:
```bash
export YDEA_API_KEY="your-api-key"
export YDEA_API_URL="https://ydea.instance.com/api"
```

## Uso

```bash
# Locale
chmod +x ydea-toolkit.sh
./ydea-toolkit.sh

# Remoto (consigliato)
curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/Ydea-Toolkit/remote/rydea-toolkit.sh | bash
```

---

🚀 **Launcher remoti**: Vedi `../remote/`
