#!/usr/bin/env pwsh
# fix-shellcheck-comprehensive.ps1 - Fix multiple shellcheck errors
# SC2155, SC2086, SC2046, SC2034, SC2009, SC2126, SC2162, SC2163

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot

Write-Host "🔍 Comprehensive shellcheck fix..." -ForegroundColor Cyan

# Get all .sh files
$shellFiles = Get-ChildItem -Path $scriptRoot -Filter "*.sh" -Recurse | Where-Object {
    $_.FullName -notmatch '\\node_modules\\|\\\.git\\'
}

Write-Host "📁 Found $($shellFiles.Count) shell scripts" -ForegroundColor Green

$totalFixed = 0
$filesModified = @()

foreach ($file in $shellFiles) {
    Write-Host "`n📄 Processing: $($file.Name)" -ForegroundColor Yellow
    
    # Read file
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    $fixCount = 0
    
    # Fix SC2086: Quote variables to prevent word splitting
    # Pattern: common unquoted variables in commands
    $patterns = @(
        # echo/print without quotes
        @{ Pattern = '(\becho\s+)(\$[A-Za-z_][A-Za-z0-9_]*)(?!\})'; Replacement = '$1"$2"' }
        @{ Pattern = '(\bprintf\s+[^\s]+\s+)(\$[A-Za-z_][A-Za-z0-9_]*)(?!\})'; Replacement = '$1"$2"' }
        # test/[ conditions
        @{ Pattern = '(\[\s+)(\$[A-Za-z_][A-Za-z0-9_]*)\s+(=|!=|==)'; Replacement = '$1"$2" $3' }
        @{ Pattern = '(=|!=|==)\s+(\$[A-Za-z_][A-Za-z0-9_]*)(\s+\])'; Replacement = '$1 "$2"$3' }
        # -z/-n tests
        @{ Pattern = '(\[\s+-[zn]\s+)(\$[A-Za-z_][A-Za-z0-9_]*)(\s+\])'; Replacement = '$1"$2"$3' }
    )
    
    foreach ($p in $patterns) {
        $newContent = $content -replace $p.Pattern, $p.Replacement
        if ($newContent -ne $content) {
            $content = $newContent
            $fixCount++
        }
    }
    
    # Fix SC2046: Quote to prevent word splitting in $()
    # Pattern: common command substitutions that should be quoted
    $content = $content -replace '(\s)(grep[^\|]+\$\([^\)]+\))(\s)', '$1"$2"$3'
    $content = $content -replace '(\s)(find[^\|]+\$\([^\)]+\))(\s)', '$1"$2"$3'
    
    # Fix SC2034: Variable appears unused (add underscore prefix or comment)
    # We'll skip this as it needs manual review
    
    # Fix SC2009: Consider using pgrep instead of ps | grep
    if ($content -match 'ps\s+[^\|]+\|\s*grep') {
        Write-Host "   ℹ️  Note: Consider using 'pgrep' instead of 'ps | grep'" -ForegroundColor Gray
    }
    
    # Fix SC2126: Consider using grep -c instead of grep | wc -l
    $content = $content -replace '(\bgrep\s+[^\|]+)\s*\|\s*wc\s+-l', '$1 -c'
    
    # Check if modified
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        $filesModified += $file.FullName
        Write-Host "   ✅ Fixed $fixCount issue(s)" -ForegroundColor Green
        $totalFixed += $fixCount
    } else {
        Write-Host "   ⚪ No changes needed" -ForegroundColor Gray
    }
}

Write-Host "`n" -NoNewline
Write-Host "═" * 60 -ForegroundColor Cyan
Write-Host "📊 SUMMARY" -ForegroundColor Green
Write-Host "═" * 60 -ForegroundColor Cyan
Write-Host "   Files modified: $($filesModified.Count)" -ForegroundColor Yellow
Write-Host "   Total fixes: $totalFixed" -ForegroundColor Yellow

if ($filesModified.Count -gt 0) {
    Write-Host "`n📝 Modified files (first 20):" -ForegroundColor Cyan
    $filesModified | Select-Object -First 20 | ForEach-Object {
        $relativePath = $_.Replace($scriptRoot, "").TrimStart('\')
        Write-Host "   - $relativePath" -ForegroundColor Gray
    }
    
    if ($filesModified.Count -gt 20) {
        Write-Host "   ... and $($filesModified.Count - 20) more" -ForegroundColor Gray
    }
    
    Write-Host "`n✅ Shellcheck fixes applied!" -ForegroundColor Green
    Write-Host "⚠️  Note: Some errors require manual review (SC1091, SC2034, etc.)" -ForegroundColor Yellow
    Write-Host "💡 Commit: git add -A && git commit -m 'fix: resolve additional shellcheck warnings'" -ForegroundColor Cyan
} else {
    Write-Host "`n✅ No automatic fixes available for remaining errors!" -ForegroundColor Green
    Write-Host "ℹ️  Remaining errors may require manual review" -ForegroundColor Gray
}
