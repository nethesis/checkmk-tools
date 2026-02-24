from __future__ import annotations

import re
import urllib.request
import shlex
from pathlib import Path

from lib.common import command_exists, log_header, log_info, log_success, run as run_cmd, run_capture
from lib.config import InstallerConfig


def _parse_version_tuple(version: str) -> tuple[int, int, int, int]:
    m = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)p(\d+)", version.strip())
    if not m:
        raise ValueError(f"Invalid CheckMK version: {version}")
    return int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4))


def _detect_latest_raw_version(timeout_sec: int = 20) -> str:
    url = "https://download.checkmk.com/checkmk/"
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (compatible; checkmk-tools-installer/1.0; +https://github.com/Coverup20/checkmk-tools)",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout_sec) as resp:
        html = resp.read().decode("utf-8", errors="replace")

    # Capture versions like 2.4.0p20, 2.5.0p1, etc.
    versions = set(re.findall(r"\b\d+\.\d+\.\d+p\d+\b", html))
    if not versions:
        raise RuntimeError("Could not detect any versions from download listing")

    return max(versions, key=_parse_version_tuple)


def run_step(cfg: InstallerConfig) -> None:
    log_header("60-CHECKMK")
    log_info("Installing CheckMK...")

    run_cmd(["apt-get", "install", "-y", "gdebi-core"])

    url = cfg.checkmk_deb_url.strip()
    if not url:
        codename = run_capture(["lsb_release", "-cs"], check=False) or "jammy"
        arch = run_capture(["dpkg", "--print-architecture"], check=False) or "amd64"

        cmk_version = (cfg.cmk_version or "").strip()
        if cmk_version.lower() in {"latest", ""}:
            log_info("CMK_VERSION=latest: detecting latest available raw version...")
            try:
                cmk_version = _detect_latest_raw_version()
            except Exception as exc:
                raise RuntimeError(f"Failed to detect latest CheckMK version: {exc}")

        url = f"https://download.checkmk.com/checkmk/{cmk_version}/check-mk-raw-{cmk_version}_0.{codename}_{arch}.deb"
        log_info(f"Using derived URL: {url}")

    deb_path = Path("/tmp") / Path(url).name
    run_cmd(["wget", "-O", str(deb_path), url])
    run_cmd(["gdebi", "-n", str(deb_path)])

    if not command_exists("omd"):
        raise RuntimeError("omd command not found after installation")

    sites_output = run_capture(["omd", "sites"], check=False)
    if cfg.site_name not in sites_output:
        run_cmd(["omd", "create", cfg.site_name])
    run_cmd(["omd", "start", cfg.site_name], check=False)

    if cfg.checkmk_admin_password:
        log_info("Setting cmkadmin password (value not shown)...")
        run_cmd(
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
