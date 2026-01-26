# Wrapper per eseguire backup con logging
$LogFile = "C:\CheckMK-Backups\logs\backup_$(Get-Date -Format 'yyyy-MM-dd').log"
$ErrorFile = "C:\CheckMK-Backups\logs\backup-error.log"

# Assicura che la cartella log esista
$LogDir = Split-Path $LogFile -Parent
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

try {
    # Esegui backup
    & "C:\Users\Marzio\Desktop\CheckMK\checkmk-tools\backup-sync-complete.ps1" -Unattended *>&1 | Tee-Object -FilePath $LogFile
    
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Backup fallito con exit code: $LASTEXITCODE"
    }
    
    exit 0
} catch {
    $errorMsg = "ERRORE BACKUP: $($_.Exception.Message)`n$($_.ScriptStackTrace)"
    $errorMsg | Out-File -FilePath $ErrorFile -Append
    Write-Host $errorMsg
    exit 1
}
