<#
.SYNOPSIS
  Installazione interattiva di frpc (FRP client) su Windows come servizio.

.DESCRIPTION
  - Abilita esecuzione script (Process=BYPASS, tenta CurrentUser=RemoteSigned)
  - Download frpc v0.64.0 da GitHub
  - Installazione in C:\Program Files\frp
  - Config frpc.toml stile [common] + [hostname]
  - Registrazione servizio Windows "frpc"
  - Avvio automatico e immediato del servizio

.REQUIREMENTS
  PowerShell 5.1+, Windows 64-bit, privilegi amministratore
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

# ===============================
# Config fissa
# ===============================
$FrpVersion  = "0.64.0"
$NssmVersion = "2.24"
$InstallPath = "C:\Program Files\frp"
$FrpcExePath = Join-Path $InstallPath "frpc.exe"
$NssmExePath = Join-Path $InstallPath "nssm.exe"
$ConfigPath  = Join-Path $InstallPath "frpc.toml"
$ServiceName = "frpc"

$DownloadUrl = "https://github.com/fatedier/frp/releases/download/v$FrpVersion/frp_${FrpVersion}_windows_amd64.zip"
$NssmDownloadUrl = "https://nssm.cc/release/nssm-$NssmVersion.zip"
$TempDir     = Join-Path $env:TEMP ("frp-install-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

# ===============================
# Utility
# ===============================
function Write-Log {
  param(
    [string]$Message,
    [ValidateSet("INFO","WARN","ERROR","OK")] [string]$Level = "INFO"
  )
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $color = switch ($Level) {
    "ERROR" { "Red" }
    "WARN"  { "Yellow" }
    "OK"    { "Green" }
    default { "White" }
  }
  Write-Host "[$ts] [$Level] $Message" -ForegroundColor $color
}

function Test-Administrator {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-ExecutionPolicy {
  try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    Write-Log "ExecutionPolicy Process=BYPASS (solo questa sessione)" "OK"
  } catch {
    Write-Log "Impossibile impostare ExecutionPolicy Process" "WARN"
  }

  try {
    $cu = Get-ExecutionPolicy -Scope CurrentUser
    if ($cu -eq "Undefined" -or $cu -eq "Restricted") {
      Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
      Write-Log "ExecutionPolicy CurrentUser=RemoteSigned" "OK"
    }
  } catch {
    Write-Log "ExecutionPolicy CurrentUser non modificabile (GPO?)" "WARN"
    Write-Log "In futuro usa: powershell -ExecutionPolicy Bypass -File <script>" "WARN"
  }
}

function Read-NonEmpty($Prompt) {
  do { $v = Read-Host $Prompt } while ([string]::IsNullOrWhiteSpace($v))
  return $v.Trim()
}

function Read-Int($Prompt) {
  while ($true) {
    $v = Read-Host $Prompt
    if ([int]::TryParse($v, [ref]$null) -and $v -ge 1 -and $v -le 65535) {
      return [int]$v
    }
    Write-Log "Porta non valida (1-65535)" "WARN"
  }
}

function Stop-And-Remove-Service {
  if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
    Write-Log "Rimozione servizio esistente '$ServiceName'" "WARN"
    try { Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue } catch {}
    & sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
  }
}

function Add-DefenderExclusion {
  Write-Log "Configurazione esclusioni Windows Defender..." "INFO"
  
  try {
    # Aggiungi esclusione per directory
    Add-MpPreference -ExclusionPath $InstallPath -ErrorAction Stop
    Write-Log "Esclusione path aggiunta: $InstallPath" "OK"
    
    # Aggiungi esclusione per eseguibile
    Add-MpPreference -ExclusionPath $FrpcExePath -ErrorAction Stop
    Write-Log "Esclusione exe aggiunta: $FrpcExePath" "OK"
    
    # Aggiungi esclusione per processo
    Add-MpPreference -ExclusionProcess "frpc.exe" -ErrorAction Stop
    Write-Log "Esclusione processo aggiunta: frpc.exe" "OK"
    
    # CRITICO: Whitelist ThreatID specifico per frpc (Trojan:Win32/Kepavll!rfn)
    try {
      Add-MpPreference -ThreatIDDefaultAction_Ids 2147939874 -ThreatIDDefaultAction_Actions Allow -Force -ErrorAction Stop
      Write-Log "ThreatID 2147939874 (frpc) whitelisted" "OK"
    } catch {
      Write-Log "Impossibile whitelist ThreatID: $($_.Exception.Message)" "WARN"
    }
    
    return $true
  } catch {
    Write-Log "Impossibile configurare esclusioni Defender: $($_.Exception.Message)" "WARN"
    Write-Log "Aggiungi manualmente con: Add-MpPreference -ExclusionPath '$InstallPath'" "WARN"
    return $false
  }
}

