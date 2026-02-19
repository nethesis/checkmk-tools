#!/usr/bin/env python3
"""
cmk-local-discovery-trigger.py

Rileva variazioni nei servizi local check visti da CheckMK (via `cmk -d HOST`) e
lancia discovery/reload solo quando necessario.

Workflow:
1) Legge host dal site (`cmk --list-hosts`) o da `--hosts`
2) Estrae la sezione <<<local>>> dell'agent output
3) Calcola hash stabile della lista service name
4) Se hash cambiato: esegue `cmk -IIv HOST`
5) Se almeno un host aggiornato: esegue un solo `cmk -O` (se `--activate`)

Version: 1.3.2
"""

import argparse
import fcntl
import hashlib
import json
import os
import pwd
import re
import shlex
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Set

VERSION = "1.3.2"
DEBUG = False


def log(message: str) -> None:
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [INFO] {message}")


def warn(message: str) -> None:
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [WARN] {message}")


def debug(message: str) -> None:
    if DEBUG:
        print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [DEBUG] {message}")


def run_site_cmd(site: str, cmk_command: str, timeout: int = 180) -> subprocess.CompletedProcess:
    site_path = f"/omd/sites/{site}/bin"
    shell_cmd = f"export PATH={site_path}:$PATH; {cmk_command}"

    current_user = ""
    try:
        current_user = pwd.getpwuid(os.geteuid()).pw_name
    except Exception:
        current_user = ""

    if current_user == site:
        return subprocess.run(
            ["sh", "-lc", shell_cmd],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True,
            timeout=timeout,
            check=False,
        )

    return subprocess.run(
        ["su", "-", site, "-c", shell_cmd],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        universal_newlines=True,
        timeout=timeout,
        check=False,
    )


def default_state_file(site: str) -> Path:
    return Path(f"/opt/omd/sites/{site}/var/check_mk/autodiscovery_local_state.json")


def load_state(path: Path) -> Dict[str, str]:
    if not path.exists():
        return {}
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(raw, dict):
            return {str(k): str(v) for k, v in raw.items()}
    except Exception:
        pass
    return {}


def save_state(path: Path, state: Dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2, sort_keys=True), encoding="utf-8")


def parse_hosts(site: str, hosts_arg: str) -> List[str]:
    if hosts_arg.strip():
        return sorted({h.strip() for h in hosts_arg.split(",") if h.strip()})

    for cmd in ("cmk --list-hosts", "cmk -l"):
        result = run_site_cmd(site, cmd, timeout=120)
        if result.returncode != 0:
            continue

        hosts = [line.strip() for line in (result.stdout or "").splitlines() if line.strip()]
        if hosts:
            log(f"Host list retrieved via '{cmd}' ({len(hosts)} host)")
            return sorted(set(hosts))

    raise RuntimeError("unable to retrieve hosts with both 'cmk --list-hosts' and 'cmk -l'")


def extract_local_services(agent_output: str) -> List[str]:
    in_local = False
    services: Set[str] = set()

    for raw in agent_output.splitlines():
        line = raw.strip()

        if line.startswith("<<<"):
            in_local = line.startswith("<<<local")
            continue

        if not in_local or not line:
            continue

        first = line[0]
        if first not in "0123":
            continue

        parts = line.split(None, 1)
        if len(parts) < 2:
            continue

        rest = parts[1]
        service_name = ""
        try:
            tokens = shlex.split(rest, posix=True)
            if tokens:
                service_name = tokens[0].strip()
        except Exception:
            service_name = ""

        if not service_name:
            service_name = rest.split(" - ", 1)[0].strip().strip('"')

        if service_name:
            services.add(service_name)

    return sorted(services)


