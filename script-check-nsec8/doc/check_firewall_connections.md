# check_firewall_connections.sh

## Descrizione
Monitora il numero di connessioni attive nel connection tracking (conntrack) del firewall NSecFirewall8.

## Funzionalità
- Legge il contatore connessioni da `/proc/sys/net/netfilter/nf_conntrack_count`
- Legge il limite massimo da `/proc/sys/net/netfilter/nf_conntrack_max`
- Calcola la percentuale di utilizzo
- Threshold configurati: WARNING 80%, CRITICAL 90%

## Stati
- **OK (0)**: Utilizzo < 80%
- **WARNING (1)**: Utilizzo >= 80%
- **CRITICAL (2)**: Utilizzo >= 90%

## Output CheckMK
```
0 Firewall_Connections connections=1234;52428;59032;0;65536 Connessioni attive: 1234/65536 (1%) - Status: OK | current=1234 max=65536 percent=1
```

## Performance Data
- `connections`: Numero corrente con threshold (warning;critical;min;max)
- `current`: Connessioni correnti
- `max`: Limite massimo configurato
- `percent`: Percentuale di utilizzo

## Requisiti
- Kernel Linux con netfilter/conntrack abilitato
- File `/proc/sys/net/netfilter/nf_conntrack_*` accessibili

## Installazione
```bash
cp check_firewall_connections.sh /usr/lib/check_mk_agent/local/rcheck_firewall_connections.sh
chmod +x /usr/lib/check_mk_agent/local/rcheck_firewall_connections.sh
```

## Test manuale
```bash
bash /opt/checkmk-tools/script-check-nsec8/full/check_firewall_connections.sh
```

## Note
- Il limite `nf_conntrack_max` può essere aumentato se necessario:
  ```bash
  echo 131072 > /proc/sys/net/netfilter/nf_conntrack_max
  ```
- Connessioni alte possono indicare:
  - Molto traffico legittimo
  - Attacco DDoS
  - Leak di connessioni (timeout troppo alti)
