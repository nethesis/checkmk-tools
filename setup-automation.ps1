#!/usr/bin/env pwsh
# Configurazione Task Scheduler per Backup Automatico CheckMK Tools
# Crea task automatizzati per backup periodici

Write-Host "⏰ Configurazione Automazione Backup" -ForegroundColor Cyan
Write-Host "=" * 40 -ForegroundColor Gray

# Verifica privilegi amministratore
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "⚠️  Attenzione: Alcuni task potrebbero richiedere privilegi di amministratore" -ForegroundColor Yellow
    Write-Host "💡 Esegui PowerShell come Amministratore per configurazione completa" -ForegroundColor DarkYellow
}

# Percorsi
$scriptPath = $PSScriptRoot
$quickBackupScript = Join-Path $scriptPath "quick-backup.ps1"
$completeBackupScript = Join-Path $scriptPath "backup-sync-complete.ps1"

# Verifica esistenza script
if (-not (Test-Path $quickBackupScript)) {
    Write-Host "❌ Script quick-backup.ps1 non trovato in $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "📁 Script backup trovati in: $scriptPath" -ForegroundColor Green

# Menu di configurazione
Write-Host "`n🔧 OPZIONI DI AUTOMAZIONE:" -ForegroundColor Cyan
Write-Host "1. 🕐 Backup ogni ora (quick-backup)" -ForegroundColor White
Write-Host "2. 🌅 Backup giornaliero (mattina ore 9:00)" -ForegroundColor White  
Write-Host "3. 🌙 Backup giornaliero (sera ore 22:00)" -ForegroundColor White
Write-Host "4. 📅 Backup settimanale (Lunedì ore 8:00)" -ForegroundColor White
Write-Host "5. 🎯 Configurazione personalizzata" -ForegroundColor White
Write-Host "6. 📋 Solo mostra comandi (senza creare task)" -ForegroundColor DarkGray

$choice = Read-Host "`nScegli un'opzione [1-6]"

# Funzione per creare task XML
function Create-TaskXML {
    param($taskName, $description, $trigger, $scriptPath)
    
    $xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>$description</Description>
    <Author>$env:USERNAME</Author>
  </RegistrationInfo>
  <Triggers>
    $trigger
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$env:USERNAME</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT10M</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-WindowStyle Hidden -ExecutionPolicy Bypass -File "$scriptPath"</Arguments>
      <WorkingDirectory>$scriptPath\..</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@
    return $xml
}

# Configurazione basata sulla scelta
switch ($choice) {
    "1" {
        $taskName = "CheckMK-Backup-Hourly"
        $description = "Backup automatico CheckMK Tools ogni ora"
        $trigger = '<TimeTrigger><Repetition><Interval>PT1H</Interval></Repetition><StartBoundary>2025-01-01T09:00:00</StartBoundary><Enabled>true</Enabled></TimeTrigger>'
        $script = $quickBackupScript
    }
    "2" {
        $taskName = "CheckMK-Backup-Daily-Morning"
        $description = "Backup automatico CheckMK Tools - mattina ore 9:00"
        $trigger = '<CalendarTrigger><StartBoundary>2025-01-01T09:00:00</StartBoundary><Enabled>true</Enabled><ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay></CalendarTrigger>'
        $script = $completeBackupScript
    }
    "3" {
        $taskName = "CheckMK-Backup-Daily-Evening"
        $description = "Backup automatico CheckMK Tools - sera ore 22:00"
        $trigger = '<CalendarTrigger><StartBoundary>2025-01-01T22:00:00</StartBoundary><Enabled>true</Enabled><ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay></CalendarTrigger>'
        $script = $completeBackupScript
    }
    "4" {
        $taskName = "CheckMK-Backup-Weekly"
        $description = "Backup automatico CheckMK Tools - settimanale Lunedì"
        $trigger = '<CalendarTrigger><StartBoundary>2025-01-01T08:00:00</StartBoundary><Enabled>true</Enabled><ScheduleByWeek><WeeksInterval>1</WeeksInterval><DaysOfWeek><Monday /></DaysOfWeek></ScheduleByWeek></CalendarTrigger>'
        $script = $completeBackupScript
    }
    "5" {
        Write-Host "`n🎯 CONFIGURAZIONE PERSONALIZZATA" -ForegroundColor Cyan
        $taskName = Read-Host "Nome del task"
        $description = Read-Host "Descrizione"
        Write-Host "💡 Per il trigger, dovrai configurarlo manualmente in Task Scheduler" -ForegroundColor Yellow
        $trigger = '<CalendarTrigger><StartBoundary>2025-01-01T12:00:00</StartBoundary><Enabled>true</Enabled><ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay></CalendarTrigger>'
        $script = $completeBackupScript
    }
    "6" {
        Write-Host "`n📋 COMANDI PER CONFIGURAZIONE MANUALE:" -ForegroundColor Cyan
        Write-Host "`n1. Backup ogni ora:" -ForegroundColor Yellow
        Write-Host "   schtasks /create /tn ""CheckMK-Backup-Hourly"" /tr ""powershell.exe -File '$quickBackupScript'"" /sc hourly /st 09:00" -ForegroundColor Gray
        
        Write-Host "`n2. Backup giornaliero:" -ForegroundColor Yellow  
        Write-Host "   schtasks /create /tn ""CheckMK-Backup-Daily"" /tr ""powershell.exe -File '$completeBackupScript'"" /sc daily /st 22:00" -ForegroundColor Gray
        
        Write-Host "`n3. Backup settimanale:" -ForegroundColor Yellow
        Write-Host "   schtasks /create /tn ""CheckMK-Backup-Weekly"" /tr ""powershell.exe -File '$completeBackupScript'"" /sc weekly /d MON /st 08:00" -ForegroundColor Gray
        
        Write-Host "`n💡 Oppure usa Task Scheduler GUI (taskschd.msc)" -ForegroundColor Cyan
        exit 0
    }
    default {
        Write-Host "❌ Scelta non valida" -ForegroundColor Red
        exit 1
    }
}

# Creazione del task
Write-Host "`n⚙️  Configurando task: $taskName" -ForegroundColor Yellow
Write-Host "📝 Descrizione: $description" -ForegroundColor Gray
Write-Host "📜 Script: $script" -ForegroundColor Gray

try {
    # Metodo tramite schtasks (più compatibile)
    $triggerParam = switch ($choice) {
        "1" { "/sc hourly /st 09:00" }
        "2" { "/sc daily /st 09:00" }
        "3" { "/sc daily /st 22:00" }
        "4" { "/sc weekly /d MON /st 08:00" }
        default { "/sc daily /st 12:00" }
    }
    
    $command = "schtasks /create /tn `"$taskName`" /tr `"powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File '$script'`" $triggerParam /f"
    
    Write-Host "`n🔧 Eseguendo: $command" -ForegroundColor DarkGray
    
    $result = Invoke-Expression $command 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Task '$taskName' creato con successo!" -ForegroundColor Green
        
        # Verifica
        Write-Host "`n🔍 Verifica task:" -ForegroundColor Cyan
        schtasks /query /tn $taskName /fo list
        
        Write-Host "`n💡 COMANDI UTILI:" -ForegroundColor Cyan
        Write-Host "   • Esegui ora: schtasks /run /tn `"$taskName`"" -ForegroundColor Gray
        Write-Host "   • Disabilita: schtasks /change /tn `"$taskName`" /disable" -ForegroundColor Gray
        Write-Host "   • Elimina: schtasks /delete /tn `"$taskName`" /f" -ForegroundColor Gray
        Write-Host "   • Gestione GUI: taskschd.msc" -ForegroundColor Gray
        
    } else {
        Write-Host "❌ Errore nella creazione del task: $result" -ForegroundColor Red
        Write-Host "💡 Prova ad eseguire come Amministratore" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Errore: $_" -ForegroundColor Red
    Write-Host "💡 Comando manuale:" -ForegroundColor Yellow
    Write-Host "   $command" -ForegroundColor Gray
}

Write-Host "`n🎉 Configurazione automazione completata!" -ForegroundColor Green