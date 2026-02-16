# Fix UTF-8 per launcher remoti NS7 - bash wrapper invece di Python diretto

$scriptDir = "C:\Users\Marzio\Desktop\CheckMK\checkmk-tools\script-check-ns7\remote"
$files = Get-ChildItem "$scriptDir\*.py" -File

foreach ($file in $files) {
    $scriptName = $file.BaseName
    $repoUrl = "https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-ns7/full/$scriptName.py"
    
    # Template bash wrapper che setta PYTHONIOENCODING prima di eseguire Python
    # Usa + concatenazione per evitare problemi con here-string annidati
    $bashWrapper = "#!/bin/bash`n"
    $bashWrapper += "# Remote launcher per $scriptName - Wrapper bash con UTF-8 encoding`n"
    $bashWrapper += "export PYTHONIOENCODING=utf-8`n"
    $bashWrapper += "export LANG=en_US.UTF-8`n"
    $bashWrapper += "export LC_ALL=en_US.UTF-8`n`n"
    
    # Nome script full senza prefisso "r" o "rssh_"
    $fullScriptName = $scriptName -replace '^r(check|ssh)[-_]', '$1_' -replace '^rcheck[-_]', 'check_' -replace '^rssh[-_]', 'ssh_'
    $fullRepoUrl = "https://raw.githubusercontent.com/Coverup20/checkmk-tools/main/script-check-ns7/full/$fullScriptName.py"
    
    $bashWrapper += "python3 - <<'PYTHON_SCRIPT'`n"
    $bashWrapper += "import urllib.request`n"
    $bashWrapper += "import sys`n`n"
    $bashWrapper += "REPO_URL = `"$fullRepoUrl`"`n`n"
    $bashWrapper += "try:`n"
    $bashWrapper += "    with urllib.request.urlopen(REPO_URL, timeout=10) as response:`n"
    $bashWrapper += "        script_code = response.read().decode('utf-8')`n"
    $bashWrapper += "    `n"
    $bashWrapper += "    exec(script_code, {'__name__': '__main__'})`n`n"
    $bashWrapper += "except Exception as e:`n"
    $serviceName = $scriptName -replace '^rcheck[-_]', '' -replace '[-_]', '_'
    $bashWrapper += "    print(f`"3 ${serviceName} - Failed to download/execute: {e}`")`n"
    $bashWrapper += "    sys.exit(0)`n"
    $bashWrapper += "PYTHON_SCRIPT`n"
    
    # Converti in LF (Unix line endings)
    $bashWrapper = $bashWrapper -replace "`r`n", "`n"
    
    # Salva con encoding UTF-8 senza BOM
    [System.IO.File]::WriteAllText($file.FullName, $bashWrapper, (New-Object System.Text.UTF8Encoding $false))
    
    Write-Host "Fixed: $($file.Name)" -ForegroundColor Green
}

Write-Host "`n✓ Completato: $($files.Count) launcher convertiti a bash wrapper UTF-8" -ForegroundColor Cyan
Write-Host "  Encoding UTF-8 settato PRIMA dell'avvio Python" -ForegroundColor Yellow
