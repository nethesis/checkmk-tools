#!/usr/bin/env python3
"""
Auto Deploy CheckMK Checks - Installazione/Rimozione interattiva script CheckMK

Menu interattivo per:
- Installare script CheckMK (remote/full/both)
- Rimuovere script installati
- Rilevamento automatico tipo host
- Forzatura permessi eseguibili garantita

Modalità CLI disponibile per automazione via curl.

Version: 1.5.0
"""

import os
import sys
import subprocess
import urllib.request
import json
import argparse
from pathlib import Path
from typing import Optional, Dict, List, Tuple

VERSION = "1.5.0"
REPO_URL = "https://raw.githubusercontent.com/Coverup20/checkmk-tools/main"
GITHUB_API = "https://api.github.com/repos/Coverup20/checkmk-tools/contents"
CHECKMK_LOCAL_PATH = Path("/usr/lib/check_mk_agent/local")

# Colori ANSI
class Colors:
    GREEN = '\033[0;32m'
    BLUE = '\033[0;34m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    CYAN = '\033[0;36m'
    MAGENTA = '\033[0;35m'
    NC = '\033[0m'


class HostDetector:
    """Rileva tipo di host e sistema operativo."""
    
    def __init__(self):
        self.os_info = self._read_os_release()
        self.host_type: Optional[str] = None
        self.script_category: Optional[str] = None
        self.detect_host_type()
    
    def _read_os_release(self) -> Dict[str, str]:
        """Leggi /etc/os-release per info OS."""
        os_info = {}
        
        if Path("/etc/os-release").exists():
            try:
                with open("/etc/os-release", 'r') as f:
                    for line in f:
                        if '=' in line:
                            key, value = line.strip().split('=', 1)
                            os_info[key] = value.strip('"')
            except IOError:
                pass
        
        return os_info
    
    def _run_command(self, cmd: List[str]) -> Tuple[int, str, str]:
        """Esegue comando e ritorna (exit_code, stdout, stderr)."""
        try:
            result = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=10
            )
            return result.returncode, result.stdout, result.stderr
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return 1, "", ""
    
    def detect_host_type(self) -> None:
        """Rileva tipo di host in base a caratteristiche del sistema."""
        
        # NethServer 7 (CentOS 7 based)
        if Path("/etc/nethserver-release").exists():
            self.host_type = "NethServer 7"
            self.script_category = "script-check-ns7"
            return
        
        # NethServer 8 (Debian based con podman)
        if Path("/usr/bin/runagent").exists() or Path("/usr/bin/api-cli").exists():
            exit_code, stdout, _ = self._run_command(["api-cli", "run", "list-modules", "--output", "json"])
            if exit_code == 0:
                self.host_type = "NethServer 8"
                self.script_category = "script-check-ns8"
                return
        
        # NethSecurity 8 (OpenWrt based)
        if Path("/etc/openwrt_release").exists():
            with open("/etc/openwrt_release", 'r') as f:
                content = f.read()
                if "NethSecurity" in content or "nethsecurity" in content.lower():
                    self.host_type = "NethSecurity 8"
                    self.script_category = "script-check-nsec8"
                    return
        
        # CheckMK Server (OMD)
        if Path("/omd").exists() or Path("/opt/omd").exists():
            # Verifica presenza siti OMD
            exit_code, stdout, _ = self._run_command(["omd", "sites"])
            if exit_code == 0:
                self.host_type = "CheckMK Server (OMD)"
                self.script_category = "script-check-ubuntu"  # Usa check generici Linux
                return
        
        # Proxmox VE
        if Path("/etc/pve").exists() and Path("/usr/bin/pvesh").exists():
            self.host_type = "Proxmox VE"
            self.script_category = "script-check-proxmox"
            return
        
        # Ubuntu/Debian generic
        if self.os_info.get("ID") in ["ubuntu", "debian"]:
            os_name = self.os_info.get("NAME", "")
            os_version = self.os_info.get("VERSION_ID", "")
            self.host_type = f"{os_name} {os_version}"
            self.script_category = "script-check-ubuntu"
            return
        
        # CentOS/RHEL/Rocky generic
        if self.os_info.get("ID") in ["centos", "rhel", "rocky", "almalinux"]:
            os_name = self.os_info.get("NAME", "")
            os_version = self.os_info.get("VERSION_ID", "")
            self.host_type = f"{os_name} {os_version}"
            self.script_category = "script-check-ubuntu"  # Usa Ubuntu come fallback
            return
        
        # Fallback generico
        os_name = self.os_info.get("NAME", "Unknown")
        self.host_type = f"{os_name} (generico)"
        self.script_category = "script-check-ubuntu"


