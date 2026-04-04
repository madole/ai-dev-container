#!/bin/bash
set -e

# Install Claude Code plugins
# This runs as postCreateCommand (once, after container creation)

CLAUDE_BIN="/usr/local/bin/claude"

if [ ! -x "$CLAUDE_BIN" ]; then
  echo "WARNING: claude not found at $CLAUDE_BIN, skipping plugin installation"
  exit 0
fi

# Official plugins (claude-plugins-official)
OFFICIAL_PLUGINS=(
  "frontend-design"
  "superpowers"
  "context7"
  "claude-md-management"
  "typescript-lsp"
  "security-guidance"
  "commit-commands"
  "pr-review-toolkit"
  "explanatory-output-style"
  "greptile"
  "learning-output-style"
  "gopls-lsp"
  "chrome-devtools-mcp"
  "circleback"
  "remember"
)

echo "Installing official Claude plugins..."
for plugin in "${OFFICIAL_PLUGINS[@]}"; do
  echo "  Installing $plugin..."
  "$CLAUDE_BIN" plugin install "$plugin@claude-plugins-official" || echo "  WARNING: Failed to install $plugin, continuing..."
done

# Agent-skills (community plugin, conditional)
if [ -f /usr/local/share/claude-dev/agent-skills-enabled ]; then
  echo "Installing agent-skills plugin..."
  "$CLAUDE_BIN" plugin marketplace add addyosmani/agent-skills || echo "  WARNING: Failed to add agent-skills marketplace"
  "$CLAUDE_BIN" plugin install agent-skills@addy-agent-skills || echo "  WARNING: Failed to install agent-skills"
fi

echo "Plugin installation complete."
