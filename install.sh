#!/usr/bin/env bash
# Install every skill in this repository into your agent's skills directory.
# Usage: ./install.sh [--target ~/.claude/skills]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pick a target: --target flag, or first existing default skills dir.
TARGET="${2:-}"
if [ -z "$TARGET" ]; then
  for d in "$HOME/.zcode/skills" "$HOME/.agents/skills" "$HOME/.claude/skills" "$HOME/.codex/skills"; do
    if [ -d "$d" ]; then TARGET="$d"; break; fi
  done
fi
if [ -z "$TARGET" ]; then
  echo "No skills directory found. Create one, or run: ./install.sh --target /path/to/skills"
  exit 1
fi

mkdir -p "$TARGET"
for skill_dir in "$REPO_DIR"/*/; do
  [ -f "$skill_dir/SKILL.md" ] || continue
  name="$(basename "$skill_dir")"
  rm -rf "$TARGET/$name"
  cp -r "$skill_dir" "$TARGET/$name"
  echo "Installed: $name -> $TARGET/$name"
done

echo "Done. Restart your agent to pick up the new skills."
