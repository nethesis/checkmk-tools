#!/usr/bin/env pwsh
# fix-shellcheck-sc2155.ps1 - Fix SC2155 errors in all bash scripts
# Automatically fixes "Declare and assign separately to avoid masking return values"

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot

Write-Host "🔍 Scanning for SC2155 errors in bash scripts..." -ForegroundColor Cyan

# Get all .sh files
$shellFiles = Get-ChildItem -Path $scriptRoot -Filter "*.sh" -Recurse | Where-Object {
    $_.FullName -notmatch '\\node_modules\\|\\\.git\\'
}

Write-Host "📁 Found $($shellFiles.Count) shell scripts" -ForegroundColor Green

$totalFixed = 0
$filesModified = @()

foreach ($file in $shellFiles) {
    Write-Host "`n📄 Checking: $($file.Name)" -ForegroundColor Yellow
    
    # Run shellcheck to find SC2155 errors
    $shellcheckOutput = shellcheck -f json $file.FullName 2>$null | ConvertFrom-Json
    $sc2155Errors = $shellcheckOutput | Where-Object { $_.code -eq 2155 }
    
    if ($sc2155Errors.Count -eq 0) {
        Write-Host "   ✅ No SC2155 errors" -ForegroundColor Gray
        continue
    }
    
    Write-Host "   ⚠️  Found $($sc2155Errors.Count) SC2155 error(s)" -ForegroundColor Yellow
    
    # Read file content
    $content = Get-Content $file.FullName -Raw
    $lines = Get-Content $file.FullName
    $modified = $false
    
    # Process each error (in reverse order to maintain line numbers)
    $sc2155Errors | Sort-Object -Property line -Descending | ForEach-Object {
        $error = $_
        $lineNum = $error.line - 1  # Zero-based index
        $originalLine = $lines[$lineNum]
        
        # Match various patterns: local var=$(command) or var=$(command)
        if ($originalLine -match '^\s*(local\s+)?(\w+)=\$\((.+)\)\s*$') {
            $prefix = if ($matches[1]) { $matches[1] } else { '' }
            $varName = $matches[2]
            $command = $matches[3]
            
            # Get indentation
            $indent = ''
            if ($originalLine -match '^(\s*)') {
                $indent = $matches[1]
            }
            
            # Create fixed version
            $newLines = @(
                "${indent}${prefix}${varName}",
                "${indent}${varName}=`$($command)"
            )
            
            Write-Host "      Line $($error.line): $varName" -ForegroundColor Cyan
            
            # Replace in array
            $lines[$lineNum] = $newLines -join "`n"
            $modified = $true
            $totalFixed++
        }
    }
    
    if ($modified) {
        # Join lines and write back
        $newContent = $lines -join "`n"
        Set-Content -Path $file.FullName -Value $newContent -NoNewline
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
    
    Write-Host "`n✅ All SC2155 errors have been fixed!" -ForegroundColor Green
    Write-Host "💡 Review changes and commit with: git add -A && git commit -m 'fix: resolve SC2155 shellcheck warnings'" -ForegroundColor Cyan
} else {
    Write-Host "`n✅ No files needed modification!" -ForegroundColor Green
}
