from __future__ import annotations

from lib.common import log_header, log_info, log_success, run
from lib.config import InstallerConfig


def run_step(cfg: InstallerConfig) -> None:
    log_header("30-FIREWALL")
    log_info("Configuring UFW...")

    run(["apt-get", "install", "-y", "ufw"])
    run(["ufw", "default", "deny", "incoming"], check=False)
    run(["ufw", "default", "allow", "outgoing"], check=False)

    run(["ufw", "allow", f"{cfg.ssh_port}/tcp"], check=False)
    if cfg.open_http_https:
        run(["ufw", "allow", "80/tcp"], check=False)
        run(["ufw", "allow", "443/tcp"], check=False)
    run(["ufw", "allow", "6556/tcp"], check=False)

    run(["bash", "-lc", "echo y | ufw enable"], check=False)
    log_success("Firewall configured")


def run(cfg: InstallerConfig) -> None:
    run_step(cfg)
