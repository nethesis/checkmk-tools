#!/usr/bin/env pwsh
# Script per riorganizzare le cartelle in remote/ e full/

$directories = @(
    "script-tools",
    "script-notify-checkmk",
    "Ydea-Toolkit",
    "Fix"
)

foreach ($dir in $directories) {
    if (Test-Path $dir) {
        Write-Host "Elaborazione cartella: $dir"
        
        # Crea sottocartelle
        $remotePath = Join-Path $dir "remote"
        $fullPath = Join-Path $dir "full"
        
        New-Item -ItemType Directory -Force -Path $remotePath | Out-Null
        New-Item -ItemType Directory -Force -Path $fullPath | Out-Null
        
        # Sposta file remoti (r*.sh, r*.ps1)
        Get-ChildItem -Path $dir -File -Filter "r*" | ForEach-Object {
            $dest = Join-Path $remotePath $_.Name
            if (-not (Test-Path $dest)) {
                git mv $_.FullName $dest
                Write-Host "  Spostato: $($_.Name) -> remote/"
            }
        }
        
        # Sposta file full (*.sh, *.ps1 senza prefisso r)
        Get-ChildItem -Path $dir -File | Where-Object { 
            ($_.Extension -eq ".sh" -or $_.Extension -eq ".ps1") -and 
            -not $_.Name.StartsWith("r") 
        } | ForEach-Object {
            $dest = Join-Path $fullPath $_.Name
            if (-not (Test-Path $dest)) {
                git mv $_.FullName $dest
                Write-Host "  Spostato: $($_.Name) -> full/"
            }
        }
    }
}

Write-Host "`nRiorganizzazione completata!"
Write-Host "Verifica i cambiamenti con: git status"
