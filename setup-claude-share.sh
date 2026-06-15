#!/usr/bin/env bash
# Share Claude Code chat history across machines via any synced folder
# (Dropbox, OneDrive, Google Drive, iCloud, a NAS share, Syncthing, etc.).
#
# Symlinks ~/.claude/projects into a folder inside your synced store. ONLY chat
# history is shared; settings/caches stay local. Safe + reversible: existing
# local history is merged (non-destructive) and the original folder is renamed
# to a .pre-share backup before the symlink is made. Nothing is deleted.
#
# Usage:
#   ./setup-claude-share.sh                       # auto-detect sync folder
#   ./setup-claude-share.sh "$HOME/Dropbox"       # explicit sync root
#   SUBFOLDER=ClaudeCodeShared ./setup-claude-share.sh

set -euo pipefail

SUBFOLDER="${SUBFOLDER:-ClaudeCodeShared}"
SHARED_ROOT="${1:-}"

info(){ printf '[*] %s\n' "$*"; }
ok(){   printf '\033[32m[OK]\033[0m %s\n' "$*"; }
warn(){ printf '\033[33m[!]\033[0m %s\n' "$*"; }
die(){  printf '\033[31m[X]\033[0m %s\n' "$*" >&2; exit 1; }

# --- 1. Resolve synced root ------------------------------------------------
FOUND=()
[ -d "$HOME/Dropbox" ] && FOUND+=("$HOME/Dropbox")
[ -d "$HOME/OneDrive" ] && FOUND+=("$HOME/OneDrive")
for g in "$HOME/Library/CloudStorage/"GoogleDrive-* "$HOME/Google Drive"; do
  [ -d "$g" ] && FOUND+=("$g")
done
[ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ] && \
  FOUND+=("$HOME/Library/Mobile Documents/com~apple~CloudDocs")

if [ -z "$SHARED_ROOT" ]; then
  count="${#FOUND[@]}"
  if [ "$count" -eq 0 ]; then die "No synced folder auto-detected. Re-run: $0 '<path to Dropbox/OneDrive/etc>'"; fi
  if [ "$count" -gt 1 ]; then
    warn "Multiple synced folders found - pass one explicitly:"
    printf '    %s\n' "${FOUND[@]}"
    exit 1
  fi
  SHARED_ROOT="${FOUND[0]}"
  info "Auto-detected sync folder: $SHARED_ROOT"
fi
[ -d "$SHARED_ROOT" ] || die "SharedRoot not found: $SHARED_ROOT"

# --- 2. Build + probe the shared projects folder ---------------------------
SHARE_DIR="$SHARED_ROOT/$SUBFOLDER"
SHARE_PROJECTS="$SHARE_DIR/projects"
mkdir -p "$SHARE_PROJECTS"
probe="$SHARE_PROJECTS/.wt_$$"
if ( : > "$probe" ) 2>/dev/null; then rm -f "$probe"; else die "Shared projects folder not writable: $SHARE_PROJECTS"; fi
ok "Shared store ready + writable: $SHARE_PROJECTS"

# --- 3. Ensure ~/.claude exists --------------------------------------------
CLAUDE="$HOME/.claude"
LOCAL_PROJECTS="$CLAUDE/projects"
mkdir -p "$CLAUDE"

# --- 4. Handle existing projects -------------------------------------------
if [ -L "$LOCAL_PROJECTS" ]; then
  cur="$(readlink "$LOCAL_PROJECTS")"
  if [ "$cur" = "$SHARE_PROJECTS" ]; then ok "Already linked to shared store. Nothing to do.";
  else warn "projects symlinked elsewhere ($cur). Repointing."; rm "$LOCAL_PROJECTS"; fi
fi

if [ -d "$LOCAL_PROJECTS" ] && [ ! -L "$LOCAL_PROJECTS" ]; then
  n="$(find "$LOCAL_PROJECTS" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')"
  info "Merging $n local transcript(s) into shared store (non-destructive)..."
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --ignore-existing "$LOCAL_PROJECTS"/ "$SHARE_PROJECTS"/
  else
    cp -an "$LOCAL_PROJECTS"/. "$SHARE_PROJECTS"/ 2>/dev/null || true
  fi
  bak="$LOCAL_PROJECTS.pre-share-$(date +%Y%m%d-%H%M%S)"
  mv "$LOCAL_PROJECTS" "$bak"
  ok "Local history merged + backed up to: $bak"
fi

# --- 5. Create the symlink -------------------------------------------------
if [ ! -e "$LOCAL_PROJECTS" ]; then
  ln -s "$SHARE_PROJECTS" "$LOCAL_PROJECTS"
  ok "Linked: $LOCAL_PROJECTS  ->  $SHARE_PROJECTS"
fi

# --- 6. Reminders ----------------------------------------------------------
echo
ok "Done. Two things to remember:"
echo "   1. RESTART your editor / Claude Code so it re-reads history."
echo "   2. Open each project from the SAME absolute path on every machine,"
echo "      or its chats land in a separate list."
echo
warn "Cloud sync can create 'conflict' copies if two machines write the same"
warn "session at once. Run clean-conflicts.sh now and then to tidy them."
