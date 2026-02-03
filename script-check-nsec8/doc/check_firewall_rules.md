# check_firewall_rules.sh

## Descrizione
Monitora il numero di regole iptables attive per chain (INPUT, FORWARD, OUTPUT, NAT) su NSecFirewall8.

## Funzionalità
- Conta regole per chain tramite `iptables -L`
- Conta regole NAT nella tabella nat
- Verifica policy default per INPUT e FORWARD
- Allarme se nessuna regola o poche regole attive

## Stati
- **OK (0)**: Almeno 5 regole attive
- **WARNING (1)**: Meno di 5 regole attive
- **CRITICAL (2)**: Nessuna regola attiva

## Output CheckMK
```
0 Firewall_Rules - INPUT:25 FORWARD:40 OUTPUT:15 NAT:20 - Policy: INPUT=DROP FORWARD=DROP - OK | input=25 forward=40 output=15 nat=20 total=100
```

## Performance Data
- `input`: Numero regole chain INPUT
- `forward`: Numero regole chain FORWARD
- `output`: Numero regole chain OUTPUT
- `nat`: Numero regole tabella nat
- `total`: Totale regole (INPUT+FORWARD+OUTPUT)

## Requisiti
- Comando `iptables` disponibile
- Permessi per leggere regole firewall

## Installazione
```bash
cp check_firewall_rules.sh /usr/lib/check_mk_agent/local/rcheck_firewall_rules.sh
chmod +x /usr/lib/check_mk_agent/local/rcheck_firewall_rules.sh
```

## Test manuale
```bash
bash /opt/checkmk-tools/script-check-nsec8/full/check_firewall_rules.sh
```

## Note
- Il conteggio include tutte le regole attive, anche quelle di default di OpenWrt
- Policy tipiche per firewall:
  - INPUT: DROP (blocca traffico in ingresso non esplicitamente permesso)
  - FORWARD: DROP (blocca routing non autorizzato)
  - OUTPUT: ACCEPT (permetti traffico in uscita)
- Poche regole possono indicare:
  - Firewall non configurato
  - Regole resettate per errore
  - Firewall service non attivo
