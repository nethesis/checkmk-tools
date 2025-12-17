# check_dns_resolution.sh

## Descrizione
Testa la risoluzione DNS del server locale (127.0.0.1) su NSecFirewall8, verificando velocità e affidabilità.

## Funzionalità
- Testa risoluzione di domini pubblici (google.com, cloudflare.com, dns.google)
- Usa `nslookup` verso 127.0.0.1 (dnsmasq locale)
- Misura tempo di risposta medio in millisecondi
- Threshold: WARNING se > 500ms, CRITICAL se nessuna risposta

## Stati
- **OK (0)**: Tutti i test OK e tempo < 500ms
- **WARNING (1)**: Alcuni test falliti o tempo > 500ms (ma < 1000ms)
- **CRITICAL (2)**: Tutti i test falliti o tempo > 1000ms

## Output CheckMK
```
0 DNS_Resolution response_time=45ms;500;1000 Test: 3/3 OK, tempo medio: 45ms - OK | successful=3 failed=0 total=3 avg_time_ms=45
```

## Performance Data
- `response_time`: Tempo medio di risposta con threshold
- `successful`: Numero test riusciti
- `failed`: Numero test falliti
- `total`: Numero totale test
- `avg_time_ms`: Tempo medio in millisecondi

## Requisiti
- Comando `nslookup` disponibile
- dnsmasq o altro DNS resolver in ascolto su 127.0.0.1:53
- Accesso internet per risolvere domini pubblici

## Installazione
```bash
cp check_dns_resolution.sh /usr/lib/check_mk_agent/local/rcheck_dns_resolution.sh
chmod +x /usr/lib/check_mk_agent/local/rcheck_dns_resolution.sh
```

## Test manuale
```bash
bash /opt/checkmk-tools/script-check-nsec8/full/check_dns_resolution.sh
```

## Note
- Test su domini pubblici per verificare chain completa (locale → upstream)
- DNS lento può indicare:
  - Upstream DNS sovraccarico o lento
  - Problemi di connettività WAN
  - dnsmasq sovraccarico (molte query)
- Fallimenti possono indicare:
  - dnsmasq non in esecuzione
  - Upstream DNS non raggiungibili
  - Problemi WAN
