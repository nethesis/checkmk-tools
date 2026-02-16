#!/usr/bin/env python3
"""
fix_frpc_config.py - Fix FRPC Configuration on Windows

Repairs common issues with FRPC (FRP Client) service on Windows:
- Permission issues on configuration files and directories
- Path corrections in TOML configuration (backslash to forward slash)
- Service startup and restart problems
- Log file management and diagnostics

Requires Administrator privileges.

Version: 1.0.0
"""

import os
import sys
import subprocess
import shutil
import time
import re
from pathlib import Path
from typing import Tuple, Optional, List
from datetime import datetime

VERSION = "1.0.0"

# Configuration paths
FRPC_INSTALL_DIR = Path("C:/frp")
FRPC_CONFIG_DIR = Path("C:/ProgramData/frp")
FRPC_LOG_DIR = Path("C:/ProgramData/frp/logs")
TOML_FILE = FRPC_CONFIG_DIR / "frpc.toml"
FRPC_PATH = FRPC_INSTALL_DIR / "frpc.exe"


def is_admin() -> bool:
    """
    Check if script is running with Administrator privileges.
    
    Returns:
        True if running as Administrator, False otherwise
    """
    try:
        import ctypes
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False


def run_command(cmd: List[str], check: bool = False, capture: bool = True, timeout: int = 30) -> Tuple[int, str, str]:
    """
    Execute a Windows command.
    
    Args:
        cmd: Command as list of strings
        check: Raise exception on non-zero exit code
        capture: Capture stdout/stderr
        timeout: Command timeout in seconds
        
    Returns:
        Tuple of (exit_code, stdout, stderr)
    """
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
            text=True,
            check=check,
            timeout=timeout,
            shell=True
        )
        return result.returncode, result.stdout or "", result.stderr or ""
    except subprocess.CalledProcessError as e:
        return e.returncode, e.stdout or "", e.stderr or ""
    except subprocess.TimeoutExpired:
        return 124, "", "Command timeout"
    except Exception as e:
        return 1, "", str(e)


def print_section(title: str):
    """Print a section header."""
    print(f"\n[*] {title}...")


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


def stop_service_and_processes() -> bool:
    """
    Stop FRPC service and terminate any residual processes.
    
    Returns:
        True if successful, False otherwise
    """
    print_section("Step 1: Arresto servizio e processi")
    
    # Stop service
    exitcode, stdout, _ = run_command(["sc", "query", "frpc"], capture=True)
    if exitcode == 0 and "RUNNING" in stdout:
        print("    [*] Arresto servizio FRPC...")
        run_command(["net", "stop", "frpc"], check=False)
        time.sleep(5)
        print_ok("Servizio arrestato")
    else:
        print_ok("Servizio già arrestato")
    
    # Terminate residual processes
    print("    [*] Terminazione processi residui...")
    run_command(["taskkill", "/F", "/IM", "frpc.exe"], check=False)
    run_command(["taskkill", "/F", "/IM", "nssm.exe"], check=False)
    time.sleep(2)
    
    return True


def verify_files() -> bool:
    """
    Verify required files and directories exist.
    
    Returns:
        True if all files exist, False otherwise
    """
    print_section("Step 2: Verifica file e directory")
    
    all_exist = True
    
    if FRPC_PATH.exists():
        print_ok(f"Eseguibile trovato: {FRPC_PATH}")
    else:
        print_err(f"Eseguibile non trovato: {FRPC_PATH}")
        all_exist = False
    
    if TOML_FILE.exists():
        print_ok(f"File configurazione trovato: {TOML_FILE}")
    else:
        print_err(f"File configurazione non trovato: {TOML_FILE}")
        all_exist = False
    
    if not FRPC_LOG_DIR.exists():
        print("    [*] Creazione directory log...")
        FRPC_LOG_DIR.mkdir(parents=True, exist_ok=True)
        print_ok("Directory log creata")
    else:
        print_ok("Directory log esistente")
    
    return all_exist


