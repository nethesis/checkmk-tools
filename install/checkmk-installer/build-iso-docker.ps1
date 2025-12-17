# Script per Build ISO con Docker Desktop
# Windows PowerShell

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  CheckMK Installer - Build ISO con Docker     " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $SCRIPT_DIR

# Verifica che Docker sia in esecuzione
Write-Host "Verifica Docker Desktop..." -ForegroundColor Yellow
try {
    docker version | Out-Null
    Write-Host "✓ Docker Desktop è in esecuzione" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker Desktop non è in esecuzione!" -ForegroundColor Red
    Write-Host "  Avvia Docker Desktop e riprova." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Build dell'immagine Docker
Write-Host "Building Docker image..." -ForegroundColor Yellow
docker build -t checkmk-iso-builder .

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Errore durante la build dell'immagine Docker" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Immagine Docker creata con successo" -ForegroundColor Green
Write-Host ""

# Esegui il container
Write-Host "Avvio container per generare ISO..." -ForegroundColor Yellow
Write-Host "Questo processo richiederà:" -ForegroundColor Cyan
Write-Host "  - Download Ubuntu 24.04.3 ISO (~3.1 GB)" -ForegroundColor White
Write-Host "  - Spazio disco: ~10 GB" -ForegroundColor White
Write-Host "  - Tempo: 10-20 minuti" -ForegroundColor White
Write-Host ""

$confirm = Read-Host "Continuare? (Y/N)"
if ($confirm -ne "Y" -and $confirm -ne "y") {
    Write-Host "Operazione annullata." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Generazione ISO in corso..." -ForegroundColor Cyan
Write-Host ""

# Esegui make-iso.sh nel container
docker run --rm `
    --privileged `
    -v "${SCRIPT_DIR}:/build" `
    checkmk-iso-builder `
    bash -c "cd /build && ./make-iso.sh"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "  ✓ ISO generata con successo!                 " -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "L'ISO si trova in:" -ForegroundColor Cyan
    Write-Host "  $SCRIPT_DIR\iso-output\checkmk-installer-v1.0-amd64.iso" -ForegroundColor White
    Write-Host ""
    Write-Host "Per scrivere su USB, usa Rufus o Balena Etcher" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "✗ Errore durante la generazione dell'ISO" -ForegroundColor Red
    Write-Host "Controlla i log sopra per maggiori dettagli." -ForegroundColor Yellow
}
