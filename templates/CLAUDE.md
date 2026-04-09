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
