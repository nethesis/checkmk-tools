#!/usr/bin/env python3
"""Best-effort repair for bash scripts damaged by missing newlines / token concatenation.

This repo has multiple scripts where formatting was corrupted (e.g. `fi echo ...`, `}print_info()`,
`<<EOF[Unit]...`, stray `do` lines, double shebangs). These issues make scripts fail `bash -n`.

Goal:
- Make scripts syntactically parseable again (pass `bash -n`) with minimal, mechanical edits.
- Keep output ASCII-only where possible (does not add new box/emoji glyphs).

Notes:
- This is heuristic and intentionally conservative.
- It will NOT fully reconstruct logic for severely corrupted scripts; it focuses on restoring
  separators/newlines so the interpreter can parse.

Usage:
  python3 tools/fix_bash_syntax_corruption.py --roots script-tools install/checkmk-installer/scripts/script-tools

"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class FixResult:
    path: Path
    changed: bool
    reason: str


_KW = (
    "clear",
    "echo",
    "read",
    "printf",
    "if",
    "elif",
    "else",
    "then",
    "fi",
    "for",
    "while",
    "do",
    "done",
    "case",
    "esac",
    "function",
    "declare",
    "local",
    "set",
    "exit",
    "return",
    "mkdir",
    "cd",
    "cat",
    "cp",
    "mv",
    "rm",
    "chmod",
    "chown",
    "systemctl",
    "tar",
    "wget",
    "curl",
    "grep",
    "awk",
    "sed",
    "head",
    "tail",
    "timeout",
    "ss",
    "nc",
    "killall",
    "pkill",
)


def iter_sh_files(roots: list[Path]) -> list[Path]:
    files: set[Path] = set()
    for root in roots:
        if not root.exists():
            continue
        for p in root.rglob("*.sh"):
            if p.is_file():
                files.add(p)
    return sorted(files)


def _normalize_line_endings(text: str) -> str:
    return text.replace("\r\n", "\n").replace("\r", "\n")


def _remove_stray_env_bash_line(text: str) -> str:
    # Remove a second-line '/usr/bin/env bash' (without shebang) which breaks parsing.
    lines = text.splitlines(True)
    if len(lines) >= 2:
        second = lines[1].strip()
        if second in {"/usr/bin/env bash", "usr/bin/env bash"}:
            del lines[1]
    # Also remove any standalone '/usr/bin/env bash' lines later on.
    out: list[str] = []
    for line in lines:
        if line.strip() in {"/usr/bin/env bash", "usr/bin/env bash"} and not line.startswith("#!"):
            continue
        out.append(line)
    return "".join(out)


def _fix_sudo_split(text: str) -> str:
    # Typical corruption in comments: 'su\ndo' => 'sudo'
    return re.sub(r"su\s*\n\s*do", "sudo", text, flags=re.IGNORECASE)


def _drop_stray_do_lines(text: str) -> str:
    # Some files have a standalone 'do' line near the top (likely from 'ibrido').
    lines = text.split("\n")
    out: list[str] = []
    for i, line in enumerate(lines):
        if i < 40 and line.strip() == "do":
            continue
        out.append(line)
    return "\n".join(out)


def _split_concatenated_control_keywords(text: str) -> str:
    # Common concatenations: 'fi echo', 'fi#', 'thenecho', 'doneecho', etc.
    patterns = [
        (r"\b(fi)(?=echo\b)", r"\\1\n"),
        (r"\b(fi)\s+(?=echo\b)", r"\\1\n"),
        (r"\b(fi)(?=\S)", r"\\1\n"),
    ]
    # The last rule is too aggressive; apply only for fi followed immediately by common commands.
    text = re.sub(r"\bfi(?=(echo|mkdir|cd|cat|read|printf|systemctl|cp|mv|rm|chmod|chown)\b)", "fi\n", text)
    text = re.sub(r"\bthen(?=(echo|mkdir|cd|cat|read|printf|systemctl|cp|mv|rm)\b)", "then\n", text)
    text = re.sub(r"\belse(?=(echo|mkdir|cd|cat|read|printf|systemctl|cp|mv|rm)\b)", "else\n", text)
    text = re.sub(r"\bdone(?=(echo|mkdir|cd|cat|read|printf|systemctl|cp|mv|rm)\b)", "done\n", text)
    text = re.sub(r"\besac(?=(echo|mkdir|cd|cat|read|printf|systemctl|cp|mv|rm)\b)", "esac\n", text)
    return text


def _split_after_quote_before_keyword(text: str) -> str:
    # Fix: NC='\033[0m'clear  => NC='\033[0m'\nclear
    # Fix: ..."..."echo     => ..."..."\necho
    kw = "|".join(map(re.escape, _KW))
    return re.sub(rf"(?<=[\"'])\s*(?=({kw})\\b)", "\n", text)


def _split_function_concatenation(text: str) -> str:
    # Fix: '}print_info() {' => '}\n\nprint_info() {'
    text = re.sub(r"}\s*(?=[A-Za-z_][A-Za-z0-9_]*\s*\(\)\s*{)", "}\n\n", text)
    return text


def _fix_double_assignments(text: str) -> str:
    # Fix obvious typos like FORCEFORCE=0
    text = re.sub(r"\bFORCEFORCE\b", "FORCE", text)
    text = re.sub(r"\bVLEVELVLEVEL\b", "VLEVEL", text)
    text = re.sub(r"\bOUTDIROUTDIR\b", "OUTDIR", text)
    text = re.sub(r"\bFRP_URLFRP_URL\b", "FRP_URL", text)
    return text


def _fix_heredoc_openers(text: str) -> str:
    # Fix: <<'EOF'[Unit]...  => <<'EOF'\n[Unit]...
    # Fix: <<EOF[Unit]...    => <<EOF\n[Unit]...
    text = re.sub(r"<<'EOF'(?=\[)", "<<'EOF'\n", text)
    text = re.sub(r"<<EOF(?=\[)", "<<EOF\n", text)
    text = re.sub(r"<<'EOT'(?=\[)", "<<'EOT'\n", text)
    text = re.sub(r"<<EOT(?=\[)", "<<EOT\n", text)
    return text


def _fix_heredoc_closer_glued(text: str) -> str:
    # Fix: EOFcat => EOF\ncat (and similar)
    text = re.sub(r"\b(EOF|EOT)(?=[A-Za-z_])", r"\\1\n", text)
    return text


def _repair_install_frpc_prompts(text: str) -> str:
    # Specific recurring corruption in install-frpc*.sh: read prompts glued together.
    # Turn patterns like: 'read ...: "\nFRP_URLFRP_URL=${FRP_URL:-...}read ... HOSTNAMEread ... REMOTE_PORT'
    # into three separate read lines and a single assignment.
    text = re.sub(
        r"read\s+-r\s+-p\s+\"URL pacchetto FRP \[default: \$FRP_URL_DEFAULT\]: \"\s*\n?\s*FRP_URL\s*FRP_URL\s*=\s*\$\{FRP_URL:-\$FRP_URL_DEFAULT\}\s*read\s+-r\s+-p\s+\"Nome host \(es: rl94ns8\): \"\s*HOSTNAME\s*read\s+-r\s+-p\s+\"Porta remota da usare: \"\s*REMOTE_PORT",
        "read -r -p \"URL pacchetto FRP [default: $FRP_URL_DEFAULT]: \" FRP_URL\nFRP_URL=${FRP_URL:-$FRP_URL_DEFAULT}\nread -r -p \"Nome host (es: rl94ns8): \" HOSTNAME\nread -r -p \"Porta remota da usare: \" REMOTE_PORT",
        text,
        flags=re.MULTILINE,
    )
    return text


def repair_text(text: str) -> tuple[str, str]:
    original = text
    text = _normalize_line_endings(text)
    text = _remove_stray_env_bash_line(text)
    text = _fix_sudo_split(text)
    text = _drop_stray_do_lines(text)
    text = _fix_double_assignments(text)
    text = _fix_heredoc_openers(text)
    text = _fix_heredoc_closer_glued(text)
    text = _split_function_concatenation(text)
    text = _split_concatenated_control_keywords(text)
    text = _split_after_quote_before_keyword(text)
    text = _repair_install_frpc_prompts(text)

    # Ensure file ends with newline
    if not text.endswith("\n"):
        text += "\n"

    if text == original:
        return text, "no-change"
    return text, "fixed"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--roots",
        nargs="+",
        default=["script-tools", "install/checkmk-installer/scripts/script-tools"],
        help="Root dirs to scan (default: script-tools and installer script-tools)",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    cwd = Path.cwd()
    roots = [cwd / r for r in args.roots]
    files = iter_sh_files(roots)
    if not files:
        print("No .sh files found under roots")
        return 0

    print(f"Found {len(files)} .sh files")

    changed = 0
    for idx, path in enumerate(files, start=1):
        if idx == 1 or idx % 200 == 0:
            print(f"[{idx}/{len(files)}] {path}")
        data = path.read_bytes()
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            # Leave non-utf8 files alone.
            continue

        new_text, reason = repair_text(text)
        if reason == "fixed":
            changed += 1
            if not args.dry_run:
                path.write_text(new_text, encoding="utf-8", newline="\n")

    print(f"Processed: {len(files)}")
    print(f"Changed:   {changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