def fix_permissions() -> bool:
    """
    Fix permissions on FRPC directories and files.
    
    Returns:
        True if successful, False otherwise
    """
    print_section("Step 3: Correzione permessi")
    
    paths = [FRPC_CONFIG_DIR, FRPC_LOG_DIR, FRPC_INSTALL_DIR]
    
    for path in paths:
        if path.exists():
            print(f"    [*] Aggiornamento permessi: {path}")
            try:
                # Grant full control to SYSTEM and Administrators
                run_command([
                    "icacls", str(path), 
                    "/grant", "SYSTEM:(OI)(CI)F", 
                    "/T", "/C", "/Q"
                ], check=False)
                run_command([
                    "icacls", str(path), 
                    "/grant", "Administrators:(OI)(CI)F", 
                    "/T", "/C", "/Q"
                ], check=False)
                print_ok(f"Permessi aggiornati: {path}")
            except Exception as e:
                print_warn(f"Errore permessi su {path}: {e}")
    
    # Fix TOML file permissions specifically
    if TOML_FILE.exists():
        try:
            run_command([
                "icacls", str(TOML_FILE), 
                "/grant", "SYSTEM:F", 
                "/C", "/Q"
            ], check=False)
            print_ok("Permessi file TOML aggiornati")
        except Exception as e:
            print_warn(f"Errore permessi TOML: {e}")
    
    return True


def fix_toml_paths() -> bool:
    """
    Fix path separators in TOML configuration file (backslash to forward slash).
    
    Returns:
        True if successful, False otherwise
    """
    print_section("Step 4: Correzione path nel file TOML")
    
    if not TOML_FILE.exists():
        print_warn("File TOML non trovato")
        return False
    
    try:
        original_content = TOML_FILE.read_text(encoding='utf-8')
        
        # Replace backslashes with forward slashes
        fixed_content = original_content.replace('\\\\', '/')
        fixed_content = re.sub(r'\\(?![/\\])', '/', fixed_content)
        
        if fixed_content != original_content:
            # Backup original file
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_file = TOML_FILE.parent / f"frpc.toml.backup_{timestamp}"
            shutil.copy2(TOML_FILE, backup_file)
            print_ok(f"Backup creato: {backup_file}")
            
            # Save fixed content
            TOML_FILE.write_text(fixed_content, encoding='utf-8')
            print_ok("Path nel TOML corretti (backslash -> forward slash)")
        else:
            print_ok("Path nel TOML già corretti")
        
        # Show preview
        print("\n    [INFO] Preview configurazione:")
        lines = fixed_content.split('\n')[:12]
        for line in lines:
            print(f"      {line}")
        
        return True
        
    except Exception as e:
        print_err(f"Errore correzione TOML: {e}")
        return False


def validate_toml_config() -> bool:
    """
    Validate TOML configuration using frpc verify command.
    
    Returns:
        True if valid, False otherwise
    """
    print_section("Step 5: Validazione configurazione")
    
    if not FRPC_PATH.exists():
        print_warn("Eseguibile frpc non trovato")
        return False
    
    try:
        exitcode, stdout, stderr = run_command([
            str(FRPC_PATH), "verify", "-c", str(TOML_FILE)
        ], check=False)
        
        if exitcode == 0:
            print_ok("Configurazione TOML valida")
            return True
        else:
            print_warn("Validazione TOML ha riportato errori:")
            if stdout:
                for line in stdout.split('\n'):
                    if line.strip():
                        print(f"      {line}")
            return False
    except Exception as e:
        print_warn(f"Comando verify non supportato: {e}")
        return True  # Don't fail if verify not supported


