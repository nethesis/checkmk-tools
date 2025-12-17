# fix-docker-desktop.ps1
# Script per sbloccare Docker Desktop quando WSL non risponde
# Autore: GitHub Copilot
# Data: 24/11/2025

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "║         Docker Desktop - Emergency Unblock Tool         ║" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Verifica permessi amministratore
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "⚠️  ATTENZIONE: Questo script richiede privilegi di amministratore!" -ForegroundColor Yellow
    Write-Host "   Riavvialo come amministratore (tasto destro -> Esegui come amministratore)`n" -ForegroundColor Yellow
    
    $response = Read-Host "Vuoi provarlo comunque? (s/n)"
    if ($response -ne "s") {
        exit
    }
}

Write-Host "🔍 Fase 1: Analisi dello stato attuale..." -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────`n"

# Check Docker Desktop
$dockerProcesses = Get-Process -Name "*Docker Desktop*", "com.docker.*" -ErrorAction SilentlyContinue
if ($dockerProcesses) {
    Write-Host "✓ Docker Desktop è in esecuzione ($($dockerProcesses.Count) processi)" -ForegroundColor Green
} else {
    Write-Host "✗ Docker Desktop non è in esecuzione" -ForegroundColor Yellow
}

# Check servizi Docker
$dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
if ($dockerService) {
    Write-Host "✓ Servizio Docker: $($dockerService.Status)" -ForegroundColor $(if ($dockerService.Status -eq "Running") {"Green"} else {"Yellow"})
}

# Check WSL
$wslService = Get-Service -Name "WSLService" -ErrorAction SilentlyContinue
if ($wslService) {
    Write-Host "✓ Servizio WSL: $($wslService.Status)" -ForegroundColor $(if ($wslService.Status -eq "Running") {"Green"} else {"Yellow"})
}

# Check processi WSL/vmmem
$wslProcesses = Get-Process -Name "wsl*", "vmmem" -ErrorAction SilentlyContinue
if ($wslProcesses) {
    Write-Host "✓ Processi WSL attivi: $($wslProcesses.Count)" -ForegroundColor Green
} else {
    Write-Host "✗ Nessun processo WSL attivo" -ForegroundColor Yellow
}

Write-Host "`n🔧 Fase 2: Avvio procedura di sblocco..." -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────`n"

$response = Read-Host "Vuoi procedere con lo sblocco? (s/n)"
if ($response -ne "s") {
    Write-Host "`n❌ Operazione annullata dall'utente" -ForegroundColor Red
    exit
}

# Step 1: Chiudi Docker Desktop
Write-Host "`n[1/6] Chiusura Docker Desktop..." -ForegroundColor Yellow
Get-Process -Name "*Docker Desktop*", "Docker Desktop", "com.docker.*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Write-Host "      ✓ Completato" -ForegroundColor Green

# Step 2: Termina processi WSL
Write-Host "[2/6] Terminazione processi WSL/vmmem..." -ForegroundColor Yellow
Get-Process -Name "wsl*", "vmmem" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "      ✓ Completato" -ForegroundColor Green

