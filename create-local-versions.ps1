# Crea versioni local di tutti gli script Proxmox
# Le versioni local non hanno echo "<<<local>>>" e hanno suffisso -local

$fullDir = "c:\Users\Marzio\Desktop\CheckMK\checkmk-tools\script-check-proxmox\full"
$localDir = "c:\Users\Marzio\Desktop\CheckMK\checkmk-tools\script-check-proxmox\local"
$remoteDir = "c:\Users\Marzio\Desktop\CheckMK\checkmk-tools\script-check-proxmox\remote"

# Crea directory local se non esiste
if (!(Test-Path $localDir)) {
    New-Item -ItemType Directory -Path $localDir | Out-Null
}

# Lista script da convertire
$scripts = Get-ChildItem "$fullDir\check-proxmox*.sh"

foreach ($script in $scripts) {
    $basename = $script.BaseName
    $localName = "$basename-local.sh"
    $localPath = Join-Path $localDir $localName
    
    Write-Host "Creando $localName..." -ForegroundColor Cyan
    
    # Leggi contenuto e rimuovi echo "<<<local>>>"
    $content = Get-Content $script.FullName -Raw
    $content = $content -replace 'echo "<<<local>>>"[\r\n]+', ''
    
    # Salva versione local con line ending Unix
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($localPath, ($content -replace "`r`n", "`n"), $utf8NoBom)
    
    # Crea launcher per local
    $launcherName = "l$basename.sh" -replace 'check-proxmox', 'check-proxmox'
    $launcherPath = Join-Path $remoteDir $launcherName
    
    $launcherContent = @"
#!/bin/bash
# Launcher LOCAL per $basename - scarica ed esegue da GitHub

# Cache buster per forzare download nuova versione
TIMESTAMP=`$(date +%s)
GITHUB_RAW_URL="https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-proxmox/local/$localName?v=`${TIMESTAMP}"

# Scarica in file temporaneo ed esegui (timeout 60s)
TEMP_SCRIPT=`$(mktemp)
curl -fsSL "`$GITHUB_RAW_URL" -o "`$TEMP_SCRIPT"
timeout 60s bash "`$TEMP_SCRIPT" "`$@"
EXIT_CODE=`$?
rm -f "`$TEMP_SCRIPT"
exit `$EXIT_CODE
"@
    
    # Salva launcher con line ending Unix
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($launcherPath, ($launcherContent -replace "`r`n", "`n"), $utf8NoBom)
    
    # Rendi eseguibile lo script tramite WSL
    wsl bash -c "chmod +x '$($launcherPath -replace '\\','/' -replace 'C:/','c:/' -replace 'c:/','c:/' -replace '^c:','/mnt/c')'" | Out-Null
    
    Write-Host "  Creato launcher: $launcherName" -ForegroundColor Green
}

Write-Host "`nCreati $(($scripts | Measure-Object).Count) script local e launcher" -ForegroundColor Green
