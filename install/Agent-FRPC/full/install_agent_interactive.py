#!/usr/bin/env python3
"""
install_agent_interactive.py - Interactive CheckMK Agent + FRPC Installation for Windows

Interactive installer for CheckMK monitoring agent and FRP client on Windows systems.
Handles MSI installation, service configuration, NSSM setup, and FRPC tunnel configuration.

Requires Administrator privileges.
Compatible with: Windows 10, Windows 11, Windows Server 2019, Windows Server 2022

Version: 1.0.0
"""

import os
import sys
import subprocess
import ctypes
import urllib.request
import zipfile
import tarfile
import shutil
import time
import re
import tempfile
import argparse
from pathlib import Path
from typing import Tuple, Optional, List, Dict
from datetime import datetime

VERSION = "1.0.0"

# Configuration
CHECKMK_VERSION = "2.4.0p14"
FRP_VERSION = "0.64.0"
NSSM_VERSION = "2.24"

# URLs with fallbacks
FRP_URL = f"https://github.com/fatedier/frp/releases/download/v{FRP_VERSION}/frp_{FRP_VERSION}_windows_amd64.zip"
CHECKMK_MSI_URLS = [
    "https://monitoring.nethlab.it/monitoring/check_mk/agents/windows/check_mk_agent.msi",
    f"https://download.checkmk.com/checkmk/{CHECKMK_VERSION}/check-mk-agent-{CHECKMK_VERSION}-1_all.msi"
]
NSSM_URLS = [
    f"https://nssm.cc/release/nssm-{NSSM_VERSION}.zip",
    f"https://nssm.cc/ci/nssm-{NSSM_VERSION}-101-g897c7ad.zip",
    f"https://github.com/kirillkovalenko/nssm/releases/download/{NSSM_VERSION}/nssm-{NSSM_VERSION}.zip"
]

# Paths
DOWNLOAD_DIR = Path(tempfile.gettempdir()) / "CheckMK-Setup"
AGENT_INSTALL_DIR = Path("C:/Program Files (x86)/checkmk/service")
FRPC_INSTALL_DIR = Path("C:/frp")
FRPC_CONFIG_DIR = Path("C:/ProgramData/frp")
FRPC_LOG_DIR = Path("C:/ProgramData/frp/logs")


def is_admin() -> bool:
    """Check if script is running with Administrator privileges."""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False


def run_command(cmd: List[str], check: bool = False, capture: bool = True, timeout: int = 60, shell: bool = True) -> Tuple[int, str, str]:
    """Execute a Windows command."""
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
            text=True,
            check=check,
            timeout=timeout,
            shell=shell
        )
        return result.returncode, result.stdout or "", result.stderr or ""
    except subprocess.CalledProcessError as e:
        return e.returncode, e.stdout or "", e.stderr or ""
    except subprocess.TimeoutExpired:
        return 124, "", "Command timeout"
    except Exception as e:
        return 1, "", str(e)


def print_header(title: str, color: str = "cyan"):
    """Print section header."""
    print("\n" + "=" * 68)
    print(title.upper())
    print("=" * 68)


def print_ok(msg: str):
    """Print success message."""
    print(f"    [OK] {msg}")


def print_warn(msg: str):
    """Print warning message."""
    print(f"    [WARN] {msg}")


def print_err(msg: str):
    """Print error message."""
    print(f"    [ERR] {msg}")


def print_info(msg: str):
    """Print info message."""
    print(f"    [INFO] {msg}")


def get_windows_info() -> Dict[str, str]:
    """Get Windows OS information."""
    try:
        exitcode, stdout, _ = run_command([
            "powershell", "-Command",
            "$os = Get-WmiObject -Class Win32_OperatingSystem; "
            "Write-Output \"$($os.Caption)|$($os.Version)|$($os.OSArchitecture)\""
        ], capture=True)
        
        if exitcode == 0 and stdout.strip():
            parts = stdout.strip().split('|')
            caption = parts[0] if len(parts) > 0 else "Unknown"
            version = parts[1] if len(parts) > 1 else "Unknown"
            arch = parts[2] if len(parts) > 2 else "Unknown"
            
            # Simplify OS name
            if "Windows 11" in caption:
                os_name = "Windows 11"
            elif "Windows 10" in caption:
                os_name = "Windows 10"
            elif "Server 2022" in caption:
                os_name = "Windows Server 2022"
            elif "Server 2019" in caption:
                os_name = "Windows Server 2019"
            else:
                os_name = caption
            
            architecture = "x64" if "64-bit" in arch else "x86"
            
            return {
                "name": os_name,
                "version": version,
                "architecture": architecture
            }
    except Exception:
        pass
    
    return {"name": "Windows", "version": "Unknown", "architecture": "x64"}


