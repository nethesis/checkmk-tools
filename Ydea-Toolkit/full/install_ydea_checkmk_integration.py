#!/usr/bin/env python3
"""
install_ydea_checkmk_integration.py - Installer integrazione CheckMK → Ydea

Script di installazione rapida per integrare CheckMK con Ydea Toolkit.
Copia script di notifica, configura .env, setup cron job, test connessione.

Usage:
    sudo python3 install_ydea_checkmk_integration.py

Requirements:
    - Root privileges
    - CheckMK installato
    - Directory Ydea Toolkit

Version: 1.0.1 (allineato a ydea_la/ydea_ag)
"""

VERSION = "1.0.1"

import sys
import os
import shutil
import subprocess
from pathlib import Path
from datetime import datetime


# ===== CONFIGURAZIONE =====

CHECKMK_SITE = os.getenv("CHECKMK_SITE", "monitoring")
CHECKMK_NOTIFY_DIR = Path(f"/omd/sites/{CHECKMK_SITE}/local/share/check_mk/notifications")
YDEA_TOOLKIT_DIR = Path(os.getenv("YDEA_TOOLKIT_DIR", "/opt/ydea-toolkit"))
SCRIPT_DIR = Path(__file__).resolve().parent


# ===== COLORI OUTPUT =====

class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color


def info(msg: str):
    print(f"{Colors.BLUE}ℹ️  {msg}{Colors.NC}")


def success(msg: str):
    print(f"{Colors.GREEN}✅ {msg}{Colors.NC}")


def warn(msg: str):
    print(f"{Colors.YELLOW}⚠️  {msg}{Colors.NC}")


def error(msg: str):
    print(f"{Colors.RED}❌ {msg}{Colors.NC}", file=sys.stderr)


def print_header():
    print(f"{Colors.BLUE}╔══════════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.BLUE}║     🎫 Installazione Integrazione CheckMK → Ydea           ║{Colors.NC}")
    print(f"{Colors.BLUE}╚══════════════════════════════════════════════════════════════╝{Colors.NC}")
    print()


# ===== FUNZIONI CONTROLLO =====

def check_root():
    """Verifica permessi root"""
    if os.geteuid() != 0:
        error("Questo script deve essere eseguito come root")
        print("  Usa: sudo python3 install_ydea_checkmk_integration.py")
        sys.exit(1)


def check_checkmk():
    """Verifica installazione CheckMK"""
    checkmk_site_dir = Path(f"/omd/sites/{CHECKMK_SITE}")
    if not checkmk_site_dir.exists():
        error(f"Sito CheckMK '{CHECKMK_SITE}' non trovato")
        print(f"  Verifica nome sito o usa: export CHECKMK_SITE='nome_sito'")
        sys.exit(1)
    success(f"CheckMK sito '{CHECKMK_SITE}' trovato")


def check_ydea_toolkit():
    """Verifica directory Ydea Toolkit"""
    if not YDEA_TOOLKIT_DIR.exists():
        warn(f"Directory Ydea Toolkit non trovata: {YDEA_TOOLKIT_DIR}")
        response = input("Vuoi crearla? (y/n) ")
        if response.lower() == 'y':
            YDEA_TOOLKIT_DIR.mkdir(parents=True, exist_ok=True)
            success(f"Directory creata: {YDEA_TOOLKIT_DIR}")
        else:
            error("Impossibile continuare senza Ydea Toolkit")
            sys.exit(1)
    else:
        success(f"Ydea Toolkit trovato: {YDEA_TOOLKIT_DIR}")


# ===== INSTALLAZIONE =====