def test_frp_server_connectivity() -> bool:
    """
    Test connectivity to FRP server configured in TOML.
    
    Returns:
        True if reachable, False otherwise
    """
    print_section("Step 6: Verifica connettività server FRP")
    
    if not TOML_FILE.exists():
        print_warn("File TOML non trovato")
        return False
    
    try:
        content = TOML_FILE.read_text(encoding='utf-8')
        
        # Extract server_addr
        server_match = re.search(r'server_addr\s*=\s*"([^"]+)"', content)
        if not server_match:
            print_warn("server_addr non trovato nel TOML")
            return False
        
        frp_server = server_match.group(1)
        
        # Extract server_port (default 7000)
        frp_port = 7000
        port_match = re.search(r'server_port\s*=\s*(\d+)', content)
        if port_match:
            frp_port = int(port_match.group(1))
        
        print(f"    [*] Test connessione a {frp_server}:{frp_port} ...")
        
        exitcode, stdout, _ = run_command([
            "powershell", "-Command",
            f"Test-NetConnection -ComputerName {frp_server} -Port {frp_port} -WarningAction SilentlyContinue | Select-Object -ExpandProperty TcpTestSucceeded"
        ], check=False)
        
        if exitcode == 0 and "True" in stdout:
            print_ok(f"Server FRP raggiungibile ({frp_server}:{frp_port})")
            return True
        else:
            print_warn("Server FRP non raggiungibile - verifica firewall o connettività")
            return False
    except Exception as e:
        print_warn(f"Impossibile testare connettività: {e}")
        return False


def configure_service_advanced() -> bool:
    """
    Configure advanced service options (delayed auto-start, failure actions).
    
    Returns:
        True if successful, False otherwise
    """
    print_section("Step 7: Configurazione avanzata servizio")
    
    exitcode, _, _ = run_command(["sc", "query", "frpc"], check=False)
    if exitcode != 0:
        print_warn("Servizio FRPC non trovato")
        return False
    
    try:
        # Set delayed auto-start
        print("    [*] Configurazione avvio automatico ritardato...")
        run_command(["sc", "config", "frpc", "start=", "delayed-auto"], check=False)
        print_ok("Avvio automatico ritardato configurato")
        
        # Configure failure actions (auto-restart)
        print("    [*] Configurazione azioni su fallimento...")
        run_command([
            "sc", "failure", "frpc", 
            "reset=", "86400", 
            "actions=", "restart/5000/restart/10000/restart/30000"
        ], check=False)
        print_ok("Restart automatico configurato")
        
        return True
    except Exception as e:
        print_warn(f"Impossibile configurare opzioni avanzate: {e}")
        return False


def start_service(max_retries: int = 3) -> bool:
    """
    Start FRPC service with retries.
    
    Args:
        max_retries: Maximum number of start attempts
        
    Returns:
        True if service started successfully, False otherwise
    """
    print_section("Step 8: Avvio servizio FRPC")
    
    for attempt in range(1, max_retries + 1):
        print(f"    [*] Tentativo {attempt}/{max_retries} ...")
        
        try:
            run_command(["net", "start", "frpc"], check=False)
            time.sleep(10)
            
            exitcode, stdout, _ = run_command(["sc", "query", "frpc"], capture=True)
            
            if exitcode == 0 and "RUNNING" in stdout:
                # Verify process exists
                exitcode_task, task_stdout, _ = run_command([
                    "tasklist", "/FI", "IMAGENAME eq frpc.exe"
                ], capture=True)
                
                if exitcode_task == 0 and "frpc.exe" in task_stdout:
                    pid_match = re.search(r'frpc\.exe\s+(\d+)', task_stdout)
                    pid = pid_match.group(1) if pid_match else "unknown"
                    print_ok(f"Servizio FRPC avviato con successo! (PID: {pid})")
                    return True
                else:
                    print_warn("Servizio running ma processo non trovato")
            else:
                print_warn(f"Servizio non in stato RUNNING")
        except Exception as e:
            print_warn(f"Errore avvio: {e}")
        
        if attempt < max_retries:
            print("    [*] Arresto e retry...")
            run_command(["net", "stop", "frpc"], check=False)
            time.sleep(3)
    
    print_err("Impossibile avviare il servizio automaticamente")
    print_info("Consultare i log per dettagli (vedi sezione 9)")
    return False


