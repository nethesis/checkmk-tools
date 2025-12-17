# Script per estrarre e aggiungere automaticamente tutte le parole sconosciute da cSpell
# Analizza i file del repository e identifica parole tecniche, comandi Unix, flag, ecc.

param(
    [switch]$WhatIf  # Mostra cosa verrebbe aggiunto senza modificare
)

$ErrorActionPreference = "Stop"
$settingsPath = ".vscode\settings.json"

Write-Host "=== Fix automatico errori cSpell ===" -ForegroundColor Cyan
Write-Host ""

# Leggi il file settings.json
if (-not (Test-Path $settingsPath)) {
    Write-Host "❌ File $settingsPath non trovato!" -ForegroundColor Red
    exit 1
}

$settingsContent = Get-Content $settingsPath -Raw
$settings = $settingsContent | ConvertFrom-Json

# Estrai il dizionario esistente
$existingWords = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
if ($settings.PSObject.Properties['cSpell.words']) {
    foreach ($word in $settings.'cSpell.words') {
        [void]$existingWords.Add($word)
    }
}

Write-Host "📖 Dizionario attuale: $($existingWords.Count) parole" -ForegroundColor Green
Write-Host ""

# Pattern per identificare parole sconosciute nei file
$newWords = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

# Pattern comuni per flag Unix/Linux e comandi tecnici
$technicalPatterns = @(
    '\b[a-z]{2,4}ln\b',           # flag comandi (tuln, xuln, etc.)
    '\b[a-z]grep\b',              # varianti grep (egrep, fgrep, etc.)
    '\bsudo[a-z]+\b',             # comandi sudo
    '\bsystemctl[a-z]*\b',        # comandi systemctl
    '\b[a-z]+ctl\b',              # comandi *ctl
    '\b[a-z]+d\b',                # daemon names (frpd, sshd, etc.)
    '\b[a-z]{2,}pkg\b',           # package managers (opkg, ipkg, etc.)
    '\b[a-z]+conf\b',             # file di configurazione
    '\b[a-z]+rc\b',               # file rc
    '\b[a-z]+\.sh\b',             # script bash
    '\b[a-z]+\.toml\b',           # file toml
    '\b[a-z]+\.log\b',            # file log
    '\b[A-Z]{2,}[a-z]+\b',        # CamelCase tecnico (DSM, ARM, etc.)
    '\b[a-z]+[0-9]+[a-z]*\b'      # versioni/nomi tecnici (x86_64, armv7, DSM7, etc.)
)

# Scansiona tutti i file rilevanti
$fileTypes = @("*.sh", "*.ps1", "*.md", "*.bat", "*.txt", "*.json", "*.toml", "*.conf")
$excludeDirs = @(".git", "node_modules", ".vscode")

Write-Host "🔍 Scansione file per parole tecniche..." -ForegroundColor Yellow

$allFiles = Get-ChildItem -Path . -Recurse -Include $fileTypes | 
    Where-Object { 
        $file = $_
        -not ($excludeDirs | Where-Object { $file.FullName -like "*\$_\*" })
    }

$wordCounts = @{}

foreach ($file in $allFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    
    # Cerca pattern tecnici
    foreach ($pattern in $technicalPatterns) {
        $matches = [regex]::Matches($content, $pattern)
        foreach ($match in $matches) {
            $word = $match.Value.Trim()
            if ($word.Length -ge 2 -and -not $existingWords.Contains($word)) {
                [void]$newWords.Add($word)
                if (-not $wordCounts.ContainsKey($word)) {
                    $wordCounts[$word] = 0
                }
                $wordCounts[$word]++
            }
        }
    }
    
    # Cerca anche parole italiane specifiche non ancora nel dizionario
    $italianPattern = '\b[a-z]{4,}(?:zione|mento|aggio|tura|tore|rice|bile|ente|ante|isce|iamo|iate|endo|ato|ita|ito|ale|oso|osa|ivo|iva)\b'
    $italianMatches = [regex]::Matches($content, $italianPattern)
    foreach ($match in $italianMatches) {
        $word = $match.Value.Trim()
        if (-not $existingWords.Contains($word)) {
            [void]$newWords.Add($word)
            if (-not $wordCounts.ContainsKey($word)) {
                $wordCounts[$word] = 0
            }
            $wordCounts[$word]++
        }
    }
}

# Ordina per frequenza
$sortedWords = $wordCounts.GetEnumerator() | 
    Sort-Object Value -Descending | 
    Select-Object -ExpandProperty Key

Write-Host "✅ Trovate $($newWords.Count) nuove parole tecniche" -ForegroundColor Green
Write-Host ""

if ($newWords.Count -eq 0) {
    Write-Host "🎉 Nessuna nuova parola da aggiungere! Dizionario completo." -ForegroundColor Green
    exit 0
}

# Mostra esempi
Write-Host "📋 Esempi di parole trovate (top 30 per frequenza):" -ForegroundColor Cyan
$sortedWords | Select-Object -First 30 | ForEach-Object {
    $count = $wordCounts[$_]
    Write-Host "  - $_ ($count occorrenze)" -ForegroundColor Gray
}

if ($sortedWords.Count -gt 30) {
    Write-Host "  ... e altre $($sortedWords.Count - 30) parole" -ForegroundColor Gray
}
Write-Host ""

# Chiedi conferma
if ($WhatIf) {
    Write-Host "⚠️  Modalità WhatIf: nessuna modifica verrà applicata" -ForegroundColor Yellow
    exit 0
}

$response = Read-Host "Vuoi aggiungere queste $($newWords.Count) parole al dizionario? (s/n)"
if ($response -ne "s") {
    Write-Host "❌ Operazione annullata" -ForegroundColor Red
    exit 0
}

# Aggiungi le nuove parole
foreach ($word in $newWords) {
    [void]$existingWords.Add($word)
}

# Ordina alfabeticamente
$sortedDict = $existingWords | Sort-Object

# Ricostruisci il JSON
$settings.'cSpell.words' = @($sortedDict)

# Salva il file
$newJson = $settings | ConvertTo-Json -Depth 10
$newJson | Set-Content $settingsPath -Encoding UTF8

Write-Host ""
Write-Host "✅ Dizionario aggiornato!" -ForegroundColor Green
Write-Host "   Parole totali: $($sortedDict.Count) (+$($newWords.Count))" -ForegroundColor Green
Write-Host ""
Write-Host "🔍 Controlla ora il contatore 'SPELL CHECKER' in VS Code!" -ForegroundColor Cyan
Write-Host "   Se ci sono ancora errori, riesegui questo script." -ForegroundColor Cyan
