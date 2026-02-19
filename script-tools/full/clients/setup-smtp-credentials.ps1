# Setup Credenziali SMTP Sicure
# Salva username e password crittografati (leggibili solo da questo utente su questa macchina)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "================================================================"
Write-Host "    CONFIGURAZIONE CREDENZIALI SMTP SICURE"
Write-Host "================================================================"
Write-Host ""

$CREDENTIAL_FILE = "C:\CheckMK-Backups\smtp_credential.xml"

Write-Host "[INFO] Le credenziali saranno crittografate e salvate in:" -ForegroundColor Cyan
Write-Host "       $CREDENTIAL_FILE" -ForegroundColor Gray
Write-Host ""
Write-Host "[SICUREZZA] Il file puo essere letto solo da:" -ForegroundColor Yellow
Write-Host "            - Utente: $env:USERNAME" -ForegroundColor Gray
Write-Host "            - Computer: $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host ""

# Richiedi credenziali
$username = Read-Host "Username SMTP"
$securePassword = Read-Host "Password SMTP" -AsSecureString

# Crea oggetto credenziali
$credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)

# Salva credenziali crittografate
try {
    $credential | Export-Clixml -Path $CREDENTIAL_FILE -Force
    Write-Host ""
    Write-Host "[OK] Credenziali salvate con successo!" -ForegroundColor Green
    Write-Host ""
    
    # Test lettura
    $testCred = Import-Clixml -Path $CREDENTIAL_FILE
    Write-Host "[TEST] Username salvato: $($testCred.UserName)" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "================================================================"
    Write-Host "    CONFIGURAZIONE COMPLETATA"
    Write-Host "================================================================"
    Write-Host ""
    Write-Host "[INFO] Ora puoi eseguire il backup con invio email:" -ForegroundColor Cyan
    Write-Host "       .\backup-simple.ps1 -Unattended" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "[ERRORE] Impossibile salvare le credenziali: $_" -ForegroundColor Red
    exit 1
}
