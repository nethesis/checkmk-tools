# check_dhcp_leases.sh

## Descrizione
Monitora l'utilizzo del pool DHCP su NSecFirewall8, controllando il numero di lease attivi rispetto al limite configurato.

## Funzionalità
- Legge il file `/tmp/dhcp.leases`
- Conta lease attivi (non scaduti) confrontando timestamp
- Legge configurazione pool da `uci get dhcp.lan.start/limit`
- Calcola percentuale di utilizzo
- Threshold: WARNING 80%, CRITICAL 90%

## Stati
- **OK (0)**: Utilizzo < 80%
- **WARNING (1)**: Utilizzo >= 80% o file leases non trovato
- **CRITICAL (2)**: Utilizzo >= 90%

## Output CheckMK
```
0 DHCP_Leases active=45;120;135;0;150 Lease attivi: 45/150 (30%) - OK | active=45 expired=5 total=50 max=150 percent=30
```

## Performance Data
- `active`: Lease attivi con threshold
- `expired`: Lease scaduti ancora nel file
- `total`: Totale lease nel file
- `max`: Dimensione pool DHCP
- `percent`: Percentuale utilizzo

## Requisiti
- File `/tmp/dhcp.leases` generato da dnsmasq
- Comando `uci` per leggere configurazione
- Comandi `date` per confrontare timestamp

## Installazione
```bash
cp check_dhcp_leases.sh /usr/lib/check_mk_agent/local/rcheck_dhcp_leases.sh
chmod +x /usr/lib/check_mk_agent/local/rcheck_dhcp_leases.sh
```

## Test manuale
```bash
bash /opt/checkmk-tools/script-check-nsec8/full/check_dhcp_leases.sh
```

## Formato file dhcp.leases
```
1732723456 aa:bb:cc:dd:ee:ff 192.168.1.100 hostname client-id
```
- Campo 1: Timestamp Unix di scadenza
- Campo 2: MAC address
- Campo 3: IP assegnato
- Campo 4: Hostname
- Campo 5: Client ID

## Note
- Pool pieno può impedire connessioni di nuovi dispositivi
- Lease statici non appaiono in questo file
- Ridurre lease time se pool piccolo e molti dispositivi temporanei
