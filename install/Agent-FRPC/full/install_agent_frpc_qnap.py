#!/usr/bin/env python3
"""
install_agent_frpc_qnap.py - Install CheckMK Agent + FRPC on QNAP NAS

Installs and configures CheckMK monitoring agent and FRP client (frpc) 
specifically for QNAP NAS systems. Handles xinetd service configuration,
FRPC download/setup, and autostart integration.

Version: 1.0.0
"""

import os
import sys
import subprocess
import urllib.request
import tarfile
import shutil
from pathlib import Path
from typing import Tuple, Optional

VERSION = "1.0.0"

# Configuration with environment variable fallbacks
FRPS_SERVER = os.environ.get("FRPS_SERVER", "frp.example.com")
FRPS_PORT = os.environ.get("FRPS_PORT", "7000")
FRPC_TOKEN = os.environ.get("FRPC_TOKEN", "your_token_here")
CHECKMK_SERVER = os.environ.get("CHECKMK_SERVER", "checkmk.example.com")
HOSTNAME = os.environ.get("HOSTNAME", subprocess.getoutput("hostname").strip())

# Paths
CHECKMK_DIR = Path("/opt/checkmk/agent")
FRPC_DIR = Path("/opt/frpc")
XINETD_CONFIG = Path("/etc/xinetd.d/check_mk")
AUTORUN_SCRIPT = Path("/etc/config/autorun.sh")

# FRPC configuration
FRPC_VERSION = "0.52.3"
FRPC_DOWNLOAD_URL = f"https://github.com/fatedier/frp/releases/download/v{FRPC_VERSION}/frp_{FRPC_VERSION}_linux_amd64.tar.gz"


def run_command(cmd: list, check: bool = True, capture: bool = False) -> Tuple[int, str, str]:
    """
    Execute a shell command.
    
    Args:
        cmd: Command as list of strings
        check: Raise exception on non-zero exit code
        capture: Capture stdout/stderr
        
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
            timeout=60
        )
        return result.returncode, result.stdout or "", result.stderr or ""
    except subprocess.CalledProcessError as e:
        return e.returncode, e.stdout or "", e.stderr or ""
    except subprocess.TimeoutExpired:
        return 124, "", "Command timeout"
    except Exception as e:
        return 1, "", str(e)


def check_qnap_system() -> bool:
    """
    Verify this is running on a QNAP NAS system.
    
    Returns:
        True if QNAP system detected, False otherwise
    """
    qpkg_conf = Path("/etc/config/qpkg.conf")
    if not qpkg_conf.exists():
        print("ERROR: This script is designed for QNAP NAS systems")
        return False
    return True


def install_checkmk_agent() -> bool:
    """
    Download and configure CheckMK agent for QNAP.
    
    Returns:
        True if successful, False otherwise
    """
    print("\n1. Installing CheckMK agent...")
    
    try:
        # Create directory
        CHECKMK_DIR.mkdir(parents=True, exist_ok=True)
        os.chdir(CHECKMK_DIR)
        
        # Download agent
        agent_url = f"http://{CHECKMK_SERVER}/monitoring/check_mk/agents/check_mk_agent.linux"
        agent_path = CHECKMK_DIR / "check_mk_agent"
        
        print(f"   Downloading from: {agent_url}")
        urllib.request.urlretrieve(agent_url, agent_path)
        agent_path.chmod(0o755)
        print("   ✓ Agent downloaded")
        
        # Create xinetd service configuration
        xinetd_dir = Path("/etc/xinetd.d")
        xinetd_dir.mkdir(parents=True, exist_ok=True)
        
        xinetd_config_content = f"""service check_mk
{{
    type           = UNLISTED
    port           = 6556
    socket_type    = stream
    protocol       = tcp
    wait           = no
    user           = admin
    server         = {agent_path}
    disable        = no
}}
"""
        XINETD_CONFIG.write_text(xinetd_config_content)
        print("   ✓ Xinetd service configured")
        
        # Restart xinetd
        exitcode, _, _ = run_command(["/etc/init.d/xinetd.sh", "restart"], check=False)
        if exitcode == 0:
            print("   ✓ Xinetd restarted")
        else:
            print("   ⚠ Xinetd restart failed (may require manual restart)")
        
        print("✓ CheckMK agent installed on port 6556")
        return True
        
    except Exception as e:
        print(f"ERROR: Failed to install CheckMK agent: {e}", file=sys.stderr)
        return False


def install_frpc_client() -> bool:
    """
    Download and configure FRP client (frpc) for QNAP.
    
    Returns:
        True if successful, False otherwise
    """
    print("\n2. Installing FRP Client...")
    
    try:
        # Create directory
        FRPC_DIR.mkdir(parents=True, exist_ok=True)
        os.chdir(FRPC_DIR)
        
        # Download FRPC
        archive_name = f"frp_{FRPC_VERSION}_linux_amd64.tar.gz"
        archive_path = FRPC_DIR / archive_name
        
        print(f"   Downloading frpc v{FRPC_VERSION}...")
        urllib.request.urlretrieve(FRPC_DOWNLOAD_URL, archive_path)
        print("   ✓ Downloaded")
        
        # Extract archive
        print("   Extracting...")
        with tarfile.open(archive_path, "r:gz") as tar:
            tar.extractall(FRPC_DIR)
        
        # Move frpc binary
        extracted_dir = FRPC_DIR / f"frp_{FRPC_VERSION}_linux_amd64"
        frpc_binary = extracted_dir / "frpc"
        frpc_dest = FRPC_DIR / "frpc"
        
        if frpc_binary.exists():
            shutil.move(str(frpc_binary), str(frpc_dest))
            frpc_dest.chmod(0o755)
            print("   ✓ FRP client binary installed")
        
        # Cleanup
        if extracted_dir.exists():
            shutil.rmtree(extracted_dir)
        if archive_path.exists():
            archive_path.unlink()
        
        # Create FRPC configuration
        frpc_config_content = f"""[common]
