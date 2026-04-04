#!/bin/bash
set -euo pipefail

FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRA_DOMAINS="${EXTRAALLOWEDDOMAINS:-}"

# Install firewall dependencies
apt-get update && apt-get install -y --no-install-recommends \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy runtime firewall script
cp "$FEATURE_DIR/init-firewall.sh" /usr/local/bin/init-firewall.sh
chmod +x /usr/local/bin/init-firewall.sh

# Write extra allowed domains to a config file read by init-firewall.sh at runtime
if [ -n "$EXTRA_DOMAINS" ]; then
  echo "$EXTRA_DOMAINS" > /usr/local/share/claude-dev/extra-domains
fi

# Set up sudoers so the remote user can run the firewall script without a password
echo "${_REMOTE_USER} ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/claude-dev-firewall
chmod 0440 /etc/sudoers.d/claude-dev-firewall

echo "Firewall setup complete."
