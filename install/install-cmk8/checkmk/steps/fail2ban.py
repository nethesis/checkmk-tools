from __future__ import annotations

from pathlib import Path

from lib.common import backup_file, command_exists, log_header, log_info, log_success, run
from lib.config import InstallerConfig


def run_step(cfg: InstallerConfig) -> None:
    log_header("40-FAIL2BAN")
    log_info("Installing and configuring Fail2Ban...")
    run(["apt-get", "install", "-y", "fail2ban"])

    jail_local = Path("/etc/fail2ban/jail.local")
    if jail_local.exists():
        backup = backup_file(jail_local)
        log_info(f"Backup created: {backup}")

    jail_local.write_text(
        "\n".join(
            [
                "[DEFAULT]",
                "bantime = 3600",
                "findtime = 600",
                "maxretry = 5",
                "",
                "[sshd]",
                "enabled = true",
                f"port = {cfg.ssh_port}",
                "logpath = /var/log/auth.log",
                "",
            ]
        ),
        encoding="utf-8",
    )

    if command_exists("systemctl"):
        run(["systemctl", "enable", "fail2ban"], check=False)
        run(["systemctl", "restart", "fail2ban"], check=False)
    log_success("Fail2Ban configured")


def run(cfg: InstallerConfig) -> None:
    run_step(cfg)
