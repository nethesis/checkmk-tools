# Script di Backup Completo Repository CheckMK-Tools
# Backup locale + opzionale su \\192.168.10.132\usbshare

$ErrorActionPreference = "Stop"

$REPO_PATH = "C:\Users\Marzio\OneDrive\Desktop\CheckMK\Script"
$LOCAL_BACKUP_BASE = "C:\CheckMK-Backups"
$NETWORK_BACKUP_BASE = "\\192.168.10.132\usbshare\CheckMK-Backups"
$TIMESTAMP = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LOCAL_BACKUP_PATH = Join-Path $LOCAL_BACKUP_BASE $TIMESTAMP
$NETWORK_BACKUP_PATH = Join-Path $NETWORK_BACKUP_BASE $TIMESTAMP

Write-Host "`n╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     📦 BACKUP COMPLETO REPOSITORY CHECKMK-TOOLS      ║" -ForegroundColor White
Write-Host "╚═══════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "📁 Repository locale: $REPO_PATH" -ForegroundColor Gray
Write-Host "💾 Backup locale: $LOCAL_BACKUP_PATH" -ForegroundColor Gray
Write-Host "🌐 Backup rete (opzionale): $NETWORK_BACKUP_PATH`n" -ForegroundColor Gray

# Crea cartella backup locale
Write-Host "📂 Creazione cartella backup locale..." -ForegroundColor Yellow
if (-not (Test-Path $LOCAL_BACKUP_BASE)) {
    New-Item -ItemType Directory -Path $LOCAL_BACKUP_BASE -Force | Out-Null
}
New-Item -ItemType Directory -Path $LOCAL_BACKUP_PATH -Force | Out-Null
Write-Host "✓ Cartella creata: $LOCAL_BACKUP_PATH`n" -ForegroundColor Green

# Funzione per copiare file
function Copy-BackupFiles {
    param(
        [string]$DestinationPath
    )
    
    Write-Host "📋 Copia file verso $DestinationPath..." -ForegroundColor Yellow
    
    $excludeDirs = @('.git', 'node_modules', '.vagrant', 'obj', 'bin')
    $excludeFiles = @('*.log', '*.tmp', '*.cache', 'Thumbs.db', '.DS_Store')

    $itemsToCopy = Get-ChildItem -Path $REPO_PATH -Recurse | Where-Object {
        $item = $_
        $exclude = $false
        
        # Escludi directory
        foreach ($dir in $excludeDirs) {
            if ($item.FullName -match [regex]::Escape("\$dir\")) {
                $exclude = $true
                break
            }
        }
        
        # Escludi file temporanei
        if (-not $exclude -and $item -is [System.IO.FileInfo]) {
            foreach ($pattern in $excludeFiles) {
                if ($item.Name -like $pattern) {
                    $exclude = $true
                    break
                }
            }
        }
        
        return -not $exclude
    }

    $totalItems = $itemsToCopy.Count
    $copied = 0

    foreach ($item in $itemsToCopy) {
        $relativePath = $item.FullName.Substring($REPO_PATH.Length + 1)
        $destPath = Join-Path $DestinationPath $relativePath
        
        if ($item.PSIsContainer) {
            New-Item -ItemType Directory -Path $destPath -Force -ErrorAction SilentlyContinue | Out-Null
        } else {
            $destDir = Split-Path $destPath -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -Path $item.FullName -Destination $destPath -Force
            $copied++
            
            if ($copied % 50 -eq 0) {
                Write-Host "  Copiati $copied / $totalItems file..." -ForegroundColor Cyan
            }
        }
    }

    Write-Host "✓ Completato: $copied file copiati`n" -ForegroundColor Green
    return $copied
}

# Backup locale
$localCopied = Copy-BackupFiles -DestinationPath $LOCAL_BACKUP_PATH

# Backup su rete (opzionale con timeout)
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║          🌐 BACKUP SU RETE (OPZIONALE)               ║" -ForegroundColor White
Write-Host "╚═══════════════════════════════════════════════════════╝`n" -ForegroundColor Yellow

Write-Host "Vuoi eseguire il backup anche su $NETWORK_BACKUP_BASE?" -ForegroundColor Cyan
Write-Host "Premi 's' entro 15 secondi per confermare..." -ForegroundColor Yellow

$timeout = 15
$elapsed = 0
$response = $null

while ($elapsed -lt $timeout -and -not $response) {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.KeyChar -eq 's' -or $key.KeyChar -eq 'S') {
            $response = 's'
        } else {
            $response = 'n'
        }
    }
    Start-Sleep -Milliseconds 100
    $elapsed += 0.1
    
    if ([math]::Floor($elapsed) % 5 -eq 0 -and ($elapsed - [math]::Floor($elapsed)) -lt 0.2) {
        Write-Host "." -NoNewline -ForegroundColor Gray
    }
}

