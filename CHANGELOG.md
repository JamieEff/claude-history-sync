# Changelog

## 1.0.0

Initial release.

- **`setup-claude-share`** (PowerShell + bash) — symlinks `~/.claude/projects`
  into a synced folder so chat history follows you between machines. Auto-detects
  Dropbox / OneDrive / Google Drive / iCloud, or takes an explicit `-SharedRoot`
  path. Existing local history is merged non-destructively and the original
  folder is backed up before the symlink is created. Nothing is deleted.
- **`clean-conflicts`** (PowerShell + bash) — moves cloud-sync "conflict" copies
  out of the project buckets into a quarantine folder (reversible).
