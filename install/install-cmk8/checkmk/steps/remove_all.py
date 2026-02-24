from __future__ import annotations

import shlex
from dataclasses import dataclass
from pathlib import Path

from lib.common import command_exists, log_error, log_header, log_info, log_success, log_warn, now_stamp, require_root
from lib.common import run as run_cmd
from lib.common import run_capture
from lib.config import InstallerConfig


@dataclass(frozen=True)
class _BackupMove:
    original: Path
    backup: Path


def _backup_dir_by_rename(path: Path) -> _BackupMove | None:
    if not path.exists():
        return None

    stamp = now_stamp()
    backup_path = path.with_name(f"{path.name}.backup_{stamp}")

    log_warn(f"Backup before delete: mv {path} -> {backup_path}")
    run_cmd(["mv", str(path), str(backup_path)], check=True)
    return _BackupMove(original=path, backup=backup_path)


def _list_installed_packages() -> set[str]:
    out = run_capture(["dpkg-query", "-W", "-f", "${Package}\n"], check=False)
    return {line.strip() for line in out.splitlines() if line.strip()}


def _filter_removal_packages(installed: set[str]) -> list[str]:
    prefixes = [
        "check-mk-raw-",
    ]

    exact = {
        "check-mk-agent",
        "check-mk-agent-logwatch",
        "gdebi-core",
        "postfix",
        "mailutils",
        "ufw",
        "fail2ban",
        "apache2",
        "certbot",
        "python3-certbot-apache",
        "timeshift",
        "chrony",
        "unattended-upgrades",
        "git",
        "python3-pip",
    }

    to_remove: set[str] = set()
    for pkg in installed:
        if pkg in exact:
            to_remove.add(pkg)
            continue
        if any(pkg.startswith(pfx) for pfx in prefixes):
            to_remove.add(pkg)

    return sorted(to_remove)


def _confirm_or_abort(host: str, site: str) -> None:
    log_header("REMOVE ALL (UNINSTALL)")
    log_warn("This will REMOVE CheckMK/OMD and related services installed by this bootstrap.")
    log_warn("It will also remove common dependencies (apache2/postfix/ufw/fail2ban/certbot/git/pip).")
    print("")
    print(f"Host: {host}")
    print(f"Site: {site}")
    print("")

    typed_host = input("Type the hostname to confirm: ").strip()
    if typed_host != host:
        raise SystemExit("Confirmation failed: hostname mismatch")

    typed = input("Type REMOVE to proceed: ").strip()
    if typed != "REMOVE":
        raise SystemExit("Aborted")


def run(cfg: InstallerConfig) -> None:
    require_root()

    host = run_capture(["hostname"], check=False) or "unknown"
    _confirm_or_abort(host=host, site=cfg.site_name)

    log_header("Stopping services")
    run_cmd(["systemctl", "stop", "--now", "auto-git-sync.service"], check=False)
    run_cmd(["systemctl", "disable", "--now", "auto-git-sync.service"], check=False)
    run_cmd(["systemctl", "stop", "--now", "apache2"], check=False)
    run_cmd(["systemctl", "stop", "--now", "postfix"], check=False)
    run_cmd(["systemctl", "stop", "--now", "fail2ban"], check=False)

    if command_exists("omd"):
        log_header("Removing OMD site")
        run_cmd(["omd", "stop", cfg.site_name], check=False)
        run_cmd(["omd", "rm", "-f", cfg.site_name], check=False)

    log_header("Backup key directories (rename)")
    backup_moves: list[_BackupMove] = []
    for path in [
        Path(cfg.auto_git_sync_target_dir),
        Path("/usr/lib/check_mk_agent/local"),
        Path("/omd"),
        Path("/etc/check_mk"),
    ]:
        move = _backup_dir_by_rename(path)
        if move:
            backup_moves.append(move)

    log_header("Purging packages")
    installed = _list_installed_packages()
    to_remove = _filter_removal_packages(installed)

    if to_remove:
        log_info(f"Purging {len(to_remove)} packages...")
        log_info("Packages: " + " ".join(shlex.quote(p) for p in to_remove))
        run_cmd(["apt-get", "purge", "-y", *to_remove], check=True)
    else:
        log_info("No matching packages to purge")

    log_header("Autoremove")
    run_cmd(["apt-get", "autoremove", "-y"], check=False)

    log_header("Result")
    log_success("Remove-all completed")

    if backup_moves:
        log_warn("Backups created (you can delete them manually when satisfied):")
        for move in backup_moves:
            log_warn(f"- {move.backup}")

        print("")
        ans = input("Delete these backups now? [y/N]: ").strip().lower()
        if ans in {"y", "yes"}:
            log_header("Deleting backups")
            for move in backup_moves:
                run_cmd(["rm", "-rf", str(move.backup)], check=False)
            log_success("Backups deleted")
        else:
            log_info("Keeping backups")

    # Minimal sanity check
    if command_exists("omd"):
        log_error("omd is still present on PATH; removal may be incomplete")
    else:
        log_info("omd not present (OK)")
