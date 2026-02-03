# check_firewall_traffic.sh

## Descrizione
Monitora il traffico di rete (RX/TX) sulle interfacce WAN e LAN del firewall NSecFirewall8.

## Funzionalità
- Rileva automaticamente interfacce WAN (wan, wwan) e LAN (lan, br-lan)
- Legge statistiche da `/sys/class/net/<device>/statistics/`
- Conta bytes, pacchetti ed errori per RX e TX
- Genera allarme se errori > 100

## Stati
- **OK (0)**: Errori RX/TX <= 100
- **WARNING (1)**: Errori RX/TX > 100

## Output CheckMK
```
0 wan_traffic - RX: 123456789 bytes, TX: 987654321 bytes | rx_bytes=123456789 tx_bytes=987654321 rx_packets=12345 tx_packets=98765 rx_errors=0 tx_errors=0
0 lan_traffic - RX: 987654321 bytes, TX: 123456789 bytes | rx_bytes=987654321 tx_bytes=123456789 rx_packets=98765 tx_packets=12345 rx_errors=0 tx_errors=0
```

## Performance Data
- `rx_bytes`: Bytes ricevuti (cumulative counter)
- `tx_bytes`: Bytes trasmessi (cumulative counter)
- `rx_packets`: Pacchetti ricevuti
- `tx_packets`: Pacchetti trasmessi
- `rx_errors`: Errori in ricezione
- `tx_errors`: Errori in trasmissione

## Requisiti
- OpenWrt con `ubus` per mappare interfacce logiche a device fisici
- Directory `/sys/class/net/` accessibile

## Installazione
```bash
cp check_firewall_traffic.sh /usr/lib/check_mk_agent/local/rcheck_firewall_traffic.sh
chmod +x /usr/lib/check_mk_agent/local/rcheck_firewall_traffic.sh
```

## Test manuale
```bash
bash /opt/checkmk-tools/script-check-nsec8/full/check_firewall_traffic.sh
```

## Note
- I counter sono cumulativi dall'ultimo boot
- CheckMK calcola automaticamente i rate (bytes/sec, packets/sec)
- Perfetti per creare grafici di banda nel tempo
- Errori elevati possono indicare:
  - Problemi hardware (cavo, scheda rete)
  - Collisioni su half-duplex
  - MTU mismatch
