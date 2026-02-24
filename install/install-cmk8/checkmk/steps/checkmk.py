from __future__ import annotations

import shlex
from pathlib import Path

from lib.common import command_exists, log_header, log_info, log_success, run, run_capture
from lib.config import InstallerConfig


def run_step(cfg: InstallerConfig) -> None:
    log_header("60-CHECKMK")
    log_info("Installing CheckMK...")

    run(["apt-get", "install", "-y", "gdebi-core"])

    url = cfg.checkmk_deb_url.strip()
    if not url:
        codename = run_capture(["lsb_release", "-cs"], check=False) or "jammy"
        arch = run_capture(["dpkg", "--print-architecture"], check=False) or "amd64"
        url = f"https://download.checkmk.com/checkmk/{cfg.cmk_version}/check-mk-raw-{cfg.cmk_version}_0.{codename}_{arch}.deb"
        log_info(f"Using derived URL: {url}")

    deb_path = Path("/tmp") / Path(url).name
    run(["wget", "-O", str(deb_path), url])
    run(["gdebi", "-n", str(deb_path)])

    if not command_exists("omd"):
        raise RuntimeError("omd command not found after installation")

    sites_output = run_capture(["omd", "sites"], check=False)
    if cfg.site_name not in sites_output:
        run(["omd", "create", cfg.site_name])
    run(["omd", "start", cfg.site_name], check=False)

    if cfg.checkmk_admin_password:
        log_info("Setting cmkadmin password (value not shown)...")
        run(
            [
                "omd",
                "su",
                cfg.site_name,
                "-c",
                f"htpasswd -b ~/etc/htpasswd cmkadmin {shlex.quote(cfg.checkmk_admin_password)}",
            ],
            check=False,
        )

    ip = run_capture(["bash", "-lc", "hostname -I | awk '{print $1}'"], check=False)
    log_success("CheckMK installed")
    log_info(f"Site: {cfg.site_name}")
    log_info(f"URL: http://{ip}/{cfg.site_name}")


def run(cfg: InstallerConfig) -> None:
    run_step(cfg)
