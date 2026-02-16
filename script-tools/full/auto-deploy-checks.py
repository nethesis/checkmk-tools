#!/usr/bin/env python3
"""
Auto Deploy CheckMK Checks - Rileva host e installa script corretti
Rileva automaticamente il tipo di sistema e propone l'installazione
degli script CheckMK appropriati dal repository.

Version: 1.1.0
"""

import os
import sys
import subprocess
import urllib.request
import json
import argparse
from pathlib import Path
from typing import Optional, Dict, List, Tuple

VERSION = "1.1.0"
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


def list_available_scripts(category: str) -> List[Tuple[str, str]]:
    """
    Lista script disponibili nella categoria via GitHub API.
    
    Args:
        category: Nome categoria (es: script-check-ns7)
        
    Returns:
        Lista di tuple (filename, url_raw)
    """
    scripts = []
    
    # Prova prima remote/, poi full/
    for subdir in ["remote", "full"]:
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
        selection: Input utente (es: "1,3,5" o "a" o "r")
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
        if part.isdigit():
            idx = int(part)
            if 1 <= idx <= max_idx:
                indices.append(idx)
    
    return indices


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
            print(f"{Colors.GREEN}✓{Colors.NC}")
            installed += 1
        else:
            print(f"{Colors.RED}✗{Colors.NC}")
    
    return installed


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
  
  # Installa tutti gli script
  %(prog)s --install-all --yes
  
  # Installa solo remote launchers
  %(prog)s --install-remote --yes
  
  # Installa script specifici
  %(prog)s --install "1,3,5" --yes
  
  # One-liner via curl
  curl -fsSL URL | sudo python3 - --install-remote --yes
"""
    )
    
    parser.add_argument('--install-all', action='store_true',
                        help='Installa tutti gli script senza menu')
    parser.add_argument('--install-remote', action='store_true',
                        help='Installa solo remote launchers')
    parser.add_argument('--install', type=str, metavar='INDICES',
                        help='Installa script specifici (es: "1,2,3")')
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
    
    # Rileva host
    print(f"{Colors.YELLOW}Rilevamento sistema in corso...{Colors.NC}\n")
    detector = HostDetector()
    
    print(f"{Colors.GREEN}✓ Sistema rilevato:{Colors.NC}")
    print(f"  {Colors.CYAN}Tipo Host:{Colors.NC} {detector.host_type}")
    print(f"  {Colors.CYAN}Categoria Script:{Colors.NC} {detector.script_category}")
    
    if detector.script_category is None:
        print(f"\n{Colors.RED}✗ Impossibile determinare categoria script appropriata{Colors.NC}")
        return 1
    
    # Lista script disponibili
    print(f"\n{Colors.YELLOW}Recupero lista script da GitHub...{Colors.NC}")
    scripts = list_available_scripts(detector.script_category)
    
    if not scripts:
        print(f"{Colors.RED}✗ Nessuno script trovato per categoria: {detector.script_category}{Colors.NC}")
        return 1
    
    print(f"{Colors.GREEN}✓ Trovati {len(scripts)} script disponibili{Colors.NC}")
    
    # Determina selezione (da args o input interattivo)
    selected_indices: List[int] = []
    
    if args.install_all:
        # Installa tutti
        selected_indices = list(range(1, len(scripts) + 1))
        print(f"\n{Colors.CYAN}Modalità: Installa TUTTI gli script{Colors.NC}")
    
    elif args.install_remote:
        # Installa solo remote launchers
        remote_indices = [i for i, (name, url) in enumerate(scripts, 1) if '/remote/' in url]
        selected_indices = remote_indices
        print(f"\n{Colors.CYAN}Modalità: Installa solo remote launchers{Colors.NC}")
    
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
            print(f"{Colors.YELLOW}Suggerimento:{Colors.NC} Usa --install-remote --yes per installazione automatica")
            return 1
        
        if selection == '0':
            print(f"{Colors.YELLOW}Installazione annullata{Colors.NC}")
            return 0
        
        # Gestione selezione "r" (solo remote)
        if selection.lower() == 'r':
            remote_indices = [i for i, (name, url) in enumerate(scripts, 1) if '/remote/' in url]
            selected_indices = remote_indices
        else:
            # Parse normale
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
    
    # Riepilogo
    print(f"\n{Colors.BLUE}{'='*60}{Colors.NC}")
    print(f"{Colors.GREEN}✓ Installazione completata{Colors.NC}")
    print(f"  Script installati: {installed}/{len(selected_indices)}")
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
