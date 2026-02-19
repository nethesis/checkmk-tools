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
5) Se almeno un host aggiornato: esegue un solo `cmk -R`

Version: 1.0.0
"""

import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Set

VERSION = "1.0.0"


def log(message: str) -> None:
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [INFO] {message}")


def warn(message: str) -> None:
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [WARN] {message}")


def run_site_cmd(site: str, cmk_command: str, timeout: int = 180) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["omd", "su", site, "-c", cmk_command],
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

    result = run_site_cmd(site, "cmk --list-hosts", timeout=120)
    if result.returncode != 0:
        raise RuntimeError(f"cmk --list-hosts failed (rc={result.returncode}): {result.stdout}")

    hosts = [line.strip() for line in (result.stdout or "").splitlines() if line.strip()]
    return sorted(set(hosts))


def extract_local_services(agent_output: str) -> List[str]:
    in_local = False
    services: Set[str] = set()

    for raw in agent_output.splitlines():
        line = raw.strip()

        if line.startswith("<<<"):
            in_local = line.startswith("<<<local>>>")
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
        service_name = rest.split(" - ", 1)[0].strip().strip('"')
        if service_name:
            services.add(service_name)

    return sorted(services)


def services_hash(services: List[str]) -> str:
    payload = "\n".join(services)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def discover_host(site: str, host: str, dry_run: bool) -> bool:
    cmd = f"cmk -IIv {host}"
    if dry_run:
        log(f"[DRY-RUN] {cmd}")
        return True

    result = run_site_cmd(site, cmd, timeout=300)
    if result.returncode == 0:
        log(f"Discovery OK: {host}")
        return True

    warn(f"Discovery FAIL: {host} (rc={result.returncode})")
    if result.stdout:
        warn(result.stdout.strip())
    return False


def reload_core(site: str, dry_run: bool) -> bool:
    cmd = "cmk -R"
    if dry_run:
        log(f"[DRY-RUN] {cmd}")
        return True

    result = run_site_cmd(site, cmd, timeout=240)
    if result.returncode == 0:
        log("Reload core OK")
        return True

    warn(f"Reload core FAIL (rc={result.returncode})")
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
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    state_path = Path(args.state_file) if args.state_file else default_state_file(args.site)
    state = load_state(state_path)

    log(f"cmk-local-discovery-trigger.py v{VERSION}")
    log(f"Site: {args.site}")
    log(f"State: {state_path}")

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

    for host in hosts:
        result = run_site_cmd(args.site, f"cmk -d {host}", timeout=180)
        if result.returncode != 0:
            warn(f"cmk -d fallito per {host} (rc={result.returncode}), skip")
            continue

        services = extract_local_services(result.stdout or "")
        current_hash = services_hash(services)
        previous_hash = state.get(host, "")

        if previous_hash != current_hash:
            changed_hosts.append(host)
            log(f"Cambio local services: {host} (prev={'yes' if previous_hash else 'no'}, now={len(services)})")

            if args.initialize_state:
                state[host] = current_hash
                continue

            if discover_host(args.site, host, args.dry_run):
                successful_discovery += 1
                state[host] = current_hash
        else:
            log(f"Nessun cambio: {host}")

    if args.initialize_state:
        save_state(state_path, state)
        log(f"Stato inizializzato per {len(state)} host")
        return 0

    if successful_discovery > 0:
        reload_core(args.site, args.dry_run)
    else:
        log("Nessuna discovery riuscita: skip cmk -R")

    save_state(state_path, state)
    log(
        f"Completato: changed={len(changed_hosts)}, discovery_ok={successful_discovery}, unchanged={len(hosts) - len(changed_hosts)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