def print_header() -> None:
    """Stampa header dello script."""
    print(f"{Colors.BLUE}╔═══════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.BLUE}║{Colors.NC}  🚀 {Colors.GREEN}Auto Deploy CheckMK Checks v{VERSION}{Colors.NC}               {Colors.BLUE}║{Colors.NC}")
    print(f"{Colors.BLUE}╠═══════════════════════════════════════════════════════════╣{Colors.NC}")
    print(f"{Colors.BLUE}║{Colors.NC}  Installazione automatica script CheckMK             {Colors.BLUE}║{Colors.NC}")
    print(f"{Colors.BLUE}╚═══════════════════════════════════════════════════════════╝{Colors.NC}")
    print()


def list_available_scripts(category: str, script_type: str = 'both') -> List[Tuple[str, str]]:
    """
    Lista script disponibili nella categoria via GitHub API.
    
    Args:
        category: Nome categoria (es: script-check-ns7)
        script_type: 'remote', 'full', o 'both'
        
    Returns:
        Lista di tuple (filename, url_raw)
    """
    scripts = []
    
    # Determina quali subdirectory scansionare
    subdirs = []
    if script_type in ['remote', 'both']:
        subdirs.append('remote')
    if script_type in ['full', 'both']:
        subdirs.append('full')
    
    for subdir in subdirs:
        api_url = f"{GITHUB_API}/{category}/{subdir}"
        
        try:
            with urllib.request.urlopen(api_url, timeout=10) as response:
                data = json.loads(response.read().decode('utf-8'))
            
            for item in data:
                if item['type'] == 'file':
                    filename = item['name']
                    # Filtra solo script Python o Bash
                    if filename.endswith(('.py', '.sh')):
                        download_url = item['download_url']
                        scripts.append((filename, download_url))
        
        except (urllib.error.URLError, json.JSONDecodeError, KeyError):
            continue
    
    return scripts


def list_installed_scripts() -> List[str]:
    """
    Lista script già installati in /usr/lib/check_mk_agent/local/.
    
    Returns:
        Lista nomi file installati
    """
    installed = []
    
    if CHECKMK_LOCAL_PATH.exists():
        for item in CHECKMK_LOCAL_PATH.iterdir():
            if item.is_file() and os.access(item, os.X_OK):
                installed.append(item.name)
    
    return sorted(installed)


def download_script(url: str, dest_path: Path) -> bool:
    """
    Scarica script da URL remoto.
    
    Args:
        url: URL raw GitHub
        dest_path: Path destinazione locale
        
    Returns:
        True se successo, False altrimenti
    """
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            content = response.read()
        
        with open(dest_path, 'wb') as f:
            f.write(content)
        
        # Rendi eseguibile
        os.chmod(dest_path, 0o755)
        
        return True
    
    except (urllib.error.URLError, IOError) as e:
        print(f"{Colors.RED}✗ Errore download: {e}{Colors.NC}")
        return False


def show_scripts_menu(scripts: List[Tuple[str, str]], category: str) -> None:
    """
    Mostra menu script disponibili con selezione multipla.
    
    Args:
        scripts: Lista (filename, url)
        category: Categoria script
    """
    print(f"\n{Colors.CYAN}Script disponibili in {category}:{Colors.NC}\n")
    
    # Separa per tipo (remote vs full)
    remote_scripts = [(i, name, url) for i, (name, url) in enumerate(scripts, 1) if '/remote/' in url]
    full_scripts = [(i, name, url) for i, (name, url) in enumerate(scripts, 1) if '/full/' in url]
    
    if remote_scripts:
        print(f"{Colors.YELLOW}▶ Remote Launchers (scaricano da GitHub):{Colors.NC}")
        for idx, name, _ in remote_scripts:
            print(f"  {Colors.BLUE}{idx:2d}){Colors.NC} {name}")
    
    if full_scripts:
        print(f"\n{Colors.YELLOW}▶ Full Scripts (standalone completi):{Colors.NC}")
        for idx, name, _ in full_scripts:
            print(f"  {Colors.BLUE}{idx:2d}){Colors.NC} {name}")
    
    print(f"\n{Colors.MAGENTA}Opzioni:{Colors.NC}")
    print(f"  {Colors.GREEN}a{Colors.NC}) Installa TUTTI gli script")
    print(f"  {Colors.GREEN}r{Colors.NC}) Installa solo remote launchers")
    print(f"  {Colors.GREEN}1,2,3{Colors.NC}) Installa script specifici (separati da virgola)")
    print(f"  {Colors.GREEN}0{Colors.NC}) Annulla")


