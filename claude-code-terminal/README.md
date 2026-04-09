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
