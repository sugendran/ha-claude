# HA Claude Code Addon - Design Spec

## Summary

A Home Assistant OS addon that runs Claude Code in a persistent tmux session, exposed via ttyd (web terminal) through HA's ingress. Provides browser-based access to Claude Code from the HA sidebar with full access to HA config files and the HA API.

## Architecture

```
HA OS (Pi 4 / NUC)
  └─ Addon Container (Debian)
       ├─ ttyd (:7681) ──► tmux session "claude" ──► claude CLI
       ├─ Mounts: /config (rw), /share (rw), /addon_configs (rw)
       └─ /data/ (persistent addon volume)
            ├─ .claude/     (symlinked to ~/.claude)
            └─ workspace/   (default working directory)

HA Ingress ──proxy──► ttyd :7681
HA Supervisor API via SUPERVISOR_TOKEN env var
```

## Authentication

Two auth methods supported:

1. **OAuth token** (Claude subscription) - User runs `claude setup-token` on their laptop, pastes token into addon config. Exported as `CLAUDE_CODE_OAUTH_TOKEN`.
2. **API key** (BYOK) - User provides their Anthropic API key. Exported as `ANTHROPIC_API_KEY`.

Only one is required. If both are set, both are exported (Claude Code resolves precedence internally).

Token stored in HA Supervisor encrypted addon options.

`~/.claude.json` is templated on first boot with `hasCompletedOnboarding: true` to skip the interactive setup wizard.

## Session Persistence

- tmux session named "claude" created on startup if it doesn't exist.
- ttyd attaches via `tmux new-session -A -s claude`.
- `~/.claude/` symlinked to `/data/.claude/` - conversation history, projects, settings persist across restarts.
- `/data/workspace/` is the default working directory for all projects.
- `/data/` is a Docker volume managed by HA Supervisor - persists across restarts, updates, reboots. Included in HA backups.

## Ingress + ttyd

- HA Supervisor ingress proxies HTTP + WebSocket to the addon.
- ttyd started with `--base-path "${INGRESS_ENTRY}"` (from `bashio::addon.ingress_entry`).
- `rendererType=canvas` avoids WebGL issues in HA's iframe.
- `--ping-interval 30` keeps WebSocket alive through ingress.
- No ttyd auth - HA's session-based ingress auth handles access control.

## Container Contents

**Base image:** `ghcr.io/hassio-addons/debian-base`

**Packages:**
- Claude Code native binary (via install script, auto-detects arch)
- ttyd (web terminal)
- tmux (session persistence)
- git, ripgrep (Claude Code dependencies)
- curl, jq (HA API interaction)

**Estimated RAM:** ~120-200MB total addon overhead.

## Addon Config (config.yaml)

```yaml
name: Claude Code Terminal
version: 0.1.0
slug: claude-code-terminal
description: Claude Code in a web terminal via the HA sidebar
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

## Startup Flow (run.sh)

1. Read addon options via bashio
2. Export auth env vars (OAuth token and/or API key)
3. Auto-update Claude Code (best-effort, non-blocking)
4. Create persistent storage dirs, symlink `~/.claude` to `/data/.claude`
5. Template `~/.claude.json` on first run (skip onboarding)
6. Seed `CLAUDE.md` into workspace if not present
7. Configure git if user/email provided
8. Start ttyd with ingress base path, attached to tmux session

## CLAUDE.md Seed

Seeded into `/data/workspace/CLAUDE.md` on first boot with:
- HA Supervisor API usage patterns (curl + SUPERVISOR_TOKEN)
- Common API endpoints (states, services, config check, restart)
- HA config file locations (/config/)
- Working directory info

## File Structure

```
ha-claude/
  config.yaml
  Dockerfile
  run.sh
  DOCS.md
  CHANGELOG.md
  templates/
    CLAUDE.md
  README.md
```

## Security

- Auth tokens in HA Supervisor encrypted options, not on disk.
- Ingress-only access behind HA authentication - no exposed ports.
- `/config` mount is the main risk surface (intentional - full HA config access).

## Out of Scope (Stretch Goals)

- HA MCP Server
- Backup integration (auto-snapshot before config changes)
- Multi-session tmux support
- Update notifications via HA persistent notification