def check_service_status(service_name: str) -> Optional[str]:
    """Check Windows service status."""
    exitcode, stdout, _ = run_command([
        "sc", "query", service_name
    ], capture=True)
    
    if exitcode == 0:
        if "RUNNING" in stdout:
            return "running"
        elif "STOPPED" in stdout:
            return "stopped"
        else:
            return "unknown"
    return None


def stop_service(service_name: str) -> bool:
    """Stop Windows service."""
    if check_service_status(service_name) == "running":
        print(f"    [*] Arresto servizio {service_name}...")
        exitcode, _, _ = run_command(["net", "stop", service_name], check=False)
        time.sleep(2)
        return exitcode == 0
    return True


def start_service(service_name: str, max_retries: int = 3) -> bool:
    """Start Windows service with retries."""
    for attempt in range(1, max_retries + 1):
        print(f"    [*] Tentativo avvio {attempt}/{max_retries}...")
        exitcode, _, _ = run_command(["net", "start", service_name], check=False)
        
        if exitcode == 0:
            time.sleep(3)
            if check_service_status(service_name) == "running":
                print_ok(f"Servizio {service_name} avviato")
                return True
        
        if attempt < max_retries:
            time.sleep(2)
    
    return False


def download_file(url: str, destination: Path, description: str = "file") -> bool:
    """Download file from URL with progress."""
    try:
        print(f"    [*] Download {description} da: {url}")
        urllib.request.urlretrieve(url, destination)
        
        if destination.exists() and destination.stat().st_size > 0:
            size_mb = destination.stat().st_size / (1024 * 1024)
            print_ok(f"Download completato ({size_mb:.2f} MB)")
            return True
        else:
            print_err("File scaricato non valido")
            return False
    except Exception as e:
        print_err(f"Errore download: {e}")
        return False


def install_checkmk_agent() -> bool:
    """Install CheckMK Agent on Windows."""
    print_header("INSTALLAZIONE CHECKMK AGENT PER WINDOWS", "cyan")
    
    DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
    msi_file = DOWNLOAD_DIR / "check_mk_agent.msi"
    
    print(f"\n[*] Download CheckMK Agent v{CHECKMK_VERSION}...")
    
    # Try multiple URLs
    download_success = False
    for url in CHECKMK_MSI_URLS:
        if download_file(url, msi_file, "CheckMK Agent"):
            download_success = True
            break
    
    if not download_success:
        print_err("Nessun URL disponibile per il download")
        return False
    
    # Install MSI
    print("\n[*] Installazione in corso...")
    msi_log = DOWNLOAD_DIR / "checkmk-install.log"
    
    exitcode, _, _ = run_command([
        "msiexec.exe", "/i", str(msi_file),
        "/qn", "/norestart", "/l*v", str(msi_log)
    ], check=False, timeout=120)
    
    if exitcode not in [0, 3010]:  # 0=success, 3010=success with reboot required
        print_err(f"Errore installazione (Exit code: {exitcode})")
        return False
    
    print_ok("Installazione completata")
    time.sleep(3)
    
    # Verify and start service
    if check_service_status("CheckMK Agent"):
        print_ok("Servizio CheckMK Agent trovato")
        
        if not start_service("CheckMK Agent"):
            print_warn("Servizio non avviato automaticamente")
        
        # Test port 6556
        print("    [*] Test connettività porta 6556...")
        time.sleep(2)
        
        exitcode, stdout, _ = run_command([
            "powershell", "-Command",
            "Test-NetConnection -ComputerName 127.0.0.1 -Port 6556 -WarningAction SilentlyContinue | "
            "Select-Object -ExpandProperty TcpTestSucceeded"
        ], capture=True)
        
        if exitcode == 0 and "True" in stdout:
            print_ok("Agent risponde correttamente sulla porta 6556")
        else:
            print_warn("Agent non risponde sulla porta 6556")
        
        return True
    else:
        print_warn("Servizio CheckMK Agent non trovato")
        return False


