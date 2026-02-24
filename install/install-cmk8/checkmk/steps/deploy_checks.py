from __future__ import annotations

from pathlib import Path

from lib.common import log_header, log_info, log_success, log_warn, run
from lib.config import InstallerConfig


def _find_repo_root() -> Path | None:
    here = Path(__file__).resolve()
    for parent in [here, *here.parents]:
        if (parent / "script-tools" / "full").exists():
            return parent
    return None


def run_step(cfg: InstallerConfig) -> None:
    log_header("60-DEPLOY-LOCAL-CHECKS")

    if not cfg.deploy_local_checks:
        log_info("DEPLOY_LOCAL_CHECKS=false: skipping")
        return

    repo_root = _find_repo_root()
    if repo_root is None:
        log_warn("Repository root not found (script-tools/full missing). Skipping local checks deploy.")
        return

    script_path = repo_root / "script-tools" / "full" / "deploy" / "auto-deploy-checks.py"
    if not script_path.exists():
        log_warn(f"auto-deploy-checks.py not found at: {script_path}. Skipping.")
        return

    log_info("Deploying OS-aware CheckMK local checks into /usr/lib/check_mk_agent/local ...")
    run(["python3", str(script_path), "--install-all", "--yes"])
    log_success("Local checks deployed")


def run(cfg: InstallerConfig) -> None:
    run_step(cfg)
