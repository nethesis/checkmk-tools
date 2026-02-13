#!/usr/bin/env python3
"""
check_ns8_tomcat8.py - CheckMK Local Check per Tomcat8 NS8

Monitora Tomcat8 in container NS8: memoria RSS e uptime processo.
Soglie configurabili per WARNING/CRITICAL su consumo memoria.

Version: 1.0.0
"""

import subprocess
import sys
import re
from typing import Tuple, List, Optional

VERSION = "1.0.0"
SERVICE = "Tomcat8"

# Soglie memoria in MB
THRESHOLD_WARNING = 1024
THRESHOLD_CRITICAL = 1536


def run_command(cmd: List[str]) -> Tuple[int, str, str]:
    """
    Execute a shell command and return exit code, stdout, stderr.
    
    Args:
        cmd: Command as list of strings
        
    Returns:
        Tuple of (exit_code, stdout, stderr)
    """
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=30
        )
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        return 1, "", "Command timeout"
    except FileNotFoundError:
        return 127, "", "Command not found"
    except Exception as e:
        return 1, "", str(e)


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


def get_containers(instance: str) -> List[str]:
    """
    Get list of containers inside an instance.
    
    Args:
        instance: Instance name
        
    Returns:
        List of container names
    """
    exit_code, stdout, stderr = run_command([
        'runagent', '-m', instance, 'podman', 'ps', '--format', '{{.Names}}'
    ])
    
    if exit_code != 0 or not stdout:
        return []
    
    return [line.strip() for line in stdout.split('\n') if line.strip()]


def get_tomcat_pid(instance: str, container: str) -> Optional[str]:
    """
    Get Tomcat8 process PID via pgrep inside container.
    
    Args:
        instance: Instance name
        container: Container name
        
    Returns:
        PID as string or None if not found
    """
    exit_code, stdout, stderr = run_command([
        'runagent', '-m', instance, 'podman', 'exec', container,
        'pgrep', '-f', 'org.apache.catalina.startup.Bootstrap'
    ])
    
    if exit_code != 0 or not stdout:
        return None
    
    # Get first line (first PID)
    lines = stdout.split('\n')
    return lines[0].strip() if lines else None


def get_process_stats(instance: str, container: str, pid: str) -> Optional[Tuple[int, str]]:
    """
    Get process memory (RSS in MB) and uptime.
    
    Args:
        instance: Instance name
        container: Container name
        pid: Process PID
        
    Returns:
        Tuple of (memory_mb, uptime) or None if error
    """
    # Get RSS in KB
    exit_code, stdout, stderr = run_command([
        'runagent', '-m', instance, 'podman', 'exec', container,
        'ps', '-o', f'rss=', '-p', pid
    ])
    
    if exit_code != 0 or not stdout:
        return None
    
    try:
        rss_kb = int(stdout.strip())
        memory_mb = round(rss_kb / 1024)
    except ValueError:
        return None
    
    # Get uptime (etime)
    exit_code, stdout, stderr = run_command([
        'runagent', '-m', instance, 'podman', 'exec', container,
        'ps', '-o', 'etime=', '-p', pid
    ])
    
    if exit_code != 0 or not stdout:
        return None
    
    uptime = stdout.strip()
    
    return memory_mb, uptime


def main() -> int:
    """
    Main check logic.
    
    Returns:
        Exit code (always 0 for CheckMK local checks)
    """
    instances = get_instances()
    found = False
    
    for instance in instances:
        containers = get_containers(instance)
        
        for container in containers:
            pid = get_tomcat_pid(instance, container)
            
            if not pid:
                continue
            
            found = True
            stats = get_process_stats(instance, container, pid)
            
            if not stats:
                continue
            
            memory_mb, uptime = stats
            
            # Evaluate thresholds
            if memory_mb >= THRESHOLD_CRITICAL:
                state = 2
                msg = f"Tomcat8 CRIT - Memoria={memory_mb}MB (>{THRESHOLD_CRITICAL}MB); Uptime={uptime}"
            elif memory_mb >= THRESHOLD_WARNING:
                state = 1
                msg = f"Tomcat8 WARN - Memoria={memory_mb}MB (>{THRESHOLD_WARNING}MB); Uptime={uptime}"
            else:
                state = 0
                msg = f"Tomcat8 OK - Memoria={memory_mb}MB; Uptime={uptime}"
            
            print(f"{state} {SERVICE} - {msg}")
    
    if not found:
        print(f"2 {SERVICE} - NON attivo")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
