# Claude Dev Container Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a reusable Dev Container Feature that packages Claude Code, agent-skills, firewall lockdown, and dev tooling — published to ghcr.io so any project can add it with one line.

**Architecture:** Single Feature with modular install scripts. `install.sh` is the entrypoint that delegates to `install-claude.sh`, `install-firewall.sh`, and `install-devtools.sh` based on option flags. Marker files bridge build-time options to runtime lifecycle commands.

**Tech Stack:** Bash, iptables/ipset, npm, Dev Container Feature spec, GitHub Actions, ghcr.io OCI registry

---

## File Structure

```
src/claude-dev/
  devcontainer-feature.json   # Feature manifest — options, capabilities, lifecycle hooks
  install.sh                  # Entrypoint — base packages, option routing, marker files
  install-claude.sh           # Installs Claude Code globally via npm
  install-firewall.sh         # Copies init-firewall.sh, sets up sudoers, injects extra domains
  install-devtools.sh         # Installs zsh, fzf, git-delta, gh, powerlevel10k
  init-firewall.sh            # Runtime iptables/ipset firewall rules
test/claude-dev/
  test.sh                     # Feature validation test
.github/workflows/
  publish.yml                 # Auto-publish to ghcr.io on tag
```

---

### Task 1: Scaffold the Feature repo structure

**Files:**
- Create: `src/claude-dev/devcontainer-feature.json`

- [ ] **Step 1: Create the Feature manifest**

```json
{
  "id": "claude-dev",
  "version": "1.0.0",
  "name": "Claude Dev Environment",
  "description": "Claude Code with agent-skills, firewall lockdown, and dev tooling",
  "options": {
    "claudeCodeVersion": {
      "type": "string",
      "default": "latest",
      "description": "Claude Code npm package version"
    },
    "agentSkills": {
      "type": "boolean",
      "default": true,
      "description": "Install agent-skills plugin from marketplace"
    },
    "firewall": {
      "type": "boolean",
      "default": true,
      "description": "Enable firewall lockdown"
    },
    "extraAllowedDomains": {
      "type": "string",
      "default": "",
      "description": "Comma-separated additional domains to whitelist (e.g. pypi.org,api.stripe.com)"
    },
    "devtools": {
      "type": "boolean",
      "default": true,
      "description": "Install dev tooling (zsh, fzf, git-delta, gh CLI, powerlevel10k)"
    },
    "gitDeltaVersion": {
      "type": "string",
      "default": "0.18.2",
      "description": "git-delta version"
    }
  },
  "capAdd": ["NET_ADMIN", "NET_RAW"],
  "containerEnv": {
    "NODE_OPTIONS": "--max-old-space-size=4096"
  },
  "postCreateCommand": "if [ -f /usr/local/share/claude-dev/agent-skills-enabled ]; then claude /plugin marketplace add addyosmani/agent-skills && claude /plugin install agent-skills@addy-agent-skills; fi",
  "postStartCommand": "if [ -x /usr/local/bin/init-firewall.sh ]; then sudo /usr/local/bin/init-firewall.sh; fi"
}
```

Write this to `src/claude-dev/devcontainer-feature.json`.

- [ ] **Step 2: Commit**

```bash
git add src/claude-dev/devcontainer-feature.json
git commit -m "feat: add devcontainer-feature.json manifest with options"
```

---

### Task 2: Create the entrypoint install.sh

**Files:**
- Create: `src/claude-dev/install.sh`

- [ ] **Step 1: Write install.sh**

This script runs as root during image build. Options are provided as uppercase env vars by the dev container runtime.

```bash
#!/bin/bash
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
```

Write this to `src/claude-dev/install.sh` and make it executable: `chmod +x src/claude-dev/install.sh`.

- [ ] **Step 2: Commit**

```bash
git add src/claude-dev/install.sh
git commit -m "feat: add install.sh entrypoint with option routing"
```

---

### Task 3: Create install-claude.sh

**Files:**
- Create: `src/claude-dev/install-claude.sh`

- [ ] **Step 1: Write install-claude.sh**

```bash
#!/bin/bash
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
if ! grep -q 'npm-global/bin' "$PROFILE_PATH" 2>/dev/null; then
  echo 'export NPM_CONFIG_PREFIX=/usr/local/share/npm-global' >> "$PROFILE_PATH"
  echo 'export PATH="$PATH:/usr/local/share/npm-global/bin"' >> "$PROFILE_PATH"
  chown "${_REMOTE_USER}:${_REMOTE_USER}" "$PROFILE_PATH"
fi

echo "Claude Code ${CLAUDE_VERSION} installed."
```

Write this to `src/claude-dev/install-claude.sh` and `chmod +x`.

- [ ] **Step 2: Commit**

```bash
git add src/claude-dev/install-claude.sh
git commit -m "feat: add install-claude.sh for Claude Code npm install"
```

---

### Task 4: Create install-firewall.sh and init-firewall.sh

**Files:**
- Create: `src/claude-dev/install-firewall.sh`
- Create: `src/claude-dev/init-firewall.sh`

