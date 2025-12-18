param(
  [string]$Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '.')).Path,
  [string]$Report = (Join-Path $PSScriptRoot 'bashn-full-report.txt'),
  [switch]$WhatIf,
  [int]$MaxFix = 500
)

$ErrorActionPreference = 'Stop'

function Convert-ToWslPath([string]$WindowsPath) {
  if ($WindowsPath -notmatch '^[A-Za-z]:\\') {
    throw "Unsupported path format: $WindowsPath"
  }
  $drive = $WindowsPath.Substring(0, 1).ToLower()
  $rest = $WindowsPath.Substring(2) -replace '\\', '/'
  return "/mnt/$drive$rest"
}

function Test-BashSyntax([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  $wslPath = Convert-ToWslPath $Path
  $null = wsl bash -n "$wslPath" 2>&1
  return ($LASTEXITCODE -eq 0)
}

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

function Resolve-SourceForDest([string]$DestPath) {
  $destLeaf = Split-Path $DestPath -Leaf

  # Heuristic mapping for installer bundle copies -> authoritative full scripts
  $lower = $DestPath.ToLower()
  $scriptRootLower = ($Root.TrimEnd('\') + '\').ToLower()

  if ($lower.Contains('\install\checkmk-installer\scripts\proxmox\')) {
    $candidate = Join-Path $Root (Join-Path 'script-check-proxmox\full' $destLeaf)
    if (Test-Path -LiteralPath $candidate) { return $candidate }
  }

  foreach ($name in @('script-check-ns7','script-check-ns8','script-check-nsec8','script-check-ubuntu','script-check-windows','script-check-proxmox','script-notify-checkmk','script-tools')) {
    $needle = ('\\install\\checkmk-installer\\scripts\\' + $name + '\\')
    if ($lower.Contains($needle)) {
      $candidate = Join-Path $Root (Join-Path ($name + '\\full') $destLeaf)
      if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
  }

  # Install/Installers: try other copies by basename outside install/checkmk-installer
  $candidates = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $destLeaf | Where-Object {
    $_.FullName -ne $DestPath -and
    ($_.FullName.ToLower().StartsWith($scriptRootLower)) -and
    (-not $_.FullName.ToLower().Contains('\\install\\checkmk-installer\\'))
  } | Select-Object -ExpandProperty FullName

  foreach ($c in $candidates) {
    if (Test-BashSyntax $c) {
      return $c
    }
  }

  return $null
}

function Copy-WithBackup([string]$SourcePath, [string]$DestPath) {
  $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
  $backup = "$DestPath.bak.$timestamp"
  Copy-Item -LiteralPath $DestPath -Destination $backup -Force
  Copy-Item -LiteralPath $SourcePath -Destination $DestPath -Force
  return $backup
}

Write-Host "Root: $Root"
Write-Host "Report: $Report"

$failFiles = Get-FailFilesFromReport $Report
Write-Host ("Fail files in report: {0}" -f $failFiles.Count)

$fixed = 0
$skipped = 0
$unresolved = New-Object System.Collections.Generic.List[object]

foreach ($dest in $failFiles) {
  if ($fixed -ge $MaxFix) { break }

  if (-not (Test-Path -LiteralPath $dest)) {
    $unresolved.Add([pscustomobject]@{ File = $dest; Reason = 'MISSING_ON_DISK' })
    continue
  }

  $src = Resolve-SourceForDest $dest
  if ([string]::IsNullOrWhiteSpace($src)) {
    $unresolved.Add([pscustomobject]@{ File = $dest; Reason = 'NO_SOURCE_FOUND' })
    continue
  }

  if (-not (Test-BashSyntax $src)) {
    $unresolved.Add([pscustomobject]@{ File = $dest; Reason = "SOURCE_FAILS_BASH_N: $src" })
    continue
  }

  if ($WhatIf) {
    Write-Host "WHATIF: $dest <= $src"
    $skipped++
    continue
  }

  $bak = Copy-WithBackup -SourcePath $src -DestPath $dest
  if (Test-BashSyntax $dest) {
    Write-Host "FIXED: $dest <= $src (backup: $bak)"
    $fixed++
  } else {
    $unresolved.Add([pscustomobject]@{ File = $dest; Reason = "DEST_STILL_FAILS_AFTER_COPY (backup: $bak)" })
  }
}

Write-Host ""
Write-Host "Summary: FIXED=$fixed SKIPPED(whatif)=$skipped UNRESOLVED=$($unresolved.Count)"

if ($unresolved.Count -gt 0) {
  $out = Join-Path $PSScriptRoot 'bashn-unresolved.txt'
  $unresolved | Sort-Object File | Format-Table -AutoSize | Out-String -Width 260 | Set-Content -LiteralPath $out -Encoding UTF8
  Write-Host "Unresolved list written: $out"
}