function Test-FrpcExecution {
  Write-Log "Test esecuzione frpc.exe per verificare Defender..." "INFO"
  
  try {
    # Testa frpc.exe manualmente con --version
    $result = & $FrpcExePath --version 2>&1
    Write-Log "Test OK: $result" "OK"
    return $true
  } catch {
    Write-Log "ERRORE test esecuzione: $($_.Exception.Message)" "ERROR"
    Write-Log "Defender potrebbe bloccare l'esecuzione di frpc.exe" "WARN"
    return $false
  }
}

function Test-DefenderBlocked {
  if (-not (Test-Path $FrpcExePath)) {
    Write-Log "" "ERROR"
    Write-Log "========================================" "ERROR"
    Write-Log "WINDOWS DEFENDER HA BLOCCATO FRPC.EXE!" "ERROR"
    Write-Log "========================================" "ERROR"
    Write-Log "" "INFO"
    Write-Log "STEP 1: Ripristina il file bloccato" "WARN"
    Write-Log "  1. Premi Win + I (Impostazioni Windows)" "INFO"
    Write-Log "  2. Vai a: Privacy e sicurezza > Sicurezza di Windows" "INFO"
    Write-Log "  3. Clicca: Protezione da virus e minacce" "INFO"
    Write-Log "  4. Scorri fino a 'Cronologia protezione'" "INFO"
    Write-Log "  5. Cerca 'frpc.exe' e clicca 'Consenti'" "INFO"
    Write-Log "" "INFO"
    Write-Log "STEP 2: Verifica esclusione" "WARN"
    Write-Log "  Esegui: Get-MpPreference | Select-Object -ExpandProperty ExclusionPath" "INFO"
    Write-Log "  Deve contenere: $InstallPath" "INFO"
    Write-Log "" "INFO"
    Write-Log "STEP 3: Rilancia questo script" "WARN"
    Write-Log "  .\install-frpc-pc.ps1" "INFO"
    Write-Log "" "INFO"
    Write-Log "ALTERNATIVA: Disabilita temporaneamente Real-time protection" "WARN"
    Write-Log "  (Impostazioni > Sicurezza di Windows > Protezione da virus e minacce)" "INFO"
    Write-Log "" "ERROR"
    return $false
  }
  return $true
}

# ===============================
# Installazione FRP
# ===============================
function Install-Nssm {
  Write-Log "Download NSSM (Non-Sucking Service Manager) v$NssmVersion" "INFO"
  
  # Assicurati che TempDir esista
  if (-not (Test-Path $TempDir)) {
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
  }
  
  $nssmZip = Join-Path $TempDir "nssm.zip"
  
  # URL con fallback
  $nssmUrls = @(
    "https://nssm.cc/release/nssm-$NssmVersion.zip",
    "https://nssm.cc/ci/nssm-$NssmVersion.zip",
    "https://github.com/kirillkovalenko/nssm/releases/download/$NssmVersion/nssm-$NssmVersion.zip"
  )
  
  $downloaded = $false
  foreach ($url in $nssmUrls) {
    try {
      Write-Log "Tentativo download da: $url" "INFO"
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      Invoke-WebRequest -Uri $url -OutFile $nssmZip -UseBasicParsing -TimeoutSec 30
      Write-Log "NSSM scaricato: $('{0:N2}' -f ((Get-Item $nssmZip).Length / 1MB)) MB" "OK"
      $downloaded = $true
      break
    } catch {
      Write-Log "Fallito: $($_.Exception.Message)" "WARN"
    }
  }
  
  if (-not $downloaded) {
    throw "Impossibile scaricare NSSM da nessun mirror disponibile"
  }
  
  Write-Log "Estrazione NSSM" "INFO"
  $nssmExtract = Join-Path $TempDir "nssm-extracted"
  Expand-Archive -Path $nssmZip -DestinationPath $nssmExtract -Force
  
  # Trova nssm.exe (architettura amd64)
  $nssmExe = Get-ChildItem -Path $nssmExtract -Filter "nssm.exe" -Recurse | Where-Object { $_.FullName -like "*win64*" -or $_.FullName -like "*amd64*" } | Select-Object -First 1
  
  if (-not $nssmExe) {
    # Fallback: prendi qualsiasi nssm.exe
    $nssmExe = Get-ChildItem -Path $nssmExtract -Filter "nssm.exe" -Recurse | Select-Object -First 1
  }
  
  if (-not $nssmExe) {
    throw "nssm.exe non trovato nell'archivio"
  }
  
  Copy-Item -Path $nssmExe.FullName -Destination $NssmExePath -Force
  Write-Log "NSSM installato: $NssmExePath" "OK"
}

