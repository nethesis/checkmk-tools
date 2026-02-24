from __future__ import annotations

from lib.common import log_header, log_info, log_success, log_warn, require_root, run as run_cmd, run_capture
from lib.config import InstallerConfig


def install(cfg: InstallerConfig) -> None:
    require_root()
    log_header("50-CERTBOT")
    log_info("Installing certbot...")

    ws = cfg.webserver.strip().lower() or "apache"
    packages = ["certbot"]
    if ws == "apache":
        packages.append("python3-certbot-apache")
    elif ws == "nginx":
        packages.append("python3-certbot-nginx")
    elif ws == "standalone":
        pass
    else:
        raise SystemExit("Invalid WEBSERVER/WS. Use apache|nginx|standalone")
    run_cmd(["apt-get", "install", "-y", *packages])
    log_success("Certbot installed")


def obtain(cfg: InstallerConfig, *, domains: list[str] | None, email: str | None, webserver: str | None) -> None:
    require_root()
    domains = domains or [d.strip() for d in cfg.letsencrypt_domains.split(",") if d.strip()]
    if not domains:
        raise SystemExit("No domains provided. Use --domain or set LETSENCRYPT_DOMAINS")
    email = (email or cfg.letsencrypt_email).strip()
    if not email:
        raise SystemExit("No email provided. Use --email or set LETSENCRYPT_EMAIL")

    ws = (webserver or cfg.webserver).strip().lower() or "apache"
    install(InstallerConfig(**{**cfg.__dict__, "webserver": ws}))

    log_header("50-CERTBOT-RUN")
    base = ["certbot"]
    if ws == "apache":
        base += ["--apache"]
    elif ws == "nginx":
        base += ["--nginx"]
    elif ws == "standalone":
        base += ["certonly", "--standalone"]
    else:
        raise SystemExit("Invalid webserver. Use apache|nginx|standalone")
    for d in domains:
        base += ["-d", d]
    base += ["--non-interactive", "--agree-tos", "--email", email]

    run_cmd(base)
    log_success(f"SSL certificate obtained for: {', '.join(domains)}")


def auto(cfg: InstallerConfig) -> None:
    require_root()
    domain = run_capture(["hostname", "-f"], check=False)
    if domain in {"localhost", ""}:
        log_warn("Cannot auto-detect domain; skipping")
        return
    obtain(cfg, domains=[domain], email=None, webserver=None)
