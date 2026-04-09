#!/usr/bin/with-contenv bashio

# 1. Auto-update Claude Code (best-effort)
bashio::log.info "Checking for Claude Code updates..."
claude update 2>/dev/null || \
  curl -fsSL https://claude.ai/install.sh | bash 2>/dev/null || \
  bashio::log.warning "Claude Code update failed, using existing version"
bashio::log.info "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"

# 2. Persistent storage setup
mkdir -p /data/.claude /data/workspace
ln -sfn /data/.claude "${HOME}/.claude"
cp -n /opt/templates/tmux.conf "${HOME}/.tmux.conf" 2>/dev/null || true

# 3. First-run config — skip onboarding wizard
if [ ! -f "${HOME}/.claude.json" ]; then
  echo '{"hasCompletedOnboarding": true}' > "${HOME}/.claude.json"
  bashio::log.info "First run — created Claude config"
fi

# 4. Seed CLAUDE.md if not present
if [ ! -f /data/workspace/CLAUDE.md ]; then
  cp /opt/templates/CLAUDE.md /data/workspace/CLAUDE.md
  bashio::log.info "Seeded workspace CLAUDE.md"
fi

# 5. Start ttyd — HA ingress strips the path prefix before forwarding
cd /data/workspace
exec ttyd \
  --writable \
  --port 7681 \
  --ping-interval 30 \
  -t rendererType=canvas \
  -t disableLeaveAlert=true \
  tmux new-session -A -s claude
