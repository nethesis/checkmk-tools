#!/usr/bin/env pwsh
# Script per aggiornare gli URL nei file remoti

$remoteFiles = Get-ChildItem -Recurse -Filter "r*" -File | Where-Object { 
    $_.Extension -in @(".sh", ".ps1") -and $_.DirectoryName -like "*\remote"
}

foreach ($file in $remoteFiles) {
    $content = Get-Content $file.FullName -Raw
    $modified = $false
    
    # Aggiorna i percorsi in base alla cartella padre
    $parentDir = Split-Path (Split-Path $file.DirectoryName -Parent) -Leaf
    
    switch ($parentDir) {
        "script-tools" {
            if ($content -match 'https://raw\.githubusercontent\.com/Coverup20/checkmk-tools/main/script-tools/([^/\s"]+)') {
                $scriptName = $matches[1]
                $content = $content -replace "main/script-tools/$scriptName", "main/script-tools/full/$scriptName"
                $modified = $true
            }
        }
        "script-notify-checkmk" {
            if ($content -match 'https://raw\.githubusercontent\.com/Coverup20/checkmk-tools/main/script-notify-checkmk/([^/\s"]+)') {
                $scriptName = $matches[1]
                $content = $content -replace "main/script-notify-checkmk/$scriptName", "main/script-notify-checkmk/full/$scriptName"
                $modified = $true
            }
        }
        "Ydea-Toolkit" {
            if ($content -match 'https://raw\.githubusercontent\.com/Coverup20/checkmk-tools/main/Ydea-Toolkit/([^/\s"]+)') {
                $scriptName = $matches[1]
                $content = $content -replace "main/Ydea-Toolkit/$scriptName", "main/Ydea-Toolkit/full/$scriptName"
                $modified = $true
            }
        }
        "Fix" {
            if ($content -match 'https://raw\.githubusercontent\.com/Coverup20/checkmk-tools/main/Fix/([^/\s"]+)') {
                $scriptName = $matches[1]
                $content = $content -replace "main/Fix/$scriptName", "main/Fix/full/$scriptName"
                $modified = $true
            }
        }
    }
    
    if ($modified) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Aggiornato: $($file.FullName)"
    }
}

Write-Host "`nURL aggiornati!"
