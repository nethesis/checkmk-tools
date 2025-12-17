# Script PowerShell per fixare tutti i launcher

$fixed = 0
$skipped = 0

Write-Host "🔧 Fix di tutti i launcher remote..." -ForegroundColor Cyan
Write-Host ""

# Trova tutti i file r*.sh nelle cartelle remote/
Get-ChildItem -Path . -Recurse -Filter "r*.sh" | Where-Object { $_.Directory.Name -eq "remote" } | ForEach-Object {
    $launcher = $_
    $launcherName = $launcher.Name
    $scriptName = $launcherName.Substring(1)  # rimuove 'r' iniziale
    
    # Path dello script full
    $fullDir = $launcher.Directory.FullName -replace '\\remote$', '\full'
    $fullScript = Join-Path $fullDir $scriptName
    
    # Verifica che lo script full esista
    if (-not (Test-Path $fullScript)) {
        Write-Host "⚠️  Skip $launcherName - script full non trovato" -ForegroundColor Yellow
        $skipped++
        return
    }
    
    # Verifica se usa GitHub
    $content = Get-Content $launcher.FullName -Raw
    if ($content -notmatch "githubusercontent") {
        Write-Host "✓ $launcherName - già fixato" -ForegroundColor Green
        $skipped++
        return
    }
    
    # Calcola path relativo per /opt/checkmk-tools/
    $relativePath = $fullScript -replace [regex]::Escape($PWD.Path + '\'), ''
    $relativePath = $relativePath -replace '\\', '/'
    $deployedPath = "/opt/checkmk-tools/$relativePath"
    
    # Crea nuovo launcher
    $newContent = @"
#!/bin/bash
# Launcher per $scriptName (usa script locale aggiornato da auto-git-sync)

LOCAL_SCRIPT="$deployedPath"

# Esegue lo script locale
exec "`$LOCAL_SCRIPT" "`$@"
"@
    
    Set-Content -Path $launcher.FullName -Value $newContent -NoNewline
    Write-Host "✅ Fixed: $launcherName → $deployedPath" -ForegroundColor Green
    $fixed++
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✅ Completato! $fixed launcher fixati, $skipped già ok/skipped" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