- [ ] **Step 1: Write install-firewall.sh**

This runs at build time to stage the runtime firewall script and configure sudoers.

```bash
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
```

Write this to `src/claude-dev/install-firewall.sh` and `chmod +x`.

- [ ] **Step 2: Write init-firewall.sh**

This is the runtime firewall script that runs on every container start. It is the same script we already have in `.devcontainer/init-firewall.sh` with the `-exist` fix applied.

```bash
#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# 1. Extract Docker DNS info BEFORE any flushing
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# Flush existing rules and delete existing ipsets
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

# 2. Selectively restore ONLY internal Docker DNS resolution
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
else
    echo "No Docker DNS rules to restore"
fi

# First allow DNS and localhost before any restrictions
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Create ipset with CIDR support
ipset create allowed-domains hash:net

# Fetch GitHub meta information and aggregate + add their IP ranges
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi

if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
    echo "ERROR: GitHub API response missing required fields"
    exit 1
fi

echo "Processing GitHub IPs..."
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "ERROR: Invalid CIDR range from GitHub meta: $cidr"
        exit 1
    fi
    echo "Adding GitHub range $cidr"
    ipset add allowed-domains "$cidr" -exist
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

# Build domain list: defaults + any extras from config
DOMAINS=(
    "registry.npmjs.org"
    "api.anthropic.com"
    "sentry.io"
    "statsig.anthropic.com"
    "statsig.com"
    "marketplace.visualstudio.com"
    "vscode.blob.core.windows.net"
    "update.code.visualstudio.com"
)

# Append extra domains from config file if present
EXTRA_DOMAINS_FILE="/usr/local/share/claude-dev/extra-domains"
if [ -f "$EXTRA_DOMAINS_FILE" ]; then
    IFS=',' read -ra EXTRA <<< "$(cat "$EXTRA_DOMAINS_FILE")"
    for d in "${EXTRA[@]}"; do
        d=$(echo "$d" | xargs) # trim whitespace
        [ -n "$d" ] && DOMAINS+=("$d")
    done
fi

# Resolve and add allowed domains
for domain in "${DOMAINS[@]}"; do
    echo "Resolving $domain..."
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "ERROR: Failed to resolve $domain"
        exit 1
    fi

    while read -r ip; do
        if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "ERROR: Invalid IP from DNS for $domain: $ip"
            exit 1
        fi
        echo "Adding $ip for $domain"
        ipset add allowed-domains "$ip" -exist
    done < <(echo "$ips")
done

# Get host IP from default route
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
    echo "ERROR: Failed to detect host IP"
    exit 1
fi

HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "Host network detected as: $HOST_NETWORK"

# Set up remaining iptables rules
iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

# Set default policies to DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow established connections for already approved traffic
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow only specific outbound traffic to allowed domains
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Reject all other outbound traffic for immediate feedback
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Firewall configuration complete"
echo "Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - was able to reach https://example.com"
    exit 1
else
    echo "Firewall verification passed - unable to reach https://example.com as expected"
fi

if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
else
    echo "Firewall verification passed - able to reach https://api.github.com as expected"
fi
```

Write this to `src/claude-dev/init-firewall.sh` and `chmod +x`.

- [ ] **Step 3: Commit**

```bash
git add src/claude-dev/install-firewall.sh src/claude-dev/init-firewall.sh
git commit -m "feat: add firewall install and runtime scripts"
```

---

### Task 5: Create install-devtools.sh

**Files:**
- Create: `src/claude-dev/install-devtools.sh`

- [ ] **Step 1: Write install-devtools.sh**

```bash
#!/bin/bash
set -euo pipefail

GIT_DELTA_VERSION="${GITDELTAVERSION:-0.18.2}"
ZSH_IN_DOCKER_VERSION="1.2.0"

# Install dev tool packages
apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  nano \
  vim \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install git-delta
ARCH=$(dpkg --print-architecture)
wget -q "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"
dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"
rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Set up zsh with powerlevel10k for the remote user
su - "${_REMOTE_USER}" -c "sh -c \"\$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)\" -- \
  -p git \
  -p fzf \
  -a \"source /usr/share/doc/fzf/examples/key-bindings.zsh\" \
  -a \"source /usr/share/doc/fzf/examples/completion.zsh\" \
  -x"

# Set zsh as default shell for the remote user
chsh -s /bin/zsh "${_REMOTE_USER}"

echo "Dev tools installed."
```

Write this to `src/claude-dev/install-devtools.sh` and `chmod +x`.

- [ ] **Step 2: Commit**

```bash
git add src/claude-dev/install-devtools.sh
git commit -m "feat: add install-devtools.sh for zsh, fzf, git-delta, gh, powerlevel10k"
```

---

### Task 6: Create the Feature test

**Files:**
- Create: `test/claude-dev/test.sh`

- [ ] **Step 1: Write test.sh**

This test runs inside a container built with the Feature to validate installation.

