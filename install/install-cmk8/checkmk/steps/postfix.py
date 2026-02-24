from __future__ import annotations

import shlex

from lib.common import command_exists, log_header, log_info, log_success, run, run_capture
from lib.config import InstallerConfig


def run_step(_: InstallerConfig) -> None:
    log_header("25-POSTFIX")
    log_info("Installing and configuring Postfix...")

    fqdn = run_capture(["hostname", "-f"], check=False) or "localhost"
    run(["bash", "-lc", f"debconf-set-selections <<< 'postfix postfix/mailname string {shlex.quote(fqdn)}'"])
    run(["bash", "-lc", "debconf-set-selections <<< \"postfix postfix/main_mailer_type string 'Internet Site'\""])

    run(["apt-get", "install", "-y", "postfix", "mailutils"])
    run(["postconf", "-e", "inet_interfaces = loopback-only"])
    run(["postconf", "-e", "mydestination = $myhostname, localhost.$mydomain, localhost"])

    if command_exists("systemctl"):
        run(["systemctl", "restart", "postfix"], check=False)
        run(["systemctl", "enable", "postfix"], check=False)
    log_success("Postfix configured")


def run(cfg: InstallerConfig) -> None:
    run_step(cfg)
