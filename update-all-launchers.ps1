# Script per aggiornare tutti i launcher remote con il formato corretto (cache buster + temp file)
$ErrorActionPreference = "Stop"

# Trova tutti i file .sh nelle cartelle remote/
$launchers = Get-ChildItem -Path "." -Filter "*.sh" -Recurse | Where-Object { $_.DirectoryName -match '\\remote$' }

Write-Host "`nTrovati $($launchers.Count) launcher da aggiornare" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$updated = 0
$skipped = 0
$errors = 0

foreach ($launcher in $launchers) {
    try {
        $content = Get-Content $launcher.FullName -Raw -ErrorAction Stop
        
        # Skip se già aggiornato (contiene TIMESTAMP e mktemp)
        if ($content -match 'TIMESTAMP=\$\(date \+%s\)' -and $content -match 'mktemp') {
            Write-Host "  ✓ $($launcher.Name) già aggiornato" -ForegroundColor Gray
            $skipped++
            continue
        }
        
        # Estrai il path dello script full/ dalla versione corrente
        $scriptPath = ""
        if ($content -match 'LOCAL_SCRIPT="([^"]+)"') {
            $scriptPath = $matches[1]
        } elseif ($content -match 'FULL_DIR="[^"]+"\s+exec "\$FULL_DIR/([^"]+)"') {
            # Per i launcher che usano FULL_DIR
            $parentDir = Split-Path -Parent $launcher.DirectoryName
            $scriptName = $matches[1]
            $scriptPath = "/opt/checkmk-tools/$((Split-Path -Leaf $parentDir))/full/$scriptName"
        } else {
            Write-Host "  ⚠️  $($launcher.Name) - formato non riconosciuto" -ForegroundColor Yellow
            $skipped++
            continue
        }
        
        # Estrai il nome dello script (ultima parte del path)
        $scriptName = Split-Path -Leaf $scriptPath
        
        # Converti path locale in GitHub URL
        # /opt/checkmk-tools/script-check-proxmox/full/check-xxx.sh
        # diventa: script-check-proxmox/full/check-xxx.sh
        $githubPath = $scriptPath -replace '^/opt/checkmk-tools/', ''
        
        # Crea il nuovo contenuto
$newContent = @"
#!/bin/bash
# Launcher remoto per $scriptName - scarica ed esegue da GitHub

# Cache buster per forzare download nuova versione
TIMESTAMP=`$(date +%s)
GITHUB_RAW_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/$githubPath?v=`${TIMESTAMP}"

# Scarica in file temporaneo ed esegui
TEMP_SCRIPT=`$(mktemp)
curl -fsSL "`$GITHUB_RAW_URL" -o "`$TEMP_SCRIPT"
bash "`$TEMP_SCRIPT" "`$@"
EXIT_CODE=`$?
rm -f "`$TEMP_SCRIPT"
exit `$EXIT_CODE
"@
        
        # Scrivi il nuovo contenuto
        Set-Content -Path $launcher.FullName -Value $newContent -NoNewline -Encoding UTF8
        Write-Host "  ✓ $($launcher.Name)" -ForegroundColor Green
        $updated++
        
    } catch {
        Write-Host "  ✗ $($launcher.Name) - Errore: $_" -ForegroundColor Red
        $errors++
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Aggiornati: $updated" -ForegroundColor Green
Write-Host "Saltati: $skipped" -ForegroundColor Gray
Write-Host "Errori: $errors" -ForegroundColor Red
