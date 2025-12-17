# Fix All Spelling Errors - Legge tutti gli errori cSpell e aggiunge le parole al dizionario
# Usage: .\fix-all-spelling-errors.ps1

$ErrorActionPreference = "Stop"
$settingsPath = Join-Path $PSScriptRoot ".vscode\settings.json"

Write-Host "🔍 Lettura configurazione VS Code..." -ForegroundColor Cyan

# Leggi il settings.json attuale
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

# Converti l'array di parole in HashSet per ricerca veloce
$existingWords = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($word in $settings.'cSpell.words') {
    [void]$existingWords.Add($word)
}

Write-Host "📚 Dizionario attuale: $($existingWords.Count) parole" -ForegroundColor Green

# Cerca tutti i file bash, PowerShell e markdown
Write-Host "`n🔍 Scansione file per parole sconosciute..." -ForegroundColor Cyan

$files = Get-ChildItem -Path $PSScriptRoot -Include "*.sh","*.ps1","*.md","*.bat" -Recurse -File | 
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|\.git|\.vscode)[\\/]' }

Write-Host "📄 Trovati $($files.Count) file da analizzare" -ForegroundColor Yellow

# Raccogli tutte le parole italiane uniche dai file
$italianWords = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

# Pattern per parole italiane comuni
$patterns = @(
    '\b[a-z]+(?:zione|mento|aggio|tura|tore|rice|bile|ente|ante|isce|eggia|ata|ato|ati|ate)\b',
    '\b(?:agg|all|app|att|avv|coll|comm|comp|conf|conn|cont|corr|cre|deb|def|dep|des|det|dev|diag|diff|disp|div|eff|elab|eleg|elim|emb|enc|equ|err|ese|eseg|eserc|esp|est|evid|exec|fall|filt|fin|form|forz|funz|gar|gen|gest|guid|ident|impl|impost|inc|ind|inf|iniz|ins|inst|int|interr|inv|iso|iter|lib|lim|log|manut|marc|mem|mess|met|migl|min|mod|monit|mot|not|obb|ogg|oper|opt|ord|org|origin|pack|param|part|pass|pend|perc|perm|pers|port|pos|prec|pred|prep|pres|prev|princ|prior|priv|prob|proc|prod|prog|prom|prop|prot|prov|pubb|pul|punt|quot|racc|ragg|rap|real|rec|reg|rel|rem|render|rep|req|res|restr|ret|rev|rich|ricon|rid|rif|ril|rim|rinv|ripr|risc|ris|risol|rist|risult|rit|riv)[a-z]{2,}\b',
    '\b(?:ad|al|dall|dell|nell|sull)[a-z]+\b',
    '\bper[a-z]+\b',
    '\b[a-z]+(?:are|ere|ire|ato|ito|uto)\b'
)

$totalMatches = 0

foreach ($file in $files) {
    try {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        foreach ($pattern in $patterns) {
            $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            foreach ($match in $matches) {
                $word = $match.Value.ToLower()
                # Filtra parole troppo corte o che sono già nel dizionario
                if ($word.Length -ge 4 -and -not $existingWords.Contains($word)) {
                    [void]$italianWords.Add($word)
                    $totalMatches++
                }
            }
        }
    } catch {
        Write-Host "  ⚠️  Errore lettura $($file.Name): $_" -ForegroundColor Yellow
    }
}

Write-Host "✅ Trovate $($italianWords.Count) parole italiane uniche ($totalMatches occorrenze totali)" -ForegroundColor Green

if ($italianWords.Count -eq 0) {
    Write-Host "`n✅ Nessuna nuova parola da aggiungere!" -ForegroundColor Green
    exit 0
}

# Mostra alcune parole di esempio
Write-Host "`n📝 Esempi di parole trovate:" -ForegroundColor Cyan
$italianWords | Select-Object -First 20 | ForEach-Object {
    Write-Host "  - $_" -ForegroundColor Gray
}
if ($italianWords.Count -gt 20) {
    Write-Host "  ... e altre $($italianWords.Count - 20) parole" -ForegroundColor Gray
}

# Chiedi conferma
Write-Host "`n❓ Aggiungere queste $($italianWords.Count) parole al dizionario?" -ForegroundColor Yellow
$confirmation = Read-Host "  [S/n]"

if ($confirmation -ne '' -and $confirmation -notmatch '^[sS]') {
    Write-Host "❌ Operazione annullata" -ForegroundColor Red
    exit 1
}

# Aggiungi le nuove parole al dizionario esistente
Write-Host "`n📝 Aggiornamento dizionario..." -ForegroundColor Cyan

foreach ($word in $italianWords) {
    [void]$existingWords.Add($word)
}

# Ordina alfabeticamente
$sortedWords = $existingWords | Sort-Object

# Aggiorna il settings.json
$settings.'cSpell.words' = $sortedWords

# Salva il file
$json = $settings | ConvertTo-Json -Depth 10
$json | Set-Content $settingsPath -Encoding UTF8

Write-Host "✅ Dizionario aggiornato: $($sortedWords.Count) parole totali (+$($italianWords.Count) nuove)" -ForegroundColor Green
Write-Host "`n💡 Controlla ora il contatore 'SPELL CHECKER' in VS Code!" -ForegroundColor Cyan
Write-Host "   Dovrebbe essere diminuito significativamente." -ForegroundColor Gray
