# Script per aggiungere parole italiane specifiche da stringhe di testo
# Basato sugli errori cSpell reali nel file install-agent-frpc-synology.sh

param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$settingsPath = ".vscode\settings.json"

Write-Host "=== Aggiungi parole italiane mancanti ===" -ForegroundColor Cyan
Write-Host ""

# Parole italiane comuni viste negli errori cSpell
$italianWords = @(
    # Dalle immagini degli errori
    "Colon", "globali", "specifiche", "Modalità", "senza", "pkill",
    "majorversion", "comunque", "Configurazione", "esserd", "eventuali",
    "caratteri", "numerici", "Visita", "Useremo", "killall", "reuseaddr",
    "compatibilità", "PYEOF", "signum", "chiusura", "setsockopt", "REUSEADDR",
    "nethlab", "riepilogo", "Riepilogo", "nohup", "Arresto", "Utilizzo",
    
    # Altre parole italiane tecniche comuni
    "avvio", "riavvio", "controllo", "configurato", "configurata", "configurati",
    "installato", "installata", "installati", "disinstallato", "disinstallata",
    "creato", "creata", "creati", "rimosso", "rimossa", "rimossi",
    "eseguito", "eseguita", "eseguiti", "completato", "completata", "completati",
    "verificato", "verificata", "verificati", "trovato", "trovata", "trovati",
    "caricato", "caricata", "caricati", "scaricato", "scaricata", "scaricati",
    "aggiornato", "aggiornata", "aggiornati", "modificato", "modificata", "modificati",
    "salvato", "salvata", "salvati", "cancellato", "cancellata", "cancellati",
    "attivo", "attiva", "attivi", "attive", "inattivo", "inattiva",
    "disponibile", "disponibili", "necessario", "necessaria", "necessari", "necessarie",
    "opzionale", "opzionali", "obbligatorio", "obbligatoria", "obbligatori", "obbligatorie",
    "automatico", "automatica", "automatici", "automatiche", "manuale", "manuali",
    "corretto", "corretta", "corretti", "corrette", "errato", "errata", "errati", "errate",
    "valido", "valida", "validi", "valide", "invalido", "invalida", "invalidi", "invalide",
    "richiesto", "richiesta", "richiesti", "richieste", "fornito", "fornita", "forniti", "fornite",
    "impostato", "impostata", "impostati", "impostate", "definito", "definita", "definiti", "definite",
    "specificato", "specificata", "specificati", "specificate",
    
    # Sostantivi comuni
    "utente", "utenti", "gruppo", "gruppi", "permesso", "permessi",
    "directory", "cartella", "cartelle", "archivio", "archivi",
    "pacchetto", "pacchetti", "dipendenza", "dipendenze",
    "servizio", "servizi", "processo", "processi", "daemon",
    "porta", "porte", "indirizzo", "indirizzi", "connessione", "connessioni",
    "timeout", "retry", "intervallo", "frequenza", "durata",
    "modalità", "opzione", "opzioni", "parametro", "parametri",
    "valore", "valori", "variabile", "variabili", "costante", "costanti",
    "stringa", "stringhe", "numero", "numeri", "carattere", "caratteri",
    "riga", "righe", "colonna", "colonne", "formato", "formati",
    "tipo", "tipi", "classe", "classi", "metodo", "metodi",
    "funzione", "funzioni", "script", "comando", "comandi",
    "output", "input", "risultato", "risultati", "messaggio", "messaggi",
    "errore", "errori", "warning", "avviso", "avvisi", "avvertimento",
    "informazione", "informazioni", "dettaglio", "dettagli",
    "percorso", "percorsi", "path", "nome", "nomi",
    "versione", "versioni", "release", "build", "aggiornamento", "aggiornamenti",
    "backup", "ripristino", "copia", "copie", "snapshot",
    "log", "registro", "registri", "evento", "eventi",
    "stato", "stati", "condizione", "condizioni", "situazione",
    "sistema", "sistemi", "piattaforma", "piattaforme", "ambiente", "ambienti",
    "server", "client", "host", "nodo", "nodi", "macchina", "macchine",
    "rete", "reti", "protocollo", "protocolli", "porta", "porte",
    
    # Verbi comuni (varie forme)
    "avviare", "avvia", "avviato", "avviando", "riavviare", "riavvia",
    "fermare", "ferma", "fermato", "fermando", "arrestare", "arresta",
    "installare", "installa", "installando", "disinstallare", "disinstalla",
    "configurare", "configura", "configurando", "impostare", "imposta",
    "verificare", "verifica", "verificando", "controllare", "controlla",
    "cercare", "cerca", "cercando", "trovare", "trova", "trovando",
    "creare", "crea", "creando", "generare", "genera", "generando",
    "eliminare", "elimina", "eliminando", "rimuovere", "rimuovi", "rimuovendo",
    "cancellare", "cancella", "cancellando", "pulire", "pulisci", "pulendo",
    "eseguire", "esegui", "eseguendo", "lanciare", "lancia", "lanciando",
    "caricare", "carica", "caricando", "scaricare", "scarica", "scaricando",
    "leggere", "leggi", "leggendo", "scrivere", "scrivi", "scrivendo",
    "salvare", "salva", "salvando", "modificare", "modifica", "modificando",
    "aggiornare", "aggiorna", "aggiornando", "sostituire", "sostituisci",
    "copiare", "copia", "copiando", "spostare", "sposta", "spostando",
    "mostrare", "mostra", "mostrando", "visualizzare", "visualizza",
    "stampare", "stampa", "stampando", "visualizzare", "visualizza",
    "attendere", "attendi", "attendendo", "aspettare", "aspetta",
    "terminare", "termina", "terminando", "completare", "completa",
    "iniziare", "inizia", "iniziando", "cominciare", "comincia",
    "continuare", "continua", "continuando", "proseguire", "prosegui",
    "ritentare", "ritenta", "ritentando", "riprovare", "riprova",
    "confermare", "conferma", "confermando", "validare", "valida",
    "testare", "testa", "testando", "provare", "prova", "provando",
    "utilizzare", "utilizza", "utilizzando", "usare", "usa", "usando",
    "applicare", "applica", "applicando", "abilitare", "abilita",
    "disabilitare", "disabilita", "attivare", "attiva", "disattivare",
    "connettere", "connetti", "connettendo", "disconnettere", "disconnetti",
    "inviare", "invia", "inviando", "ricevere", "ricevi", "ricevendo",
    "trasmettere", "trasmetti", "ascoltare", "ascolta", "rispondere", "rispondi",
    
    # Aggettivi e avverbi
    "nuovo", "nuova", "nuovi", "nuove", "vecchio", "vecchia", "vecchi", "vecchie",
    "primo", "prima", "primi", "prime", "ultimo", "ultima", "ultimi", "ultime",
    "precedente", "precedenti", "successivo", "successiva", "successivi", "successive",
    "prossimo", "prossima", "prossimi", "prossime", "corrente", "correnti",
    "attuale", "attuali", "presente", "presenti", "futuro", "futura", "futuri", "future",
    "locale", "locali", "remoto", "remota", "remoti", "remote",
    "pubblico", "pubblica", "pubblici", "pubbliche", "privato", "privata", "privati", "private",
    "interno", "interna", "interni", "interne", "esterno", "esterna", "esterni", "esterne",
    "completo", "completa", "completi", "complete", "parziale", "parziali",
    "totale", "totali", "singolo", "singola", "singoli", "singole",
    "multiplo", "multipla", "multipli", "multiple", "doppio", "doppia", "doppi", "doppie",
    "principale", "principali", "secondario", "secondaria", "secondari", "secondarie",
    "primario", "primaria", "primari", "primarie", "ausiliario", "ausiliaria",
    "temporaneo", "temporanea", "temporanei", "temporanee", "permanente", "permanenti",
    "statico", "statica", "statici", "statiche", "dinamico", "dinamica", "dinamici", "dinamiche",
    "fisso", "fissa", "fissi", "fisse", "variabile", "variabili",
    "sicuro", "sicura", "sicuri", "sicure", "insicuro", "insicura",
    "veloce", "veloci", "lento", "lenta", "lenti", "lente",
    "grande", "grandi", "piccolo", "piccola", "piccoli", "piccole",
    "lungo", "lunga", "lunghi", "lunghe", "corto", "corta", "corti", "corte",
    "alto", "alta", "alti", "alte", "basso", "bassa", "bassi", "basse",
    "forte", "forti", "debole", "deboli", "massimo", "massima", "massimi", "massime",
    "minimo", "minima", "minimi", "minime", "medio", "media", "medi", "medie",
    "superiore", "superiori", "inferiore", "inferiori", "uguale", "uguali",
    "diverso", "diversa", "diversi", "diverse", "identico", "identica", "identici", "identiche",
    "simile", "simili", "differente", "differenti", "uguale", "uguali",
    
    # Preposizioni e congiunzioni
    "attraverso", "mediante", "tramite", "durante", "entro", "oltre",
    "oppure", "ovvero", "ossia", "quindi", "dunque", "perciò", "pertanto",
    "tuttavia", "comunque", "invece", "mentre", "quando", "qualora",
    "affinché", "sebbene", "benché", "nonostante", "malgrado",
    
    # Espressioni tecniche
    "localhost", "hostname", "username", "password", "token",
    "endpoint", "callback", "webhook", "payload", "query",
    "checksum", "hash", "signature", "certificate", "chiave",
    "autenticazione", "autorizzazione", "credenziali", "sessione",
    "timeout", "retry", "fallback", "default", "override",
    "deploy", "deployment", "rollback", "migration", "upgrade",
    "downgrade", "patch", "hotfix", "bugfix", "feature",
    "debug", "verbose", "quiet", "silent", "interactive",
    "batch", "bulk", "stream", "buffer", "cache", "pool"
)

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

