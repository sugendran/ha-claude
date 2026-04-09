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
bashio::log.info "Ingress entry: ${INGRESS_ENTRY}"
cd /data/workspace
exec ttyd \
  --writable \
  --port 7681 \
  --base-path "${INGRESS_ENTRY}" \
  --ping-interval 30 \
  -t rendererType=canvas \
  -t disableLeaveAlert=true \
  tmux new-session -A -s claude
