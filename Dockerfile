FROM node:24-bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG GO_VERSION=""
ARG CODEX_VERSION=latest
ARG PLAYWRIGHT_VERSION=1.62.0

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    GOPATH=/go \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    PATH=/usr/local/go/bin:/usr/local/cargo/bin:/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    wget \
    git \
    git-lfs \
    openssh-client \
    gnupg \
    dirmngr \
    less \
    procps \
    psmisc \
    lsof \
    tree \
    jq \
    yq \
    ripgrep \
    fd-find \
    vim-tiny \
    nano \
    unzip \
    zip \
    tar \
    xz-utils \
    file \
    rsync \
    iproute2 \
    iputils-ping \
    dnsutils \
    netcat-openbsd \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    ninja-build \
    pkg-config \
    clang \
    lldb \
    gdb \
    shellcheck \
    shfmt \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    python-is-python3 \
    openjdk-17-jdk-headless \
    libssl-dev \
    zlib1g-dev \
    libffi-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    liblzma-dev \
 && git lfs install --system \
 && rm -rf /var/lib/apt/lists/*

# 给 login shell / interactive shell 都补一份环境变量
RUN set -eux; \
    printf '%s\n' \
      'export GOPATH="${GOPATH:-/go}"' \
      'export RUSTUP_HOME="${RUSTUP_HOME:-/usr/local/rustup}"' \
      'export CARGO_HOME="${CARGO_HOME:-/usr/local/cargo}"' \
      'case ":$PATH:" in *":/usr/local/go/bin:"*) ;; *) PATH="/usr/local/go/bin:$PATH" ;; esac' \
      'case ":$PATH:" in *":$CARGO_HOME/bin:"*) ;; *) PATH="$CARGO_HOME/bin:$PATH" ;; esac' \
      'case ":$PATH:" in *":$GOPATH/bin:"*) ;; *) PATH="$GOPATH/bin:$PATH" ;; esac' \
      'export PATH' \
      > /etc/profile.d/dev-env.sh; \
    chmod 0644 /etc/profile.d/dev-env.sh; \
    printf '%s\n' \
      '' \
      '# dev env' \
      'if [ -r /etc/profile.d/dev-env.sh ]; then . /etc/profile.d/dev-env.sh; fi' \
      >> /etc/bash.bashrc; \
    mkdir -p /go/bin

# Go
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) go_arch="amd64" ;; \
      arm64) go_arch="arm64" ;; \
      armhf) go_arch="armv6l" ;; \
      i386) go_arch="386" ;; \
      *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    if [ -z "$GO_VERSION" ]; then \
      go_version="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n 1)"; \
    else \
      go_version="go${GO_VERSION#go}"; \
    fi; \
    curl -fsSL "https://go.dev/dl/${go_version}.linux-${go_arch}.tar.gz" -o /tmp/go.tgz; \
    rm -rf /usr/local/go; \
    tar -C /usr/local -xzf /tmp/go.tgz; \
    rm -f /tmp/go.tgz; \
    ln -sf /usr/local/go/bin/go /usr/local/bin/go; \
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt; \
    go version; \
    gofmt -w /dev/null 2>/dev/null || true

# Rust
RUN set -eux; \
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable; \
    rustup component add rustfmt clippy; \
    find /usr/local/cargo/bin -maxdepth 1 -type f -executable -exec sh -c \
      'for p do ln -sf "$p" "/usr/local/bin/$(basename "$p")"; done' sh {} +; \
    rustc --version; \
    cargo --version; \
    rustfmt --version; \
    cargo clippy --version; \
    rm -rf "${CARGO_HOME}/registry" "${CARGO_HOME}/git"

# Playwright and Chromium.
RUN set -eux; \
    npm i -g "@playwright/test@${PLAYWRIGHT_VERSION}"; \
    playwright install --with-deps chromium; \
    case "$(node --version)" in v24.*) ;; *) exit 1 ;; esac; \
    test "$(playwright --version)" = "Version ${PLAYWRIGHT_VERSION}"; \
    NODE_PATH="$(npm root -g)" node -e 'const { chromium } = require("@playwright/test"); (async () => { const browser = await chromium.launch({ headless: true }); console.log(await browser.version()); await browser.close(); })().catch(error => { console.error(error); process.exit(1); });'; \
    chmod -R a+rX "${PLAYWRIGHT_BROWSERS_PATH}"; \
    npm cache clean --force; \
    rm -rf /var/lib/apt/lists/*

# Node package managers and Codex.
RUN set -eux; \
    corepack enable; \
    npm i -g "@openai/codex@${CODEX_VERSION}"; \
    codex --version; \
    npm cache clean --force

WORKDIR /workspace

CMD ["tail", "-f", "/dev/null"]
