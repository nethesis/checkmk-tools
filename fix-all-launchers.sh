#!/usr/bin/env bash
set -euo pipefail

# Script per fixare tutti i launcher remote per usare script locali invece di GitHub

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "Fix di tutti i launcher remote..."
echo

fixed=0
skipped=0

while IFS= read -r launcher; do
  launcher_name=$(basename "$launcher")
  script_name="${launcher_name#r}"

  dir=$(dirname "$launcher")
  full_dir="${dir/\/remote/\/full}"
  full_script="$full_dir/$script_name"

  if [[ ! -f "$full_script" ]]; then
    echo "SKIP: $launcher_name - full script non trovato: $full_script"
    ((skipped++))
    continue
  fi

  if ! grep -q "githubusercontent" "$launcher" 2>/dev/null; then
    echo "OK: $launcher_name - gia fixato o non usa GitHub"
    ((skipped++))
    continue
  fi

  relative_path="${full_script#"$ROOT_DIR"/}"
  deployed_path="/opt/checkmk-tools/$relative_path"

  cat > "$launcher" <<EOF
#!/usr/bin/env bash
set -euo pipefail

# Launcher per $script_name (usa script locale aggiornato da auto-git-sync)
LOCAL_SCRIPT="$deployed_path"

exec "\$LOCAL_SCRIPT" "\$@"
EOF

  chmod +x "$launcher" 2>/dev/null || true
  echo "FIXED: $launcher_name -> $deployed_path"
  ((fixed++))
done < <(find . -path "*/remote/r*.sh" -type f)

echo
echo "Completato"
echo "- $fixed launcher fixati"
echo "- $skipped skip"
