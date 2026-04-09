# HA Claude Code Addon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Home Assistant OS addon that runs Claude Code in a persistent tmux session, exposed via ttyd web terminal through HA's ingress.

**Architecture:** Debian-based addon container with ttyd serving a tmux session running Claude Code CLI. Auth via env vars from HA addon config. Persistent storage in /data/ volume. HA ingress proxies to ttyd with correct base path.

**Tech Stack:** Bash (run.sh), Dockerfile (Debian base), HA addon config (YAML), ttyd, tmux, Claude Code native binary.

---

### Task 1: Addon Metadata (config.yaml)

**Files:**
- Create: `config.yaml`

- [ ] **Step 1: Create config.yaml**

```yaml
name: Claude Code Terminal
version: 0.1.0
slug: claude-code-terminal
description: Claude Code in a web terminal via the HA sidebar
url: https://github.com/sugendran/ha-claude
arch:
  - aarch64
  - amd64
startup: application
boot: auto
ingress: true
ingress_port: 7681
panel_icon: mdi:console
panel_title: Claude Code
homeassistant_api: true
map:
  - config:rw
  - share:rw
  - addon_config:rw
init: false

options:
  claude_oauth_token: ""
  anthropic_api_key: ""
  claude_model: "sonnet"
  git_user_name: ""
  git_user_email: ""

schema:
  claude_oauth_token: str?
  anthropic_api_key: str?
  claude_model: list(sonnet|opus|haiku)
  git_user_name: str?
  git_user_email: str?
```

- [ ] **Step 2: Commit**

```bash
git add config.yaml
git commit -m "feat: add addon metadata config.yaml

Defines addon name, arch support (aarch64/amd64), ingress on port 7681,
HA API access, volume mounts, and user-configurable options for auth,
model selection, and git identity."
```

---

### Task 2: Dockerfile

**Files:**
- Create: `Dockerfile`

- [ ] **Step 1: Create Dockerfile**

```dockerfile
ARG BUILD_FROM=ghcr.io/hassio-addons/debian-base:7.8.0
FROM ${BUILD_FROM}

# Install runtime dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tmux \
        ttyd \
        git \
        ripgrep \
        curl \
        jq \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code native binary
RUN curl -fsSL https://claude.ai/install.sh | bash

# Copy addon files
COPY run.sh /
COPY templates/ /opt/templates/

RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
```

Note: If `ttyd` is not in Debian repos for both architectures, we may need to install from the ttyd GitHub releases. Check during build testing — the step below handles both cases.

- [ ] **Step 2: Verify ttyd availability**

Run: `docker run --rm ghcr.io/hassio-addons/debian-base:7.8.0 bash -c "apt-get update && apt-cache search ttyd"`

If ttyd is NOT in apt, update the Dockerfile to install from GitHub releases instead:

```dockerfile
# Replace the ttyd line in apt-get install with:
RUN ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "arm64" ]; then TTYD_ARCH="aarch64"; else TTYD_ARCH="x86_64"; fi \
    && curl -fsSL -o /usr/local/bin/ttyd \
        "https://github.com/nicktrav/ttyd/releases/latest/download/ttyd.${TTYD_ARCH}" \
    && chmod +x /usr/local/bin/ttyd
```

- [ ] **Step 3: Commit**

```bash
git add Dockerfile
git commit -m "feat: add Dockerfile

Debian base image with tmux, ttyd, git, ripgrep, curl, jq.
Installs Claude Code native binary via official install script.
Copies run.sh entrypoint and template files."
```

---

### Task 3: CLAUDE.md Seed Template

**Files:**
- Create: `templates/CLAUDE.md`

- [ ] **Step 1: Create templates/CLAUDE.md**

```markdown
# Home Assistant Claude Code Environment

## HA API Access
The Supervisor API is available via:
  curl -sH "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/core/api/<endpoint>

Common endpoints:
- GET  /states                    — all entity states
- GET  /states/<entity_id>        — single entity
- POST /services/<domain>/<service> — call a service
- POST /config/core/check         — validate config
- POST /restart                   — restart HA core

## HA Config Files
HA configuration is mounted at /config/:
- /config/configuration.yaml
- /config/automations.yaml
- /config/scripts.yaml
- /config/scenes.yaml
- /config/custom_components/

## Working Directory
/data/workspace/ persists across addon restarts.
Your projects and files here are safe.

## Important Notes
- After editing YAML in /config/, validate with the check endpoint before restarting.
- HA uses a custom Jinja2 dialect — not standard Jinja2. Always test templates.
- Entity IDs follow the pattern: domain.object_id (e.g. light.living_room).
```