function Install-Frpc {
  Write-Log "Download frpc v$FrpVersion" "INFO"
  New-Item -Path $TempDir -ItemType Directory -Force | Out-Null

  $zipPath = Join-Path $TempDir "frp.zip"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Uri $DownloadUrl -OutFile $zipPath -UseBasicParsing

  Write-Log "Estrazione archivio" "INFO"
  $extractPath = Join-Path $TempDir "extracted"
  Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

  $frpc = Get-ChildItem -Path $extractPath -Filter "frpc.exe" -Recurse | Select-Object -First 1
  if (-not $frpc) { throw "frpc.exe non trovato nello zip" }

  if (-not (Test-Path $InstallPath)) {
    New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
  }

  Copy-Item -Path $frpc.FullName -Destination $FrpcExePath -Force
  Write-Log "frpc.exe copiato, attendo verifica Defender..." "INFO"
  
  # Attendi che Defender analizzi il file
  Start-Sleep -Seconds 2
  
  # Verifica multipla se Defender ha bloccato
  $attempts = 0
  $maxAttempts = 5
  while ($attempts -lt $maxAttempts) {
    if (Test-Path $FrpcExePath) {
      $fileSize = (Get-Item $FrpcExePath).Length
      if ($fileSize -gt 0) {
        Write-Log "frpc.exe verificato: $('{0:N2}' -f ($fileSize / 1MB)) MB" "OK"
        break
      }
    }
    $attempts++
    if ($attempts -lt $maxAttempts) {
      Write-Log "Tentativo $attempts/$maxAttempts - Attendo Defender..." "WARN"
      Start-Sleep -Seconds 1
    }
  }
  
  if (-not (Test-Path $FrpcExePath)) {
    throw "Windows Defender ha rimosso frpc.exe. Ripristina il file dalla Cronologia protezione e rilancia lo script."
  }
}

function Write-FrpcConfig {
  param(
    [string]$HostName,
    [string]$ServerAddr,
    [string]$Token,
    [int]$RemotePort
  )

  # Formato TOML corretto per FRP v0.64.0+
  $content = @"
[common]
server_addr = "$ServerAddr"
server_port = 7000
auth.method = "token"
auth.token  = "$Token"
tls.enable  = true
log.to      = "$InstallPath\\frpc.log"
log.level   = "info"

[$HostName]
type        = "tcp"
local_ip    = "127.0.0.1"
local_port  = 6556
remote_port = $RemotePort
"@

  Set-Content -Path $ConfigPath -Value $content -Encoding UTF8
  Write-Log "Configurazione scritta: $ConfigPath" "OK"
}

