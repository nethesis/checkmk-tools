# CheckMK Notification Scripts - Remoti (Launcher)

Launcher remoti per script di notifica CheckMK.

## Script Disponibili

- `rmail_realip` - Notifica email con real IP (launcher)
- `rtelegram_realip` - Notifica Telegram con real IP (launcher)
- `rydea_realip` - Notifica Ydea con real IP e ticket automatico (launcher)

## Uso

```bash
# Esegui direttamente
./rydea_realip

# O scarica ed esegui
curl -fsSL https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-notify-checkmk/remote/rydea_realip | bash
```

## Integrazione CheckMK

Gli script remoti possono essere usati direttamente come notification scripts in CheckMK:

1. Scarica il launcher nel server CheckMK
2. Rendilo eseguibile: `chmod +x rydea_realip`
3. Configura in CheckMK Setup > Notifications

---

📁 **Script completi**: Vedi `../full/`
