# Claude Dev Container Feature - Design Spec

## Overview

A single Dev Container Feature published to `ghcr.io` that packages Claude Code, agent-skills, a firewall lockdown, and dev tooling into a reusable, configurable unit. Any project adds one line to its `devcontainer.json` to get the full AI dev environment.

## Distribution

- Published as an OCI artifact to GitHub Container Registry
- Referenced as `ghcr.io/andrewmcdowell/claude-dev-feature/claude-dev:1`
- Versioned with semver; major/minor tags auto-updated on publish

## Repository Structure

```
claude-dev-feature/
  src/
    claude-dev/
      devcontainer-feature.json   # Feature manifest with options
      install.sh                  # Entrypoint - delegates to sub-scripts
      install-claude.sh           # Claude Code npm install
      install-firewall.sh         # Firewall script + sudoers setup
      install-devtools.sh         # zsh, fzf, git-delta, gh, powerlevel10k
      init-firewall.sh            # Runtime firewall (iptables/ipset rules)
  test/
    claude-dev/
      test.sh                    # Validates the Feature installed correctly
  .github/
    workflows/
      publish.yml                # Auto-publish to ghcr.io on release
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `claudeCodeVersion` | string | `"latest"` | Claude Code npm package version |
| `agentSkills` | boolean | `true` | Install agent-skills plugin from marketplace |
| `firewall` | boolean | `true` | Enable firewall lockdown |
| `extraAllowedDomains` | string | `""` | Comma-separated domains to add to firewall whitelist |
| `devtools` | boolean | `true` | Install zsh, fzf, git-delta, gh CLI, powerlevel10k |
| `gitDeltaVersion` | string | `"0.18.2"` | git-delta version |

All options are overridable per-project in the project's `devcontainer.json`.

## Feature Manifest (devcontainer-feature.json)

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
      "description": "Comma-separated additional domains to whitelist"
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

Note: `capAdd` for NET_ADMIN/NET_RAW applies even when firewall is disabled. This is a spec limitation - capabilities cannot be conditional. Harmless in practice.

## Runtime Lifecycle

### Image Build (install.sh, runs as root)

1. `install.sh` reads options as environment variables, delegates to sub-scripts
2. `install-claude.sh`: `npm install -g @anthropic-ai/claude-code@${CLAUDECODEVERSION}`
3. `install-firewall.sh` (if firewall=true): copies `init-firewall.sh` to `/usr/local/bin`, injects `extraAllowedDomains` into the script, sets up sudoers for passwordless execution by `$_REMOTE_USER`
4. `install-devtools.sh` (if devtools=true): installs zsh, fzf, git-delta, gh CLI, powerlevel10k theme, configures zsh as default shell

### Container Create (postCreateCommand, runs once)

- If marker file `/usr/local/share/claude-dev/agent-skills-enabled` exists (written by `install.sh` when `agentSkills=true`): runs `claude /plugin marketplace add addyosmani/agent-skills && claude /plugin install agent-skills@addy-agent-skills`
- Marker file pattern used because Feature lifecycle commands don't have access to option env vars - only `install.sh` does

### Container Start (postStartCommand, runs every start)

- If firewall script exists at `/usr/local/bin/init-firewall.sh`: runs it via sudo
- Firewall resolves domain IPs fresh each start (handles DNS changes)
- Verifies by confirming example.com is blocked and api.github.com is reachable

## Firewall Behavior

Default whitelisted domains:
- `registry.npmjs.org` (npm)
- `api.anthropic.com` (Claude API)
- `sentry.io`, `statsig.anthropic.com`, `statsig.com` (telemetry)
- `marketplace.visualstudio.com`, `vscode.blob.core.windows.net`, `update.code.visualstudio.com` (VS Code)
- GitHub IP ranges (fetched from api.github.com/meta)

The `extraAllowedDomains` option appends project-specific domains to this list. Domains are resolved to IPs at container start and added to an ipset. All other outbound traffic is rejected.

## Per-Project Usage

```jsonc
// Minimal - all defaults
{
  "image": "node:lts",
  "features": {
    "ghcr.io/andrewmcdowell/claude-dev-feature/claude-dev:1": {}
  }
}

// Customized per project
{
  "image": "node:lts",
  "features": {
    "ghcr.io/andrewmcdowell/claude-dev-feature/claude-dev:1": {
      "firewall": true,
      "extraAllowedDomains": "api.stripe.com,pypi.org",
      "claudeCodeVersion": "1.0.50",
      "agentSkills": true
    }
  }
}

// Minimal for quick prototyping (no firewall, no devtools)
{
  "image": "node:lts",
  "features": {
    "ghcr.io/andrewmcdowell/claude-dev-feature/claude-dev:1": {
      "firewall": false,
      "devtools": false
    }
  }
}
```

## Publishing

GitHub Actions workflow triggered on release tag:
1. Uses `devcontainers/action@v1` to publish to `ghcr.io`
2. Tags with semver (e.g., `1.0.0`, `1.0`, `1`)
3. Requires `GITHUB_TOKEN` with `packages:write` scope

## Install Script Design

`install.sh` is the entrypoint. It:
1. Installs shared base packages (curl, jq, sudo) needed by all sub-scripts
2. Reads option env vars (options become uppercase env vars: `CLAUDECODEVERSION`, `AGENTSKILLS`, `FIREWALL`, `EXTRAALLOWEDDOMAINS`, `DEVTOOLS`, `GITDELTAVERSION`)
3. Always calls `install-claude.sh`
4. Conditionally calls `install-firewall.sh` if `FIREWALL=true`
5. Conditionally calls `install-devtools.sh` if `DEVTOOLS=true`
6. Writes marker files to `/usr/local/share/claude-dev/` for options needed by lifecycle commands (e.g., `agent-skills-enabled` when `AGENTSKILLS=true`)

Each sub-script is self-contained and idempotent. They use `$_REMOTE_USER` and `$_REMOTE_USER_HOME` for user-specific setup.