function Install-And-Start-Service {
  # Verifica FINALE critica che exe esista
  Write-Log "Verifica finale frpc.exe e nssm.exe..." "INFO"
  
  if (-not (Test-Path $FrpcExePath)) {
    throw "frpc.exe non trovato: $FrpcExePath"
  }
  
  if (-not (Test-Path $NssmExePath)) {
    throw "nssm.exe non trovato: $NssmExePath"
  }
  
  $fileInfo = Get-Item $FrpcExePath
  Write-Log "frpc.exe verificato: $($fileInfo.Length) bytes" "OK"
  
  Write-Log "Creazione servizio Windows con NSSM '$ServiceName'" "INFO"
  
  # Usa NSSM per installare il servizio
  $nssmInstall = & $NssmExePath install $ServiceName "`"$FrpcExePath`"" -c "`"$ConfigPath`"" 2>&1
  
  if ($LASTEXITCODE -ne 0) {
    Write-Log "Output NSSM: $nssmInstall" "ERROR"
    throw "Creazione servizio con NSSM fallita (exit code: $LASTEXITCODE)"
  }
  
  Write-Log "Servizio creato con NSSM" "OK"
  
  # Configura servizio
  & $NssmExePath set $ServiceName DisplayName "Fast Reverse Proxy Client" | Out-Null
  & $NssmExePath set $ServiceName Description "FRP Client - Fast Reverse Proxy (frpc) - Managed by NSSM" | Out-Null
  & $NssmExePath set $ServiceName Start SERVICE_AUTO_START | Out-Null
  & $NssmExePath set $ServiceName AppStdout "`"$InstallPath\frpc-stdout.log`"" | Out-Null
  & $NssmExePath set $ServiceName AppStderr "`"$InstallPath\frpc-stderr.log`"" | Out-Null
  & $NssmExePath set $ServiceName AppRotateFiles 1 | Out-Null
  & $NssmExePath set $ServiceName AppRotateBytes 1048576 | Out-Null
  
  Write-Log "Configurazione servizio completata" "OK"
  
  # Verifica servizio creato
  Start-Sleep -Milliseconds 500
  if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
    throw "Servizio '$ServiceName' non trovato dopo creazione"
  }

  Write-Log "Avvio servizio '$ServiceName'" "INFO"
  try {
    Start-Service -Name $ServiceName -ErrorAction Stop
    Start-Sleep -Seconds 2

    $svc = Get-Service -Name $ServiceName
    if ($svc.Status -eq "Running") {
      Write-Log "Servizio avviato con successo. Stato: $($svc.Status)" "OK"
      return
    } else {
      Write-Log "Servizio creato ma non in esecuzione. Stato: $($svc.Status)" "WARN"
    }
  } catch {
    Write-Log "Primo tentativo avvio fallito: $($_.Exception.Message)" "WARN"
    
    # RETRY con whitelist ThreatID esplicito
    Write-Log "Tentativo whitelist ThreatID e retry avvio..." "INFO"
    try {
      # Whitelist ThreatID frpc (se non fatto prima)
      Add-MpPreference -ThreatIDDefaultAction_Ids 2147939874 -ThreatIDDefaultAction_Actions Allow -Force -ErrorAction SilentlyContinue
      
      # Retry avvio
      Start-Sleep -Seconds 1
      Start-Service -Name $ServiceName -ErrorAction Stop
      Start-Sleep -Seconds 2
      
      $svc = Get-Service -Name $ServiceName
      if ($svc.Status -eq "Running") {
        Write-Log "Servizio avviato con successo dopo whitelist ThreatID!" "OK"
        return
      }
    } catch {
      # Fallback: istruzioni manuali
    }
    
    Write-Log "" "WARN"
    Write-Log "============================================" "WARN"
    Write-Log "SERVIZIO CREATO - Avvio bloccato da Defender" "WARN"
    Write-Log "============================================" "WARN"
    Write-Log "" "INFO"
    Write-Log "INSTALLAZIONE COMPLETATA con successo!" "OK"
    Write-Log "Il servizio frpc e' stato creato ma non avviato." "INFO"
    Write-Log "" "INFO"
    Write-Log "PER AVVIARE IL SERVIZIO:" "WARN"
    Write-Log "" "INFO"
    Write-Log "METODO 1: Whitelist ThreatID (consigliato)" "WARN"
    Write-Log "  Add-MpPreference -ThreatIDDefaultAction_Ids 2147939874 -ThreatIDDefaultAction_Actions Allow -Force" "INFO"
    Write-Log "  Start-Service frpc" "INFO"
    Write-Log "" "INFO"
    Write-Log "METODO 2: Disabilita Real-time protection (temporaneo)" "WARN"
    Write-Log "  Win + I > Sicurezza di Windows > Protezione da virus e minacce" "INFO"
    Write-Log "  > Gestisci impostazioni > DISATTIVA 'Protezione in tempo reale'" "INFO"
    Write-Log "  Start-Service frpc" "INFO"
    Write-Log "  Poi RIATTIVA protezione" "INFO"
    Write-Log "" "INFO"
    Write-Log "Verifica:" "WARN"
    Write-Log "  Get-Service frpc                                    # Deve essere 'Running'" "INFO"
    Write-Log "  Get-Content 'C:\\Program Files\\frp\\frpc.log' -Tail 20  # Log connessione" "INFO"
    Write-Log "" "INFO"
    Write-Log "Il servizio si avviera' automaticamente ai prossimi riavvii." "OK"
    Write-Log "" "INFO"
  }
}