def services_hash(services: List[str]) -> str:
    payload = "\n".join(services)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def discovered_local_services(site: str, host: str) -> Set[str]:
    cmd = f"cmk -D {shlex.quote(host)}"
    result = run_site_cmd(site, cmd, timeout=180)
    if result.returncode != 0:
        debug(f"cmk -D failed for {host} rc={result.returncode}")
        return set()

    discovered: Set[str] = set()
    for raw in (result.stdout or "").splitlines():
        line = raw.rstrip()
        match = re.match(r"^\s*local\s+(.+?)\s+\{", line)
        if not match:
            continue
        service_name = match.group(1).strip()
        if service_name:
            discovered.add(service_name)

    debug(f"Discovered local services on {host}: count={len(discovered)}")

    return discovered


def discover_hosts(site: str, hosts: List[str], dry_run: bool, detect_plugins: str, activate: bool) -> bool:
    if not hosts:
        return True

    plugins_opt = ""
    if detect_plugins.strip():
        plugins_opt = f" --detect-plugins {shlex.quote(detect_plugins.strip())}"

    hosts_part = " ".join(shlex.quote(host) for host in hosts)
    cmd = f"cmk -IIv{plugins_opt} {hosts_part}"
    if activate:
        cmd = f"{cmd} && cmk -O"

    if dry_run:
        log(f"[DRY-RUN] {cmd}")
        return True

    timeout = min(1800, 240 + (120 * len(hosts)))
    result = run_site_cmd(site, cmd, timeout=timeout)
    if result.returncode == 0:
        for host in hosts:
            log(f"Discovery OK: {host}")
        if activate:
            log("Activate changes OK")
        else:
            log("Discovery completata: activate disabilitato (skip cmk -O)")
        return True

    warn(f"Discovery/Activate FAIL (rc={result.returncode}) hosts={','.join(hosts)}")
    if result.stdout:
        warn(result.stdout.strip())
    return False


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Trigger discovery CheckMK su cambi local checks")
    parser.add_argument("--site", default="monitoring", help="Nome site OMD")
    parser.add_argument("--hosts", default="", help="Lista host separati da virgola")
    parser.add_argument("--state-file", default="", help="Path file stato JSON")
    parser.add_argument("--dry-run", action="store_true", help="Simula comandi senza eseguirli")
    parser.add_argument(
        "--initialize-state",
        action="store_true",
        help="Inizializza stato corrente senza discovery/reload",
    )
    parser.add_argument(
        "--agent-timeout",
        type=int,
        default=90,
        help="Timeout in secondi per singolo 'cmk -d <host>' (default: 90)",
    )
    parser.add_argument(
        "--detect-plugins",
        default="local",
        help="Plugin discovery target (default: local). Vuoto = tutti i plugin.",
    )
    parser.add_argument(
        "--activate",
        action="store_true",
        help="Esegue anche 'cmk -O' a fine ciclo se ci sono discovery riuscite.",
    )
    parser.add_argument(
        "--lock-file",
        default="/tmp/cmk-local-discovery-trigger.lock",
        help="Path lock file per evitare esecuzioni sovrapposte.",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Abilita log debug dettagliati per troubleshooting.",
    )
    return parser.parse_args()


def acquire_lock(lock_file: str):
    primary = Path(lock_file)
    fallback = Path(f"/tmp/cmk-local-discovery-trigger.{os.geteuid()}.lock")
    candidates = [primary]
    if fallback != primary:
        candidates.append(fallback)

    for candidate in candidates:
        try:
            handle = open(candidate, "a+", encoding="utf-8")
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            handle.seek(0)
            handle.truncate(0)
            handle.write(f"pid={os.getpid()} started={datetime.now().isoformat()}\n")
            handle.flush()
            return handle, str(candidate)
        except BlockingIOError:
            raise
        except PermissionError:
            continue

    raise PermissionError(f"Impossibile scrivere lock file: {primary}")


