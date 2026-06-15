<#
.SYNOPSIS
  Share Claude Code chat history across machines via any synced folder
  (Dropbox, OneDrive, Google Drive, iCloud, a NAS share, Syncthing, etc.).

.DESCRIPTION
  Symlinks ~/.claude/projects into a folder inside your synced store, so every
  machine reads and writes the same transcripts. ONLY chat history is shared;
  settings, caches and machine-specific state stay local to each machine.

  Safe + reversible: existing local history is merged into the shared store
  (non-destructive) and the original folder is renamed to a .pre-share backup
  before the symlink is created. Nothing is deleted.

.PARAMETER SharedRoot
  Path to your synced folder root (e.g. "C:\Users\you\Dropbox"). If omitted, the
  script auto-detects Dropbox / OneDrive / Google Drive / iCloud.

.PARAMETER SubFolder
  Name of the shared sub-folder created under SharedRoot. Default "ClaudeCodeShared".

.EXAMPLE
  .\setup-claude-share.ps1
  .\setup-claude-share.ps1 -SharedRoot "D:\Sync\Dropbox"
  .\setup-claude-share.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$SharedRoot,
  [string]$SubFolder = 'ClaudeCodeShared'
)

$ErrorActionPreference = 'Stop'
function Info($m){ Write-Host "[*] $m" }
function Ok($m){ Write-Host "[OK] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[!] $m" -ForegroundColor Yellow }
function Die($m){ Write-Host "[X] $m" -ForegroundColor Red; exit 1 }

# --- 1. Resolve the synced root --------------------------------------------
function Find-SyncRoots {
  $c = [ordered]@{}
  foreach ($p in @("$env:LOCALAPPDATA\Dropbox\info.json","$env:APPDATA\Dropbox\info.json")) {
    if (Test-Path $p) {
      try { $j = Get-Content $p -Raw | ConvertFrom-Json
            foreach ($k in $j.PSObject.Properties) { if ($k.Value.path) { $c["Dropbox ($($k.Name))"] = $k.Value.path } } } catch {}
    }
  }
  if ($c.Count -eq 0 -and (Test-Path "$env:USERPROFILE\Dropbox")) { $c['Dropbox'] = "$env:USERPROFILE\Dropbox" }
  foreach ($v in 'OneDrive','OneDriveConsumer','OneDriveCommercial') {
    $val = [Environment]::GetEnvironmentVariable($v); if ($val -and (Test-Path $val)) { $c["OneDrive ($v)"] = $val }
  }
  foreach ($p in @("$env:USERPROFILE\Google Drive","G:\My Drive","H:\My Drive")) { if (Test-Path $p) { $c['Google Drive'] = $p } }
  if (Test-Path "$env:USERPROFILE\iCloudDrive") { $c['iCloud'] = "$env:USERPROFILE\iCloudDrive" }
  $c
}

if (-not $SharedRoot) {
  $found = Find-SyncRoots
  if ($found.Count -eq 0) { Die "No synced folder auto-detected. Re-run with -SharedRoot '<path to your Dropbox/OneDrive/etc>'." }
  elseif ($found.Count -eq 1) { $SharedRoot = @($found.Values)[0]; Info "Auto-detected sync folder: $SharedRoot" }
  else {
    Warn "Multiple synced folders found - pick one and re-run with -SharedRoot:"
    $found.GetEnumerator() | ForEach-Object { Write-Host "    $($_.Key)  ->  $($_.Value)" }
    exit 1
  }
}
if (-not (Test-Path $SharedRoot)) { Die "SharedRoot not found: $SharedRoot" }

# --- 2. Build + probe the shared projects folder ---------------------------
$shareDir      = Join-Path $SharedRoot $SubFolder
$shareProjects = Join-Path $shareDir 'projects'
if ($PSCmdlet.ShouldProcess($shareProjects,'create shared projects folder')) {
  New-Item -ItemType Directory -Path $shareProjects -Force | Out-Null
}
$probe = Join-Path $shareProjects ("_wt_{0}.tmp" -f ([guid]::NewGuid().ToString('N')))
try { Set-Content -LiteralPath $probe -Value 'ok' -ErrorAction Stop; Remove-Item -LiteralPath $probe -Force }
catch { Die "Shared projects folder is not writable: $shareProjects" }
Ok "Shared store ready + writable: $shareProjects"

# --- 3. Ensure ~/.claude exists as a real dir ------------------------------
$claude        = Join-Path $env:USERPROFILE '.claude'
$localProjects = Join-Path $claude 'projects'
if (-not (Test-Path $claude)) { New-Item -ItemType Directory -Path $claude -Force | Out-Null }

# --- 4. Handle existing projects -------------------------------------------
$item = Get-Item -LiteralPath $localProjects -Force -ErrorAction SilentlyContinue
if ($item -and $item.LinkType -eq 'SymbolicLink') {
  if ($item.Target -eq $shareProjects) { Ok "Already linked to the shared store. Nothing to do." }
  else {
    Warn "projects is symlinked elsewhere: $($item.Target). Repointing."
    if ($PSCmdlet.ShouldProcess($localProjects,'remove existing symlink')) { (Get-Item -LiteralPath $localProjects).Delete() }
    $item = $null
  }
}
if ($item -and $item.LinkType -ne 'SymbolicLink') {
  $count = @(Get-ChildItem $localProjects -Filter *.jsonl -Recurse -EA SilentlyContinue).Count
  Info "Merging $count local transcript(s) into the shared store (non-destructive)..."
  if ($PSCmdlet.ShouldProcess($shareProjects,'merge local history')) {
    robocopy "$localProjects" "$shareProjects" /E /XC /XN /XO /R:1 /W:1 | Out-Null
  }
  $bakLeaf = "projects.pre-share-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')
  if ($PSCmdlet.ShouldProcess($localProjects,"rename to $bakLeaf")) { Rename-Item -LiteralPath $localProjects -NewName $bakLeaf }
  Ok "Local history merged + backed up to: $(Join-Path $claude $bakLeaf)"
}

# --- 5. Create the symlink -------------------------------------------------
if (-not (Test-Path $localProjects)) {
  if ($PSCmdlet.ShouldProcess($localProjects,"symlink -> $shareProjects")) {
    try { New-Item -ItemType SymbolicLink -Path $localProjects -Target $shareProjects | Out-Null }
    catch { Die "Could not create symlink. On Windows enable Developer Mode (Settings > Privacy & security > For developers) OR run this script as Administrator, then re-run." }
  }
  Ok "Linked: $localProjects  ->  $shareProjects"
}

# --- 6. Reminders ----------------------------------------------------------
Write-Host ""
Ok "Done. Two things to remember:"
Write-Host "   1. RESTART your editor / Claude Code so it re-reads history (VS Code: Developer: Reload Window)."
Write-Host "   2. Open each project from the SAME absolute path on every machine, or its chats land in a separate list."
Write-Host ""
Warn "Cloud sync can create 'conflict' copies if two machines write the same session at once."
Warn "Run clean-conflicts.ps1 now and then to tidy them."