def install_scripts():
    """Installa script di notifica CheckMK"""
    info("Installazione script di notifica CheckMK...")
    
    # Determina percorso script-notify-checkmk
    notify_script_dir = None
    possible_paths = [
        SCRIPT_DIR / "script-notify-checkmk" / "full",
        SCRIPT_DIR.parent / "script-notify-checkmk" / "full",
        SCRIPT_DIR / "script-notify-checkmk",
        SCRIPT_DIR.parent / "script-notify-checkmk"
    ]
    
    for path in possible_paths:
        if path.exists():
            notify_script_dir = path
            break
    
    if not notify_script_dir:
        error("Cartella script-notify-checkmk non trovata")
        for path in possible_paths:
            print(f"  Provato: {path}")
        sys.exit(1)
    
    info(f"Usando script da: {notify_script_dir}")
    
    # Crea directory notifiche se non esiste
    CHECKMK_NOTIFY_DIR.mkdir(parents=True, exist_ok=True)
    
    # Copia notifier Ydea principali (con ID persona dedicato)
    required_notifiers = {
        "ydea_la": ["ydea_la.py", "ydea_la"],
        "ydea_ag": ["ydea_ag.py", "ydea_ag"],
    }

    for destination_name, candidates in required_notifiers.items():
        source = None
        for candidate in candidates:
            candidate_path = notify_script_dir / candidate
            if candidate_path.exists():
                source = candidate_path
                break

        if not source:
            error(
                f"File richiesto {destination_name} non trovato in {notify_script_dir}/ "
                f"(attesi: {', '.join(candidates)})"
            )
            sys.exit(1)

        shutil.copy(source, CHECKMK_NOTIFY_DIR / destination_name)
        (CHECKMK_NOTIFY_DIR / destination_name).chmod(0o755)
        success(f"{destination_name} installato da {source.name}")

    # Copia eventuale notifier legacy (opzionale)
    ydea_realip = notify_script_dir / "ydea_realip"
    if ydea_realip.exists():
        shutil.copy(ydea_realip, CHECKMK_NOTIFY_DIR / "ydea_realip")
        (CHECKMK_NOTIFY_DIR / "ydea_realip").chmod(0o755)
        warn("ydea_realip installato (legacy opzionale)")
    
    # Copia mail_ydea_down (opzionale)
    mail_ydea_down = notify_script_dir / "mail_ydea_down"
    if mail_ydea_down.exists():
        shutil.copy(mail_ydea_down, CHECKMK_NOTIFY_DIR / "mail_ydea_down")
        (CHECKMK_NOTIFY_DIR / "mail_ydea_down").chmod(0o755)
        success("mail_ydea_down installato")
    else:
        warn("File mail_ydea_down non trovato (opzionale)")
    
    # Copia health monitor (supporta sia .sh che .py)
    info("Installazione health monitor...")
    health_monitor = None
    possible_monitors = [
        SCRIPT_DIR / "ydea_health_monitor.py",
        SCRIPT_DIR / "ydea-health-monitor.sh",
        SCRIPT_DIR / "Ydea-Toolkit" / "ydea_health_monitor.py",
        SCRIPT_DIR / "Ydea-Toolkit" / "ydea-health-monitor.sh"
    ]
    
    for monitor in possible_monitors:
        if monitor.exists():
            health_monitor = monitor
            break
    
    if not health_monitor:
        error("File ydea_health_monitor.py o ydea-health-monitor.sh non trovato")
        sys.exit(1)
    
    shutil.copy(health_monitor, YDEA_TOOLKIT_DIR / health_monitor.name)
    (YDEA_TOOLKIT_DIR / health_monitor.name).chmod(0o755)
    success(f"{health_monitor.name} installato")


def setup_env():
    """Configura file .env"""
    info("Configurazione file .env...")
    
    env_file = YDEA_TOOLKIT_DIR / ".env"
    
    if env_file.exists():
        warn("File .env già esistente, salvo backup")
        backup_file = env_file.with_suffix(f".backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}")
        shutil.copy(env_file, backup_file)
    
    # Copia .env template se esiste (supporta più path)
    env_candidates = [
        SCRIPT_DIR / ".env",
        SCRIPT_DIR / ".env.la",
        SCRIPT_DIR / ".env.ag",
        SCRIPT_DIR.parent / ".env",
        SCRIPT_DIR.parent / ".env.la",
        SCRIPT_DIR.parent / ".env.ag",
        SCRIPT_DIR / "Ydea-Toolkit" / ".env",
    ]

    env_template = next((candidate for candidate in env_candidates if candidate.exists()), None)
    if env_template:
        shutil.copy(env_template, env_file)
        success(f"Template .env copiato da: {env_template}")
    else:
        warn(f"Nessun template .env trovato, creo file vuoto: {env_file}")
        env_file.write_text("")
    
    print()
    warn("⚠️  IMPORTANTE: Configura le credenziali Ydea in:")
    print(f"  {env_file}")
    print()
    print("Modifica le righe:")
    print('  export YDEA_ID="il_tuo_id"')
    print('  export YDEA_API_KEY="la_tua_api_key"')
    print('  export YDEA_ALERT_EMAIL="massimo.palazzetti@nethesis.it"')
    print()
    
    response = input("Vuoi modificarlo ora? (y/n) ")
    if response.lower() == 'y':
        editor = os.getenv("EDITOR", "nano")
        subprocess.run([editor, str(env_file)])