# ===============================
# MAIN
# ===============================
try {
  Ensure-ExecutionPolicy

  if (-not (Test-Administrator)) { throw "Esegui PowerShell come Amministratore" }
  if (-not [Environment]::Is64BitOperatingSystem) { throw "Richiesto Windows 64-bit" }
  if (-not [Environment]::Is64BitProcess) { throw "Usa PowerShell 64-bit" }

  Write-Log "=== Installazione frpc Windows ===" "OK"

  $hostName   = Read-NonEmpty "Nome host (es. box-lab00)"
  $remotePort = Read-Int "Remote port (es. 6006)"

  $serverAddr = Read-Host "Server FRP [monitor.nethlab.it]"
  if ([string]::IsNullOrWhiteSpace($serverAddr)) { $serverAddr = "monitor.nethlab.it" }

  $token = Read-NonEmpty "Token FRP"

  # Configura esclusioni Defender PRIMA di installare
  Write-Log "" "INFO"
  Add-DefenderExclusion
  Write-Log "" "INFO"

  Stop-And-Remove-Service
  Install-Nssm
  Install-Frpc
  
  # Verifica che Defender non abbia bloccato
  if (-not (Test-DefenderBlocked)) {
    throw "Installazione bloccata da Windows Defender"
  }
  
  # Test esecuzione PRIMA di creare servizio
  Write-Log "" "INFO"
  if (-not (Test-FrpcExecution)) {
    Write-Log "" "ERROR"
    Write-Log "============================================" "ERROR"
    Write-Log "DEFENDER BLOCCA L'ESECUZIONE DI FRPC.EXE!" "ERROR"
    Write-Log "============================================" "ERROR"
    Write-Log "" "INFO"
    Write-Log "SOLUZIONE: Disabilita temporaneamente Real-time protection" "WARN"
    Write-Log "1. Premi Win + I (Impostazioni)" "INFO"
    Write-Log "2. Privacy e sicurezza > Sicurezza di Windows" "INFO"
    Write-Log "3. Protezione da virus e minacce" "INFO"
    Write-Log "4. Gestisci impostazioni (sotto Impostazioni protezione da virus e minacce)" "INFO"
    Write-Log "5. DISATTIVA: Protezione in tempo reale (temporaneamente)" "INFO"
    Write-Log "6. Rilancia questo script" "INFO"
    Write-Log "7. Dopo installazione, RIATTIVA la protezione" "INFO"
    Write-Log "" "WARN"
    Write-Log "ALTERNATIVA: Aggiungi frpc.exe alle esclusioni di processo" "WARN"
    Write-Log "  Add-MpPreference -ExclusionProcess 'frpc.exe'" "INFO"
    Write-Log "" "ERROR"
    throw "Windows Defender blocca l'esecuzione di frpc.exe"
  }
  Write-Log "" "INFO"
  
  Write-FrpcConfig -HostName $hostName -ServerAddr $serverAddr -Token $token -RemotePort $remotePort
  Install-And-Start-Service

  Write-Log "" "INFO"
  Write-Log "=== INSTALLAZIONE COMPLETATA ===" "OK"
  Write-Log "" "INFO"
  Write-Log "DETTAGLI INSTALLAZIONE:" "INFO"
  Write-Log "  Eseguibile: $FrpcExePath" "INFO"
  Write-Log "  Config    : $ConfigPath" "INFO"
  Write-Log "  Log       : $InstallPath\\frpc.log" "INFO"
  Write-Log "  Servizio  : $ServiceName (Startup: Automatic)" "INFO"
  Write-Log "" "INFO"
  Write-Log "COMANDI UTILI:" "INFO"
  Write-Log "  Get-Service frpc                                   # Stato servizio" "INFO"
  Write-Log "  Start-Service frpc                                 # Avvia servizio" "INFO"
  Write-Log "  Stop-Service frpc                                  # Ferma servizio" "INFO"
  Write-Log "  Get-Content 'C:\\Program Files\\frp\\frpc.log' -Tail 20 # Ultimi log" "INFO"
  Write-Log "" "OK"

  exit 0
}
catch {
  Write-Log "ERRORE: $($_.Exception.Message)" "ERROR"
  exit 1
}
finally {
  if (Test-Path $TempDir) {
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}