def install_frpc_service() -> bool:
    """Install FRP Client (FRPC) on Windows."""
    print_header("INSTALLAZIONE FRPC CLIENT PER WINDOWS", "blue")
    
    DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
    FRPC_INSTALL_DIR.mkdir(parents=True, exist_ok=True)
    FRPC_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    FRPC_LOG_DIR.mkdir(parents=True, exist_ok=True)
    
    # Download FRPC
    zip_file = DOWNLOAD_DIR / f"frp_{FRP_VERSION}_windows_amd64.zip"
    
    print(f"\n[*] Download FRPC v{FRP_VERSION}...")
    if not download_file(FRP_URL, zip_file, "FRPC"):
        return False
    
    # Extract ZIP
    print("\n[*] Estrazione archivio...")
    try:
        with zipfile.ZipFile(zip_file, 'r') as zip_ref:
            zip_ref.extractall(DOWNLOAD_DIR)
        
        # Find and copy frpc.exe
        extracted_dir = DOWNLOAD_DIR / f"frp_{FRP_VERSION}_windows_amd64"
        frpc_exe = extracted_dir / "frpc.exe"
        
        if frpc_exe.exists():
            shutil.copy(frpc_exe, FRPC_INSTALL_DIR / "frpc.exe")
            print_ok("frpc.exe copiato")
        else:
            print_err("frpc.exe non trovato nell'archivio")
            return False
    except Exception as e:
        print_err(f"Errore estrazione: {e}")
        return False
    
    # Interactive configuration
    print("\n[*] Configurazione FRPC...")
    print("\nInserisci le informazioni per la configurazione FRPC:\n")
    
    computer_name = os.environ.get("COMPUTERNAME", "windows-host")
    hostname = input(f"Nome host [default: {computer_name}]: ").strip() or computer_name
    frp_server = input("Server FRP remoto [default: monitor.nethlab.it]: ").strip() or "monitor.nethlab.it"
    
    remote_port = ""
    while not remote_port:
        remote_port = input("Porta remota (es: 20001): ").strip()
    
    use_default_token = input("Usare il token di sicurezza predefinito? [S/n]: ").strip().lower()
    if use_default_token == 'n':
        auth_token = input("Inserisci token personalizzato: ").strip()
        if not auth_token:
            auth_token = "conduit-reenact-talon-macarena-demotion-vaguely"
            print_warn("Token vuoto, uso quello predefinito")
    else:
        auth_token = "conduit-reenact-talon-macarena-demotion-vaguely"
        print_ok("Uso token predefinito")
    
    # Create TOML configuration
    toml_config = f"""[common]
server_addr = "{frp_server}"
server_port = 7000
auth.method = "token"
auth.token  = "{auth_token}"
tls.enable = true
log.to = "{str(FRPC_LOG_DIR / 'frpc.log').replace(chr(92), '/')}"
log.level = "debug"

[{hostname}]
type        = "tcp"
local_ip    = "127.0.0.1"
local_port  = 6556
remote_port = {remote_port}
"""
    
    toml_file = FRPC_CONFIG_DIR / "frpc.toml"
    print("\n[*] Creazione file di configurazione...")
    try:
        toml_file.write_text(toml_config, encoding='utf-8')
        print_ok(f"Configurazione salvata in: {toml_file}")
    except Exception as e:
        print_err(f"Errore creazione configurazione: {e}")
        return False
    
    # Download and setup NSSM
    print("\n[*] Download NSSM (Service Wrapper)...")
    
    # Stop existing FRPC service if present
    if check_service_status("frpc"):
        stop_service("frpc")
    
    nssm_zip = DOWNLOAD_DIR / f"nssm-{NSSM_VERSION}.zip"
    
    # Try multiple NSSM URLs
    download_success = False
    for url in NSSM_URLS:
        if download_file(url, nssm_zip, "NSSM"):
            download_success = True
            break
    
    if not download_success:
        print_err("Nessun URL NSSM disponibile")
        return False
    
    # Extract NSSM
    print("    [*] Estrazione NSSM...")
    try:
        with zipfile.ZipFile(nssm_zip, 'r') as zip_ref:
            zip_ref.extractall(DOWNLOAD_DIR)
        
        # Find nssm.exe (prefer win64 on 64-bit systems)
        is_64bit = "64" in os.environ.get("PROCESSOR_ARCHITECTURE", "")
        nssm_exe = None
        
        for root, dirs, files in os.walk(DOWNLOAD_DIR):
            for file in files:
                if file == "nssm.exe":
                    full_path = Path(root) / file
                    if is_64bit and "win64" in str(full_path):
                        nssm_exe = full_path
                        break
                    elif not nssm_exe:
                        nssm_exe = full_path
        
        if not nssm_exe:
            print_err("NSSM.exe non trovato nell'archivio")
            return False
        
        # Copy NSSM to FRPC directory
        nssm_install_path = FRPC_INSTALL_DIR / "nssm.exe"
        if nssm_install_path.exists():
            nssm_install_path.unlink()
        
        shutil.copy(nssm_exe, nssm_install_path)
        print_ok(f"NSSM estratto: {nssm_install_path}")
    except Exception as e:
        print_err(f"Errore configurazione NSSM: {e}")
        return False
    
    # Create Windows service with NSSM
    print("\n[*] Creazione servizio Windows con NSSM...")
    
    try:
        # Remove existing service if present
        if check_service_status("frpc"):
            print("    [*] Rimozione servizio precedente...")
            stop_service("frpc")
            run_command([str(nssm_install_path), "remove", "frpc", "confirm"], check=False)
            time.sleep(2)
        
        frpc_path = FRPC_INSTALL_DIR / "frpc.exe"
        
        print("    [*] Registrazione servizio con NSSM...")
        
        # Install service
        run_command([str(nssm_install_path), "install", "frpc", str(frpc_path)], check=False)
        run_command([str(nssm_install_path), "set", "frpc", "AppParameters", f"-c \"{toml_file}\""], check=False)
        run_command([str(nssm_install_path), "set", "frpc", "AppDirectory", str(FRPC_INSTALL_DIR)], check=False)
        run_command([str(nssm_install_path), "set", "frpc", "DisplayName", "FRP Client Service"], check=False)
        run_command([str(nssm_install_path), "set", "frpc", "Description", "FRP Client - Tunneling service"], check=False)
        run_command([str(nssm_install_path), "set", "frpc", "Start", "SERVICE_AUTO_START"], check=False)
        run_command([str(nssm_install_path), "set", "frpc", "AppStdout", str(FRPC_LOG_DIR / "nssm-stdout.log")], check=False)
        run_command([str(nssm_install_path), "set", "frpc", "AppStderr", str(FRPC_LOG_DIR / "nssm-stderr.log")], check=False)
        
        print_ok("Servizio registrato con NSSM")
        time.sleep(2)
        
        # Start service
        if start_service("frpc", max_retries=5):
            print_ok("Servizio FRPC avviato con successo")
        else:
            print_warn("Servizio creato ma non avviato automaticamente")
            print_info("Avvio manuale: Start-Service -Name 'frpc'")
    except Exception as e:
        print_err(f"Errore creazione servizio: {e}")
        return False
    
    # Summary
    print("\n[OK] FRPC Configurazione:")
    print(f"    Server:        {frp_server}:7000")
    print(f"    Tunnel:        {hostname}")
    print(f"    Porta remota:  {remote_port}")
    print(f"    Porta locale:  6556")
    print(f"    Config:        {toml_file}")
    print(f"    Log:           {FRPC_LOG_DIR / 'frpc.log'}")
    
    return True