```bash
#!/bin/bash
set -e

echo "Testing Claude Dev Feature installation..."

# Test 1: Claude Code is installed and on PATH
if command -v claude &>/dev/null; then
  echo "PASS: claude command found"
else
  echo "FAIL: claude command not found"
  exit 1
fi

# Test 2: Marker directory exists
if [ -d /usr/local/share/claude-dev ]; then
  echo "PASS: marker directory exists"
else
  echo "FAIL: marker directory missing"
  exit 1
fi

# Test 3: Firewall script is installed (when firewall=true, the default)
if [ -x /usr/local/bin/init-firewall.sh ]; then
  echo "PASS: firewall script installed and executable"
else
  echo "FAIL: firewall script missing or not executable"
  exit 1
fi

# Test 4: Sudoers entry exists for firewall
if [ -f /etc/sudoers.d/claude-dev-firewall ]; then
  echo "PASS: firewall sudoers entry exists"
else
  echo "FAIL: firewall sudoers entry missing"
  exit 1
fi

# Test 5: zsh is installed (when devtools=true, the default)
if command -v zsh &>/dev/null; then
  echo "PASS: zsh installed"
else
  echo "FAIL: zsh not found"
  exit 1
fi

# Test 6: git-delta is installed
if command -v delta &>/dev/null; then
  echo "PASS: git-delta installed"
else
  echo "FAIL: git-delta not found"
  exit 1
fi

# Test 7: gh CLI is installed
if command -v gh &>/dev/null; then
  echo "PASS: gh CLI installed"
else
  echo "FAIL: gh CLI not found"
  exit 1
fi

# Test 8: Agent skills marker file exists (when agentSkills=true, the default)
if [ -f /usr/local/share/claude-dev/agent-skills-enabled ]; then
  echo "PASS: agent-skills marker exists"
else
  echo "FAIL: agent-skills marker missing"
  exit 1
fi

echo "All tests passed!"
```

Write this to `test/claude-dev/test.sh` and `chmod +x`.

- [ ] **Step 2: Commit**

```bash
git add test/claude-dev/test.sh
git commit -m "test: add Feature validation test"
```

---

### Task 7: Create the GitHub Actions publish workflow

**Files:**
- Create: `.github/workflows/publish.yml`

- [ ] **Step 1: Write publish.yml**

```yaml
name: Publish Dev Container Feature

on:
  release:
    types: [published]

permissions:
  packages: write
  contents: read

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Publish Feature
        uses: devcontainers/action@v1
        with:
          publish-features: true
          base-path-to-features: src
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Write this to `.github/workflows/publish.yml`.

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/publish.yml
git commit -m "ci: add GitHub Actions workflow to publish Feature to ghcr.io"
```

---

### Task 8: Add a test devcontainer.json that uses the local Feature

**Files:**
- Create: `.devcontainer/devcontainer.json`

This is for local development and testing of the Feature itself.

- [ ] **Step 1: Write .devcontainer/devcontainer.json**

```json
{
  "image": "node:lts",
  "features": {
    "./src/claude-dev": {
      "claudeCodeVersion": "latest",
      "agentSkills": true,
      "firewall": true,
      "extraAllowedDomains": "",
      "devtools": true
    }
  }
}
```

Write this to `.devcontainer/devcontainer.json`.

- [ ] **Step 2: Commit**

```bash
git add .devcontainer/devcontainer.json
git commit -m "chore: add local devcontainer.json for Feature development/testing"
```

---

### Task 9: Clean up the old devcontainer files

**Files:**
- Delete: `.devcontainer/Dockerfile`
- Delete: `.devcontainer/init-firewall.sh`
- Delete: `.devcontainer/agent-skills/` (entire directory)

- [ ] **Step 1: Remove old files**

The old Dockerfile-based setup is replaced by the Feature. Remove the files that are no longer needed.

```bash
git rm .devcontainer/Dockerfile
git rm .devcontainer/init-firewall.sh
git rm -r .devcontainer/agent-skills/
```

- [ ] **Step 2: Commit**

```bash
git commit -m "chore: remove old Dockerfile-based devcontainer setup"
```

---

### Task 10: Test the Feature locally

- [ ] **Step 1: Open the project in VS Code and reopen in container**

Open the repo in VS Code, then `Cmd+Shift+P` -> "Dev Containers: Rebuild and Reopen in Container". This will build using the local Feature path `./src/claude-dev`.

- [ ] **Step 2: Verify inside the container**

Run the test script manually:

```bash
bash /workspaces/*/test/claude-dev/test.sh
```

Expected output: all 8 tests pass.

- [ ] **Step 3: Verify firewall**

```bash
curl --connect-timeout 5 https://example.com
```

Expected: connection refused/timeout (blocked by firewall).

```bash
curl --connect-timeout 5 https://api.github.com/zen
```

Expected: returns a GitHub zen quote (allowed by firewall).

- [ ] **Step 4: Verify Claude Code**

```bash
claude --version
```

Expected: prints the installed Claude Code version.