- [ ] **Step 2: Commit**

```bash
git add templates/CLAUDE.md
git commit -m "feat: add CLAUDE.md seed template

Seeded into workspace on first boot. Contains HA API usage patterns,
common endpoints, config file locations, and working directory info."
```

---

### Task 4: Startup Script (run.sh)

**Files:**
- Create: `run.sh`

- [ ] **Step 1: Create run.sh**

```bash
#!/usr/bin/with-contenv bashio

# 1. Read addon options
CLAUDE_TOKEN=$(bashio::config 'claude_oauth_token')
API_KEY=$(bashio::config 'anthropic_api_key')
CLAUDE_MODEL=$(bashio::config 'claude_model')
GIT_NAME=$(bashio::config 'git_user_name')
GIT_EMAIL=$(bashio::config 'git_user_email')
INGRESS_ENTRY=$(bashio::addon.ingress_entry)

# 2. Export auth — at least one of these must be set
if bashio::config.has_value 'claude_oauth_token'; then
  export CLAUDE_CODE_OAUTH_TOKEN="${CLAUDE_TOKEN}"
  bashio::log.info "Using OAuth token authentication"
fi

if bashio::config.has_value 'anthropic_api_key'; then
  export ANTHROPIC_API_KEY="${API_KEY}"
  bashio::log.info "Using API key authentication"
fi

if ! bashio::config.has_value 'claude_oauth_token' && ! bashio::config.has_value 'anthropic_api_key'; then
  bashio::log.warning "No authentication configured — Claude Code will prompt for login"
fi

# 3. Auto-update Claude Code (best-effort)
bashio::log.info "Checking for Claude Code updates..."
claude update 2>/dev/null || \
  curl -fsSL https://claude.ai/install.sh | bash 2>/dev/null || \
  bashio::log.warning "Claude Code update failed, using existing version"
bashio::log.info "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"

# 4. Persistent storage setup
mkdir -p /data/.claude /data/workspace
ln -sfn /data/.claude "${HOME}/.claude"

# 5. First-run config — skip onboarding wizard
if [ ! -f "${HOME}/.claude.json" ]; then
  echo '{"hasCompletedOnboarding": true}' > "${HOME}/.claude.json"
  bashio::log.info "First run — created Claude config"
fi

# 6. Seed CLAUDE.md if not present
if [ ! -f /data/workspace/CLAUDE.md ]; then
  cp /opt/templates/CLAUDE.md /data/workspace/CLAUDE.md
  bashio::log.info "Seeded workspace CLAUDE.md"
fi

# 7. Git config (if provided)
if bashio::config.has_value 'git_user_name'; then
  git config --global user.name "${GIT_NAME}"
fi
if bashio::config.has_value 'git_user_email'; then
  git config --global user.email "${GIT_EMAIL}"
fi

# 8. Export model preference
if bashio::config.has_value 'claude_model'; then
  export CLAUDE_MODEL="${CLAUDE_MODEL}"
fi

# 9. Start ttyd with ingress base path
cd /data/workspace
exec ttyd \
  --writable \
  --port 7681 \
  --base-path "${INGRESS_ENTRY}" \
  --ping-interval 30 \
  -t rendererType=canvas \
  -t disableLeaveAlert=true \
  tmux new-session -A -s claude
```

- [ ] **Step 2: Commit**

```bash
git add run.sh
git commit -m "feat: add startup script run.sh

Reads addon config via bashio, exports auth env vars, auto-updates
Claude Code, sets up persistent storage with symlinks, seeds CLAUDE.md,
configures git, and starts ttyd attached to a tmux session."
```

---

### Task 5: Documentation (DOCS.md, CHANGELOG.md, README.md)

**Files:**
- Create: `DOCS.md`
- Create: `CHANGELOG.md`
- Create: `README.md`

- [ ] **Step 1: Create DOCS.md**

This is the documentation shown in the HA addon UI.

