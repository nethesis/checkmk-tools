from __future__ import annotations

import shlex
from pathlib import Path

from lib.common import cleanup_backup_files, command_exists, log_error, log_header, log_info, log_success, log_warn, require_root
from lib.common import run as run_cmd
from lib.common import run_capture
from lib.config import InstallerConfig

# Directories where backup_file() may have left *.backup / *.backup_* files
_BACKUP_DIRS_TO_CLEAN: list[Path] = [
    Path("/etc/apt/apt.conf.d"),
    Path("/etc/ssh"),
    Path("/etc/chrony"),
    Path("/etc/fail2ban"),
    Path("/lib/systemd/system"),
]


def _delete_dir(path: Path) -> bool:
    """Delete a directory (rm -rf). Returns True if something was deleted."""
    if not path.exists():
        return False
    log_warn(f"Deleting: {path}")
    run_cmd(["rm", "-rf", str(path)], check=False)
    return True


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


def _confirm_non_interactive(host: str, confirm_hostname: str) -> None:
    if not confirm_hostname:
        raise SystemExit("--assume-yes requires --confirm-hostname")
    if confirm_hostname != host:
        raise SystemExit(f"Confirmation failed: expected hostname '{confirm_hostname}', got '{host}'")


def run(cfg: InstallerConfig, *, assume_yes: bool = False, confirm_hostname: str = "") -> None:
    require_root()

    host = run_capture(["hostname"], check=False) or "unknown"
    if assume_yes:
        _confirm_non_interactive(host=host, confirm_hostname=confirm_hostname)
    else:
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
        run_cmd(["omd", "rm", "--yes", cfg.site_name], check=False)
        # Fallback: if site dir still exists after omd rm, delete it manually
        site_dir = Path(f"/omd/sites/{cfg.site_name}")
        if site_dir.exists():
            log_warn(f"omd rm did not remove {site_dir} - deleting manually")
            run_cmd(["rm", "-rf", str(site_dir)], check=False)

    log_header("Cleaning up installer backup files from system dirs")
    total_cleaned = 0
    for d in _BACKUP_DIRS_TO_CLEAN:
        n = cleanup_backup_files(d)
        if n:
            log_info(f"  Deleted {n} backup file(s) from {d}")
            total_cleaned += n
    if total_cleaned == 0:
        log_info("No backup files found to clean")
    else:
        log_success(f"Cleaned {total_cleaned} backup file(s) total")

    log_header("Purging packages")
    installed = _list_installed_packages()
    to_remove = _filter_removal_packages(installed)

    if to_remove:
        log_info(f"Purging {len(to_remove)} packages...")
        log_info("Packages: " + " ".join(shlex.quote(p) for p in to_remove))
        run_cmd(["apt-get", "purge", "-y", *to_remove], check=False)
    else:
        log_info("No matching packages to purge")

    log_header("Autoremove")
    run_cmd(["apt-get", "autoremove", "-y"], check=False)

    # Explicitly remove leftover config dirs dpkg won't delete when not empty
    log_header("Removing leftover config directories")
    _leftover_dirs: list[Path] = [
        Path("/etc/fail2ban"),
        Path("/etc/apache2"),
        Path("/etc/postfix"),
        Path("/etc/ufw"),
        Path("/etc/chrony"),
        Path("/usr/lib/check_mk_agent"),
        Path("/omd"),
    ]
    for d in _leftover_dirs:
        _delete_dir(d)

    log_header("Deleting directories")
    target_repo_dir = Path(cfg.auto_git_sync_target_dir)
    installer_root = Path(__file__).resolve().parents[2]
    postpone_repo_delete = False
    try:
        postpone_repo_delete = str(installer_root).startswith(str(target_repo_dir.resolve()) + "/")
    except Exception:
        postpone_repo_delete = False

    dirs_to_delete: list[Path] = [
        Path("/usr/lib/check_mk_agent/local"),
        Path("/omd"),
        Path("/etc/check_mk"),
    ]
    if not postpone_repo_delete:
        dirs_to_delete.insert(0, target_repo_dir)

    for path in dirs_to_delete:
        _delete_dir(path)

    if postpone_repo_delete:
        log_header("Deleting repository directory")
        _delete_dir(target_repo_dir)

    log_header("Result")
    if command_exists("omd"):
        log_error("omd is still present on PATH; removal may be incomplete")
    else:
        log_success("Remove-all completed (omd not present)")

