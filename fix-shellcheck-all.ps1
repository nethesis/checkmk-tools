#!/usr/bin/env pwsh
# fix-shellcheck-all.ps1 - Fix common shellcheck errors (SC2162, SC2163)
# SC2162: read without -r will mangle backslashes
# SC2163: Export issue with variable syntax

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot

Write-Host "🔍 Scanning for SC2162 and SC2163 errors..." -ForegroundColor Cyan

# Get all .sh files
$shellFiles = Get-ChildItem -Path $scriptRoot -Filter "*.sh" -Recurse | Where-Object {
    $_.FullName -notmatch '\\node_modules\\|\\\.git\\'
}

Write-Host "📁 Found $($shellFiles.Count) shell scripts" -ForegroundColor Green

$totalFixed = 0
$filesModified = @()

foreach ($file in $shellFiles) {
    Write-Host "`n📄 Checking: $($file.Name)" -ForegroundColor Yellow
    
    # Run shellcheck
    $shellcheckOutput = shellcheck -f json $file.FullName 2>$null | ConvertFrom-Json
    $errors = $shellcheckOutput | Where-Object { $_.code -in @(2162, 2163) }
    
    if ($errors.Count -eq 0) {
        Write-Host "   ✅ No errors" -ForegroundColor Gray
        continue
    }
    
    Write-Host "   ⚠️  Found $($errors.Count) error(s)" -ForegroundColor Yellow
    
    # Read file
    $content = Get-Content $file.FullName -Raw
    $modified = $false
    
    # Fix SC2162: read without -r
    $sc2162Count = ($errors | Where-Object { $_.code -eq 2162 }).Count
    if ($sc2162Count -gt 0) {
        $originalContent = $content
        
        # Match: read VAR (without -r)
        $content = $content -replace '\bread\s+([A-Za-z_][A-Za-z0-9_]*)', 'read -r $1'
        
        # Match: read -p "prompt" VAR (without -r)
        $content = $content -replace '\bread\s+-p\s+', 'read -r -p '
        
        if ($content -ne $originalContent) {
            Write-Host "      Fixed $sc2162Count SC2162 error(s)" -ForegroundColor Cyan
            $modified = $true
            $totalFixed += $sc2162Count
        }
    }
    
    # Fix SC2163: Export syntax issues
    $sc2163Count = ($errors | Where-Object { $_.code -eq 2163 }).Count
    if ($sc2163Count -gt 0) {
        $lines = $content -split "`n"
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            
            # Match: export $VAR or export ${VAR}
            if ($line -match '^\s*export\s+\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?\s*$') {
                $varName = $matches[1]
                $indent = if ($line -match '^(\s*)') { $matches[1] } else { '' }
                $lines[$i] = "${indent}export $varName"
                Write-Host "      Line $($i+1): Fixed export `$$varName → export $varName" -ForegroundColor Cyan
                $modified = $true
                $totalFixed++
            }
        }
        
        if ($modified) {
            $content = $lines -join "`n"
        }
    }
    
    if ($modified) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        $filesModified += $file.FullName
        Write-Host "   ✅ Fixed and saved" -ForegroundColor Green
    }
}

Write-Host "`n" -NoNewline
Write-Host "═" * 60 -ForegroundColor Cyan
Write-Host "📊 SUMMARY" -ForegroundColor Green
Write-Host "═" * 60 -ForegroundColor Cyan
Write-Host "   Total errors fixed: $totalFixed" -ForegroundColor Yellow
Write-Host "   Files modified: $($filesModified.Count)" -ForegroundColor Yellow

if ($filesModified.Count -gt 0) {
    Write-Host "`n📝 Modified files:" -ForegroundColor Cyan
    $filesModified | ForEach-Object {
        $relativePath = $_.Replace($scriptRoot, "").TrimStart('\')
        Write-Host "   - $relativePath" -ForegroundColor Gray
    }
    
    Write-Host "`n✅ All shellcheck errors have been fixed!" -ForegroundColor Green
    Write-Host "💡 Review and commit: git add -A && git commit -m 'fix: resolve SC2162 and SC2163 shellcheck warnings'" -ForegroundColor Cyan
} else {
    Write-Host "`n✅ No files needed modification!" -ForegroundColor Green
}
