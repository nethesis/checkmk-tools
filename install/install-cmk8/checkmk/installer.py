#!/usr/bin/env python3
"""checkmk - Python guided installer (Ubuntu) for CheckMK and related services.

Re-implements the workflow in install-cmk8/install-cmk/scripts/*.sh in Python.

Version: 1.0.15
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from lib.common import VERSION, log_header, log_info, log_success
from lib.config import config_to_env, load_config, write_dotenv
from steps import (
    apache,
    auto_git_sync,
    certbot,
    checkmk,
    deploy_checks,
    fail2ban,
    firewall,
    ntp,
    packages,
    postfix,
    remove_all,
    ssh,
    unattended,
    verify,
)
from steps import timeshift


def bootstrap(env_file: Path, interactive: bool) -> None:
    if not env_file.exists() and not interactive:
        raise SystemExit(
            f"Env file not found: {env_file}. Run: ./installer.py init --interactive (or copy .env.example to .env)"
        )

    cfg = load_config(env_file=env_file, interactive=interactive)
    log_header(f"CheckMK Installation Bootstrap (Python v{VERSION})")

    ssh.run(cfg)
    ntp.run(cfg)
    packages.run(cfg)
    unattended.run(cfg)
    postfix.run(cfg)
    firewall.run(cfg)
    fail2ban.run(cfg)
    checkmk.run(cfg)
    deploy_checks.run(cfg)
    auto_git_sync.run(cfg)
    apache.run(cfg)
    certbot.bootstrap_step(cfg)
    timeshift.run(cfg)

    log_header("Installation Complete")
    log_success("CheckMK installation finished")

    log_header("Next Steps")
    if cfg.letsencrypt_email.strip() and cfg.letsencrypt_domains.strip():
        log_info("Certbot: you provided LETSENCRYPT_* values. Run: ./installer.py certbot run (or certbot auto)")
    else:
        log_info("Certbot: configure LETSENCRYPT_EMAIL/LETSENCRYPT_DOMAINS in .env or run with --interactive")
    log_info("Verify: ./installer.py verify")


def init_env(env_file: Path, interactive: bool) -> None:
    cfg = load_config(env_file=env_file, interactive=interactive)
    values = config_to_env(cfg)
    env_file.parent.mkdir(parents=True, exist_ok=True)
    write_dotenv(env_file, values)
    log_success(f"Wrote env file: {env_file}")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="installer.py", description="Python guided installer for CheckMK on Ubuntu")
    p.add_argument("--version", action="version", version=f"%(prog)s v{VERSION}")
    p.add_argument("--env-file", default=str(Path(__file__).with_name(".env")), help="Path to .env file")
    p.add_argument("--interactive", action="store_true", help="Prompt for key settings")
    sub = p.add_subparsers(dest="cmd", required=False)

    sub.add_parser("menu", help="Interactive menu")
    sub.add_parser("init", help="Create/update .env with a guided prompt")
    sub.add_parser("bootstrap", help="Run full installation")
    sub.add_parser("verify", help="Verify installation")
    rm = sub.add_parser("remove-all", help="Remove CheckMK and related services installed by this bootstrap")
    rm.add_argument(
        "--assume-yes",
        action="store_true",
        help="Non-interactive mode (requires --confirm-hostname to avoid accidents)",
    )
    rm.add_argument(
        "--confirm-hostname",
        default="",
        help="Hostname that must match (required with --assume-yes)",
    )

    cert = sub.add_parser("certbot", help="Certbot helpers")
    cert_sub = cert.add_subparsers(dest="cert_cmd", required=True)
    cert_sub.add_parser("install", help="Install certbot and plugin")

    run_p = cert_sub.add_parser("run", help="Obtain certificate")
    run_p.add_argument("--domain", action="append", dest="domains", help="Domain (repeatable)")
    run_p.add_argument("--email", help="Let's Encrypt email")
    run_p.add_argument("--webserver", choices=["apache", "nginx", "standalone"], help="Webserver plugin")

    cert_sub.add_parser("auto", help="Auto-detect domain from hostname -f and run")
    return p


def _menu_loop(env_file: Path) -> int:
    while True:
        print("")
        print("========================================")
        print(f" CheckMK Installer (Python v{VERSION})")
        print("========================================")
        print("")
        print(" 1) Init .env (guided)")
        print(" 2) Bootstrap (install)")
        print(" 3) Verify")
        print(" 4) Certbot install")
        print(" 5) Certbot auto")
        print(" 6) Remove all (uninstall)")
        print(" 0) Exit")
        print("")
        try:
            choice = input("Select: ").strip()
        except EOFError:
            return 1

        if choice == "0":
            return 0
        if choice == "1":
            init_env(env_file, interactive=True)
            continue
        if choice == "2":
            if not _is_root():
                script_name = Path(__file__).name
                print("[INFO] bootstrap requires root. Run:")
                print(f"  sudo -E ./{script_name} bootstrap --env-file {env_file}")
                continue
            bootstrap(env_file, interactive=False)
            continue
        if choice == "3":
            if not _is_root():
                script_name = Path(__file__).name
                print("[INFO] verify requires root. Run:")
                print(f"  sudo -E ./{script_name} verify --env-file {env_file}")
                continue
            cfg = load_config(env_file=env_file, interactive=False)
            return int(verify.run(cfg))
        if choice == "4":
            if not _is_root():
                script_name = Path(__file__).name
                print("[INFO] certbot install requires root. Run:")
                print(f"  sudo -E ./{script_name} certbot install --env-file {env_file}")
                continue
            cfg = load_config(env_file=env_file, interactive=False)
            certbot.install(cfg)
            continue
        if choice == "5":
            if not _is_root():
                script_name = Path(__file__).name
                print("[INFO] certbot auto requires root. Run:")
                print(f"  sudo -E ./{script_name} certbot auto --env-file {env_file}")
                continue
            cfg = load_config(env_file=env_file, interactive=False)
            certbot.auto(cfg)
            continue

        if choice == "6":
            if not _is_root():
                script_name = Path(__file__).name
                print("[INFO] remove-all requires root. Run:")
                print(f"  sudo -E ./{script_name} remove-all --env-file {env_file}")
                continue
            cfg = load_config(env_file=env_file, interactive=False)
            remove_all.run(cfg)
            continue
        print("Invalid selection")


def _is_root() -> bool:
    return os.name == "posix" and hasattr(os, "geteuid") and os.geteuid() == 0


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    env_file = Path(args.env_file)
    interactive = bool(args.interactive)

    if args.cmd in {None, "menu"}:
        return _menu_loop(env_file)

    root_required = args.cmd in {"bootstrap", "certbot", "verify", "remove-all"}
    if root_required and not _is_root():
        script_name = Path(__file__).name
        raise SystemExit(
            "Root privileges required. Run via sudo with a TTY, for example:\n"
            f"  sudo -E ./{script_name} {args.cmd} --env-file {env_file}" + (" --interactive" if interactive else "")
        )

    if args.cmd == "init":
        if not interactive:
            print("[INFO] For init it's recommended to use --interactive")
        init_env(env_file, interactive=True)
        return 0
    if args.cmd == "bootstrap":
        bootstrap(env_file, interactive)
        return 0
    if args.cmd == "verify":
        cfg = load_config(env_file=env_file, interactive=False)
        return verify.run(cfg)
    if args.cmd == "remove-all":
        cfg = load_config(env_file=env_file, interactive=False)
        remove_all.run(
            cfg,
            assume_yes=bool(getattr(args, "assume_yes", False)),
            confirm_hostname=str(getattr(args, "confirm_hostname", "") or "").strip(),
        )
        return 0
    if args.cmd == "certbot":
        cfg = load_config(env_file=env_file, interactive=interactive)
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
