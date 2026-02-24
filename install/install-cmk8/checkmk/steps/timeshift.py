from __future__ import annotations

from lib.common import command_exists, log_header, log_info, log_success, run as run_cmd
from lib.config import InstallerConfig


def run_step(_: InstallerConfig) -> None:
    log_header("80-TIMESHIFT")
    log_info("Installing Timeshift...")

    if command_exists("add-apt-repository"):
        run_cmd(["add-apt-repository", "-y", "ppa:teejee2008/timeshift"], check=False)
    run_cmd(["apt-get", "update"])
    run_cmd(["apt-get", "install", "-y", "timeshift"], check=False)
    if command_exists("timeshift"):
        run_cmd(
            [
                "timeshift",
                "--create",
                "--comments",
                "Initial snapshot after CheckMK installation",
                "--tags",
                "D",
            ],
            check=False,
        )
    log_success("Timeshift step completed")


def run(cfg: InstallerConfig) -> None:
    run_step(cfg)
