#!/usr/bin/env pwsh
# Script per configurare ShellCheck in VS Code

Write-Host "🔧 Configurazione ShellCheck per VS Code" -ForegroundColor Cyan
Write-Host "=" * 40 -ForegroundColor Gray

# Trova il percorso di ShellCheck
$shellcheckPath = Get-Command shellcheck -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source

if (-not $shellcheckPath) {
    Write-Host "❌ ShellCheck non trovato nel PATH!" -ForegroundColor Red
    Write-Host "💡 Installa prima con: winget install koalaman.shellcheck" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ ShellCheck trovato in: $shellcheckPath" -ForegroundColor Green

# Percorso settings VS Code (utente)
$vscodeSettingsPath = "$env:APPDATA\Code\User\settings.json"

Write-Host "`n📝 Configurazione VS Code..." -ForegroundColor Cyan

# Leggi settings esistenti o crea nuovo
$settings = @{}
if (Test-Path $vscodeSettingsPath) {
    try {
        $content = Get-Content $vscodeSettingsPath -Raw
        if ($content.Trim()) {
            $settings = ConvertFrom-Json $content -AsHashtable -ErrorAction SilentlyContinue
            if (-not $settings) { $settings = @{} }
        }
    } catch {
        Write-Host "⚠️  Errore lettura settings esistenti, creo nuovi" -ForegroundColor Yellow
        $settings = @{}
    }
} else {
    # Crea directory se non esiste
    $settingsDir = Split-Path $vscodeSettingsPath -Parent
    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }
}

# Aggiungi configurazione ShellCheck
$settings["shellcheck.executablePath"] = $shellcheckPath.Replace('\', '\\')
$settings["shellcheck.enable"] = $true
$settings["shellcheck.run"] = "onType"

# Salva settings
try {
    $settings | ConvertTo-Json -Depth 10 | Set-Content $vscodeSettingsPath -Encoding UTF8
    Write-Host "✅ Settings VS Code aggiornati!" -ForegroundColor Green
    Write-Host "   File: $vscodeSettingsPath" -ForegroundColor Gray
} catch {
    Write-Host "❌ Errore nel salvare settings: $_" -ForegroundColor Red
    exit 1
}

# Configurazione locale (workspace)
$workspaceSettingsPath = ".vscode\settings.json"
$workspaceDir = ".vscode"

if (-not (Test-Path $workspaceDir)) {
    New-Item -ItemType Directory -Path $workspaceDir -Force | Out-Null
}

$workspaceSettings = @{
    "shellcheck.executablePath" = $shellcheckPath.Replace('\', '\\')
    "shellcheck.enable" = $true
    "shellcheck.run" = "onType"
}

try {
    $workspaceSettings | ConvertTo-Json -Depth 10 | Set-Content $workspaceSettingsPath -Encoding UTF8
    Write-Host "✅ Settings workspace aggiornati!" -ForegroundColor Green
    Write-Host "   File: $workspaceSettingsPath" -ForegroundColor Gray
} catch {
    Write-Host "❌ Errore nel salvare workspace settings: $_" -ForegroundColor Red
}

Write-Host "`n🔄 RIAVVIA VS CODE per applicare le modifiche!" -ForegroundColor Yellow
Write-Host "💡 Oppure usa: Ctrl+Shift+P → 'Developer: Reload Window'" -ForegroundColor Cyan

Write-Host "`n📋 Configurazione applicata:" -ForegroundColor Green
Write-Host "   • Percorso ShellCheck: $shellcheckPath" -ForegroundColor Gray
Write-Host "   • Abilitato: Sì" -ForegroundColor Gray  
Write-Host "   • Esecuzione: Automatica durante la digitazione" -ForegroundColor Gray

Write-Host "`n🎉 Configurazione completata!" -ForegroundColor Green