def parse_selection(selection: str, max_idx: int) -> List[int]:
    """
    Parsea input utente per selezione multipla.
    
    Args:
        selection: Input utente (es: "1,3,5" o "1-5" o "a" o "r")
        max_idx: Numero massimo script
        
    Returns:
        Lista indici selezionati
    """
    if selection.lower() == 'a':
        return list(range(1, max_idx + 1))
    
    if selection.lower() == 'r':
        return []  # Gestito separatamente
    
    indices = []
    for part in selection.split(','):
        part = part.strip()
        
        # Gestione range: "1-5" → [1,2,3,4,5]
        if '-' in part:
            try:
                start, end = part.split('-', 1)
                start = int(start.strip())
                end = int(end.strip())
                
                # Valida range
                if 1 <= start <= max_idx and 1 <= end <= max_idx and start <= end:
                    indices.extend(range(start, end + 1))
            except (ValueError, AttributeError):
                # Ignora range malformati
                pass
        
        # Gestione singoli numeri: "3" → [3]
        elif part.isdigit():
            idx = int(part)
            if 1 <= idx <= max_idx:
                indices.append(idx)
    
    return sorted(set(indices))  # Rimuovi duplicati e ordina


def install_scripts(scripts: List[Tuple[str, str]], selected_indices: List[int]) -> int:
    """
    Installa script selezionati.
    
    Args:
        scripts: Lista completa (filename, url)
        selected_indices: Indici da installare
        
    Returns:
        Numero script installati con successo
    """
    if not CHECKMK_LOCAL_PATH.exists():
        print(f"{Colors.RED}✗ Path CheckMK non trovato: {CHECKMK_LOCAL_PATH}{Colors.NC}")
        print(f"{Colors.YELLOW}  Installare prima CheckMK Agent{Colors.NC}")
        return 0
    
    installed = 0
    
    for idx in selected_indices:
        if idx < 1 or idx > len(scripts):
            continue
        
        filename, url = scripts[idx - 1]
        
        # Rimuovi estensione per deployment (CheckMK convention)
        deploy_name = filename.rsplit('.', 1)[0] if '.' in filename else filename
        dest_path = CHECKMK_LOCAL_PATH / deploy_name
        
        print(f"{Colors.CYAN}Installazione:{Colors.NC} {filename} → {dest_path}... ", end='', flush=True)
        
        if download_script(url, dest_path):
            # Forza permessi eseguibili (doppia sicurezza)
            try:
                os.chmod(dest_path, 0o755)
            except OSError:
                pass  # Ignora errori chmod, già gestito in download_script
            
            print(f"{Colors.GREEN}✓{Colors.NC}")
            installed += 1
        else:
            print(f"{Colors.RED}✗{Colors.NC}")
    
    return installed


def uninstall_scripts(script_names: List[str]) -> int:
    """
    Rimuove script installati.
    
    Args:
        script_names: Lista nomi file da rimuovere
        
    Returns:
        Numero script rimossi con successo
    """
    if not CHECKMK_LOCAL_PATH.exists():
        print(f"{Colors.RED}✗ Path CheckMK non trovato: {CHECKMK_LOCAL_PATH}{Colors.NC}")
        return 0
    
    removed = 0
    
    for script_name in script_names:
        script_path = CHECKMK_LOCAL_PATH / script_name
        
        if not script_path.exists():
            print(f"{Colors.YELLOW}⚠ Non trovato:{Colors.NC} {script_name}")
            continue
        
        print(f"{Colors.CYAN}Rimozione:{Colors.NC} {script_name}... ", end='', flush=True)
        
        try:
            script_path.unlink()
            print(f"{Colors.GREEN}✓{Colors.NC}")
            removed += 1
        except OSError as e:
            print(f"{Colors.RED}✗ {e}{Colors.NC}")
    
    return removed


