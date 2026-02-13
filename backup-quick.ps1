# Script di Backup Veloce Repository CheckMK-Tools
# Versione QUICK senza controllo integrita (da usare dopo check-integrity.ps1)
# Ottimizzato per workflow conversione Python

param(
    [switch]$Unattended
)

$ErrorActionPreference = "Stop"

# === CONFIGURAZIONE ===
$REPO_PATH = "C:\Users\Marzio\Desktop\CheckMK\checkmk-tools"
$LOCAL_BACKUP_BASE = "C:\CheckMK-Backups"
$NETWORK_BACKUP_BASE = "\\192.168.10.132\usbshare\CheckMK-Backups"
$TIMESTAMP = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LOCAL_BACKUP_PATH = Join-Path $LOCAL_BACKUP_BASE $TIMESTAMP
$NETWORK_BACKUP_PATH = Join-Path $NETWORK_BACKUP_BASE $TIMESTAMP
$RETENTION_COUNT = 20

# === CONFIGURAZIONE EMAIL ===
$SMTP_SERVER = "smtp-relay.nethesis.it"
$SMTP_PORT = 587
$SMTP_USE_SSL = $true
$EMAIL_FROM = "checkmk@nethesis.it"
$EMAIL_TO = "marzio@nethesis.it"
$EMAIL_CREDENTIAL_FILE = Join-Path $LOCAL_BACKUP_BASE "smtp_credential.xml"
$SEND_EMAIL = $true

# === VARIABILI GLOBALI PER EMAIL ERRORE ===
$GLOBAL_ERROR_MESSAGE = ""

Write-Host ""
Write-Host "================================================================"
Write-Host "     BACKUP VELOCE REPOSITORY CHECKMK-TOOLS"
Write-Host "================================================================"
Write-Host ""
Write-Host "[INFO] Modalita QUICK - controllo integrita DISABILITATO" -ForegroundColor Cyan
Write-Host "[INFO] Eseguire check-integrity.ps1 separatamente se necessario" -ForegroundColor Gray
Write-Host ""

