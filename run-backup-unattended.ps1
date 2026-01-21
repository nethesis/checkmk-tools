# Wrapper per eseguire backup in modalità unattended con logging
$ErrorActionPreference = "Continue"

$SCRIPT_PATH = "C:\Users\Marzio\Desktop\CheckMK\checkmk-tools\backup-sync-complete.ps1"
$LOG_PATH = "C:\CheckMK-Backups\logs"
$LOG_FILE = Join-Path $LOG_PATH "backup_$(Get-Date -Format 'yyyy-MM-dd').log"

# Crea cartella log se non esiste
if (-not (Test-Path $LOG_PATH)) {
    New-Item -ItemType Directory -Path $LOG_PATH -Force | Out-Null
}

# Registra inizio esecuzione
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Inizio backup automatico..." | Out-File -FilePath $LOG_FILE -Append -Encoding UTF8

# Esegui backup
try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SCRIPT_PATH -Unattended 2>&1 | Out-File -FilePath $LOG_FILE -Append -Encoding UTF8
    $exitCode = $LASTEXITCODE
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Backup completato (exit code: $exitCode)" | Out-File -FilePath $LOG_FILE -Append -Encoding UTF8
    exit $exitCode
} catch {
    "ERRORE: $_" | Out-File -FilePath $LOG_FILE -Append -Encoding UTF8
    exit 1
}