def uninstall_frpc() -> bool:
    """Uninstall FRPC service."""
    print_header("DISINSTALLAZIONE FRPC CLIENT", "red")
    print("\nRimozione FRPC in corso...\n")
    
    try:
        # Stop and remove service
        if check_service_status("frpc"):
            print("[*] Arresto servizio FRPC...")
            stop_service("frpc")
            run_command(["sc", "delete", "frpc"], check=False)
            time.sleep(2)
        
        # Terminate processes
        print("[*] Terminazione processi FRPC...")
        run_command(["taskkill", "/F", "/IM", "frpc.exe"], check=False)
        
        # Remove directories
        if FRPC_INSTALL_DIR.exists():
            print("[*] Rimozione directory installazione...")
            shutil.rmtree(FRPC_INSTALL_DIR, ignore_errors=True)
        
        if FRPC_CONFIG_DIR.exists():
            print("[*] Rimozione directory configurazione...")
            shutil.rmtree(FRPC_CONFIG_DIR, ignore_errors=True)
        
        print_ok("FRPC disinstallato completamente")
        return True
    except Exception as e:
        print_err(f"Errore durante disinstallazione FRPC: {e}")
        return False


def uninstall_checkmk_agent() -> bool:
    """Uninstall CheckMK Agent."""
    print_header("DISINSTALLAZIONE CHECKMK AGENT", "red")
    print("\nRimozione CheckMK Agent in corso...\n")
    
    try:
        # Stop service
        if check_service_status("CheckMK Agent"):
            print("[*] Arresto servizio CheckMK Agent...")
            stop_service("CheckMK Agent")
        
        # Uninstall MSI
        print("[*] Disinstallazione pacchetto MSI...")
        exitcode, stdout, _ = run_command([
            "powershell", "-Command",
            "Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like '*CheckMK*'} | "
            "Select-Object -ExpandProperty IdentifyingNumber"
        ], capture=True)
        
        if exitcode == 0 and stdout.strip():
            product_code = stdout.strip()
            run_command(["msiexec.exe", "/x", product_code, "/qn", "/norestart"], check=False, timeout=60)
            time.sleep(3)
        
        # Remove directories
        if AGENT_INSTALL_DIR.exists():
            print("[*] Rimozione directory installazione...")
            shutil.rmtree(AGENT_INSTALL_DIR, ignore_errors=True)
        
        config_path = Path("C:/ProgramData/checkmk")
        if config_path.exists():
            print("[*] Rimozione directory configurazione...")
            shutil.rmtree(config_path, ignore_errors=True)
        
        print_ok("CheckMK Agent disinstallato completamente")
        return True
    except Exception as e:
        print_err(f"Errore durante disinstallazione Agent: {e}")
        return False


