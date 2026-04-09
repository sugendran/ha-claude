#!/usr/bin/with-contenv bashio

# 1. Ensure Claude Code is in PATH for all sessions
export PATH="/root/.local/bin:${PATH}"
echo 'export PATH="/root/.local/bin:$PATH"' > /root/.bashrc

# 2. Auto-update Claude Code (best-effort)
bashio::log.info "Checking for Claude Code updates..."
claude update 2>/dev/null || \
  curl -fsSL https://claude.ai/install.sh | bash 2>/dev/null || \
  bashio::log.warning "Claude Code update failed, using existing version"
bashio::log.info "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"

# 3. Persistent storage setup
mkdir -p /data/.claude /data/workspace
ln -sfn /data/.claude "${HOME}/.claude"

# 4. First-run config — skip onboarding wizard
if [ ! -f "${HOME}/.claude.json" ]; then
  echo '{"hasCompletedOnboarding": true}' > "${HOME}/.claude.json"
  bashio::log.info "First run — created Claude config"
fi

# 5. Seed CLAUDE.md if not present
if [ ! -f /data/workspace/CLAUDE.md ]; then
  cp /opt/templates/CLAUDE.md /data/workspace/CLAUDE.md
  bashio::log.info "Seeded workspace CLAUDE.md"
fi

# 6. Claude Code Router — persist config in /data, start if configured
mkdir -p /data/.claude-code-router
ln -sfn /data/.claude-code-router "${HOME}/.claude-code-router"
if [ -f "${HOME}/.claude-code-router/config.json" ]; then
  bashio::log.info "Starting Claude Code Router..."
  ccr start &
  sleep 2
  eval "$(ccr activate 2>/dev/null)" || true
  # Write router env vars to bashrc so tmux sessions get them
  ccr activate 2>/dev/null >> /root/.bashrc || true
  bashio::log.info "Claude Code Router started"
else
  bashio::log.info "No Claude Code Router config found — skipping (create /data/.claude-code-router/config.json to enable)"
fi

# 7. Start ttyd — HA ingress strips the path prefix before forwarding
cd /data/workspace
exec ttyd \
  --writable \
  --port 7681 \
  --ping-interval 30 \
  -t rendererType=canvas \
  -t disableLeaveAlert=true \
  tmux new-session -A -s claude
