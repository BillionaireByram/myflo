#!/usr/bin/env bash
# Remove MyFlo. Keeps Claude Code, Ego Lite and the ~/MyFlo workspace folder.
set -euo pipefail

MYFLO_HOME="${MYFLO_HOME:-$HOME/.myflo}"

echo "This removes MyFlo, including its threads and settings in $MYFLO_HOME/data."
read -r -p "Continue? [y/N] " reply </dev/tty || reply=""
[[ $reply =~ ^[Yy] ]] || { echo "Nothing removed."; exit 0; }

"$MYFLO_HOME/bin/myflo" stop >/dev/null 2>&1 || true
if command -v claude >/dev/null; then claude mcp remove --scope user peekaboo >/dev/null 2>&1 || true; fi
rm -rf "$HOME/.claude/skills/mac-computer" "$HOME/Applications/MyFlo.app"
[[ -L $HOME/.local/bin/myflo ]] && rm -f "$HOME/.local/bin/myflo"
rm -rf "$MYFLO_HOME"
echo "MyFlo removed. Claude Code, Ego Lite and ~/MyFlo were left in place."
