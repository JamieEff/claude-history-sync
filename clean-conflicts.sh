#!/usr/bin/env bash
# Move sync "conflict" copies out of the shared Claude Code chat history.
#
# Cloud sync tools create a duplicate when two machines change a file at once.
# Those copies land inside the project buckets as extra *.jsonl files and can
# show as garbled/duplicate chat entries. This moves any file whose name
# contains "conflict" out to a _conflict-quarantine folder next to the store.
# Reversible: files are MOVED, not deleted.

set -euo pipefail

PROJECTS="$HOME/.claude/projects"
[ -e "$PROJECTS" ] || { echo "No projects folder at $PROJECTS"; exit 0; }

if [ -L "$PROJECTS" ]; then REAL="$(readlink "$PROJECTS")"; else REAL="$PROJECTS"; fi
QUAR="$(dirname "$REAL")/_conflict-quarantine"

found=0
while IFS= read -r -d '' f; do
  rel="${f#"$PROJECTS"/}"
  dest="$QUAR/$rel"
  mkdir -p "$(dirname "$dest")"
  mv "$f" "$dest"
  found=$((found+1))
done < <(find "$PROJECTS" -type f -iname '*conflict*' -print0)

printf '\033[32mQuarantined %s conflict file(s) to %s\033[0m\n' "$found" "$QUAR"
