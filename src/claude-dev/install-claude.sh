#\!/bin/bash
set -euo pipefail

CLAUDE_VERSION="${CLAUDECODEVERSION:-latest}"

# Ensure npm global directory exists and is accessible
mkdir -p /usr/local/share/npm-global
chown -R "${_REMOTE_USER}:${_REMOTE_USER}" /usr/local/share/npm-global

# Set npm prefix for the remote user
export NPM_CONFIG_PREFIX=/usr/local/share/npm-global

# Install Claude Code globally
npm install -g "@anthropic-ai/claude-code@${CLAUDE_VERSION}"

# Add npm global bin to PATH for the remote user's shell profile
PROFILE_PATH="${_REMOTE_USER_HOME}/.profile"
if \! grep -q 'npm-global/bin' "$PROFILE_PATH" 2>/dev/null; then
  echo 'export NPM_CONFIG_PREFIX=/usr/local/share/npm-global' >> "$PROFILE_PATH"
  echo 'export PATH="$PATH:/usr/local/share/npm-global/bin"' >> "$PROFILE_PATH"
  chown "${_REMOTE_USER}:${_REMOTE_USER}" "$PROFILE_PATH"
fi

echo "Claude Code ${CLAUDE_VERSION} installed."
