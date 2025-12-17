[CmdletBinding()]
param(
  [string]$OutFile = 'BAD_SCRIPTS_SCAN_v3.txt'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path .).Path
$bad = @()

$files = Get-ChildItem -LiteralPath $root -Recurse -File
foreach ($f in $files) {
  $name = $f.Name
  $ext = $f.Extension

  $first = $null
  try { $first = Get-Content -LiteralPath $f.FullName -TotalCount 1 -ErrorAction Stop } catch { $first = $null }

  $isBashCandidate = $false
  if ($ext -eq '.sh') { $isBashCandidate = $true }
  elseif ($first -match '^#!/') { $isBashCandidate = $true }
  elseif ($ext -eq '' -and $name -match '^r[^.]*$') { $isBashCandidate = $true } # r* no extension

  if (-not $isBashCandidate) { continue }

  $raw = $null
  try { $raw = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop } catch { $raw = $null }
  if ([string]::IsNullOrEmpty($raw)) { continue }

  # If the file contains an archived corrupted tail wrapped in a heredoc, ignore it.
  $marker = ": <<'CORRUPTED_ORIGINAL'"
  $pos = $raw.IndexOf($marker)
  if ($pos -ge 0) {
    $raw = $raw.Substring(0, $pos)
  }

  $hit = $false
  if ($raw -match '\)if\b|\)elif\b|\)then\b|\)else\b') { $hit = $true }
  if ($raw -match '\b[0-9]elif\b') { $hit = $true }
  if ($raw -match '\bfi[\t ]+(echo|read)\b') { $hit = $true }
  if ($raw -match '\bdone[\t ]+(echo|read)\b') { $hit = $true }
  if ($raw -match '\bexit[\t ]+[0-9]+(elif|else|fi)\b') { $hit = $true }

  if ($hit) {
    $rel = $f.FullName.Substring($root.Length).TrimStart('\')
    $bad += $rel
  }
}

$bad = $bad | Sort-Object -Unique
$bad | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $root $OutFile)

Write-Host "Trovati: $($bad.Count)" -ForegroundColor Cyan
Write-Host "Lista: $OutFile" -ForegroundColor DarkGray
$bad | Select-Object -First 40 | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
