#!/usr/bin/env python3
"""checkmk - Python guided installer (Ubuntu) for CheckMK and related services.

Re-implements the workflow in install-cmk8/install-cmk/scripts/*.sh in Python.

Version: 1.0.0
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from lib.common import VERSION, log_header, log_success
from lib.config import load_config
from steps import (
    certbot,
    checkmk,
    fail2ban,
    firewall,
    ntp,
    packages,
    postfix,
    ssh,
    verify,
)
from steps import timeshift


def bootstrap(env_file: Path, interactive: bool) -> None:
    cfg = load_config(env_file=env_file, interactive=interactive)
    log_header(f"CheckMK Installation Bootstrap (Python v{VERSION})")

    ssh.run(cfg)
    ntp.run(cfg)
    packages.run(cfg)
    postfix.run(cfg)
    firewall.run(cfg)
    fail2ban.run(cfg)
    certbot.install(cfg)
    checkmk.run(cfg)
    timeshift.run(cfg)

    log_header("Installation Complete")
    log_success("CheckMK installation finished")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="installer.py", description="Python guided installer for CheckMK on Ubuntu")
    p.add_argument("--version", action="version", version=f"%(prog)s v{VERSION}")
    p.add_argument("--env-file", default=str(Path(__file__).with_name(".env")), help="Path to .env file")
    p.add_argument("--interactive", action="store_true", help="Prompt for key settings")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("bootstrap", help="Run full installation")
    sub.add_parser("verify", help="Verify installation")

    cert = sub.add_parser("certbot", help="Certbot helpers")
    cert_sub = cert.add_subparsers(dest="cert_cmd", required=True)
    cert_sub.add_parser("install", help="Install certbot and plugin")

    run_p = cert_sub.add_parser("run", help="Obtain certificate")
    run_p.add_argument("--domain", action="append", dest="domains", help="Domain (repeatable)")
    run_p.add_argument("--email", help="Let's Encrypt email")
    run_p.add_argument("--webserver", choices=["apache", "nginx", "standalone"], help="Webserver plugin")

    cert_sub.add_parser("auto", help="Auto-detect domain from hostname -f and run")
    return p


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    env_file = Path(args.env_file)
    interactive = bool(args.interactive)

    if args.cmd == "bootstrap":
        bootstrap(env_file, interactive)
        return 0
    if args.cmd == "verify":
        cfg = load_config(env_file=env_file, interactive=False)
        return verify.run(cfg)
    if args.cmd == "certbot":
        cfg = load_config(env_file=env_file, interactive=False)
        if args.cert_cmd == "install":
            certbot.install(cfg)
            return 0
        if args.cert_cmd == "run":
            certbot.obtain(cfg, domains=args.domains, email=args.email, webserver=args.webserver)
            return 0
        if args.cert_cmd == "auto":
            certbot.auto(cfg)
            return 0
    raise SystemExit("Unhandled command")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