def show_main_menu() -> str:
    """
    Mostra menu principale e restituisce azione scelta.
    
    Returns:
        'install_agent', 'install', 'uninstall', o 'exit'
    """
    print(f"\n{Colors.CYAN}╔═══════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.CYAN}║  Cosa vuoi fare?                      ║{Colors.NC}")
    print(f"{Colors.CYAN}╚═══════════════════════════════════════╝{Colors.NC}\n")
    print(f"  {Colors.MAGENTA}1.{Colors.NC} Installa CheckMK Agent (prerequisito)")
    print(f"  {Colors.GREEN}2.{Colors.NC} Installa script CheckMK")
    print(f"  {Colors.RED}3.{Colors.NC} Rimuovi script installati")
    print(f"  {Colors.YELLOW}0.{Colors.NC} Esci\n")
    
    try:
        print(f"{Colors.YELLOW}Scelta:{Colors.NC} ", end='', flush=True)
        choice = input().strip()
    except EOFError:
        return 'exit'
    
    if choice == '1':
        return 'install_agent'
    elif choice == '2':
        return 'install'
    elif choice == '3':
        return 'uninstall'
    elif choice == '0':
        return 'exit'
    else:
        print(f"{Colors.YELLOW}Scelta non valida{Colors.NC}")
        return 'exit'


