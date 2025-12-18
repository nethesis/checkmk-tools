#!/usr/bin/env python3
"""Fix common mojibake caused by: UTF-8 text opened as CP437 and saved back as UTF-8.

Symptom examples in repo:
- "modalit├á" instead of "modalità"
- box/emoji strings becoming sequences like "ÔòöÔòÉ..."

The reverse operation is: take current Unicode text, encode it as CP437 bytes,
then treat those bytes as the intended UTF-8 file bytes.

This script rewrites files in-place (after making a .bak next to each file).
"""

from __future__ import annotations

import argparse
from pathlib import Path
import unicodedata


def iter_files(roots: list[Path], patterns: list[str]) -> list[Path]:
    out: list[Path] = []
    for root in roots:
        if not root.exists():
            continue
        for pattern in patterns:
            out.extend(root.rglob(pattern))
    # Stable order for repeatability
    return sorted({p for p in out if p.is_file()})


def is_probably_text(data: bytes) -> bool:
    # Heuristic: reject binaries with NUL bytes
    return b"\x00" not in data


def _try_cp437_roundtrip(text: str) -> bytes | None:
    """Strict cp437 encode -> bytes, expecting bytes to be valid UTF-8."""
    try:
        raw = text.encode("cp437")
    except UnicodeEncodeError:
        return None
    try:
        raw.decode("utf-8")
    except UnicodeDecodeError:
        return None
    return raw


def _hybrid_recover_bytes(text: str) -> bytes | None:
    """Hybrid recovery for mixed-content files.

    For each non-ASCII char:
    - if it can be encoded as cp437 (typical mojibake glyphs like '├', 'á', 'Ô', ...),
      emit the cp437 byte (which usually is the original UTF-8 byte)
    - otherwise, keep the character as real UTF-8 bytes.

    This avoids skipping files that contain a mix of mojibake and legit Unicode.
    """
    out = bytearray()
    for ch in text:
        codepoint = ord(ch)
        if codepoint <= 0x7F:
            out.append(codepoint)
            continue

        try:
            b = ch.encode("cp437")
        except UnicodeEncodeError:
            out.extend(ch.encode("utf-8"))
            continue

        # cp437 encoding always yields a single byte for a single character
        if len(b) == 1:
            out.extend(b)
        else:
            out.extend(ch.encode("utf-8"))

    raw = bytes(out)
    try:
        raw.decode("utf-8")
    except UnicodeDecodeError:
        return None
    return raw


def _to_ascii_bytes(utf8_bytes: bytes) -> bytes:
    """Convert UTF-8 bytes to ASCII-only bytes (best-effort).

    Goal: stop unreadable glyphs in terminals/locales that can’t render UTF-8 well.
    """
    text = utf8_bytes.decode("utf-8", errors="replace")

    # Replace common UI glyphs before stripping accents.
    table = str.maketrans(
        {
            "╔": "+",
            "╗": "+",
            "╚": "+",
            "╝": "+",
            "═": "=",
            "║": "|",
            "•": "-",
            "→": "->",
            "✓": "OK",
            "✅": "OK",
            "✗": "ERR",
            "⚠": "WARN",
        }
    )
    text = text.translate(table)

    # Strip accents/diacritics and drop any remaining non-ascii.
    text = unicodedata.normalize("NFKD", text)
    ascii_bytes = text.encode("ascii", errors="ignore")
    return ascii_bytes


def fix_bytes_cp437_saved_utf8(data: bytes, *, ascii_only: bool) -> tuple[bytes, str] | tuple[None, str]:
    """Return (fixed_bytes, reason) or (None, reason)."""
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        return None, f"skip: not utf-8 ({exc})"

    # If the user explicitly wants ASCII-only output, do it even when there is no mojibake.
    if ascii_only:
        ascii_bytes = _to_ascii_bytes(data)
        if ascii_bytes != data:
            if not ascii_bytes.endswith(b"\n"):
                ascii_bytes += b"\n"
            return ascii_bytes, "ascii-only"

    raw = _try_cp437_roundtrip(text)
    if raw is None:
        raw = _hybrid_recover_bytes(text)
        if raw is None:
            return None, "skip: cannot recover"

    if raw == data:
        return None, "skip: no change"

    # Normalize final newline (common in scripts)
    if not raw.endswith(b"\n"):
        raw += b"\n"

    return raw, "fixed"


def main() -> int:
    parser = argparse.ArgumentParser(description="Fix CP437-saved UTF-8 mojibake in-place")
    parser.add_argument(
        "roots",
        nargs="*",
        default=["script-tools", "install/checkmk-installer/scripts/script-tools"],
        help="Root directories to scan (default: script-tools and installer script-tools)",
    )
    parser.add_argument(
        "--patterns",
        nargs="+",
        default=["*.sh"],
        help="Glob patterns to include (default: *.sh)",
    )
    parser.add_argument(
        "--ascii",
        action="store_true",
        help="After recovery, rewrite files as ASCII-only (drops accents/emoji/box drawing)",
    )
    parser.add_argument("--no-backup", action="store_true", help="Do not create .bak files")
    args = parser.parse_args()

    workspace = Path.cwd()
    roots = [workspace / r for r in args.roots]

    files = iter_files(roots, args.patterns)
    if not files:
        print("No files matched.")
        return 0

    changed = 0
    skipped = 0
    failed = 0

    for path in files:
        data = path.read_bytes()
        if not is_probably_text(data):
            skipped += 1
            continue

        fixed, reason = fix_bytes_cp437_saved_utf8(data, ascii_only=args.ascii)
        if fixed is None:
            if reason.startswith("skip:"):
                skipped += 1
            else:
                skipped += 1
            continue

        try:
            if not args.no_backup:
                bak = path.with_suffix(path.suffix + ".bak")
                if not bak.exists():
                    bak.write_bytes(data)
            path.write_bytes(fixed)
            changed += 1
        except OSError as exc:
            failed += 1
            print(f"ERROR writing {path}: {exc}")

    print(f"Processed: {len(files)}")
    print(f"Changed:   {changed}")
    print(f"Skipped:   {skipped}")
    print(f"Failed:    {failed}")

    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
