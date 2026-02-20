#!/usr/bin/env python3
"""
check-proxmox_snapshots_status.py - CheckMK Local Check for Proxmox Snapshots

Monitor snapshot count and age for QEMU VMs (WARN 14 days, CRIT 30 days).

Proxmox VE

Version: 1.0.0
"""

import subprocess
import sys
import re
import time

VERSION = "1.0.0"
PVE_TIMEOUT = 30
WARN_DAYS = 14
CRIT_DAYS = 30


def sanitize_name(name):
    """Sanitize VM name for CheckMK service name."""
    name = re.sub(r'[ /]', '__', name)
    name = re.sub(r'[^A-Za-z0-9_.:-]', '', name)
    return name


def run_cmd(cmd, timeout=PVE_TIMEOUT):
    """Run command with timeout."""
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            timeout=timeout
        )
        return result.returncode, result.stdout
    except subprocess.TimeoutExpired:
        return 124, ""
    except FileNotFoundError:
        return 127, ""


def get_vmids():
    """Get list of VMID from qm list."""
    rc, out = run_cmd(["qm", "list"])
    if rc != 0:
        return []
    
    vmids = []
    for line in out.splitlines()[1:]:  # Skip header
        parts = line.split()
        if parts:
            vmids.append(parts[0])
    return vmids


def get_vm_name(vmid):
    """Get VM name from config."""
    rc, out = run_cmd(["qm", "config", vmid])
    if rc != 0:
        return f"vm{vmid}"
    
    for line in out.splitlines():
        if line.startswith("name:"):
            return line.split(":", 1)[1].strip()
    return f"vm{vmid}"


def get_snapshot_count(vmid):
    """Get snapshot count for VM."""
    rc, out = run_cmd(["qm", "listsnapshot", vmid])
    if rc != 0:
        return 0
    
    count = 0
    for line in out.splitlines()[1:]:  # Skip header
        if line.strip():
            count += 1
    return count


def get_oldest_snapshot_age(vmid):
    """Get oldest snapshot age in days from /etc/pve/qemu-server/VMID.conf."""
    conf_path = f"/etc/pve/qemu-server/{vmid}.conf"
    
    try:
        with open(conf_path, 'r') as f:
            content = f.read()
    except (FileNotFoundError, PermissionError):
        return None
    
    # Find all snaptime entries
    snaptimes = []
    for line in content.splitlines():
        if line.startswith("snaptime:"):
            try:
                snaptime = int(line.split(":", 1)[1].strip())
                snaptimes.append(snaptime)
            except (ValueError, IndexError):
                continue
    
    if not snaptimes:
        return None
    
    # Get oldest snapshot
    oldest = min(snaptimes)
    now = int(time.time())
    age_sec = now - oldest
    age_days = age_sec // 86400
    
    return age_days


def main():
    # Check qm command exists
    try:
        subprocess.run(
            ["qm", "--version"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=5
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        print("3 PVE_QEMU_Snapshots - qm command not found")
        return 0
    
    vmids = get_vmids()
    if not vmids:
        print("3 PVE_QEMU_Snapshots_Summary - No VMs found")
        return 0
    
    # Summary
    vm_total = len(vmids)
    snaps_total = sum(get_snapshot_count(vmid) for vmid in vmids)
    print(f"0 PVE_QEMU_Snapshots_Summary vms={vm_total} snapshots={snaps_total} OK - {snaps_total} snapshots across {vm_total} VMs")
    
    # Per-VM checks
    for vmid in vmids:
        name = get_vm_name(vmid)
        safe_name = sanitize_name(name)
        svc_base = f"SNP_{safe_name}"
        
        snap_count = get_snapshot_count(vmid)
        
        if snap_count == 0:
            print(f"2 {svc_base}_Count count=0 CRIT - 0 snapshots")
            continue
        elif snap_count == 1:
            print(f"1 {svc_base}_Count count=1 WARN - 1 snapshot")
        else:
            print(f"0 {svc_base}_Count count={snap_count} OK - {snap_count} snapshots")
        
        # Check age
        age_days = get_oldest_snapshot_age(vmid)
        if age_days is not None:
            if age_days >= CRIT_DAYS:
                state = 2
            elif age_days >= WARN_DAYS:
                state = 1
            else:
                state = 0
            
            print(f"{state} {svc_base}_Age age_days={age_days};{WARN_DAYS};{CRIT_DAYS} - oldest snapshot {age_days} days")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
