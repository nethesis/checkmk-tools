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

Version: 1.0.2 (prompt interattivo credenziali)
"""

VERSION = "1.0.2"

import sys
import os
import shutil
import subprocess
import getpass
import argparse
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
    candidate_roots = [
        SCRIPT_DIR,
        SCRIPT_DIR.parent,
        SCRIPT_DIR.parent.parent,
        Path.cwd(),
        Path.cwd().parent,
    ]
    possible_paths = []
    for root in candidate_roots:
        possible_paths.extend([
            root / "script-notify-checkmk" / "full",
            root / "script-notify-checkmk",
        ])
    
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

    # Copia dipendenze Python del monitor/toolkit (se disponibili)
    info("Installazione dipendenze toolkit Ydea...")
    dependency_candidates = {
        "ydea_common.py": [
            SCRIPT_DIR / "ydea_common.py",
            SCRIPT_DIR / "Ydea-Toolkit" / "ydea_common.py",
        ],
        "ydea-toolkit.py": [
            SCRIPT_DIR / "ydea-toolkit.py",
            SCRIPT_DIR / "Ydea-Toolkit" / "ydea-toolkit.py",
        ],
    }

    for dependency_name, candidates in dependency_candidates.items():
        source = next((candidate for candidate in candidates if candidate.exists()), None)
        if not source:
            warn(f"Dipendenza {dependency_name} non trovata (skip)")
            continue

        destination = YDEA_TOOLKIT_DIR / dependency_name
        shutil.copy(source, destination)
        destination.chmod(0o755)
        success(f"{dependency_name} installato")


def read_env_exports(env_file: Path) -> dict:
    """Legge variabili export da un file .env"""
    values = {}
    if not env_file.exists():
        return values

    for line in env_file.read_text().splitlines():
        stripped = line.strip()
        if not stripped.startswith("export ") or "=" not in stripped:
            continue
        key, value = stripped[len("export "):].split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def update_env_exports(env_file: Path, updates: dict):
    """Aggiorna/aggiunge variabili export in un file .env"""
    existing_lines = env_file.read_text().splitlines() if env_file.exists() else []
    pending = dict(updates)
    new_lines = []

    for line in existing_lines:
        stripped = line.strip()
        if stripped.startswith("export ") and "=" in stripped:
            key = stripped[len("export "):].split("=", 1)[0].strip()
            if key in pending:
                value = str(pending.pop(key)).replace('"', '\\"')
                new_lines.append(f'export {key}="{value}"')
                continue
        new_lines.append(line)

    for key, value in pending.items():
        safe_value = str(value).replace('"', '\\"')
        new_lines.append(f'export {key}="{safe_value}"')

    env_file.write_text("\n".join(new_lines).rstrip() + "\n")


def prompt_value(label: str, current_value: str = "", required: bool = False, secret: bool = False) -> str:
    """Prompt interattivo con default e validazione"""
    while True:
        if secret:
            if current_value:
                prompt = f"{label} (invio per mantenere valore esistente): "
            else:
                prompt = f"{label}: "
            value = getpass.getpass(prompt).strip()
        else:
            prompt = f"{label}"
            if current_value:
                prompt += f" [{current_value}]"
            prompt += ": "
            value = input(prompt).strip()

        if value:
            return value
        if current_value:
            return current_value
        if not required:
            return ""

        warn(f"{label} è obbligatorio")


def normalize_existing_value(key: str, value: str) -> str:
    """Tratta placeholder come valori vuoti per forzare input reale quando richiesto."""
    if not value:
        return ""
    normalized = value.strip().strip('"').strip("'")
    placeholder_tokens = {
        "INSERISCI_ID",
        "INSERISCI_API_KEY",
        "INSERISCI_USER_ID",
        "INSERISCI_CONTRATTO_ID",
        "ID",
        "TOKEN",
        "il_tuo_id",
        "la_tua_api_key",
    }
    if normalized in placeholder_tokens:
        return ""
    if key == "YDEA_API_KEY" and normalized.upper().startswith("INSERISCI"):
        return ""
    return normalized


def prepare_env_profile_file(env_name: str, template_candidates: list) -> Path:
    """Prepara il file env copiando template e facendo backup se necessario."""
    env_file = YDEA_TOOLKIT_DIR / env_name
    if env_file.exists():
        warn(f"File {env_name} già esistente, salvo backup")
        backup_file = env_file.with_suffix(f".backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}")
        shutil.copy(env_file, backup_file)

    env_template = next((candidate for candidate in template_candidates if candidate.exists()), None)
    if env_template:
        shutil.copy(env_template, env_file)
        success(f"Template {env_name} copiato da: {env_template}")
    else:
        warn(f"Nessun template trovato per {env_name}, creo file vuoto: {env_file}")
        env_file.write_text("")

    return env_file


def configure_env_profile(env_file: Path, profile_label: str):
    """Configura interattivamente un profilo env specifico."""
    current_values = read_env_exports(env_file)

    print()
    info(f"Configurazione interattiva profilo {profile_label}: {env_file}")
    print("Campi richiesti: YDEA_ID, YDEA_API_KEY, YDEA_USER_ID")
    print("Campi opzionali: YDEA_USER_NAME, YDEA_CONTRATTO_ID, YDEA_ALERT_EMAIL")
    print()

    ydea_id = prompt_value(
        f"{profile_label} - YDEA_ID",
        normalize_existing_value("YDEA_ID", current_values.get("YDEA_ID", "")),
        required=True,
    )
    ydea_api_key = prompt_value(
        f"{profile_label} - YDEA_API_KEY",
        normalize_existing_value("YDEA_API_KEY", current_values.get("YDEA_API_KEY", "")),
        required=True,
        secret=True,
    )
    default_user_id = current_values.get("YDEA_USER_ID", current_values.get("YDEA_USER_ID_CREATE_TICKET", ""))
    ydea_user_id = prompt_value(
        f"{profile_label} - YDEA_USER_ID",
        normalize_existing_value("YDEA_USER_ID", default_user_id),
        required=True,
    )
    ydea_user_name = prompt_value(
        f"{profile_label} - YDEA_USER_NAME",
        normalize_existing_value("YDEA_USER_NAME", current_values.get("YDEA_USER_NAME", "")),
        required=False,
    )
    ydea_contratto_id = prompt_value(
        f"{profile_label} - YDEA_CONTRATTO_ID",
        normalize_existing_value("YDEA_CONTRATTO_ID", current_values.get("YDEA_CONTRATTO_ID", "")),
        required=False,
    )
    ydea_alert_email = prompt_value(
        f"{profile_label} - YDEA_ALERT_EMAIL",
        normalize_existing_value("YDEA_ALERT_EMAIL", current_values.get("YDEA_ALERT_EMAIL", "massimo.palazzetti@nethesis.it")),
        required=False,
    )

    updates = {
        "YDEA_ID": ydea_id,
        "YDEA_API_KEY": ydea_api_key,
        "YDEA_USER_ID": ydea_user_id,
        "YDEA_USER_ID_CREATE_NOTE": ydea_user_id,
        "YDEA_USER_ID_CREATE_TICKET": ydea_user_id,
        "YDEA_ALERT_EMAIL": ydea_alert_email,
    }
    if ydea_user_name:
        updates["YDEA_USER_NAME"] = ydea_user_name
    if ydea_contratto_id:
        updates["YDEA_CONTRATTO_ID"] = ydea_contratto_id

    update_env_exports(env_file, updates)
    success(f"Credenziali salvate in {env_file}")


def setup_env():
    """Configura file .env, .env.la e .env.ag"""
    info("Configurazione file env Ydea (.env, .env.la, .env.ag)...")

    base_candidates = [
        SCRIPT_DIR / ".env",
        SCRIPT_DIR.parent / ".env",
        SCRIPT_DIR / "Ydea-Toolkit" / ".env",
    ]
    la_candidates = [
        SCRIPT_DIR / ".env.la",
        SCRIPT_DIR.parent / ".env.la",
        SCRIPT_DIR / ".env",
        SCRIPT_DIR.parent / ".env",
    ]
    ag_candidates = [
        SCRIPT_DIR / ".env.ag",
        SCRIPT_DIR.parent / ".env.ag",
        SCRIPT_DIR / ".env",
        SCRIPT_DIR.parent / ".env",
    ]

    env_base = prepare_env_profile_file(".env", base_candidates)
    env_la = prepare_env_profile_file(".env.la", la_candidates)
    env_ag = prepare_env_profile_file(".env.ag", ag_candidates)

    print()
    warn("⚠️  Configurazione interattiva profili Ydea")
    print(f"  Base: {env_base}")
    print(f"  LA:   {env_la}")
    print(f"  AG:   {env_ag}")
    print()

    configure_base = input("Configurare ora il profilo BASE (.env)? (y/n) ").strip().lower() == "y"
    if configure_base:
        configure_env_profile(env_base, "BASE")
    else:
        warn("Configurazione BASE saltata")

    configure_la = input("Configurare ora il profilo LA (.env.la)? (y/n) ").strip().lower() == "y"
    if configure_la:
        configure_env_profile(env_la, "LA")
    else:
        warn("Configurazione LA saltata")

    configure_ag = input("Configurare ora il profilo AG (.env.ag)? (y/n) ").strip().lower() == "y"
    if configure_ag:
        configure_env_profile(env_ag, "AG")
    else:
        warn("Configurazione AG saltata")


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


def backup_and_remove(path: Path, label: str):
    """Backup e rimozione sicura di file/dir"""
    if not path.exists():
        return

    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_path = path.with_name(f"{path.name}.backup_remove_{timestamp}")
    try:
        if path.is_dir():
            shutil.copytree(path, backup_path)
            shutil.rmtree(path)
        else:
            shutil.copy2(path, backup_path)
            path.unlink()
        success(f"{label} rimosso (backup: {backup_path})")
    except Exception as exc:
        warn(f"Impossibile rimuovere {path}: {exc}")


def remove_cron_entries():
    """Rimuove cron entries ydea-health-monitor"""
    info("Rimozione cron job Ydea health monitor...")
    try:
        result = subprocess.run(
            ["crontab", "-l"],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            warn("Nessun crontab utente trovato")
            return

        original_lines = result.stdout.splitlines()
        filtered_lines = [
            line for line in original_lines
            if "ydea_health_monitor" not in line
            and "ydea-health-monitor" not in line
            and "Ydea Health Monitor - ogni 15 minuti" not in line
        ]

        if filtered_lines == original_lines:
            warn("Nessun cron job Ydea da rimuovere")
            return

        new_crontab = "\n".join(filtered_lines).rstrip() + "\n"
        subprocess.run(["crontab", "-"], input=new_crontab, text=True, check=True)
        success("Cron job Ydea rimosso")
    except Exception as exc:
        warn(f"Errore rimozione cron job: {exc}")


def remove_installation():
    """Rimuove integrazione Ydea installata"""
    print_header()
    check_root()

    warn("Modalità REMOVE attiva")
    print("Verranno rimossi (con backup):")
    print(f"  - Notifier da {CHECKMK_NOTIFY_DIR}")
    print(f"  - Profili env e health monitor da {YDEA_TOOLKIT_DIR}")
    print("  - Cron job ydea-health-monitor")
    print()

    confirm = input("Confermi la rimozione? (y/n) ").strip().lower()
    if confirm != "y":
        warn("Rimozione annullata")
        return

    info("Rimozione notifier CheckMK...")
    for notifier in ["ydea_la", "ydea_ag", "ydea_realip", "mail_ydea_down"]:
        backup_and_remove(CHECKMK_NOTIFY_DIR / notifier, f"Notifier {notifier}")

    info("Rimozione file Ydea Toolkit...")
    for env_name in [".env", ".env.la", ".env.ag"]:
        backup_and_remove(YDEA_TOOLKIT_DIR / env_name, f"Profilo {env_name}")

    for monitor_name in ["ydea_health_monitor.py", "ydea-health-monitor.sh"]:
        backup_and_remove(YDEA_TOOLKIT_DIR / monitor_name, f"Health monitor {monitor_name}")

    for cache_name in ["ydea_checkmk_tickets.json", "ydea_checkmk_flapping.json"]:
        backup_and_remove(Path("/tmp") / cache_name, f"Cache {cache_name}")

    backup_and_remove(Path("/var/log/ydea_health.log"), "Log ydea_health.log")
    remove_cron_entries()

    print()
    success("Rimozione completata")


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
    parser = argparse.ArgumentParser(description="Installer integrazione CheckMK → Ydea")
    parser.add_argument("--remove", action="store_true", help="Rimuove integrazione Ydea (con backup file)")
    args = parser.parse_args()

    if args.remove:
        remove_installation()
        return

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