Write-Host ""

$networkCopied = 0
if ($response -eq 's') {
    Write-Host "✓ Backup su rete confermato`n" -ForegroundColor Green
    
    # Verifica connessione rete
    Write-Host "🔍 Verifica connessione rete..." -ForegroundColor Yellow
    if (-not (Test-Path $NETWORK_BACKUP_BASE)) {
        Write-Host "✗ Impossibile accedere a $NETWORK_BACKUP_BASE" -ForegroundColor Red
        Write-Host "  Backup locale completato, rete saltata`n" -ForegroundColor Yellow
    } else {
        Write-Host "✓ Connessione OK`n" -ForegroundColor Green
        
        # Crea cartella backup rete
        New-Item -ItemType Directory -Path $NETWORK_BACKUP_PATH -Force | Out-Null
        
        # Esegui backup rete
        $networkCopied = Copy-BackupFiles -DestinationPath $NETWORK_BACKUP_PATH
    }
} else {
    Write-Host "⊗ Backup su rete saltato (timeout o rifiutato)`n" -ForegroundColor Gray
}

# Statistiche
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              📊 STATISTICHE BACKUP                    ║" -ForegroundColor White
Write-Host "╚═══════════════════════════════════════════════════════╝`n" -ForegroundColor Green

$localSize = (Get-ChildItem -Path $LOCAL_BACKUP_PATH -Recurse -File | Measure-Object -Property Length -Sum).Sum
$localSizeMB = [math]::Round($localSize / 1MB, 2)

Write-Host "📦 BACKUP LOCALE:" -ForegroundColor Cyan
Write-Host "   File copiati:     $localCopied" -ForegroundColor White
Write-Host "   Dimensione:       $localSizeMB MB" -ForegroundColor White
Write-Host "   Percorso:         $LOCAL_BACKUP_PATH`n" -ForegroundColor White

if ($networkCopied -gt 0) {
    $networkSize = (Get-ChildItem -Path $NETWORK_BACKUP_PATH -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $networkSizeMB = [math]::Round($networkSize / 1MB, 2)
    
    Write-Host "🌐 BACKUP RETE:" -ForegroundColor Cyan
    Write-Host "   File copiati:     $networkCopied" -ForegroundColor White
    Write-Host "   Dimensione:       $networkSizeMB MB" -ForegroundColor White
    Write-Host "   Percorso:         $NETWORK_BACKUP_PATH`n" -ForegroundColor White
}

Write-Host "⏰ Timestamp:        $TIMESTAMP`n" -ForegroundColor Cyan

# Conta backup precedenti locali
$previousBackups = Get-ChildItem -Path $LOCAL_BACKUP_BASE -Directory | 
    Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$' } |
    Sort-Object Name -Descending

Write-Host "📚 Backup locali disponibili: $($previousBackups.Count)" -ForegroundColor Gray

if ($previousBackups.Count -gt 20) {
    Write-Host "⚠️  Hai più di 20 backup locali, considera di eliminare quelli vecchi`n" -ForegroundColor Yellow
}
Write-Host "📚 Backup totali disponibili: $($previousBackups.Count)" -ForegroundColor Gray

if ($previousBackups.Count -gt 20) {
    Write-Host "⚠️  Hai più di 20 backup, considera di eliminare quelli vecchi`n" -ForegroundColor Yellow
}

Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          ✓ BACKUP COMPLETATO CON SUCCESSO ✓          ║" -ForegroundColor White
Write-Host "╚═══════════════════════════════════════════════════════╝`n" -ForegroundColor Green
