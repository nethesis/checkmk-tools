# Aggiungi parole specifiche dagli errori cSpell visibili negli screenshot

param(
    [string[]]$Words = @(
        # Dagli screenshot fix-all-cspell-errors.ps1
        "verrebbe", "tecnici", "varianti", "tecnici", "Scansione", "anche", "iate", "endo",
        
        # Dagli screenshot install-agent-frpc-synology.sh  
        "ricostruisci", "riesegui", "Colon", "continuera", "essercì", "netcat", "natìvo",
        "sendall", "binario", "anche",
        
        # Dagli screenshot fix-italian-words.ps1
        "sugli", "reali", "mancanti", "negli", "viste", "negii", "immagini", "degli",
        "Sostantivi", "verbi", "Aggettivi", "avverbi", "Preposizioni", "congiunzioni", "Espressioni",
        
        # Parole tecniche italiane comuni che mancano
        "verrebbe", "potrebbero", "dovrebbe", "dovrebbero", "sarebbe", "sarebbero",
        "farebbe", "farebbero", "avrebbe", "avrebbero", "vorrebbe", "vorrebbero",
        "potrebbe", "andrebbero", "verrebbero", "darebbe", "darebbero",
        "tecnici", "tecnica", "tecniche", "variante", "varianti",
        "scansione", "scansioni", "analisi", "elaborazione", "elaborazioni",
        "esecuzione", "esecuzioni", "operazioni", "procedura", "procedure",
        "ricostruzione", "ricostruzioni", "riesecuzione", "riesecuzioni",
        "continuazione", "continuazioni", "proseguimento", "prosecuzione",
        "binari", "binaria", "binarie", "eseguibili", "eseguibile",
        "nativi", "nativa", "native", "nativo",
        "sugli", "negli", "dagli", "degli", "agli",
        "reali", "reale", "virtuale", "virtuali", "fisici", "fisica", "fisiche",
        "viste", "vista", "visibili", "visibile", "invisibili", "invisibile",
        "mancante", "mancanti", "assente", "assenti", "presente", "presenti",
        "immagine", "immagini", "icona", "icone", "simbolo", "simboli",
        "sostantivo", "sostantivi", "verbo", "verbi", "aggettivo", "aggettivi",
        "avverbio", "avverbi", "preposizione", "preposizioni",
        "congiunzione", "congiunzioni", "espressione", "espressioni",
        "frase", "frasi", "termine", "termini", "parola", "parole",
        
        # Forme verbali che mancano
        "verrebbero", "andrebbero", "farebbe", "farebbero", "darebbe", "darebbero",
        "direbbe", "direbbero", "vedrebbe", "vedrebbero", "saprebbe", "saprebbero",
        "vorrebbe", "vorrebbero", "potrebbe", "potrebbero", "dovrebbe", "dovrebbero",
        
        # Altre parole tecniche
        "ricostruire", "rieseguire", "riavviare", "ricaricare", "riconfigurare",
        "ridistribuire", "reinstallare", "ricompilare", "rigenerare", "ricalcolare",
        "proseguire", "continuare", "interrompere", "sospendere", "riprendere",
        "binario", "eseguibile", "libreria", "librerie", "modulo", "moduli",
        "componente", "componenti", "plugin", "estensione", "estensioni",
        "nativo", "nativa", "nativi", "native", "compilato", "compilata", "compilati",
        "interpretato", "interpretata", "interpretati", "interpretate",
        
        # Preposizioni articolate
        "sullo", "sugli", "sulla", "sulle", "sul",
        "nello", "negli", "nella", "nelle", "nel",
        "dallo", "dagli", "dalla", "dalle", "dal",
        "dello", "degli", "della", "delle", "del",
        "allo", "agli", "alla", "alle", "al",
        
        # Pronomi e articoli
        "questo", "questa", "questi", "queste", "quello", "quella", "quelli", "quelle",
        "qualche", "alcuni", "alcune", "parecchi", "parecchie", "molti", "molte",
        "pochi", "poche", "tutti", "tutte", "ciascuno", "ciascuna",
        
        # Avverbi comuni
        "molto", "poco", "troppo", "abbastanza", "assai", "quanto", "tanto",
        "più", "meno", "anche", "pure", "ancora", "già", "sempre", "mai",
        "spesso", "raramente", "talvolta", "qualche volta", "ogni volta",
        "subito", "presto", "tardi", "dopo", "prima", "ora", "adesso",
        "qui", "qua", "lì", "là", "dove", "ovunque", "altrove",
        "così", "come", "quanto", "tanto", "troppo",
        "sì", "no", "forse", "probabilmente", "certamente", "sicuramente",
        
        # Congiunzioni e connettivi
        "però", "ma", "però", "tuttavia", "comunque", "invece",
        "quindi", "perciò", "pertanto", "dunque", "allora",
        "oppure", "ovvero", "ossia", "cioè", "infatti",
        "perché", "poiché", "siccome", "dato che", "visto che",
        "affinché", "purché", "sebbene", "benché", "nonostante",
        "se", "qualora", "quando", "mentre", "finché",
        
        # Verbi comuni mancanti
        "vedere", "vede", "vedi", "veda", "vedano", "vedendo", "visto", "vista",
        "dire", "dice", "dici", "dica", "dicano", "dicendo", "detto", "detta",
        "fare", "fa", "fai", "faccia", "facciano", "facendo", "fatto", "fatta",
        "dare", "da", "dai", "dia", "diano", "dando", "dato", "data",
        "stare", "sta", "stai", "stia", "stiano", "stando", "stato", "stata",
        "andare", "va", "vai", "vada", "vadano", "andando", "andato", "andata",
        "venire", "viene", "vieni", "venga", "vengano", "venendo", "venuto", "venuta",
        "sapere", "sa", "sai", "sappia", "sappiano", "sapendo", "saputo", "saputa",
        "volere", "vuole", "vuoi", "voglia", "vogliano", "volendo", "voluto", "voluta",
        "potere", "può", "puoi", "possa", "possano", "potendo", "potuto", "potuta",
        "dovere", "deve", "devi", "debba", "debbano", "dovendo", "dovuto", "dovuta"
    )
)

