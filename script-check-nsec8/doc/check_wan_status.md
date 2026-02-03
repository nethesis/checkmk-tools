# check_wan_status.sh

## Descrizione
Script di monitoraggio per CheckMK che verifica lo stato delle interfacce WAN su NSecFirewall8 (OpenWrt).

## Funzionalità
- Rileva automaticamente tutte le interfacce WAN configurate (wan, wan6, wwan, vwan)
- Verifica lo stato UP/DOWN tramite `ubus`
- Testa la connettività reale pingando il gateway
- Fallback su DNS pubblici (8.8.8.8, 1.1.1.1) se gateway non disponibile
- Output formato CheckMK con perfdata

## Stati
- **OK (0)**: Tutte le WAN sono UP e raggiungibili
- **WARNING (1)**: WAN UP ma senza connettività o stato sconosciuto
- **CRITICAL (2)**: Almeno una WAN è DOWN

## Output CheckMK
### Sezione wan_status
```
0 WAN_Status status=OK wan=OK - wan: UP (gateway 192.168.1.1 reachable)
```

### Sezione wan_metrics
```
0 WAN_Metrics - Total=1 Up=1 Down=0 Degraded=0 | total=1 up=1 down=0 degraded=0
```

## Performance Data
- `total`: Numero totale di interfacce WAN
- `up`: Numero di interfacce UP e funzionanti
- `down`: Numero di interfacce DOWN
- `degraded`: Numero di interfacce UP ma senza connettività

## Requisiti
- OpenWrt con `ubus`
- Comando `ping` disponibile
- Comando `jsonfilter` per parsing JSON

## Installazione
```bash
# Copia in directory agent CheckMK
cp check_wan_status.sh /usr/lib/check_mk_agent/local/rcheck_wan_status.sh
chmod +x /usr/lib/check_mk_agent/local/rcheck_wan_status.sh
```

## Test manuale
```bash
bash /opt/checkmk-tools/script-check-nsec8/full/check_wan_status.sh
```

## Note
- Lo script usa `ubus call network.interface.<name> status` per ottenere lo stato
- Test di connettività con timeout di 2 secondi e 2 tentativi
- Interfacce multiple WAN supportate (failover, load balancing)
