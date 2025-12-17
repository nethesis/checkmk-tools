[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$ListPath = "BAD_SCRIPTS_SCAN.txt",

  [int]$MaxCommitsPerFile = 2000,

  [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-BashCorruption {
  param([Parameter(Mandatory)] [string]$Text)

  # Ignore archived corrupted tails wrapped in a heredoc marker.
  $marker = ": <<'CORRUPTED_ORIGINAL'"
  $pos = $Text.IndexOf($marker)
  if ($pos -ge 0) {
    $Text = $Text.Substring(0, $pos)
  }

  # Strong corruption signatures observed in this repo.
  if ($Text -match '\)if\b|\)elif\b|\)then\b|\)else\b') { return $true }
  if ($Text -match '\b[0-9]elif\b') { return $true }

  # Detect keyword glued to next command on the same line (space/tab only; newline is OK).
  if ($Text -match '\bfi[\t ]+(echo|read)\b') { return $true }
  if ($Text -match '\bdone[\t ]+(echo|read)\b') { return $true }
  if ($Text -match '\bexit[\t ]+[0-9]+(elif|else|fi)\b') { return $true }

  return $false
}

function Invoke-Git {
  param(
    [Parameter(Mandatory)] [string[]]$Args
  )

  $pinfo = New-Object System.Diagnostics.ProcessStartInfo
  $pinfo.FileName = 'git'
  $pinfo.RedirectStandardOutput = $true
  $pinfo.RedirectStandardError = $true
  $pinfo.UseShellExecute = $false
  $pinfo.CreateNoWindow = $true
  foreach ($a in $Args) { [void]$pinfo.ArgumentList.Add($a) }

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $pinfo
  [void]$p.Start()
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  return [pscustomobject]@{
    ExitCode = $p.ExitCode
    Stdout   = $stdout
    Stderr   = $stderr
  }
}

$repoRoot = (Resolve-Path .).Path
$inputPath = Join-Path $repoRoot $ListPath
if (-not (Test-Path -LiteralPath $inputPath)) {
  throw "List file not found: $inputPath"
}

$paths = Get-Content -LiteralPath $inputPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

$report = New-Object System.Collections.Generic.List[string]
$fixedCount = 0
$skippedCount = 0
$notFoundCount = 0

foreach ($rel in $paths) {
  $rel = $rel.Trim()
  $relFs = $rel
  $relGit = ($rel -replace '\\','/')

  $fullPath = Join-Path $repoRoot $relFs

  # Only attempt tracked files.
  $tracked = Invoke-Git -Args @('ls-files', '--error-unmatch', $relGit)
  if ($tracked.ExitCode -ne 0) {
    $skippedCount++
    $report.Add("SKIP (untracked): $rel")
    continue
  }

  $revList = Invoke-Git -Args @('rev-list', 'HEAD', '--', $relGit)
  if ($revList.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($revList.Stdout)) {
    $skippedCount++
    $report.Add("SKIP (no history): $rel")
    continue
  }

  $commits = $revList.Stdout -split "`r?`n" | Where-Object { $_ }
  if ($commits.Count -gt $MaxCommitsPerFile) {
    $commits = $commits[0..($MaxCommitsPerFile - 1)]
  }

  $chosenCommit = $null
  $chosenText = $null

  foreach ($c in $commits) {
    $show = Invoke-Git -Args @('show', "$c`:$relGit")
    if ($show.ExitCode -ne 0) {
      continue
    }

    if (-not (Test-BashCorruption -Text $show.Stdout)) {
      $chosenCommit = $c
      $chosenText = $show.Stdout
      break
    }
  }

  if (-not $chosenCommit) {
    $notFoundCount++
    $report.Add("NO-GOOD-REV: $rel")
    continue
  }

  if (-not $WhatIf) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($fullPath, $chosenText, $utf8NoBom)
  }

  $fixedCount++
  $report.Add("RESTORED: $rel <= $chosenCommit")
}

$reportPath = Join-Path $repoRoot 'REPAIR_REPORT.txt'
$report | Set-Content -Encoding UTF8 -LiteralPath $reportPath

Write-Host "Restored: $fixedCount" -ForegroundColor Cyan
Write-Host "Skipped (untracked/no history): $skippedCount" -ForegroundColor Yellow
Write-Host "No good revision found: $notFoundCount" -ForegroundColor Red
Write-Host "Report: $reportPath" -ForegroundColor DarkGray
