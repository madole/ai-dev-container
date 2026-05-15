#!/bin/bash
# Mirror Claude Code plugin skills (~/.claude/plugins/cache/.../skills/*/) into
# Cursor Agent Skills (~/.cursor/skills/<id>/). Safe to re-run; overwrites copies.
set -euo pipefail

HOME_DIR="${_REMOTE_USER_HOME:-$HOME}"
CLAUDE_CACHE="$HOME_DIR/.claude/plugins/cache"
CURSOR_SKILLS="$HOME_DIR/.cursor/skills"

if [ ! -d "$CLAUDE_CACHE" ]; then
  echo "sync-cursor-skills: No Claude plugin cache at $CLAUDE_CACHE"
  echo "  Open Claude Code once in this container so plugins install, then run:"
  echo "  bash /usr/local/bin/sync-cursor-skills.sh"
  exit 0
fi

mkdir -p "$CURSOR_SKILLS"

synced=0
while IFS= read -r -d '' skill_md; do
  skill_dir=$(dirname "$skill_md")
  leaf=$(basename "$skill_dir")
  prefix="${skill_dir%/skills/$leaf}"
  prefix="${prefix#$CLAUDE_CACHE/}"
  # e.g. claude-plugins-official-superpowers-5-1-0-brainstorming
  cursor_id=$(printf '%s' "$prefix/$leaf" | tr '/' '-' | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/-+/-/g; s/^-|-$//g')
  if [ -z "$cursor_id" ]; then
    continue
  fi
  dest="$CURSOR_SKILLS/$cursor_id"
  rm -rf "$dest"
  mkdir -p "$dest"
  cp -a "$skill_dir"/. "$dest"/
  synced=$((synced + 1))
done < <(find "$CLAUDE_CACHE" -type f -path '*/skills/*/SKILL.md' -print0)

if [ -n "${_REMOTE_USER:-}" ]; then
  chown -R "${_REMOTE_USER}:${_REMOTE_USER}" "$CURSOR_SKILLS" 2>/dev/null || true
fi

if [ "$synced" -eq 0 ]; then
  echo "sync-cursor-skills: no skills found under $CLAUDE_CACHE — open Claude Code once, then run this script again."
else
  echo "sync-cursor-skills: copied $synced skill director(ies) to $CURSOR_SKILLS"
fi
