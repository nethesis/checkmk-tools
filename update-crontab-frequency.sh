
#!/bin/bash
/bin/bash
# Script interattivo per aggiornare la frequenza del ticket-monitor
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "  Configurazione frequenza ticket-monitor"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo ""
# Mostra configurazione attualecurrent_freq=$(crontab -l 2>/dev/null | grep "ydea-ticket-monitor.sh" | awk '{print $1}')if [[ "$current_freq" == "*/5" ]]; then  current_text="5 minuti"elif [[ "$current_freq" == "*/10" ]]; then  current_text="10 minuti"elif [[ "$current_freq" == "*/15" ]]; then  current_text="15 minuti"elif [[ "$current_freq" == "*/30" ]]; then  current_text="30 minuti"else  current_text="$current_freq (personalizzato)"fi
echo "­ƒôè Frequenza attuale: $current_text ($current_freq)"
echo ""
echo "Scegli nuova frequenza:"
echo "  1) Ogni 1 minuto   (*/1) - tempo reale (debug)"
echo "  2) Ogni 5 minuti   (*/5) - molto reattivo"
echo "  3) Ogni 10 minuti  (*/10) - bilanciato"
echo "  4) Ogni 15 minuti  (*/15) - moderato"
echo "  5) Ogni 30 minuti  (*/30) - leggero"
echo "  6) Personalizzato"
echo "  0) Esci"
echo ""read -p "Scelta [1-6, 0]: " choicecase $choice in  1) new_freq="*/1" ;;  2) new_freq="*/5" ;;  3) new_freq="*/10" ;;  4) new_freq="*/15" ;;  5) new_freq="*/30" ;;  6)    
echo ""    read -p "Inserisci frequenza (es. */5 o 0,15,30,45): " new_freq    ;;  0)    
echo "Annullato."    exit 0    ;;  *)    
echo "ÔØî Scelta non valida"    exit 1    ;;esac
echo ""
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"
echo "ÔÜá´©Å  Cambio frequenza: $current_freq ÔåÆ $new_freq"
echo "ÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöüÔöü"read -p "Confermi? [s/N]: " confirmif [[ "$confirm" != "s" && "$confirm" != "S" ]]; then  
echo "Annullato."  exit 0fi
# Backup del crontabbackup_file="/tmp/crontab.backup.$(date +%Y%m%d_%H%M%S)"crontab -l > "$backup_file"
echo "­ƒÆ¥ Backup crontab: $backup_file"
# Aggiorna la frequenzacrontab -l | sed "s|^.* \* \* \* \* /opt/ydea-toolkit/rydea-ticket-monitor.sh|$new_freq * * * * /opt/ydea-toolkit/rydea-ticket-monitor.sh|" | crontab -
echo ""
echo "Ô£à Crontab aggiornato!"
echo ""
echo "Configurazione attuale:"crontab -l | grep -E "ydea-ticket-monitor|ydea-health-monitor"
echo ""
