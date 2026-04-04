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

# Add npm global bin to PATH system-wide (for lifecycle commands and all shells)
echo "export PATH=/usr/local/share/npm-global/bin:\$PATH" > /etc/profile.d/npm-global.sh
chmod +x /etc/profile.d/npm-global.sh

# Also symlink claude to /usr/local/bin so it's always on PATH
ln -sf /usr/local/share/npm-global/bin/claude /usr/local/bin/claude

echo "Claude Code ${CLAUDE_VERSION} installed."
