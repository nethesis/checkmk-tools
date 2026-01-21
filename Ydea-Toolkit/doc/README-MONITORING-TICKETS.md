# Sistema di Creazione Ticket Ydea da CheckMK

## 📋 Panoramica

Sistema automatico per creare ticket Ydea quando CheckMK rileva un problema, con gestione intelligente delle tipologie e tracking automatico.

## 🎯 Caratteristiche

- ✅ **8 Tipologie di allarme** mappate automaticamente
- ✅ **Priorità Bassa** (Premium_Mon SLA)
- ✅ **Tracking automatico** dello stato dei ticket
- ✅ **Rilevamento intelligente** della tipologia in base a keyword
- ✅ **Descrizione completa** con dettagli dell'allarme

## 📂 Struttura File

```
Ydea-Toolkit/
├── config/
│   └── premium-mon-config.json       # Configurazione tipologie e mapping
├── full/
│   ├── create-monitoring-ticket.sh   # Script principale creazione ticket
│   ├── test-ticket-creation.sh       # Script di test
│   └── ydea-toolkit.sh               # Libreria API Ydea
└── remote/
    └── rcreate-monitoring-ticket.sh  # Launcher remoto
```

## ⚙️ Configurazione

### File: `premium-mon-config.json`

```json
{
  "anagrafica_id": 2339268,
  "priorita_id": 30,
  "fonte": "Partner portal",
  "sla_nome": "Premium_Mon",
  "tipologie": {
    "nethvoice": {
      "tipo_ydea": "Centrale Telefonica Nethvoice",
      "keywords": ["voip", "pbx", "telefon", "sip", "asterisk", "nethvoice"]
    },
    ...
  }
}
```

**Campi configurabili:**
- `anagrafica_id`: ID cliente Ydea (2339268 = AZIENDA MONITORATA test)
- `priorita_id`: 30 = Bassa
- `tipologie`: Mapping keyword → tipologia Ydea

## 🚀 Utilizzo

### Creazione Manuale

```bash
/opt/checkmk-tools/Ydea-Toolkit/remote/rcreate-monitoring-ticket.sh \
  "mail.example.com" \
  "SMTP" \
  "CRITICAL" \
  "Connection timeout" \
  "192.168.1.100"
```

**Parametri:**
1. `HOST`: Nome host
2. `SERVICE`: Nome servizio CheckMK
3. `STATE`: DOWN, CRITICAL, WARNING, OK
4. `OUTPUT`: Messaggio di output
5. `HOST_IP`: (opzionale) Indirizzo IP

### Test Completo

```bash
/opt/checkmk-tools/Ydea-Toolkit/full/test-ticket-creation.sh
```

Crea 8 ticket di test, uno per ogni tipologia.

## 🔍 Mapping Tipologie

Lo script determina automaticamente la tipologia in base a keyword:

| Tipologia | Keywords | Tipo Ydea |
|-----------|----------|-----------|
| **NethVoice** | voip, pbx, telefon, sip, asterisk, nethvoice, cti | Centrale Telefonica Nethvoice |
| **NethSecurity** | firewall, utm, security, vpn, nethsecurity, fw | Firewall UTM Nethsecurity |
| **NethService** | webtop, mail, email, smtp, imap, webmail | Collaboration Suite Nethservice |
| **Computer Client** | workstation, pc, desktop, laptop, client, windows | Computer Client |
| **Server** | server, srv | Server |
| **Networking** | switch, router, network, lan, wan, ethernet, wifi | Apparati di rete - Networking |
| **Hypervisor** | kvm, proxmox, vm, virtual, hypervisor, qemu | Virtualizzazione - KVM |
| **Consulenza** | consulenza, supporto, assistenza, tecnica | Consulenza tecnica specialistica |

**Default**: Se nessuna keyword matcha → `Server`

## 📊 Output

Lo script restituisce:
```
✅ Ticket creato con successo!
   ID: 1528466
   Codice: TK25/003619
   Link: https://my.ydea.cloud/ticket/1528466
TICKET_ID=1528466
TICKET_CODE=TK25/003619
```

## 🔧 Integrazione con CheckMK

### Notifica Custom

Crea una notifica in CheckMK che esegue:

```bash
/opt/checkmk-tools/Ydea-Toolkit/remote/rcreate-monitoring-ticket.sh \
  "$HOSTNAME$" \
  "$SERVICEDESC$" \
  "$SERVICESTATE$" \
  "$SERVICEOUTPUT$" \
  "$HOSTADDRESS$"
```

### Per allarmi HOST:

```bash
/opt/checkmk-tools/Ydea-Toolkit/remote/rcreate-monitoring-ticket.sh \
  "$HOSTNAME$" \
  "Host" \
  "$HOSTSTATE$" \
  "$HOSTOUTPUT$" \
  "$HOSTADDRESS$"
```

## 📝 Tracking Ticket

I ticket creati vengono automaticamente tracciati in:
```
/var/log/ydea-tickets-tracking.json
```

Visualizza statistiche:
```bash
/opt/checkmk-tools/Ydea-Toolkit/full/ydea-toolkit.sh stats
```

Aggiorna stati:
```bash
/opt/checkmk-tools/Ydea-Toolkit/full/ydea-toolkit.sh update-tracking
```

## 🎨 Personalizzazione

### Modificare le Keywords

Edita `premium-mon-config.json`:

```json
{
  "tipologie": {
    "nethvoice": {
      "tipo_ydea": "Centrale Telefonica Nethvoice",
      "keywords": ["voip", "telefonia", "mio-keyword-custom"]
    }
  }
}
```

### Cambiare Cliente/Priorità

```json
{
  "anagrafica_id": 12345,
  "priorita_id": 20
}
```

## 🐛 Debug

Abilita debug mode:
```bash
export YDEA_DEBUG=1
/opt/checkmk-tools/Ydea-Toolkit/remote/rcreate-monitoring-ticket.sh ...
```

Visualizza log:
```bash
tail -f /var/log/ydea-toolkit.log
```

## ✅ Checklist Deployment

- [ ] Configurato `premium-mon-config.json` con anagrafica corretta
- [ ] Testato con `test-ticket-creation.sh`
- [ ] Verificati ticket creati su Ydea
- [ ] Configurata notifica CheckMK
- [ ] Testato tracking con `stats`
- [ ] Verificata pulizia automatica ticket risolti

## 📞 Note

- **SLA "Premium_Mon"**: Associata automaticamente all'anagrafica 2339268
- **Priorità**: Sempre "Bassa" (ID: 30)
- **Fonte**: "Partner portal"
- **Tracking**: Mantiene storico per 365 giorni (configurabile)