# === INIZIO TRY GLOBALE PER GESTIONE ERRORI ===
try {

# Crea cartella backup se non esiste
if (-not (Test-Path $LOCAL_BACKUP_BASE)) {
    New-Item -ItemType Directory -Path $LOCAL_BACKUP_BASE -Force | Out-Null
}

# Verifica che il repository esista
if (-not (Test-Path $REPO_PATH)) {
    Write-Host "[ERRORE] Repository non trovato: $REPO_PATH" -ForegroundColor Red
    throw "Repository non trovato: $REPO_PATH"
}

# Conta tutti i file per il backup (con filtri di esclusione)
$allFiles = Get-ChildItem -Path $REPO_PATH -Recurse -File -ErrorAction SilentlyContinue | 
    Where-Object { 
        $_.FullName -notmatch '\\\.git\\' -and
        $_.FullName -notmatch '\\BACKUP' -and
        $_.FullName -notmatch '\.BACKUP' -and
        $_.FullName -notmatch 'BACKUP-CORRUPTED-' -and
        $_.Name -notmatch '^\.' # Escludi file nascosti
    }
$totalFiles = $allFiles.Count

if ($totalFiles -eq 0) {
    Write-Host "[ERRORE] Nessun file trovato nel repository!" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Trovati $totalFiles file da backuppare" -ForegroundColor Cyan
Write-Host ""

if (-not $Unattended) {
    Write-Host "Premi un tasto per continuare con il backup..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
}

# === BACKUP LOCALE ===
Write-Host "================================================================"
Write-Host "    BACKUP LOCALE"
Write-Host "================================================================"
Write-Host ""
Write-Host "[INFO] Destinazione: $LOCAL_BACKUP_PATH" -ForegroundColor Gray
Write-Host ""

# Crea cartella backup
try {
    New-Item -ItemType Directory -Path $LOCAL_BACKUP_PATH -Force | Out-Null
    Write-Host "[OK] Cartella backup creata" -ForegroundColor Green
} catch {
    Write-Host "[ERRORE] Impossibile creare cartella backup: $_" -ForegroundColor Red
    exit 1
}

# Copia file
Write-Host ""
Write-Host "[INFO] Copia file in corso..." -ForegroundColor Cyan

$copiedFiles = 0
$errorCount = 0

foreach ($file in $allFiles) {
    $relativePath = $file.FullName.Replace($REPO_PATH, "").TrimStart('\')
    $destinationPath = Join-Path $LOCAL_BACKUP_PATH $relativePath
    $destinationDir = Split-Path $destinationPath -Parent
    
    try {
        if (-not (Test-Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }
        
        Copy-Item -Path $file.FullName -Destination $destinationPath -Force
        $copiedFiles++
        
        if ($copiedFiles % 50 -eq 0) {
            Write-Host "  Copiati $copiedFiles / $totalFiles file..." -ForegroundColor Gray
        }
    } catch {
        $errorCount++
        Write-Host "[WARN] Errore copia file $relativePath" -ForegroundColor Yellow
    }
}

Write-Host "[OK] Completato: $copiedFiles file copiati" -ForegroundColor Green

if ($errorCount -gt 0) {
    Write-Host "[WARN] $errorCount file non copiati" -ForegroundColor Yellow
}

# Calcola dimensione backup locale
$backupSize = (Get-ChildItem -Path $LOCAL_BACKUP_PATH -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB

# === BACKUP SU RETE ===
Write-Host ""
Write-Host "================================================================"
Write-Host "    BACKUP SU RETE"
Write-Host "================================================================"
Write-Host ""

$networkCopied = 0
$networkSuccess = $false

# Verifica connessione rete
if (Test-Path $NETWORK_BACKUP_BASE) {
    Write-Host "[INFO] Share di rete raggiungibile" -ForegroundColor Green
    Write-Host "[INFO] Destinazione: $NETWORK_BACKUP_PATH" -ForegroundColor Gray
    Write-Host ""
    
    try {
        # Crea cartella backup di rete
        New-Item -ItemType Directory -Path $NETWORK_BACKUP_PATH -Force -ErrorAction Stop | Out-Null
        Write-Host "[OK] Cartella backup rete creata" -ForegroundColor Green
        Write-Host ""
        Write-Host "[INFO] Copia file su rete in corso..." -ForegroundColor Cyan
        
        # Copia ricorsiva
        foreach ($file in $allFiles) {
            $relativePath = $file.FullName.Replace($REPO_PATH, "").TrimStart('\')
            $destinationPath = Join-Path $NETWORK_BACKUP_PATH $relativePath
            $destinationDir = Split-Path $destinationPath -Parent
            
            try {
                if (-not (Test-Path $destinationDir)) {
                    New-Item -ItemType Directory -Path $destinationDir -Force -ErrorAction Stop | Out-Null
                }
                
                Copy-Item -Path $file.FullName -Destination $destinationPath -Force -ErrorAction Stop
                $networkCopied++
                
                if ($networkCopied % 50 -eq 0) {
                    Write-Host "  Copiati $networkCopied / $totalFiles file..." -ForegroundColor Gray
                }
            } catch {
                Write-Host "[WARN] Errore copia file $relativePath su rete" -ForegroundColor Yellow
            }
        }
        
        Write-Host "[OK] Backup rete completato: $networkCopied file copiati" -ForegroundColor Green
        $networkSuccess = $true
        
    } catch {
        Write-Host "[ERRORE] Backup su rete fallito: $_" -ForegroundColor Red
        Write-Host "[INFO] Il backup locale e comunque disponibile" -ForegroundColor Yellow
    }
} else {
    Write-Host "[WARN] Share di rete non raggiungibile: $NETWORK_BACKUP_BASE" -ForegroundColor Yellow
    Write-Host "[INFO] Continuo solo con backup locale" -ForegroundColor Yellow
}

# === STATISTICHE ===
Write-Host ""
Write-Host "================================================================"
Write-Host "    STATISTICHE BACKUP"
Write-Host "================================================================"
Write-Host ""
Write-Host "  LOCALE:" -ForegroundColor Cyan
Write-Host "    File copiati:     $copiedFiles" -ForegroundColor Gray
Write-Host "    Dimensione:       $([math]::Round($backupSize, 2)) MB" -ForegroundColor Gray
Write-Host "    Percorso:         $LOCAL_BACKUP_PATH" -ForegroundColor Gray
Write-Host ""
if ($networkSuccess) {
    Write-Host "  RETE:" -ForegroundColor Cyan
    Write-Host "    File copiati:     $networkCopied" -ForegroundColor Gray
    Write-Host "    Percorso:         $NETWORK_BACKUP_PATH" -ForegroundColor Gray
} else {
    Write-Host "  RETE: Non disponibile" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Timestamp:        $TIMESTAMP" -ForegroundColor Gray
Write-Host ""

# === RETENTION POLICY ===
Write-Host "================================================================"
Write-Host "    PULIZIA BACKUP VECCHI (Retention)"
Write-Host "================================================================"
Write-Host ""

$existingBackups = Get-ChildItem -Path $LOCAL_BACKUP_BASE -Directory | 
    Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$' } |
    Sort-Object Name -Descending

$backupCount = $existingBackups.Count
Write-Host "[INFO] Backup totali: $backupCount (retention: $RETENTION_COUNT)" -ForegroundColor Cyan

if ($backupCount -gt $RETENTION_COUNT) {
    $toDelete = $backupCount - $RETENTION_COUNT
    Write-Host "[INFO] Verranno eliminati $toDelete backup piu vecchi..." -ForegroundColor Yellow
    Write-Host ""
    
    $backupsToDelete = $existingBackups | Select-Object -Skip $RETENTION_COUNT
    
    foreach ($backup in $backupsToDelete) {
        try {
            Write-Host "  [DELETE] $($backup.Name)" -ForegroundColor Gray
            Remove-Item -Path $backup.FullName -Recurse -Force -ErrorAction Stop
            Write-Host "     [OK] Eliminato" -ForegroundColor Green
        } catch {
            Write-Host "     [ERRORE] $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "[OK] Pulizia completata: mantenuti gli ultimi $RETENTION_COUNT backup" -ForegroundColor Green
} else {
    Write-Host "[INFO] Nessun backup da eliminare" -ForegroundColor Green
}

Write-Host ""
Write-Host "================================================================"
Write-Host "    BACKUP COMPLETATO CON SUCCESSO"
Write-Host "================================================================"
Write-Host ""

# === INVIO EMAIL REPORT ===
if ($SEND_EMAIL) {
    Write-Host "================================================================"
    Write-Host "    INVIO EMAIL REPORT"
    Write-Host "================================================================"
    Write-Host ""
    
    try {
        $emailSubject = "[CheckMK Backup] Quick Backup Completato - $TIMESTAMP"
        
        $emailBody = @"
===============================================================
       REPORT BACKUP VELOCE REPOSITORY CHECKMK-TOOLS
===============================================================

Data e ora: $TIMESTAMP
Host: $env:COMPUTERNAME
Modalita: QUICK (senza controllo integrita)

---------------------------------------------------------------
  BACKUP LOCALE
---------------------------------------------------------------
File copiati:          $copiedFiles
Dimensione:            $([math]::Round($backupSize, 2)) MB
Percorso:              $LOCAL_BACKUP_PATH

---------------------------------------------------------------
  BACKUP RETE
---------------------------------------------------------------
"@
        
        if ($networkSuccess) {
            $emailBody += @"
Stato:                 COMPLETATO
File copiati:          $networkCopied
Percorso:              $NETWORK_BACKUP_PATH

"@
        } else {
            $emailBody += @"
Stato:                 NON DISPONIBILE
Motivo:                Share di rete non raggiungibile

"@
        }
        
        $emailBody += @"
---------------------------------------------------------------
  RETENTION POLICY
---------------------------------------------------------------
Backup totali:         $backupCount
Retention:             $RETENTION_COUNT
"@
        
        if ($backupCount -gt $RETENTION_COUNT) {
            $deleted = $backupCount - $RETENTION_COUNT
            $emailBody += "Backup eliminati:      $deleted`n"
        } else {
            $emailBody += "Backup eliminati:      0`n"
        }
        
        $emailBody += @"

===============================================================
  BACKUP COMPLETATO CON SUCCESSO
===============================================================

Nota: Questo backup e stato eseguito in modalita QUICK 
      (senza controllo integrita script).
      Eseguire check-integrity.ps1 separatamente se necessario.

Questo e un messaggio automatico generato dal sistema di backup.
"@
        
        # Prepara credenziali se necessarie
        $smtpParams = @{
            SmtpServer = $SMTP_SERVER
            Port = $SMTP_PORT
            From = $EMAIL_FROM
            To = $EMAIL_TO
            Subject = $emailSubject
            Body = $emailBody
            Encoding = [System.Text.Encoding]::UTF8
        }
        
        if ($SMTP_USE_SSL) {
            $smtpParams.UseSsl = $true
        }
        
        # Carica credenziali crittografate se esistono
        if (Test-Path $EMAIL_CREDENTIAL_FILE) {
            $credential = Import-Clixml -Path $EMAIL_CREDENTIAL_FILE
            $smtpParams.Credential = $credential
        } else {
            Write-Host "[WARN] File credenziali non trovato: $EMAIL_CREDENTIAL_FILE" -ForegroundColor Yellow
            Write-Host "[INFO] Esegui: .\setup-smtp-credentials.ps1 per configurare" -ForegroundColor Cyan
            throw "Credenziali SMTP mancanti"
        }
        
        Send-MailMessage @smtpParams -WarningAction SilentlyContinue
        
        Write-Host "[OK] Email inviata a: $EMAIL_TO" -ForegroundColor Green
        
    } catch {
        Write-Host "[WARN] Impossibile inviare email: $_" -ForegroundColor Yellow
        Write-Host "[INFO] Il backup e comunque completato correttamente" -ForegroundColor Cyan
    }
    
    Write-Host ""
}

exit 0

} catch {
    # === GESTIONE ERRORE GLOBALE CON INVIO EMAIL ===
    $GLOBAL_ERROR_MESSAGE = $_.Exception.Message
    $errorDetails = $_.Exception | Out-String
    
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host "    BACKUP FALLITO - ERRORE CRITICO" -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "[ERRORE] $GLOBAL_ERROR_MESSAGE" -ForegroundColor Red
    Write-Host ""
    
    # Invia email di errore
    if ($SEND_EMAIL) {
        try {
            $emailSubject = "[CheckMK Backup] ERRORE Quick Backup - $TIMESTAMP"
            
            $emailBody = @"
===============================================================
       BACKUP FALLITO - ERRORE CRITICO
===============================================================

Data e ora: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Host: $env:COMPUTERNAME
Repository: $REPO_PATH
Modalita: QUICK (senza controllo integrita)

---------------------------------------------------------------
  DETTAGLIO ERRORE
---------------------------------------------------------------
$GLOBAL_ERROR_MESSAGE

---------------------------------------------------------------
  STACK TRACE
---------------------------------------------------------------
$errorDetails

---------------------------------------------------------------
  AZIONE RICHIESTA
---------------------------------------------------------------
Verificare manualmente il sistema di backup.
Log disponibile in: C:\CheckMK-Backups\logs\

===============================================================
  NOTIFICA AUTOMATICA DI ERRORE
===============================================================

Questo e un messaggio automatico generato dal sistema di backup.
"@
            
            $smtpParams = @{
                SmtpServer = $SMTP_SERVER
                Port = $SMTP_PORT
                From = $EMAIL_FROM
                To = $EMAIL_TO
                Subject = $emailSubject
                Body = $emailBody
                Encoding = [System.Text.Encoding]::UTF8
            }
            
            if ($SMTP_USE_SSL) {
                $smtpParams.UseSsl = $true
            }
            
            if (Test-Path $EMAIL_CREDENTIAL_FILE) {
                $credential = Import-Clixml -Path $EMAIL_CREDENTIAL_FILE
                $smtpParams.Credential = $credential
                
                Send-MailMessage @smtpParams -WarningAction SilentlyContinue
                Write-Host "[OK] Email di errore inviata a: $EMAIL_TO" -ForegroundColor Green
            } else {
                Write-Host "[WARN] Impossibile inviare email: credenziali mancanti" -ForegroundColor Yellow
            }
            
        } catch {
            Write-Host "[WARN] Impossibile inviare email di errore: $_" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    exit 1
}