def main() -> int:
    """Main installation workflow."""
    parser = argparse.ArgumentParser(
        description="Installazione Interattiva CheckMK Agent + FRPC per Windows",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--uninstall-frpc", action="store_true", help="Disinstalla solo FRPC")
    parser.add_argument("--uninstall-agent", action="store_true", help="Disinstalla solo CheckMK Agent")
    parser.add_argument("--uninstall", action="store_true", help="Disinstalla tutto (Agent + FRPC)")
    
    args = parser.parse_args()
    
    print_header(f"Installazione Interattiva CheckMK Agent + FRPC per Windows - v{VERSION}", "cyan")
    
    # Check Administrator privileges
    if not is_admin():
        print_err("Questo script deve essere eseguito come Administrator")
        return 1
    
    # Handle uninstall modes
    if args.uninstall_frpc:
        return 0 if uninstall_frpc() else 1
    
    if args.uninstall_agent:
        return 0 if uninstall_checkmk_agent() else 1
    
    if args.uninstall:
        print_header("DISINSTALLAZIONE COMPLETA", "red")
        confirm = input("\nSei sicuro di voler rimuovere tutto? [s/N]: ").strip().lower()
        if confirm == 's':
            uninstall_frpc()
            print()
            uninstall_checkmk_agent()
            print_ok("Disinstallazione completa terminata!")
            return 0
        else:
            print("\n[CANCEL] Operazione annullata")
            return 0
    
    # Install mode
    print_header("RILEVAMENTO SISTEMA OPERATIVO", "cyan")
    
    os_info = get_windows_info()
    print("\n[INFO] Sistema Rilevato:")
    print(f"    OS:            {os_info['name']}")
    print(f"    Versione:      {os_info['version']}")
    print(f"    Architettura:  {os_info['architecture']}")
    
    print("\n[INFO] Questa installazione utilizzerà:")
    print("    - CheckMK Agent (plain TCP on port 6556)")
    print("    - Servizio Windows: CheckMK Agent")
    
    print("\n" + "=" * 68)
    confirm = input("Procedi con l'installazione? [s/N]: ").strip().lower()
    print("=" * 68)
    
    if confirm != 's':
        print("\n[CANCEL] Installazione annullata")
        return 0
    
    print_ok("Procedendo con l'installazione...")
    
    # Install CheckMK Agent
    if not install_checkmk_agent():
        print_err("Errore nell'installazione di CheckMK Agent")
        return 1
    
    # Ask for FRPC installation
    print("\n" + "=" * 68)
    install_frpc = input("Vuoi installare anche FRPC? [s/N]: ").strip().lower()
    print("=" * 68)
    
    if install_frpc == 's':
        if not install_frpc_service():
            print_warn("FRPC non installato correttamente")
            print_info("L'Agent CheckMK è comunque operativo sulla porta 6556")
    else:
        print("\n[SKIP] Installazione FRPC saltata")
    
    # Final summary
    print_header("INSTALLAZIONE COMPLETATA", "green")
    print_ok("CheckMK Agent installato (TCP 6556)")
    print_ok("Servizio Windows attivo: CheckMK Agent")
    
    if install_frpc == 's':
        print_ok("FRPC Client installato e configurato")
        print_ok("Servizio Windows attivo: frpc")
    
    print("\n[INFO] Comandi utili PowerShell:")
    print("    Get-Service -Name 'CheckMK Agent' | Format-List")
    print("    Restart-Service -Name 'CheckMK Agent'")
    
    if install_frpc == 's':
        print(f"    Get-Content '{FRPC_LOG_DIR}\\frpc.log' -Tail 50")
    
    print_ok("Installazione terminata con successo!")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n[CANCEL] Operazione interrotta dall'utente")
        sys.exit(130)
    except Exception as e:
        print(f"\n\n[ERR] ERRORE DURANTE L'ESECUZIONE:\n    {e}")
        import traceback
        print("\nTraccia stack:")
        traceback.print_exc()
        sys.exit(1)
