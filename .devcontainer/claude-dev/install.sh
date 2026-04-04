#\!/bin/bash
set -euo pipefail

FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER_DIR="/usr/local/share/claude-dev"

# Install base packages needed by sub-scripts
apt-get update && apt-get install -y --no-install-recommends \
  curl \
  jq \
  sudo \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create marker directory
mkdir -p "$MARKER_DIR"

# Always install Claude Code
echo "Installing Claude Code (version: ${CLAUDECODEVERSION:-latest})..."
bash "$FEATURE_DIR/install-claude.sh"

# Conditionally install firewall
if [ "${FIREWALL:-true}" = "true" ]; then
  echo "Setting up firewall..."
  bash "$FEATURE_DIR/install-firewall.sh"
fi

# Conditionally install dev tools
if [ "${DEVTOOLS:-true}" = "true" ]; then
  echo "Installing dev tools..."
  bash "$FEATURE_DIR/install-devtools.sh"
fi

# Write marker files for lifecycle commands
if [ "${AGENTSKILLS:-true}" = "true" ]; then
  touch "$MARKER_DIR/agent-skills-enabled"
fi

echo "Claude Dev Feature installation complete."
