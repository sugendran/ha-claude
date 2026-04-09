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
