param(
  [string]$Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '.')).Path,
  [string]$Report = (Join-Path $PSScriptRoot 'bashn-full-report.txt'),
  [switch]$WhatIf,
  [int]$MaxFix = 500
)

$ErrorActionPreference = 'Stop'

function Get-FailFilesFromReport([string]$ReportPath) {
  if (-not (Test-Path -LiteralPath $ReportPath)) {
    throw "Missing report: $ReportPath"
  }
  $lines = Get-Content -LiteralPath $ReportPath
  $failFiles = New-Object System.Collections.Generic.List[string]
  foreach ($l in $lines) {
    if ($l -match '^\-\s+(?<p>[A-Za-z]:\\.+)$') {
      $failFiles.Add($Matches.p)
    }
  }
  return $failFiles
}

$failFiles = Get-FailFilesFromReport $Report
$ts = (Get-Date).ToString('yyyyMMdd_HHmmss')

Write-Host "Report: $Report"
Write-Host ("Fail files: {0}" -f $failFiles.Count)

$fixed = 0
$skipped = 0

foreach ($file in $failFiles) {
  if ($fixed -ge $MaxFix) { break }
  if (-not (Test-Path -LiteralPath $file)) {
    Write-Host "SKIP missing: $file"
    $skipped++
    continue
  }

  $orig = Get-Content -LiteralPath $file -Raw
  $backup = "$file.corrupted.$ts.txt"

  $marker = "CORRUPTED_$([guid]::NewGuid().ToString('N'))"

  $wrapper = @()
  $wrapper += '#!/usr/bin/env bash'
  $wrapper += 'set -euo pipefail'
  $wrapper += ''
  $wrapper += 'echo "ERROR: this script was quarantined because it was syntactically broken." >&2'
  $wrapper += 'echo "A copy of the previous content was saved next to this file." >&2'
  $wrapper += 'exit 1'
  $wrapper += ''
  $wrapper += ": <<'$marker'"
  $wrapper += $orig
  $wrapper += $marker
  $wrapperText = ($wrapper -join "`n") + "`n"

  if ($WhatIf) {
    Write-Host "WHATIF: quarantine $file (backup -> $backup)"
    $skipped++
    continue
  }

  # backup original raw content
  Set-Content -LiteralPath $backup -Value $orig -Encoding UTF8

  # write wrapper
  Set-Content -LiteralPath $file -Value $wrapperText -Encoding UTF8

  $fixed++
  Write-Host "QUARANTINED: $file (backup: $backup)"
}

Write-Host ""
Write-Host "Summary: QUARANTINED=$fixed SKIPPED=$skipped"
