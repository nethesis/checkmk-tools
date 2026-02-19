#!/usr/bin/env python3
"""
check_ns8_containers.py - CheckMK Local Check per Container NS8

Monitora stato e risorse dei container NethServer 8 via runagent.
Include controllo attività, CPU/RAM usage, e sessioni IMAP per Mail.

Version: 1.1.0
"""

import subprocess
import sys
import re
import time
from typing import Tuple, List, Optional, Dict

VERSION = "1.1.0"
SCRIPT_TIMEOUT_SECONDS = 8
COMMAND_TIMEOUT_SECONDS = 4
_SCRIPT_START = time.monotonic()

# Mapping nomi container friendly
FRIENDLY_NAMES = {
    'ldapproxy': 'LdapProxy',
    'openldap': 'OpenLDAP',
    'webtop': 'WebTop',
    'nextcloud': 'Nextcloud',
    'nethvoice': 'NethVoice',
    'traefik': 'Traefik',
    'mail': 'Mail',
    'samba': 'Samba',
    'mattermost': 'Mattermost',
    'metrics': 'Metrics',
    'loki': 'Loki',
    'nethsecurity': 'NethSecurity',
}


def run_command(cmd: List[str]) -> Tuple[int, str, str]:
    """
    Execute a shell command and return exit code, stdout, stderr.
    
    Args:
        cmd: Command as list of strings
        
    Returns:
        Tuple of (exit_code, stdout, stderr)
    """
    try:
        remaining = SCRIPT_TIMEOUT_SECONDS - (time.monotonic() - _SCRIPT_START)
        if remaining <= 0:
            return 124, "", "Script timeout budget exceeded"

        effective_timeout = min(COMMAND_TIMEOUT_SECONDS, max(1, int(remaining)))
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=effective_timeout
        )
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        return 1, "", "Command timeout"
    except FileNotFoundError:
        return 127, "", "Command not found"
    except Exception as e:
        return 1, "", str(e)


def get_friendly_name(instance: str) -> str:
    """
    Get friendly name for instance with pattern matching.
    
    Args:
        instance: Instance name (e.g., 'mail1', 'webtop2')
        
    Returns:
        Friendly display name
    """
    # Extract base name (remove digits)
    base_name = re.sub(r'\d+$', '', instance)
    
    return FRIENDLY_NAMES.get(base_name, instance)


def get_instances() -> List[str]:
    """
    Get list of NS8 instances via runagent, excluding cluster/node.
    
    Returns:
        List of instance names
    """
    exit_code, stdout, stderr = run_command(['runagent', '-l'])
    
    if exit_code != 0:
        return []
    
    instances = []
    for line in stdout.split('\n'):
        line = line.strip()
        if line and line not in ['cluster', 'node']:
            instances.append(line)
    
    return instances


def check_instance_active(instance: str) -> bool:
    """
    Check if instance is active via runagent true command.
    
    Args:
        instance: Instance name
        
    Returns:
        True if active, False otherwise
    """
    exit_code, stdout, stderr = run_command(['runagent', '-m', instance, 'true'])
    
    return exit_code == 0


def get_instance_stats(instance: str) -> Optional[Dict[str, str]]:
    """
    Get CPU/RAM stats from podman inside instance.
    
    Args:
        instance: Instance name
        
    Returns:
        Dict with 'cpu', 'mem_used', 'mem_pct' or None if error
    """
    exit_code, stdout, stderr = run_command([
        'runagent', '-m', instance, 'podman', 'stats', 
        '--no-stream', '--format', '{{.CPUPerc}} {{.MemUsage}} {{.MemPerc}}'
    ])
    
    if exit_code != 0 or not stdout:
        return None
    
    # Parse first line of stats
    lines = stdout.split('\n')
    if not lines:
        return None
    
    parts = lines[0].split()
    if len(parts) < 3:
        return None
    
    try:
        cpu = parts[0].replace('%', '')
        mem_used = parts[1]
        mem_pct = parts[2].replace('%', '')
        
        return {
            'cpu': cpu,
            'mem_used': mem_used,
            'mem_pct': mem_pct
        }
    except Exception:
        return None


def get_imap_sessions(instance: str) -> int:
    """
    Get count of active IMAP sessions via doveadm who.
    
    Args:
        instance: Instance name (must be Mail)
        
    Returns:
        Count of IMAP sessions, 0 if error
    """
    exit_code, stdout, stderr = run_command([
        'runagent', '-m', instance, 'doveadm', 'who'
    ])
    
    if exit_code != 0 or not stdout:
        return 0
    
    # Count lines excluding header (first line)
    lines = stdout.split('\n')
    if len(lines) <= 1:
        return 0
    
    return len(lines) - 1


def main() -> int:
    """
    Main check logic.
    
    Returns:
        Exit code (always 0 for CheckMK local checks)
    """
    instances = get_instances()
    
    if not instances:
        # No instances found, silent exit
        return 0
    
    for instance in instances:
        if (time.monotonic() - _SCRIPT_START) >= SCRIPT_TIMEOUT_SECONDS:
            print("1 NS8_Containers - WARNING: timeout budget raggiunto durante scansione")
            return 0

        name = get_friendly_name(instance)
        
        # Check instance active
        if not check_instance_active(instance):
            print(f"2 {name} - {name} NON attivo")
            continue
        
        print(f"0 {name} - {name} attivo")
        
        # Get CPU/RAM stats
        stats = get_instance_stats(instance)
        if stats:
            print(f"0 {name}_CPU - CPU {stats['cpu']}%")
            print(f"0 {name}_RAM - RAM {stats['mem_used']} ({stats['mem_pct']}%)")
        
        # IMAP sessions for Mail instances
        if name == 'Mail':
            imap_count = get_imap_sessions(instance)
            
            if imap_count > 0:
                print(f"0 Mail_IMAP - Sessioni IMAP attive: {imap_count}")
            else:
                print(f"1 Mail_IMAP - Nessuna sessione IMAP attiva")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