# Step 3: Shutdown WSL
Write-Host "[3/6] Shutdown WSL..." -ForegroundColor Yellow
try {
    $wslShutdown = Start-Process -FilePath "wsl" -ArgumentList "--shutdown" -Wait -PassThru -NoNewWindow -ErrorAction Stop
    if ($wslShutdown.ExitCode -eq 0) {
        Write-Host "      ✓ WSL arrestato correttamente" -ForegroundColor Green
    } else {
        Write-Host "      ⚠ WSL shutdown restituito codice: $($wslShutdown.ExitCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "      ⚠ Impossibile arrestare WSL (potrebbe essere già fermo)" -ForegroundColor Yellow
}
Start-Sleep -Seconds 2

# Step 4: Riavvia servizio WSL
Write-Host "[4/6] Riavvio servizio WSL..." -ForegroundColor Yellow
try {
    Restart-Service -Name "WSLService" -Force -ErrorAction Stop
    Write-Host "      ✓ Servizio WSL riavviato" -ForegroundColor Green
} catch {
    Write-Host "      ⚠ Impossibile riavviare servizio WSL: $($_.Exception.Message)" -ForegroundColor Yellow
}
Start-Sleep -Seconds 3

# Step 5: Riavvia servizio Docker
Write-Host "[5/6] Riavvio servizio Docker..." -ForegroundColor Yellow
try {
    Restart-Service -Name "com.docker.service" -Force -ErrorAction Stop
    Write-Host "      ✓ Servizio Docker riavviato" -ForegroundColor Green
} catch {
    Write-Host "      ⚠ Impossibile riavviare servizio Docker: $($_.Exception.Message)" -ForegroundColor Yellow
}
Start-Sleep -Seconds 3

# Step 6: Avvia Docker Desktop
Write-Host "[6/6] Avvio Docker Desktop..." -ForegroundColor Yellow
$dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (Test-Path $dockerPath) {
    Start-Process -FilePath $dockerPath
    Write-Host "      ✓ Docker Desktop avviato" -ForegroundColor Green
} else {
    Write-Host "      ✗ Docker Desktop non trovato in: $dockerPath" -ForegroundColor Red
    Write-Host "      Avvialo manualmente" -ForegroundColor Yellow
}

Write-Host "`n⏳ Attendo 30 secondi per l'avvio completo di Docker Desktop..." -ForegroundColor Cyan
for ($i = 30; $i -gt 0; $i--) {
    Write-Host -NoNewline "`r   Tempo rimanente: $i secondi  " -ForegroundColor Yellow
    Start-Sleep -Seconds 1
}
Write-Host "`r   ✓ Attesa completata                    " -ForegroundColor Green

Write-Host "`n🔍 Fase 3: Verifica finale..." -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────`n"

# Verifica Docker
Write-Host "Controllo Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
    if ($dockerVersion) {
        Write-Host "✓ Docker Engine: v$dockerVersion" -ForegroundColor Green
    } else {
        throw "Docker non risponde"
    }
} catch {
    Write-Host "✗ Docker Engine non risponde ancora" -ForegroundColor Red
    Write-Host "  Potrebbe aver bisogno di più tempo..." -ForegroundColor Yellow
}

# Verifica WSL
Write-Host "`nControllo WSL..." -ForegroundColor Yellow
try {
    $wslStatus = wsl --status 2>&1 | Out-String
    if ($wslStatus -match "Versione predefinita") {
        Write-Host "✓ WSL funzionante" -ForegroundColor Green
    } else {
        Write-Host "⚠ WSL potrebbe non essere completamente avviato" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ WSL non risponde" -ForegroundColor Red
}

# Verifica container
Write-Host "`nControllo container..." -ForegroundColor Yellow
try {
    $containers = docker ps -a --format "{{.Names}}: {{.Status}}" 2>$null
    if ($containers) {
        Write-Host "✓ Container disponibili:" -ForegroundColor Green
        $containers | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }
    } else {
        Write-Host "⚠ Nessun container trovato" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Impossibile elencare i container" -ForegroundColor Red
}

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                          ║" -ForegroundColor Green
Write-Host "║              ✓ Procedura completata!                    ║" -ForegroundColor Green
Write-Host "║                                                          ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "💡 Suggerimenti:" -ForegroundColor Cyan
Write-Host "   - Se Docker non risponde, attendi altri 30-60 secondi"
Write-Host "   - Se il problema persiste, prova: Restart-Computer"
Write-Host "   - Per avviare container: docker start <nome-container>"
Write-Host "   - Per connettersi: docker exec -it <nome-container> bash`n"

# Opzione pulizia
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║                   Pulizia Memoria                        ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Magenta

$cleanup = Read-Host "Vuoi liberare memoria Docker? (s/n)"
if ($cleanup -eq "s") {
    Write-Host "`n🧹 Avvio pulizia Docker..." -ForegroundColor Yellow
    
    # Container fermi
    Write-Host "`n[1/4] Rimozione container fermi..." -ForegroundColor Cyan
    $stoppedContainers = docker ps -a -f "status=exited" --format "{{.Names}}" 2>$null
    if ($stoppedContainers) {
        Write-Host "      Container da rimuovere:" -ForegroundColor Yellow
        $stoppedContainers | ForEach-Object { Write-Host "        - $_" -ForegroundColor Gray }
        docker container prune -f 2>$null | Out-Null
        Write-Host "      ✓ Container fermi rimossi" -ForegroundColor Green
    } else {
        Write-Host "      ✓ Nessun container fermo da rimuovere" -ForegroundColor Green
    }
    
    # Immagini dangling
    Write-Host "`n[2/4] Rimozione immagini dangling..." -ForegroundColor Cyan
    $danglingImages = docker images -f "dangling=true" -q 2>$null
    if ($danglingImages) {
        docker image prune -f 2>$null | Out-Null
        Write-Host "      ✓ Immagini dangling rimosse" -ForegroundColor Green
    } else {
        Write-Host "      ✓ Nessuna immagine dangling" -ForegroundColor Green
    }
    
    # Build cache
    Write-Host "`n[3/4] Pulizia build cache..." -ForegroundColor Cyan
    docker builder prune -f 2>$null | Out-Null
    Write-Host "      ✓ Build cache pulita" -ForegroundColor Green
    
    # Volumi inutilizzati
    Write-Host "`n[4/4] Rimozione volumi inutilizzati..." -ForegroundColor Cyan
    docker volume prune -f 2>$null | Out-Null
    Write-Host "      ✓ Volumi inutilizzati rimossi" -ForegroundColor Green
    
    Write-Host "`n✓ Pulizia completata!" -ForegroundColor Green
    
    # Mostra spazio liberato
    Write-Host "`n📊 Stato attuale:" -ForegroundColor Cyan
    try {
        $diskUsage = docker system df 2>$null
        if ($diskUsage) {
            Write-Host $diskUsage -ForegroundColor Gray
        }
    } catch {
        Write-Host "   Impossibile ottenere statistiche" -ForegroundColor Yellow
    }
}

Write-Host "`n"

# Opzione avvio container
$startContainer = Read-Host "Vuoi avviare un container? (nome o 'n' per uscire)"
if ($startContainer -ne "n" -and $startContainer -ne "") {
    Write-Host "`nAvvio container '$startContainer'..." -ForegroundColor Yellow
    try {
        docker start $startContainer
        Write-Host "✓ Container '$startContainer' avviato" -ForegroundColor Green
        
        $connect = Read-Host "`nVuoi connetterti al container? (s/n)"
        if ($connect -eq "s") {
            docker exec -it $startContainer bash
        }
    } catch {
        Write-Host "✗ Errore nell'avvio del container: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n👋 Arrivederci!`n" -ForegroundColor Cyan