def check_agent_installed() -> Tuple[bool, str]:
    """
    Controlla se CheckMK Agent è installato.
    
    Returns:
        (is_installed, version_info)
    """
    try:
        result = subprocess.run(
            ['check_mk_agent'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=5
        )
        
        if result.returncode == 0:
            # Estrai versione da output
            for line in result.stdout.split('\n'):
                if 'Version:' in line:
                    version = line.split('Version:')[1].strip()
                    return True, version
            return True, "(versione sconosciuta)"
        else:
            return False, ""
    
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False, ""


def check_frpc_installed() -> Tuple[bool, str]:
    """
    Controlla se FRPC è installato e attivo.
    
    Returns:
        (is_installed, status_info)
    """
    # Controlla se binario esiste
    if not Path("/usr/local/bin/frpc").exists():
        return False, "non installato"
    
    try:
        # Controlla servizio systemd
        result = subprocess.run(
            ['systemctl', 'is-active', 'frpc'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=5
        )
        
        status = result.stdout.strip()
        if status == "active":
            return True, "attivo"
        elif status == "inactive":
            return True, "installato (non attivo)"
        else:
            return True, f"installato ({status})"
    
    except (FileNotFoundError, subprocess.TimeoutExpired):
        # Se systemctl non funziona, controlla solo file
        return True, "installato (stato sconosciuto)"


def show_current_status() -> Tuple[bool, bool]:
    """
    Mostra stato attuale CheckMK Agent e FRPC.
    
    Returns:
        (agent_installed, frpc_installed)
    """
    print(f"\n{Colors.CYAN}╔═══════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.CYAN}║  📊 Stato Attuale Sistema                                ║{Colors.NC}")
    print(f"{Colors.CYAN}╚═══════════════════════════════════════════════════════════╝{Colors.NC}\n")
    
    # CheckMK Agent
    agent_installed, agent_info = check_agent_installed()
    if agent_installed:
        print(f"  {Colors.GREEN}✓ CheckMK Agent:{Colors.NC} Installato - {agent_info}")
    else:
        print(f"  {Colors.RED}✗ CheckMK Agent:{Colors.NC} Non installato")
    
    # FRPC
    frpc_installed, frpc_info = check_frpc_installed()
    if frpc_installed:
        print(f"  {Colors.GREEN}✓ FRPC Client:{Colors.NC} {frpc_info}")
    else:
        print(f"  {Colors.RED}✗ FRPC Client:{Colors.NC} {frpc_info}")
    
    print()
    return agent_installed, frpc_installed


def install_checkmk_agent() -> int:
    """
    Installa CheckMK Agent + FRPC eseguendo install-agent-interactive.sh da GitHub.
    Controlla prima lo stato attuale e offre opzioni appropriate.
    
    Returns:
        0 se successo, 1 se errore
    """
    print(f"\n{Colors.MAGENTA}╔═══════════════════════════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.MAGENTA}║  🔧 Installazione CheckMK Agent + FRPC                   ║{Colors.NC}")
    print(f"{Colors.MAGENTA}╚═══════════════════════════════════════════════════════════╝{Colors.NC}")
    
    # Mostra stato attuale
    agent_installed, frpc_installed = show_current_status()
    
    # Se entrambi già installati, chiedi conferma reinstallazione
    if agent_installed and frpc_installed:
        print(f"{Colors.YELLOW}⚠ CheckMK Agent e FRPC sono già installati.{Colors.NC}")
        print(f"\nOpzioni:")
        print(f"  {Colors.GREEN}1.{Colors.NC} Reinstalla (sovrascrive configurazione)")
        print(f"  {Colors.YELLOW}2.{Colors.NC} Salta (mantieni installazione attuale)")
        print(f"  {Colors.RED}0.{Colors.NC} Annulla\n")
        
        try:
            print(f"{Colors.YELLOW}Scelta:{Colors.NC} ", end='', flush=True)
            choice = input().strip()
        except EOFError:
            print(f"{Colors.YELLOW}Annullato{Colors.NC}")
            return 0
        
        if choice == '2':
            print(f"{Colors.GREEN}✓ Mantengo installazione attuale{Colors.NC}\n")
            return 0
        elif choice != '1':
            print(f"{Colors.YELLOW}Annullato{Colors.NC}\n")
            return 0
    
    elif agent_installed:
        print(f"{Colors.YELLOW}ℹ CheckMK Agent già installato. Lo script installerà/configurerà FRPC.{Colors.NC}\n")
    
    elif frpc_installed:
        print(f"{Colors.YELLOW}ℹ FRPC già installato. Lo script installerà CheckMK Agent.{Colors.NC}\n")
    
    else:
        print(f"{Colors.GREEN}✓ Sistema pulito. Procedo con installazione completa.{Colors.NC}\n")
    
    installer_url = f"{REPO_URL}/script-tools/full/install-agent-interactive.sh"
    
    print(f"{Colors.CYAN}Scarico script installazione da:{Colors.NC}")
    print(f"  {installer_url}\n")
    
    try:
        # Scarica script in /tmp
        tmp_script = "/tmp/install-agent-interactive.sh"
        
        print(f"{Colors.YELLOW}Download in corso...{Colors.NC}")
        request = urllib.request.Request(
            installer_url,
            headers={'Cache-Control': 'no-cache'}
        )
        
        with urllib.request.urlopen(request, timeout=30) as response:
            script_content = response.read().decode('utf-8')
        
        with open(tmp_script, 'w') as f:
            f.write(script_content)
        
        os.chmod(tmp_script, 0o755)
        
        print(f"{Colors.GREEN}✓ Download completato{Colors.NC}\n")
        print(f"{Colors.YELLOW}═══════════════════════════════════════════════════════════{Colors.NC}")
        print(f"{Colors.CYAN}Esecuzione install-agent-interactive.sh...{Colors.NC}")
        print(f"{Colors.YELLOW}Lo script chiederà:{Colors.NC}")
        print(f"  - Conferma installazione CheckMK Agent")
        print(f"  - Se installare FRPC (tunnel per monitoraggio remoto)")
        print(f"  - Configurazione FRPC (server, porta, token)")
        print(f"{Colors.YELLOW}═══════════════════════════════════════════════════════════{Colors.NC}\n")
        
        # Esegui script con bash in modalità interattiva
        result = subprocess.run(
            ['bash', tmp_script],
            stdin=sys.stdin,
            stdout=sys.stdout,
            stderr=sys.stderr
        )
        
        print(f"\n{Colors.YELLOW}═══════════════════════════════════════════════════════════{Colors.NC}\n")
        
        # Cleanup
        try:
            os.remove(tmp_script)
        except OSError:
            pass
        
        if result.returncode == 0:
            print(f"{Colors.GREEN}✓ Installazione completata con successo{Colors.NC}")
            
            # Mostra nuovo stato
            show_current_status()
            return 0
        else:
            print(f"{Colors.RED}✗ Installazione fallita (exit code: {result.returncode}){Colors.NC}\n")
            return 1
    
    except urllib.error.URLError as e:
        print(f"{Colors.RED}✗ Errore download script: {e}{Colors.NC}\n")
        return 1
    except Exception as e:
        print(f"{Colors.RED}✗ Errore durante installazione: {e}{Colors.NC}\n")
        return 1


def ask_script_type() -> str:
    """
    Chiede all'utente quale tipo di script installare.
    
    Returns:
        'remote', 'full', o 'both'
    """
    print(f"\n{Colors.CYAN}╔═══════════════════════════════════════╗{Colors.NC}")
    print(f"{Colors.CYAN}║  Quale tipo di script?                ║{Colors.NC}")
    print(f"{Colors.CYAN}╚═══════════════════════════════════════╝{Colors.NC}\n")
    print(f"  {Colors.GREEN}1.{Colors.NC} Remote launchers (eseguono script da GitHub)")
    print(f"  {Colors.GREEN}2.{Colors.NC} Full scripts (script completi locali)")
    print(f"  {Colors.GREEN}3.{Colors.NC} Entrambi (remote + full)")
    print(f"  {Colors.YELLOW}0.{Colors.NC} Annulla\n")
    
    try:
        print(f"{Colors.YELLOW}Scelta:{Colors.NC} ", end='', flush=True)
        choice = input().strip()
    except EOFError:
        return 'remote'  # Default per pipe execution
    
    if choice == '1':
        return 'remote'
    elif choice == '2':
        return 'full'
    elif choice == '3':
        return 'both'
    elif choice == '0':
        return 'cancel'
    else:
        print(f"{Colors.YELLOW}Scelta non valida, uso remote{Colors.NC}")
        return 'remote'


def main() -> int:
    """Main entry point."""
    
    # Parse argomenti CLI
    parser = argparse.ArgumentParser(
        description='Auto Deploy CheckMK Checks - Rileva host e installa script corretti',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Esempi:
  # Modalità interattiva (menu)
  %(prog)s
  
  # Installa tutti remote launchers
  %(prog)s --type remote --install-all --yes
  
  # Installa tutti full scripts
  %(prog)s --type full --install-all --yes
  
  # Installa script specifici
  %(prog)s --install "1,3,5" --yes
  
  # Rimuovi script installati (interattivo)
  %(prog)s --uninstall
  
  # One-liner via curl
  curl -fsSL URL | sudo python3 - --type remote --install-all --yes
"""
    )
    
    parser.add_argument('--install-all', action='store_true',
                        help='Installa tutti gli script senza menu')
    parser.add_argument('--install-remote', action='store_true',
                        help='[DEPRECATO] Usa --type remote --install-all')
    parser.add_argument('--install', type=str, metavar='INDICES',
                        help='Installa script specifici (es: "1,2,3")')
    parser.add_argument('--type', type=str, choices=['remote', 'full', 'both'],
                        help='Tipo script da installare (remote/full/both)')
    parser.add_argument('--uninstall', action='store_true',
                        help='Rimuovi script installati')
    parser.add_argument('--yes', '-y', action='store_true',
                        help='Conferma automaticamente senza chiedere')
    parser.add_argument('--version', action='version',
                        version=f'%(prog)s {VERSION}')
    
    args = parser.parse_args()
    
    print_header()
    
    # Verifica root
    if os.geteuid() != 0:
        print(f"{Colors.RED}✗ Questo script richiede privilegi root{Colors.NC}")
        print(f"{Colors.YELLOW}  Esegui con: sudo {sys.argv[0]}{Colors.NC}\n")
        return 1
    
    # ===== MENU INTERATTIVO (se nessun argomento CLI specificato) =====
    if not any([args.uninstall, args.install_all, args.install, args.type, args.install_remote]):
        # Modalità interattiva con menu principale
        action = show_main_menu()
        
        if action == 'exit':
            print(f"{Colors.YELLOW}Uscita{Colors.NC}")
            return 0
        
        elif action == 'install_agent':
            # Installa CheckMK Agent
            return install_checkmk_agent()
        
        elif action == 'uninstall':
            # Forza modalità uninstall
            args.uninstall = True
        
        elif action == 'install':
            # Modalità interattiva installazione
            # Il tipo verrà chiesto più avanti nel flusso
            pass
    
    # ===== MODALITÀ RIMOZIONE =====
    if args.uninstall:
        print(f"\n{Colors.YELLOW}Modalità: Rimozione script installati{Colors.NC}\n")
        
        installed = list_installed_scripts()
        
        if not installed:
            print(f"{Colors.YELLOW}Nessuno script installato in {CHECKMK_LOCAL_PATH}{Colors.NC}")
            return 0
        
        print(f"{Colors.GREEN}Script installati ({len(installed)}):{Colors.NC}\n")
        for i, name in enumerate(installed, 1):
            print(f"  {Colors.GREEN}{i:2d}.{Colors.NC} {name}")
        
        print(f"\n{Colors.YELLOW}Seleziona script da rimuovere{Colors.NC}")
        print(f"  {Colors.CYAN}Esempio:{Colors.NC} 1,3,5 oppure 1-3 oppure all")
        print(f"  {Colors.YELLOW}0.{Colors.NC} Annulla\n")
        
        try:
            print(f"{Colors.YELLOW}Selezione:{Colors.NC} ", end='', flush=True)
            selection = input().strip().lower()
        except EOFError:
            print(f"\n{Colors.RED}✗ Input non disponibile{Colors.NC}")
            return 1
        
        if selection == '0':
            print(f"{Colors.YELLOW}Rimozione annullata{Colors.NC}")
            return 0
        
        # Parse selezione
        if selection == 'all':
            to_remove = installed
        else:
            indices = parse_selection(selection, len(installed))
            to_remove = [installed[i - 1] for i in indices]
        
        if not to_remove:
            print(f"{Colors.RED}✗ Nessuno script selezionato{Colors.NC}")
            return 1
        
        # Conferma rimozione
        print(f"\n{Colors.RED}⚠ Verranno rimossi {len(to_remove)} script{Colors.NC}")
        for name in to_remove:
            print(f"  - {name}")
        
        if not args.yes:
            try:
                print(f"\n{Colors.YELLOW}Confermi rimozione? (s/n):{Colors.NC} ", end='', flush=True)
                confirm = input().strip().lower()
            except EOFError:
                confirm = 'n'
            
            if confirm not in ['s', 'si', 'y', 'yes']:
                print(f"{Colors.YELLOW}Rimozione annullata{Colors.NC}")
                return 0
        
        # Esegui rimozione
        print(f"\n{Colors.RED}▶ Rimozione in corso...{Colors.NC}\n")
        removed = uninstall_scripts(to_remove)
        
        print(f"\n{Colors.BLUE}{'='*60}{Colors.NC}")
        print(f"{Colors.GREEN}✓ Rimozione completata{Colors.NC}")
        print(f"  Script rimossi: {removed}/{len(to_remove)}")
        print(f"{Colors.BLUE}{'='*60}{Colors.NC}\n")
        
        return 0
    
    # ===== MODALITÀ INSTALLAZIONE =====
    
    # Rileva host
    print(f"{Colors.YELLOW}Rilevamento sistema in corso...{Colors.NC}\n")
    detector = HostDetector()
    
    print(f"{Colors.GREEN}✓ Sistema rilevato:{Colors.NC}")
    print(f"  {Colors.CYAN}Tipo Host:{Colors.NC} {detector.host_type}")
    print(f"  {Colors.CYAN}Categoria Script:{Colors.NC} {detector.script_category}")
    
    if detector.script_category is None:
        print(f"\n{Colors.RED}✗ Impossibile determinare categoria script appropriata{Colors.NC}")
        return 1
    
    # Determina tipo script (da args o chiedi)
    script_type = args.type
    
    # Backward compatibility con --install-remote
    if args.install_remote:
        script_type = 'remote'
        print(f"\n{Colors.YELLOW}[DEPRECATO] Usa --type remote al posto di --install-remote{Colors.NC}")
    
    # Chiedi tipo se non specificato e modalità interattiva
    if not script_type and not (args.install_all or args.install):
        script_type = ask_script_type()
        
        if script_type == 'cancel':
            print(f"{Colors.YELLOW}Installazione annullata{Colors.NC}")
            return 0
    
    # Default a 'both' se ancora non specificato
    if not script_type:
        script_type = 'both'
    
    # Lista script disponibili
    print(f"\n{Colors.YELLOW}Recupero lista script da GitHub...{Colors.NC}")
    scripts = list_available_scripts(detector.script_category, script_type)
    
    if not scripts:
        print(f"{Colors.RED}✗ Nessuno script trovato per categoria: {detector.script_category} (tipo: {script_type}){Colors.NC}")
        return 1
    
    type_label = {
        'remote': 'remote launchers',
        'full': 'full scripts',
        'both': 'script (remote + full)'
    }.get(script_type, script_type)
    
    print(f"{Colors.GREEN}✓ Trovati {len(scripts)} {type_label}{Colors.NC}")
    
    # Determina selezione (da args o input interattivo)
    selected_indices: List[int] = []
    
    if args.install_all:
        # Installa tutti
        selected_indices = list(range(1, len(scripts) + 1))
        print(f"\n{Colors.CYAN}Modalità: Installa TUTTI gli script ({type_label}){Colors.NC}")
    
    elif args.install:
        # Installa script specifici
        selected_indices = parse_selection(args.install, len(scripts))
        print(f"\n{Colors.CYAN}Modalità: Installa script specifici{Colors.NC}")
    
    else:
        # Modalità interattiva
        show_scripts_menu(scripts, detector.script_category)
        
        try:
            print(f"\n{Colors.YELLOW}Selezione:{Colors.NC} ", end='', flush=True)
            selection = input().strip()
        except EOFError:
            print(f"\n{Colors.RED}✗ Input non disponibile (esegui interattivamente o usa --install-*)${Colors.NC}")
            print(f"{Colors.YELLOW}Suggerimento:{Colors.NC} Usa --type remote --install-all --yes per installazione automatica")
            return 1
        
        if selection == '0':
            print(f"{Colors.YELLOW}Installazione annullata{Colors.NC}")
            return 0
        
        # Parse selezione
        selected_indices = parse_selection(selection, len(scripts))
    
    if not selected_indices:
        print(f"{Colors.RED}✗ Nessuno script selezionato{Colors.NC}")
        return 1
    
    # Conferma installazione
    print(f"\n{Colors.YELLOW}Verranno installati {len(selected_indices)} script in:{Colors.NC}")
    print(f"  {CHECKMK_LOCAL_PATH}\n")
    
    if not args.yes:
        try:
            print(f"{Colors.YELLOW}Confermi? (s/n):{Colors.NC} ", end='', flush=True)
            confirm = input().strip().lower()
        except EOFError:
            print(f"\n{Colors.YELLOW}Conferma automatica (usa --yes per evitare prompt){Colors.NC}")
            confirm = 's'
        
        if confirm not in ['s', 'si', 'y', 'yes']:
            print(f"{Colors.YELLOW}Installazione annullata{Colors.NC}")
            return 0
    else:
        print(f"{Colors.GREEN}Conferma automatica (--yes){Colors.NC}")
    
    # Installazione
    print(f"\n{Colors.GREEN}▶ Installazione in corso...{Colors.NC}\n")
    installed = install_scripts(scripts, selected_indices)
    
    # Verifica permessi eseguibili post-installazione
    executable_count = 0
    if CHECKMK_LOCAL_PATH.exists():
        for item in CHECKMK_LOCAL_PATH.iterdir():
            if item.is_file() and os.access(item, os.X_OK):
                executable_count += 1
    
    # Riepilogo
    print(f"\n{Colors.BLUE}{'='*60}{Colors.NC}")
    print(f"{Colors.GREEN}✓ Installazione completata{Colors.NC}")
    print(f"  Script installati: {installed}/{len(selected_indices)}")
    print(f"  Script eseguibili: {executable_count}")
    print(f"  Path: {CHECKMK_LOCAL_PATH}")
    print(f"{Colors.BLUE}{'='*60}{Colors.NC}\n")
    
    # Suggerimenti post-installazione
    print(f"{Colors.CYAN}Prossimi step:{Colors.NC}")
    print(f"  1. Verifica output agent: {Colors.YELLOW}check_mk_agent{Colors.NC}")
    print(f"  2. Forza discovery su CheckMK server")
    print(f"  3. Check visibili in CheckMK UI\n")
    
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Interrotto dall'utente{Colors.NC}")
        sys.exit(130)
    except Exception as e:
        print(f"{Colors.RED}✗ Errore inatteso: {e}{Colors.NC}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
