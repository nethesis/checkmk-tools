# check_vpn_tunnels.sh

## Descrizione
Monitora lo stato dei tunnel VPN su NSecFirewall8, supportando OpenVPN, WireGuard e IPSec (strongSwan).

## Funzionalità
- **OpenVPN**: Legge file status in `/var/run/openvpn/*.status`, conta client connessi
- **WireGuard**: Usa `wg show` per verificare handshake recenti (< 3 minuti)
- **IPSec**: Usa `ipsec status` per contare tunnel ESTABLISHED
- Distingue tunnel totali da tunnel attivi

## Stati
- **OK (0)**: Tutti i tunnel VPN sono attivi o nessun VPN configurato
- **WARNING (1)**: Alcuni tunnel sono down
- **CRITICAL (2)**: Tutti i tunnel sono down

## Output CheckMK
```
0 VPN_Tunnels active=2;0;0;0;2 Total:2 Active:2 - OK - All VPN active | total=2 active=2 inactive=0
0 VPN_Details - OpenVPN_server: 3 client, WireGuard_wg0: 2/5 peers active
```

## Performance Data
- `total`: Numero totale tunnel configurati
- `active`: Numero tunnel attivi/connessi
- `inactive`: Numero tunnel inattivi/disconnessi

## Requisiti OpenVPN
- File status in `/var/run/openvpn/`
- Formato status OpenVPN con `CLIENT_LIST`

## Requisiti WireGuard
- Comando `wg` disponibile
- Interfacce WireGuard configurate

## Requisiti IPSec
- strongSwan installato
- Comando `ipsec status` disponibile

## Installazione
```bash
cp check_vpn_tunnels.sh /usr/lib/check_mk_agent/local/rcheck_vpn_tunnels.sh
chmod +x /usr/lib/check_mk_agent/local/rcheck_vpn_tunnels.sh
```

## Test manuale
```bash
bash /opt/checkmk-tools/script-check-nsec8/full/check_vpn_tunnels.sh
```

## Note
- WireGuard: peer considerato attivo se handshake < 180 secondi
- OpenVPN: server considerato attivo se ha almeno 1 client connesso
- IPSec: solo tunnel ESTABLISHED sono contati come attivi
- Se nessun VPN configurato, stato è OK (normale per firewall senza VPN)