def show_diagnostics():
    """Show service diagnostics and recent logs."""
    print_section("Step 9: Diagnostica finale")
    
    # Service status
    exitcode, stdout, _ = run_command(["sc", "query", "frpc"], capture=True)
    if exitcode == 0:
        print("\n    [INFO] Stato servizio:")
        for line in stdout.split('\n'):
            if "STATE" in line or "START_TYPE" in line:
                print(f"      {line.strip()}")
    
    # Process info
    exitcode, stdout, _ = run_command([
        "tasklist", "/FI", "IMAGENAME eq frpc.exe", "/V"
    ], capture=True)
    
    if "frpc.exe" in stdout:
        print("\n    [INFO] Processo FRPC:")
        lines = stdout.split('\n')
        for line in lines:
            if "frpc.exe" in line:
                print(f"      {line.strip()}")
    
    # Show recent logs
    print("\n    [INFO] Ultimi log FRPC:")
    log_file = FRPC_LOG_DIR / "frpc.log"
    
    if log_file.exists():
        print(f"      File: {log_file}")
        try:
            with log_file.open('r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
                recent_lines = lines[-15:] if len(lines) > 15 else lines
                
                for line in recent_lines:
                    line = line.strip()
                    if any(word in line.lower() for word in ['error', 'failed', 'fatal']):
                        print(f"      [ERR] {line}")
                    elif 'warn' in line.lower():
                        print(f"      [WARN] {line}")
                    elif any(word in line.lower() for word in ['success', 'start', 'login']):
                        print(f"      [OK] {line}")
                    else:
                        print(f"      {line}")
        except Exception as e:
            print_warn(f"Impossibile leggere log: {e}")
    else:
        print_warn(f"Log file non trovato: {log_file}")


def show_useful_commands():
    """Show useful diagnostic commands."""
    print("\n" + "="*68)
    print("FIX COMPLETATO")
    print("="*68)
    
    print("\n[INFO] Comandi utili per diagnostica:")
    commands = [
        ("Stato servizio", "Get-Service -Name 'frpc' | Format-List"),
        ("Restart servizio", "Restart-Service -Name 'frpc'"),
        ("Log FRPC", f"Get-Content '{FRPC_LOG_DIR}\\frpc.log' -Tail 50"),
        ("Test manuale FRPC", f"& '{FRPC_PATH}' -c '{TOML_FILE}'"),
        ("Verifica config", f"& '{FRPC_PATH}' verify -c '{TOML_FILE}'"),
    ]
    
    for desc, cmd in commands:
        print(f"  - {desc:20} {cmd}")


def main() -> int:
    """
    Main fix workflow.
    
    Returns:
        Exit code (0=success, 1=failure)
    """
    print("="*68)
    print("FIX CONFIGURAZIONE FRPC")
    print("="*68)
    
    # Check Administrator privileges
    if not is_admin():
        print_err("Questo script deve essere eseguito come Administrator")
        return 1
    
    # Step 1: Stop service and processes
    stop_service_and_processes()
    
    # Step 2: Verify files exist
    if not verify_files():
        print_err("File necessari mancanti. Esegui prima l'installazione completa.")
        return 1
    
    # Step 3: Fix permissions
    fix_permissions()
    
    # Step 4: Fix TOML paths
    fix_toml_paths()
    
    # Step 5: Validate configuration
    validate_toml_config()
    
    # Step 6: Test connectivity
    test_frp_server_connectivity()
    
    # Step 7: Configure advanced service options
    configure_service_advanced()
    
    # Step 8: Start service
    service_started = start_service()
    
    # Step 9: Show diagnostics
    show_diagnostics()
    
    # Show useful commands
    show_useful_commands()
    
    # Final status
    if service_started:
        print("\n[OK] Servizio FRPC operativo!")
        return 0
    else:
        print("\n[WARN] Servizio non in esecuzione - consulta i log per dettagli")
        return 1


if __name__ == "__main__":
    sys.exit(main())
