#!/bin/bash
set -e

# Pre-seed Claude Code plugin settings
# Plugins are declared in settings.json and installed automatically on first launch

CLAUDE_CONFIG_DIR="${_REMOTE_USER_HOME:-$HOME}/.claude"
SETTINGS_FILE="$CLAUDE_CONFIG_DIR/settings.json"

mkdir -p "$CLAUDE_CONFIG_DIR"

# If the user already has a valid settings.json with plugins configured,
# don't clobber it. Users often mount their own ~/.claude into the container
# (to preserve auth, MCP servers, custom plugin selections, etc.).
if [ -f "$SETTINGS_FILE" ] && python3 -c "
import json, sys
try:
    with open('$SETTINGS_FILE') as f:
        data = json.load(f)
    sys.exit(0 if data.get('enabledPlugins') else 1)
except Exception:
    sys.exit(1)
" 2>/dev/null; then
  echo "Claude settings.json already exists with enabledPlugins; preserving user config."
  exit 0
fi

AGENT_SKILLS_ENTRY=""
AGENT_SKILLS_MARKETPLACE=""
if [ -f /usr/local/share/claude-dev/agent-skills-enabled ]; then
  AGENT_SKILLS_ENTRY=',
    "agent-skills@addy-agent-skills": true'
  AGENT_SKILLS_MARKETPLACE=',
    "addy-agent-skills": {
      "source": {
        "source": "github",
        "repo": "addyosmani/agent-skills"
      }
    }'
fi

cat > "$SETTINGS_FILE" << EOF
{
  "extraKnownMarketplaces": {
    "placeholder": null${AGENT_SKILLS_MARKETPLACE},
    "caveman": {
      "source": {
        "source": "github",
        "repo": "JuliusBrussee/caveman"
      }
    }
  },
  "enabledPlugins": {
    "frontend-design@claude-plugins-official": true,
    "superpowers@claude-plugins-official": true,
    "context7@claude-plugins-official": true,
    "claude-md-management@claude-plugins-official": true,
    "typescript-lsp@claude-plugins-official": true,
    "security-guidance@claude-plugins-official": true,
    "commit-commands@claude-plugins-official": true,
    "pr-review-toolkit@claude-plugins-official": true,
    "explanatory-output-style@claude-plugins-official": true,
    "learning-output-style@claude-plugins-official": true,
    "gopls-lsp@claude-plugins-official": true,
    "chrome-devtools-mcp@claude-plugins-official": true,
    "circleback@claude-plugins-official": true,
    "remember@claude-plugins-official": true,
    "caveman@caveman": true${AGENT_SKILLS_ENTRY}
  },
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest", "--browser-url", "http://host.docker.internal:9222"]
    }
  }
}
EOF

# Remove the placeholder null entry from extraKnownMarketplaces
# (used to keep valid JSON when no extra marketplaces are needed)
python3 -c "
import json, sys
with open('$SETTINGS_FILE') as f:
    data = json.load(f)
data['extraKnownMarketplaces'].pop('placeholder', None)
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || true

# Fix ownership
if [ -n "${_REMOTE_USER:-}" ]; then
  chown -R "${_REMOTE_USER}:${_REMOTE_USER}" "$CLAUDE_CONFIG_DIR"
fi

echo "Claude plugin settings pre-seeded. Plugins will install on first launch."
