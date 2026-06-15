<#
.SYNOPSIS
  Move sync "conflict" copies out of the shared Claude Code chat history.

.DESCRIPTION
  Cloud sync tools (Dropbox, OneDrive, Google Drive, Synology, ...) create a
  duplicate copy of a file when two machines change it at once. Those copies
  land inside the project buckets as extra *.jsonl files and can show up as
  garbled/duplicate chat entries. This script moves any file whose name contains
  "conflict" out to a _conflict-quarantine folder next to the shared store.

  Reversible: files are MOVED, not deleted. Review/bin the quarantine yourself.

.EXAMPLE
  .\clean-conflicts.ps1
  .\clean-conflicts.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$projects = Join-Path $env:USERPROFILE '.claude\projects'
if (-not (Test-Path $projects)) { Write-Host "No projects folder at $projects"; exit }

$pi = Get-Item -LiteralPath $projects -Force
$realProjects = if ($pi.LinkType -eq 'SymbolicLink' -and $pi.Target) { $pi.Target } else { $pi.FullName }
$quarantine   = Join-Path (Split-Path $realProjects -Parent) '_conflict-quarantine'
$rootLen      = (Get-Item -LiteralPath $projects).FullName.Length

$files = Get-ChildItem $projects -Recurse -File -EA SilentlyContinue | Where-Object { $_.Name -match 'conflict' }
if (-not $files) { Write-Host "No conflict files found. Nothing to do."; exit }

foreach ($f in $files) {
  $rel  = $f.FullName.Substring($rootLen).TrimStart('\','/')
  $dest = Join-Path $quarantine $rel
  if ($PSCmdlet.ShouldProcess($f.FullName, "quarantine -> $dest")) {
    New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
    Move-Item -LiteralPath $f.FullName -Destination $dest -Force
  }
}
Write-Host ("Quarantined {0} conflict file(s) to {1}" -f $files.Count, $quarantine) -ForegroundColor Green