def main() -> int:
    global DEBUG
    args = parse_args()
    DEBUG = args.debug

    lock_handle = None
    try:
        lock_handle, active_lock = acquire_lock(args.lock_file)
    except BlockingIOError:
        warn(f"Altra esecuzione in corso (lock: {args.lock_file}), skip")
        return 0
    except PermissionError as exc:
        warn(str(exc))
        return 0

    state_path = Path(args.state_file) if args.state_file else default_state_file(args.site)
    state = load_state(state_path)

    log(f"cmk-local-discovery-trigger.py v{VERSION}")
    log(f"Site: {args.site}")
    log(f"State: {state_path}")
    log(f"Lock: {active_lock}")
    debug(f"Args: hosts='{args.hosts}', detect_plugins='{args.detect_plugins}', activate={args.activate}, initialize_state={args.initialize_state}")

    try:
        hosts = parse_hosts(args.site, args.hosts)
    except Exception as exc:
        print(f"[ERROR] Impossibile ottenere host list: {exc}", file=sys.stderr)
        return 1

    if not hosts:
        warn("Nessun host trovato")
        return 0

    log(f"Host totali: {len(hosts)}")

    changed_hosts: List[str] = []
    successful_discovery = 0
    pending_discovery: List[str] = []

    for host in hosts:
        log(f"Probe host: {host}")
        host_quoted = shlex.quote(host)
        probe_cmd = f"timeout -k 5 {args.agent_timeout}s cmk -d {host_quoted}"
        try:
            result = run_site_cmd(args.site, probe_cmd, timeout=args.agent_timeout + 10)
        except subprocess.TimeoutExpired:
            warn(f"cmk -d timeout per {host} (> {args.agent_timeout}s), skip")
            continue

        if result.returncode == 124:
            warn(f"cmk -d timeout (rc=124) per {host} dopo {args.agent_timeout}s, skip")
            continue

        if result.returncode != 0:
            warn(f"cmk -d fallito per {host} (rc={result.returncode}), skip")
            continue

        services = extract_local_services(result.stdout or "")
        current_hash = services_hash(services)
        previous_hash = state.get(host, "")
        debug(
            f"Host={host} local_count={len(services)} prev_hash={(previous_hash[:12] if previous_hash else 'none')} curr_hash={current_hash[:12]}"
        )
        if services:
            debug(f"Host={host} local sample: {', '.join(services[:6])}{' ...' if len(services) > 6 else ''}")
        else:
            warn(f"Nessun local service estratto da cmk -d per {host} (payload local vuoto)")

        if previous_hash != current_hash:
            changed_hosts.append(host)
            log(f"Cambio local services: {host} (prev={'yes' if previous_hash else 'no'}, now={len(services)})")

            if args.initialize_state:
                state[host] = current_hash
                continue

            pending_discovery.append(host)
        else:
            log(f"Nessun cambio: {host}")

            if services:
                discovered = discovered_local_services(args.site, host)
                missing_services = sorted(set(services) - discovered)
                debug(
                    f"Host={host} discovered_count={len(discovered)} missing_count={len(missing_services)}"
                )
                if missing_services:
                    warn(
                        f"Inventory mismatch su {host}: {len(missing_services)} local service mancanti in discovery, forzo rediscovery"
                    )
                    warn(f"Missing: {', '.join(missing_services[:8])}{' ...' if len(missing_services) > 8 else ''}")
                    pending_discovery.append(host)

    if args.initialize_state:
        save_state(state_path, state)
        log(f"Stato inizializzato per {len(state)} host")
        return 0

    unique_pending = list(dict.fromkeys(pending_discovery))
    if unique_pending:
        debug(f"Pending discovery hosts: {', '.join(unique_pending)}")
        if discover_hosts(args.site, unique_pending, args.dry_run, args.detect_plugins, args.activate):
            successful_discovery = len(unique_pending)
            for host in unique_pending:
                probe_cmd = f"timeout -k 5 {args.agent_timeout}s cmk -d {shlex.quote(host)}"
                try:
                    refresh = run_site_cmd(args.site, probe_cmd, timeout=args.agent_timeout + 10)
                    if refresh.returncode == 0:
                        state[host] = services_hash(extract_local_services(refresh.stdout or ""))
                except Exception:
                    pass
    else:
        log("Nessuna discovery riuscita: skip cmk -O")

    save_state(state_path, state)
    log(
        f"Completato: changed={len(changed_hosts)}, discovery_ok={successful_discovery}, unchanged={len(hosts) - len(changed_hosts)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
