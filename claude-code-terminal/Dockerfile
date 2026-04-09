ARG BUILD_FROM=ghcr.io/home-assistant/aarch64-base-debian:bookworm
FROM ${BUILD_FROM}

# Install runtime dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tmux \
        git \
        ripgrep \
        curl \
        jq \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install ttyd from GitHub releases (not in Debian repos)
ARG TTYD_VERSION=1.7.7
RUN ARCH=$(uname -m) \
    && curl -fsSL -o /usr/local/bin/ttyd \
        "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${ARCH}" \
    && chmod +x /usr/local/bin/ttyd

# Install Claude Code native binary
RUN curl -fsSL https://claude.ai/install.sh | bash

# Ensure Claude Code is in PATH
RUN ln -sf /root/.local/bin/claude /usr/local/bin/claude

# Copy addon files
COPY run.sh /
COPY templates/ /opt/templates/

RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
