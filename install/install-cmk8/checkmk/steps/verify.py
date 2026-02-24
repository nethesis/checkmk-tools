from __future__ import annotations

import subprocess
from pathlib import Path

from lib.common import Colors, command_exists, run_capture
from lib.config import InstallerConfig


def _ok(msg: str) -> None:
    print(f"{Colors.GREEN}✓{Colors.NC} {msg}")


def _fail(msg: str) -> None:
    print(f"{Colors.RED}✗{Colors.NC} {msg}")


def _warn(msg: str) -> None:
    print(f"{Colors.YELLOW}⚠{Colors.NC} {msg}")


def _verify_site(site: str) -> tuple[bool, str]:
    if not command_exists("omd"):
        return False, "OMD not installed"
    sites = run_capture(["omd", "sites"], check=False)
    if site not in sites:
        return False, f"Site '{site}' not found"
    status = run_capture(["omd", "status", site], check=False)
    if "running" not in status:
        return False, f"Site '{site}' is not running"
    return True, "OK"


def run(cfg: InstallerConfig) -> int:
    errors = 0

    print("=== CheckMK Installation Verification ===\n")

    print("1. Checking OMD...")
    ok, msg = _verify_site(cfg.site_name)
    if ok:
        _ok("OMD installed")
        _ok(f"Site '{cfg.site_name}' exists and is running")
    else:
        _fail(msg)
        errors += 1
    print("")

    print("2. Checking Apache...")
    if command_exists("systemctl"):
        apache_running = subprocess.run(["systemctl", "is-active", "--quiet", "apache2"]).returncode == 0
        httpd_running = subprocess.run(["systemctl", "is-active", "--quiet", "httpd"]).returncode == 0
        if apache_running or httpd_running:
            _ok("Apache is running")
        else:
            _fail("Apache is not running")
            errors += 1
    else:
        _warn("systemctl not available; cannot check Apache")
    print("")

    print("3. Checking Firewall...")
    if command_exists("ufw"):
        status = run_capture(["ufw", "status"], check=False)
        if "Status: active" in status:
            _ok("UFW is active")
            if "80/tcp" in status:
                _ok("HTTP port 80 is open")
            else:
                _warn("HTTP port 80 may not be open")
            if "443/tcp" in status:
                _ok("HTTPS port 443 is open")
            else:
                _warn("HTTPS port 443 may not be open")
        else:
            _warn("UFW is inactive")
    else:
        _warn("ufw not installed")
    print("")

    print("4. Checking Fail2Ban...")
    if command_exists("systemctl"):
        if subprocess.run(["systemctl", "is-active", "--quiet", "fail2ban"]).returncode == 0:
            _ok("Fail2Ban is running")
        else:
            _warn("Fail2Ban is not running")
    else:
        _warn("systemctl not available; cannot check fail2ban")
    print("")

    print("5. Checking SSL...")
    if Path("/etc/letsencrypt/live").is_dir():
        _ok("Let's Encrypt directory exists")
    else:
        _warn("No Let's Encrypt certificates found")
    print("")

    print("6. Checking Web Access...")
    if command_exists("curl"):
        code = run_capture(
            [
                "bash",
                "-lc",
                f"curl -s -o /dev/null -w '%{{http_code}}' http://localhost/{cfg.site_name}/",
            ],
            check=False,
        )
        if code.startswith(("200", "301", "302")):
            _ok("CheckMK web interface accessible locally")
        else:
            _fail(f"CheckMK web interface not accessible (HTTP {code})")
            errors += 1
    else:
        _warn("curl not installed")

    print("\n===================================")
    ip = run_capture(["bash", "-lc", "hostname -I | awk '{print $1}'"], check=False)
    if errors == 0:
        print(f"{Colors.GREEN}✓ All checks passed{Colors.NC}\n")
        print(f"Access CheckMK at: http://{ip}/{cfg.site_name}")
        return 0
    print(f"{Colors.RED}✗ {errors} check(s) failed{Colors.NC}\n")
    print("Review the errors above and fix any issues")
    return 1
