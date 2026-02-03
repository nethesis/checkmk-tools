# check_uptime.sh

## Descrizione
Monitora uptime del sistema e load average su NSecFirewall8, normalizzando il load per numero di CPU.

## Funzionalità
- Legge uptime da `/proc/uptime` e converte in giorni/ore/minuti
- Legge load average (1min, 5min, 15min) da `/proc/loadavg`
- Conta CPU disponibili con `nproc`
- Normalizza load per CPU (load / cpu_count)
- Threshold: WARNING se load/cpu > 0.8, CRITICAL se > 1.5

## Stati
- **OK (0)**: Load normalizzato < 0.8 per CPU
- **WARNING (1)**: Load normalizzato >= 0.8 per CPU
- **CRITICAL (2)**: Load normalizzato >= 1.5 per CPU

## Output CheckMK
```
0 Firewall_Uptime - Uptime: 15d 8h 42m, Load: 0.35 0.42 0.38 (4 CPU) - OK | uptime_seconds=1331520 load1=0.35 load5=0.42 load15=0.38 cpu_count=4
```

## Performance Data
- `uptime_seconds`: Uptime totale in secondi
- `load1`: Load average 1 minuto
- `load5`: Load average 5 minuti
- `load15`: Load average 15 minuti
- `cpu_count`: Numero di CPU/core

## Requisiti
- File `/proc/uptime` e `/proc/loadavg`
- Comando `nproc` per contare CPU

## Installazione
```bash
cp check_uptime.sh /usr/lib/check_mk_agent/local/rcheck_uptime.sh
chmod +x /usr/lib/check_mk_agent/local/rcheck_uptime.sh
```

## Test manuale
```bash
bash /opt/checkmk-tools/script-check-nsec8/full/check_uptime.sh
```

## Interpretazione Load Average
- **< 0.7 per CPU**: Sistema tranquillo
- **0.7-1.0 per CPU**: Sistema carico ma gestibile
- **1.0-1.5 per CPU**: Sistema molto carico, attenzione
- **> 1.5 per CPU**: Sistema sovraccarico, processi in coda

## Note
- Load normalizzato aiuta a confrontare sistemi con CPU diverse
- Load alto su firewall può indicare:
  - Molto traffico da processare
  - Regole firewall inefficienti
  - Attacco in corso
  - Processi in background pesanti
- Uptime molto lungo può richiedere reboot per aggiornamenti kernel
