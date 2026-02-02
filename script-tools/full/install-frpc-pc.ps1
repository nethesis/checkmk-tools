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
$InstallPath = "C:\Program Files\frp"
$FrpcExePath = Join-Path $InstallPath "frpc.exe"
$ConfigPath  = Join-Path $InstallPath "frpc.toml"
$ServiceName = "frpc"

$DownloadUrl = "https://github.com/fatedier/frp/releases/download/v$FrpVersion/frp_${FrpVersion}_windows_amd64.zip"
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
    Write-Log "In futuro usa: powershell -ExecutionPolicy Bypass -File install-frpc.ps1" "WARN"
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
    Write-Log "Porta non valida (1–65535)" "WARN"
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

# ===============================
# Installazione FRP
# ===============================
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
  Write-Log "frpc.exe installato in $InstallPath" "OK"
}

function Write-FrpcConfig {
  param(
    [string]$HostName,
    [string]$ServerAddr,
    [string]$Token,
    [int]$RemotePort
  )

  $content = @"
[common]
server_addr = "$ServerAddr"
server_port = 7000
auth.method = "token"
auth.token  = "$Token"
tls.enable  = true
log.to      = "$InstallPath\frpc.log"
log.level   = "debug"

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
  $binPath = "`"$FrpcExePath`" -c `"$ConfigPath`""

  Write-Log "Creazione servizio Windows '$ServiceName'" "INFO"
  & sc.exe create $ServiceName binPath= $binPath start= auto DisplayName= "Fast Reverse Proxy Client" | Out-Null
  & sc.exe description $ServiceName "FRP Client - Fast Reverse Proxy (frpc)" | Out-Null
  & sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null

  Write-Log "Avvio servizio '$ServiceName'" "INFO"
  Start-Service -Name $ServiceName
  Start-Sleep -Seconds 1

  $svc = Get-Service -Name $ServiceName
  Write-Log "Servizio avviato. Stato: $($svc.Status)" "OK"
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

  Stop-And-Remove-Service
  Install-Frpc
  Write-FrpcConfig -HostName $hostName -ServerAddr $serverAddr -Token $token -RemotePort $remotePort
  Install-And-Start-Service

  Write-Log "=== COMPLETATO ===" "OK"
  Write-Log "Config : $ConfigPath" "INFO"
  Write-Log "Log    : $InstallPath\frpc.log" "INFO"
  Write-Log "Check  : Get-Service frpc" "INFO"

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
