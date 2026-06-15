# Share Claude Code chat history across machines

*One small script to give Claude Code the same conversation history on every
computer you use — backed by whatever folder you already keep in sync.*

Use Claude Code on more than one computer and want the **same chat history**
(the left-hand "resume" list) on all of them? This tiny toolkit points each
machine's `~/.claude/projects` folder at one folder kept in sync by whatever
you already use — **Dropbox, OneDrive, Google Drive, iCloud, Syncthing, or a
NAS share**. No NAS required.

Only **chat history** is shared. Settings, caches, plugins and machine-specific
state stay local to each machine.

## Why this exists

Claude Code keeps each conversation in a local file, so its history is tied to
the machine you were on. Switch to a laptop and your earlier chats aren't there.

There's no built-in sync — but there doesn't need to be. The history lives in
one folder, and most of us already run *something* that keeps a folder in sync
across machines (Dropbox, OneDrive, a NAS, Syncthing...). Point Claude Code's
history folder at that, and your chats follow you. That's all this does — with
the fiddly bits (safe merge, backups, symlink creation, the cross-platform and
permission quirks) handled for you.

## How it works

Claude Code stores each conversation as a `.jsonl` file under
`~/.claude/projects/<encoded-project-path>/`. If that `projects` folder is a
symlink to a synced location, every machine reads and writes the same files —
so your history follows you.

The setup script:
1. Finds your synced folder (auto-detects, or pass it explicitly).
2. Creates `<SyncedFolder>/ClaudeCodeShared/projects` and checks it's writable.
3. Merges any history already on this machine into the shared store
   (non-destructive — nothing overwritten), then renames the old folder to a
   `projects.pre-share-<timestamp>` backup.
4. Symlinks `~/.claude/projects` -> the shared folder.

It is **safe and reversible**: nothing is deleted.

## Usage

### Windows (PowerShell)

```powershell
# Auto-detect Dropbox / OneDrive / Google Drive / iCloud
.\setup-claude-share.ps1

# Or point it at your synced folder explicitly
.\setup-claude-share.ps1 -SharedRoot "C:\Users\you\Dropbox"

# Preview without changing anything
.\setup-claude-share.ps1 -WhatIf
```

Windows needs permission to create symlinks: turn on **Developer Mode**
(Settings > Privacy & security > For developers) **or** run PowerShell as
Administrator. The script tells you if it hits this.

If you see *"running scripts is disabled on this system"*, your execution policy
is blocking unsigned scripts. Either run it for one session only:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-claude-share.ps1
```

or unblock the downloaded file first: `Unblock-File .\setup-claude-share.ps1`.

### macOS / Linux (bash)

```bash
chmod +x setup-claude-share.sh clean-conflicts.sh

# Auto-detect, or pass your synced folder
./setup-claude-share.sh
./setup-claude-share.sh "$HOME/Dropbox"
```

Run the **same setup on each machine**, pointing at the same synced folder.

## After running — two things that matter

1. **Restart Claude Code / your editor.** The chat list is built at launch; it
   won't show the shared history until you reload (VS Code: *Developer: Reload
   Window*).
2. **Open each project from the *same path* on every machine.** History is
   bucketed by the project's absolute path. `C:\Work\app` on one machine and
   `D:\Projects\app` on another are treated as *different* projects and won't
   share a list. (Letter-case doesn't matter on Windows; a different *location*
   does.)

## The one real caveat: sync conflicts

Cloud sync tools were not built for files that two machines append to at the
same time. If you run sessions on two machines before sync catches up, you'll
occasionally get **"conflict" copies** (e.g. `chat (conflicted copy).jsonl`).
They're harmless but clutter the list. In practice it's rare, because each
session is its own file — it only happens with genuinely overlapping use.

To tidy them up (moves them out to a quarantine folder, nothing deleted):

```powershell
.\clean-conflicts.ps1          # Windows
```
```bash
./clean-conflicts.sh           # macOS / Linux
```

If you want bullet-proof multi-writer history instead of best-effort sync,
a git-backed approach is the heavier-duty alternative — but for most people
"symlink into the folder you already sync" is the 5-minute 90% solution.

## Uninstall / revert

Delete the symlink and restore your backup:

```powershell
# Windows
(Get-Item "$env:USERPROFILE\.claude\projects").Delete()
Rename-Item "$env:USERPROFILE\.claude\projects.pre-share-<timestamp>" projects
```
```bash
# macOS / Linux
rm "$HOME/.claude/projects"
mv "$HOME/.claude/projects.pre-share-<timestamp>" "$HOME/.claude/projects"
```

The shared copy in your synced folder is untouched either way.
