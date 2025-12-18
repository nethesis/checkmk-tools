param(
  [string]$Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '.')).Path,
  [string]$OutFile = (Join-Path $PSScriptRoot 'bashn-full-report.txt'),
  [switch]$FailOnError
)

$ErrorActionPreference = 'Stop'

function Convert-ToWslPath([string]$WindowsPath) {
  # Supports drive-letter paths: C:\...
  if ($WindowsPath -notmatch '^[A-Za-z]:\\') {
    throw "Unsupported path format: $WindowsPath"
  }
  $drive = $WindowsPath.Substring(0, 1).ToLower()
  $rest = $WindowsPath.Substring(2) -replace '\\', '/'
  return "/mnt/$drive$rest"
}

Write-Host "Root: $Root"
Write-Host "OutFile: $OutFile"

$shFiles = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.sh' | Select-Object -ExpandProperty FullName

$extlessShebang = New-Object System.Collections.Generic.List[string]
Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object {
  $_.Extension -eq '' -and $_.Length -lt 1MB
} | ForEach-Object {
  $path = $_.FullName
  try {
    $first = Get-Content -LiteralPath $path -TotalCount 1 -ErrorAction Stop
  } catch {
    return
  }
  if ($first -match '^#!.*\b(bash|sh)\b') {
    $extlessShebang.Add($path)
  }
}

$targets = @($shFiles + $extlessShebang.ToArray()) | Sort-Object -Unique

$fails = New-Object System.Collections.Generic.List[object]
$missing = 0

$idx = 0
foreach ($f in $targets) {
  $idx++
  if (-not (Test-Path -LiteralPath $f)) {
    $missing++
    $fails.Add([pscustomobject]@{ File = $f; Error = 'MISSING_ON_DISK' })
    continue
  }

  $wslPath = Convert-ToWslPath $f
  $out = wsl bash -n "$wslPath" 2>&1
  if ($LASTEXITCODE -ne 0) {
    $msg = ($out -join "`n")
    if ($msg.Length -gt 700) { $msg = $msg.Substring(0, 700) + '...' }
    $fails.Add([pscustomobject]@{ File = $f; Error = $msg })
  }
}

$summary = [pscustomobject]@{
  Root = $Root
  TotalSh = $shFiles.Count
  TotalExtlessShebang = $extlessShebang.Count
  TotalTargets = $targets.Count
  MissingOnDisk = $missing
  Fail = $fails.Count
  Timestamp = (Get-Date).ToString('o')
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add(("TOTAL_SH={0} EXTLESS_SHEBANG={1} TOTAL_TARGETS={2} MISSING={3} FAIL={4}" -f $summary.TotalSh, $summary.TotalExtlessShebang, $summary.TotalTargets, $summary.MissingOnDisk, $summary.Fail))
$lines.Add(("TIMESTAMP={0}" -f $summary.Timestamp))

if ($fails.Count -gt 0) {
  $lines.Add('')
  $lines.Add('FAILURES:')
  foreach ($row in ($fails | Sort-Object File)) {
    $lines.Add("- $($row.File)")
    $lines.Add("  $($row.Error)")
  }
}

$lines | Set-Content -LiteralPath $OutFile -Encoding UTF8

Write-Host $lines[0]
Write-Host "Report scritto in: $OutFile"

if ($FailOnError -and $fails.Count -gt 0) {
  exit 1
}