# Filtra parole già presenti
$newWords = $italianWords | Where-Object { -not $existingWords.Contains($_) }

Write-Host "✅ Trovate $($newWords.Count) nuove parole italiane da aggiungere" -ForegroundColor Green
Write-Host ""

if ($newWords.Count -eq 0) {
    Write-Host "🎉 Tutte le parole sono già nel dizionario!" -ForegroundColor Green
    exit 0
}

# Mostra esempi
Write-Host "📋 Esempi di parole da aggiungere:" -ForegroundColor Cyan
$newWords | Select-Object -First 50 | ForEach-Object {
    Write-Host "  - $_" -ForegroundColor Gray
}

if ($newWords.Count -gt 50) {
    Write-Host "  ... e altre $($newWords.Count - 50) parole" -ForegroundColor Gray
}
Write-Host ""

if ($WhatIf) {
    Write-Host "⚠️  Modalità WhatIf: nessuna modifica" -ForegroundColor Yellow
    exit 0
}

$response = Read-Host "Aggiungi queste $($newWords.Count) parole? (s/n)"
if ($response -ne "s") {
    Write-Host "❌ Operazione annullata" -ForegroundColor Red
    exit 0
}

# Aggiungi parole
foreach ($word in $newWords) {
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
Write-Host "   Parole totali: $($sortedDict.Count) (+$($newWords.Count))" -ForegroundColor Green
Write-Host ""
Write-Host "🔍 Controlla il contatore SPELL CHECKER!" -ForegroundColor Cyan
