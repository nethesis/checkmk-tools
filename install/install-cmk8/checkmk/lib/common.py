from __future__ import annotations

import datetime as _dt
import os
import shlex
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path


VERSION = "1.0.6"


class Colors:
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    CYAN = "\033[0;36m"
    NC = "\033[0m"


def now_stamp() -> str:
    return _dt.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")


def log_header(message: str) -> None:
    print("")
    print(f"{Colors.CYAN}========================================{Colors.NC}")
    print(f"{Colors.CYAN}  {message}{Colors.NC}")
    print(f"{Colors.CYAN}========================================{Colors.NC}")
    print("")


def log_info(message: str) -> None:
    print(f"{Colors.BLUE}[INFO]{Colors.NC} {message}")


def log_success(message: str) -> None:
    print(f"{Colors.GREEN}[SUCCESS]{Colors.NC} {message}")


def log_warn(message: str) -> None:
    print(f"{Colors.YELLOW}[WARN]{Colors.NC} {message}")


def log_error(message: str) -> None:
    print(f"{Colors.RED}[ERROR]{Colors.NC} {message}")


def require_root() -> None:
    if os.name != "posix":
        raise SystemExit("This installer must run on Linux (Ubuntu).")
    if os.geteuid() != 0:
        raise SystemExit("This command must be run as root (use sudo).")


def command_exists(name: str) -> bool:
    return shutil.which(name) is not None


@dataclass(frozen=True)
class RunResult:
    returncode: int


def run(cmd: list[str], *, check: bool = True) -> RunResult:
    log_info(f"Running: {shlex.join(cmd)}")
    res = subprocess.run(cmd)
    if check and res.returncode != 0:
        raise subprocess.CalledProcessError(res.returncode, cmd)
    return RunResult(returncode=res.returncode)


def run_capture(cmd: list[str], *, check: bool = True) -> str:
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and res.returncode != 0:
        raise subprocess.CalledProcessError(res.returncode, cmd, output=res.stdout, stderr=res.stderr)
    return res.stdout.strip()


def backup_file(path: Path) -> Path:
    if not path.exists():
        return path
    backup_path = path.with_name(f"{path.name}.backup_{now_stamp()}")
    shutil.copy2(path, backup_path)
    return backup_path