```markdown
# Claude Code Terminal

Access Claude Code from your Home Assistant sidebar via a web terminal.

## Setup

1. Install the addon from the addon store
2. Get your authentication token:
   - **OAuth (recommended):** Run `claude setup-token` on your computer and paste the token into the addon configuration
   - **API Key:** Enter your Anthropic API key in the addon configuration
3. Start the addon
4. Open "Claude Code" from the sidebar

## Configuration

| Option | Description |
|--------|-------------|
| `claude_oauth_token` | OAuth token from `claude setup-token` |
| `anthropic_api_key` | Anthropic API key (alternative to OAuth) |
| `claude_model` | Default model: sonnet, opus, or haiku |
| `git_user_name` | Git commit author name (optional) |
| `git_user_email` | Git commit author email (optional) |

Only one authentication method is required. If both are provided, both are available to Claude Code.

## What Can It Do?

- Edit HA configuration files (automations, scripts, scenes, etc.)
- Call HA services and check entity states via the Supervisor API
- Create and manage coding projects in the persistent workspace
- Use git for version control

## File Locations

- **HA Config:** `/config/` (read/write)
- **Shared Storage:** `/share/` (read/write)
- **Projects:** `/data/workspace/` (persistent across restarts)

## Session Persistence

Your terminal session persists across page reloads — tmux keeps the session alive in the background. Your workspace files in `/data/workspace/` persist across addon restarts, updates, and HA reboots.

## Security

- Authentication tokens are stored in HA's encrypted addon options
- Access is through HA's ingress — no ports are exposed to the network
- The addon has read/write access to your HA configuration files
```

- [ ] **Step 2: Create CHANGELOG.md**

```markdown
# Changelog

## 0.1.0

- Initial release
- Claude Code in a web terminal via HA ingress
- OAuth token and API key authentication
- Persistent tmux sessions
- HA config file access (/config)
- HA Supervisor API access via SUPERVISOR_TOKEN
- Auto-update Claude Code on startup
- CLAUDE.md seed with HA API patterns
```

- [ ] **Step 3: Create README.md**

```markdown
# Claude Code Terminal — Home Assistant Addon

A Home Assistant OS addon that runs [Claude Code](https://claude.ai/code) in a web terminal accessible from the HA sidebar.

## Features

- Browser-based Claude Code access via the HA sidebar
- Persistent tmux sessions (survive page reloads)
- Full read/write access to HA configuration files
- HA Supervisor API access for calling services, checking states, restarting HA
- Persistent workspace for coding projects
- Auto-updates Claude Code on startup
- Supports aarch64 (Pi 4/5) and amd64 (Intel NUCs)

## Installation

1. Add this repository to your HA addon store
2. Install "Claude Code Terminal"
3. Configure your authentication token (see DOCS.md)
4. Start the addon and open from the sidebar

## Architecture

```
ttyd (web terminal) → tmux session → Claude Code CLI
```

HA Ingress proxies the web terminal — no ports exposed to the network.
```

- [ ] **Step 4: Commit**

```bash
git add DOCS.md CHANGELOG.md README.md
git commit -m "docs: add DOCS.md, CHANGELOG.md, and README.md

DOCS.md shown in HA addon UI with setup instructions and config reference.
CHANGELOG.md for release tracking. README.md for the GitHub repository."
```

---

### Task 6: Build and Smoke Test

This task verifies the addon builds correctly for at least one architecture.

- [ ] **Step 1: Test Docker build locally**

```bash
cd /Users/sugendran/code/sugendran/ha-claude
docker build --build-arg BUILD_FROM=ghcr.io/hassio-addons/debian-base:7.8.0 -t ha-claude-test .
```

If the build fails, fix the Dockerfile and re-run.

- [ ] **Step 2: Verify Claude Code is installed in the image**

```bash
docker run --rm ha-claude-test claude --version
```

Expected: A version string like `2.x.x (Claude Code)`.

- [ ] **Step 3: Verify ttyd is installed**

```bash
docker run --rm ha-claude-test ttyd --version
```

Expected: A version string like `ttyd version x.x.x`.

- [ ] **Step 4: Verify tmux is installed**

```bash
docker run --rm ha-claude-test tmux -V
```

Expected: A version string like `tmux 3.x`.

- [ ] **Step 5: Verify template files are in place**

```bash
docker run --rm ha-claude-test cat /opt/templates/CLAUDE.md
```

Expected: The CLAUDE.md seed content.

- [ ] **Step 6: Verify run.sh is executable**

```bash
docker run --rm ha-claude-test ls -la /run.sh
```

Expected: `-rwxr-xr-x` permissions.

- [ ] **Step 7: Commit any fixes from smoke testing**

If any changes were needed, commit them:

```bash
git add -A
git commit -m "fix: address issues found during smoke testing"
```