server_addr = {FRPS_SERVER}
server_port = {FRPS_PORT}
auth_method = token
auth_token = {FRPC_TOKEN}

[checkmk-{HOSTNAME}]
type = tcp
local_ip = 127.0.0.1
local_port = 6556
remote_port = 0
"""
        frpc_config = FRPC_DIR / "frpc.ini"
        frpc_config.write_text(frpc_config_content)
        print("   ✓ Configuration created")
        
        # Create startup script
        startup_script_content = """#!/bin/bash
cd /opt/frpc
./frpc -c frpc.ini &
"""
        startup_script = FRPC_DIR / "frpc.sh"
        startup_script.write_text(startup_script_content)
        startup_script.chmod(0o755)
        print("   ✓ Startup script created")
        
        # Add to autostart
        if AUTORUN_SCRIPT.exists():
            autorun_content = AUTORUN_SCRIPT.read_text()
            frpc_start_cmd = "/opt/frpc/frpc.sh"
            
            if frpc_start_cmd not in autorun_content:
                with AUTORUN_SCRIPT.open("a") as f:
                    f.write(f"\n{frpc_start_cmd}\n")
                print("   ✓ Added to autostart")
            else:
                print("   ✓ Already in autostart")
        
        # Start FRPC
        exitcode, _, _ = run_command([str(startup_script)], check=False)
        if exitcode == 0:
            print("   ✓ FRP Client started")
        else:
            print("   ⚠ FRP Client start may have failed (check logs)")
        
        print("✓ FRP Client installed and started")
        return True
        
    except Exception as e:
        print(f"ERROR: Failed to install FRPC: {e}", file=sys.stderr)
        return False


def main() -> int:
    """
    Main installation workflow.
    
    Returns:
        Exit code (0=success, 1=failure)
    """
    print("=== CheckMK Agent + FRPC Installation for QNAP ===")
    print()
    
    # Check if running on QNAP
    if not check_qnap_system():
        return 1
    
    # Check root privileges
    if os.geteuid() != 0:
        print("ERROR: This script must be run as root", file=sys.stderr)
        return 1
    
    # Install CheckMK agent
    if not install_checkmk_agent():
        return 1
    
    # Install FRPC
    if not install_frpc_client():
        return 1
    
    # Summary
    print()
    print("=== Installation Complete ===")
    print(f"Agent listening on: 127.0.0.1:6556")
    print(f"FRP Server: {FRPS_SERVER}:{FRPS_PORT}")
    print(f"Tunnel name: checkmk-{HOSTNAME}")
    print()
    print("Configure CheckMK to monitor via the FRP tunnel remote port")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
