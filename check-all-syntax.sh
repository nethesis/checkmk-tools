#!/usr/bin/env bash
set -euo pipefail

# Run from the repository root (directory containing this script).
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$SCRIPT_DIR"

for dir in script-check-ns7/full script-check-ns8/full script-check-nsec8/full script-check-proxmox/full script-check-ubuntu/full script-check-windows/full script-tools/full; do
  echo "=== $dir ==="
  fail=0
  ok=0
  for f in "$dir"/*.sh; do
    [[ -f "$f" ]] || continue
    if bash -n "$f" 2>/dev/null; then
      ((ok++))
    else
      echo "  FAIL: ${f##*/}"
      bash -n "$f" 2>&1 | head -2 | sed 's/^/    /'
      ((fail++))
    fi
  done
  echo "  Total: $ok OK, $fail FAIL"
  echo ""
done

echo "============================================"
echo "FINAL SUMMARY"
echo "============================================"