$ErrorActionPreference = "Stop"
$settingsPath = ".vscode\settings.json"

Write-Host "=== Aggiungi parole specifiche dagli errori ===" -ForegroundColor Cyan
Write-Host ""

# Leggi settings.json
if (-not (Test-Path $settingsPath)) {
    Write-Host "❌ File $settingsPath non trovato!" -ForegroundColor Red
    exit 1
}

$settingsContent = Get-Content $settingsPath -Raw
$settings = $settingsContent | ConvertFrom-Json

# Dizionario esistente
$existingWords = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
if ($settings.PSObject.Properties['cSpell.words']) {
    foreach ($word in $settings.'cSpell.words') {
        [void]$existingWords.Add($word)
    }
}

Write-Host "📖 Dizionario attuale: $($existingWords.Count) parole" -ForegroundColor Green

# Rimuovi duplicati e filtra parole già presenti
$uniqueWords = $Words | Select-Object -Unique | Where-Object { $_ -and $_.Trim() -and -not $existingWords.Contains($_) }

Write-Host "✅ Trovate $($uniqueWords.Count) nuove parole da aggiungere" -ForegroundColor Green
Write-Host ""

if ($uniqueWords.Count -eq 0) {
    Write-Host "🎉 Tutte le parole sono già nel dizionario!" -ForegroundColor Green
    exit 0
}

# Mostra tutte le parole
Write-Host "📋 Parole da aggiungere:" -ForegroundColor Cyan
$uniqueWords | ForEach-Object {
    Write-Host "  - $_" -ForegroundColor Gray
}
Write-Host ""

$response = Read-Host "Aggiungi queste $($uniqueWords.Count) parole? (s/n)"
if ($response -ne "s") {
    Write-Host "❌ Operazione annullata" -ForegroundColor Red
    exit 0
}

# Aggiungi parole
foreach ($word in $uniqueWords) {
    [void]$existingWords.Add($word)
}

# Ordina
$sortedDict = $existingWords | Sort-Object

# Aggiorna JSON
$settings.'cSpell.words' = @($sortedDict)
$newJson = $settings | ConvertTo-Json -Depth 10
$newJson | Set-Content $settingsPath -Encoding UTF8

Write-Host ""
Write-Host "✅ Dizionario aggiornato!" -ForegroundColor Green
Write-Host "   Parole totali: $($sortedDict.Count) (+$($uniqueWords.Count))" -ForegroundColor Green
Write-Host ""
Write-Host "🔍 Controlla il contatore SPELL CHECKER!" -ForegroundColor Cyan
