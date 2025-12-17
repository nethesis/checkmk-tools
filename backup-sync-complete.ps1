# Script di Backup Completo Repository CheckMK-Tools
# Sincronizza repository locale con backup su \\192.168.10.132\usbshare

$ErrorActionPreference = "Stop"

$REPO_PATH = "C:\Users\Marzio\OneDrive\Desktop\CheckMK\Script"
$BACKUP_BASE = "\\192.168.10.132\usbshare\CheckMK-Backups"
$TIMESTAMP = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$BACKUP_PATH = Join-Path $BACKUP_BASE $TIMESTAMP

Write-Host "`n╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     📦 BACKUP COMPLETO REPOSITORY CHECKMK-TOOLS      ║" -ForegroundColor White
Write-Host "╚═══════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "📁 Repository locale: $REPO_PATH" -ForegroundColor Gray
Write-Host "💾 Destinazione backup: $BACKUP_PATH`n" -ForegroundColor Gray

# Verifica connessione rete
Write-Host "🔍 Verifica connessione rete..." -ForegroundColor Yellow
if (-not (Test-Path $BACKUP_BASE)) {
    Write-Host "✗ Errore: impossibile accedere a $BACKUP_BASE" -ForegroundColor Red
    Write-Host "  Verifica che il NAS sia raggiungibile e condivisione montata`n" -ForegroundColor Yellow
    exit 1
}
Write-Host "✓ Connessione OK`n" -ForegroundColor Green

# Crea cartella backup
Write-Host "📂 Creazione cartella backup..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $BACKUP_PATH -Force | Out-Null
Write-Host "✓ Cartella creata: $BACKUP_PATH`n" -ForegroundColor Green

# Copia file (escludi .git, node_modules, e file temporanei)
Write-Host "📋 Copia file in corso..." -ForegroundColor Yellow
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
    $destPath = Join-Path $BACKUP_PATH $relativePath
    
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

Write-Host "✓ Backup completato: $copied file copiati`n" -ForegroundColor Green

# Statistiche
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              📊 STATISTICHE BACKUP                    ║" -ForegroundColor White
Write-Host "╚═══════════════════════════════════════════════════════╝`n" -ForegroundColor Green

$backupSize = (Get-ChildItem -Path $BACKUP_PATH -Recurse -File | Measure-Object -Property Length -Sum).Sum
$backupSizeMB = [math]::Round($backupSize / 1MB, 2)

Write-Host "📦 File copiati:     $copied" -ForegroundColor Cyan
Write-Host "💾 Dimensione totale: $backupSizeMB MB" -ForegroundColor Cyan
Write-Host "📁 Percorso backup:  $BACKUP_PATH" -ForegroundColor Cyan
Write-Host "⏰ Timestamp:        $TIMESTAMP`n" -ForegroundColor Cyan

# Conta backup precedenti
$previousBackups = Get-ChildItem -Path $BACKUP_BASE -Directory | 
    Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$' } |
    Sort-Object Name -Descending

Write-Host "📚 Backup totali disponibili: $($previousBackups.Count)" -ForegroundColor Gray

if ($previousBackups.Count -gt 20) {
    Write-Host "⚠️  Hai più di 20 backup, considera di eliminare quelli vecchi`n" -ForegroundColor Yellow
}

Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          ✓ BACKUP COMPLETATO CON SUCCESSO ✓          ║" -ForegroundColor White
Write-Host "╚═══════════════════════════════════════════════════════╝`n" -ForegroundColor Green