def test_connection():
    """Test connessione Ydea API"""
    info("Test connessione Ydea API...")
    
    # Cerca ydea-toolkit (supporta sia .sh che .py)
    toolkit_script = None
    possible_toolkits = [
        YDEA_TOOLKIT_DIR / "ydea-toolkit.py",
        YDEA_TOOLKIT_DIR / "ydea-toolkit.sh"
    ]
    
    for toolkit in possible_toolkits:
        if toolkit.exists():
            toolkit_script = toolkit
            break
    
    if not toolkit_script:
        warn("ydea-toolkit non trovato, skip test")
        return
    
    try:
        # Test login
        result = subprocess.run(
            [str(toolkit_script), "login"],
            cwd=str(YDEA_TOOLKIT_DIR),
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if "Login effettuato" in result.stdout or result.returncode == 0:
            success("Connessione Ydea OK")
        else:
            warn("Test connessione fallito - verifica credenziali in .env")
    except Exception as e:
        warn(f"Test connessione fallito: {e}")


def setup_cron():
    """Configura cron job per health monitor"""
    info("Configurazione cron job per health monitor...")
    
    # Determina quale health monitor usare
    health_monitor = None
    if (YDEA_TOOLKIT_DIR / "ydea_health_monitor.py").exists():
        health_monitor = YDEA_TOOLKIT_DIR / "ydea_health_monitor.py"
    elif (YDEA_TOOLKIT_DIR / "ydea-health-monitor.sh").exists():
        health_monitor = YDEA_TOOLKIT_DIR / "ydea-health-monitor.sh"
    else:
        warn("Health monitor non trovato, skip cron setup")
        return
    
    cron_line = f"*/15 * * * * {health_monitor} >> /var/log/ydea_health.log 2>&1"
    
    try:
        # Controlla se già esiste
        result = subprocess.run(
            ["crontab", "-l"],
            capture_output=True,
            text=True
        )
        
        if "ydea-health-monitor" in result.stdout or "ydea_health_monitor" in result.stdout:
            warn("Cron job già configurato")
        else:
            # Aggiungi al crontab
            new_crontab = result.stdout if result.returncode == 0 else ""
            new_crontab += f"\n# Ydea Health Monitor - ogni 15 minuti\n{cron_line}\n"
            
            subprocess.run(
                ["crontab", "-"],
                input=new_crontab,
                text=True,
                check=True
            )
            success("Cron job configurato (ogni 15 minuti)")
    except Exception as e:
        warn(f"Errore configurazione cron: {e}")
    
    # Crea file log
    log_file = Path("/var/log/ydea_health.log")
    log_file.touch(exist_ok=True)
    log_file.chmod(0o666)
    success("Log file creato: /var/log/ydea_health.log")


def create_cache_files():
    """Inizializza file cache"""
    info("Inizializzazione file cache...")
    
    cache_files = [
        Path("/tmp/ydea_checkmk_tickets.json"),
        Path("/tmp/ydea_checkmk_flapping.json")
    ]
    
    for cache_file in cache_files:
        cache_file.write_text("{}")
        cache_file.chmod(0o666)
    
    success("File cache inizializzati")


def show_next_steps():
    """Mostra prossimi passi"""
    print()
    print(f"{Colors.GREEN}╔══════════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.GREEN}║              ✅ Installazione Completata!                   ║{Colors.NC}")
    print(f"{Colors.GREEN}╚══════════════════════════════════════════════════════════════╝{Colors.NC}")
    print()
    print(f"{Colors.BLUE}📋 PROSSIMI PASSI:{Colors.NC}")
    print()
    print("1️⃣  Configura notification rule in CheckMK:")
    print("   → Setup → Notifications → Add rule")
    print("   → Script: ydea_la / ydea_ag")
    print()
    print("2️⃣  Verifica credenziali Ydea:")
    print(f"   → {YDEA_TOOLKIT_DIR}/.env")
    print()
    print("3️⃣  Test manuale:")
    print(f"   → cd {YDEA_TOOLKIT_DIR}")
    print("   → source .env")
    print("   → ./ydea-toolkit.py login")
    print()
    print("4️⃣  Monitora log:")
    print("   → tail -f /var/log/ydea_health.log")
    print(f"   → tail -f /omd/sites/{CHECKMK_SITE}/var/log/notify.log")
    print()
    print("5️⃣  Documentazione completa:")
    print(f"   → {YDEA_TOOLKIT_DIR}/README-CHECKMK-INTEGRATION.md")
    print()
    print(f"{Colors.YELLOW}⚠️  RICORDA: Configura le credenziali in .env prima dell'uso!{Colors.NC}")
    print()


# ===== MAIN =====

def main():
    """Main installation"""
    print_header()
    check_root()
    check_checkmk()
    check_ydea_toolkit()
    install_scripts()
    setup_env()
    create_cache_files()
    setup_cron()
    test_connection()
    show_next_steps()


if __name__ == "__main__":
    main()
