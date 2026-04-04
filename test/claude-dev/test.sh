#\!/bin/bash
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

echo "All tests passed\!"
