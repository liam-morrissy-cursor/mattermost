# Toolchains come from Docker Hub rather than go.dev / nodejs.org. This builder
# blocks some upstream hosts (cli.github.com already failed with curl exit 35),
# and the registry is the one source the build has to reach anyway for the base
# image. These are the official images, so the binaries are the upstream ones.
ARG GO_VERSION=1.26.4
ARG NODE_VERSION=24.11.1

FROM golang:${GO_VERSION}-bookworm AS go_src
FROM node:${NODE_VERSION}-bookworm AS node_src

FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG GO_VERSION
ARG NODE_VERSION
ARG NVM_VERSION=0.40.3
ARG DOCKER_VERSION=5:28.5.2-1~ubuntu.24.04~noble
ARG CONTAINERD_VERSION=2.2.3-1~ubuntu.24.04~noble
ARG DOCKER_BUILDX_VERSION=0.33.0-1~ubuntu.24.04~noble
ARG DOCKER_COMPOSE_VERSION=5.1.3-1~ubuntu.24.04~noble

ENV DEBIAN_FRONTEND=noninteractive
ENV NVM_DIR=/home/ubuntu/.nvm
ENV GOPATH=/home/ubuntu/go
ENV PATH=/home/ubuntu/.nvm/versions/node/v${NODE_VERSION}/bin:/usr/local/go/bin:/home/ubuntu/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    apt-transport-https \
    acl \
    bash \
    build-essential \
    ca-certificates \
    curl \
    dnsutils \
    file \
    fuse-overlayfs \
    git \
    git-lfs \
    gnupg \
    iproute2 \
    iptables \
    jq \
    less \
    libasound2t64 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcairo2 \
    libcups2 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libsecret-1-0 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    libxshmfence1 \
    locales \
    lsof \
    make \
    nano \
    netcat-openbsd \
    openssh-server \
    pgloader \
    pkg-config \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    rsync \
    sudo \
    tar \
    tmux \
    unzip \
    vim \
    xmlsec1 \
    xz-utils \
    zip && \
    locale-gen en_US.UTF-8 && \
    git lfs install --system && \
    rm -rf /var/lib/apt/lists/*

RUN install -m 0755 -d /etc/apt/keyrings && \
    curl --retry 3 --retry-delay 5 -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    docker-ce=${DOCKER_VERSION} \
    docker-ce-cli=${DOCKER_VERSION} \
    containerd.io=${CONTAINERD_VERSION} \
    docker-buildx-plugin=${DOCKER_BUILDX_VERSION} \
    docker-compose-plugin=${DOCKER_COMPOSE_VERSION} && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/docker && \
    printf '%s\n' \
    '{' \
    '  "storage-driver": "fuse-overlayfs",' \
    '  "features": {' \
    '    "buildkit": true' \
    '  }' \
    '}' > /etc/docker/daemon.json && \
    update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# Install gh from GitHub releases. The cli.github.com apt repo fails in this
# builder with curl exit 35 (SSL connect) on the keyring download.
ARG GH_VERSION=2.81.0
RUN case "$(dpkg --print-architecture)" in \
      amd64) gh_arch=amd64 ;; \
      arm64) gh_arch=arm64 ;; \
      *) echo "Unsupported gh architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac && \
    curl --retry 5 --retry-delay 5 --retry-all-errors -fsSL \
      "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${gh_arch}.tar.gz" \
      -o /tmp/gh.tgz && \
    tar -C /tmp -xzf /tmp/gh.tgz && \
    install -m 0755 "/tmp/gh_${GH_VERSION}_linux_${gh_arch}/bin/gh" /usr/local/bin/gh && \
    rm -rf /tmp/gh.tgz "/tmp/gh_${GH_VERSION}_linux_${gh_arch}"

COPY --from=go_src /usr/local/go /usr/local/go
RUN ln -sfnT /usr/local/go/bin/go /usr/local/bin/go && \
    ln -sfnT /usr/local/go/bin/gofmt /usr/local/bin/gofmt && \
    go version | grep -q "go${GO_VERSION}"

# Best effort: nothing in this repo needs the AWS CLI, and awscli.amazonaws.com
# may be blocked here. A missing aws must not fail the build; the install hook
# already reports it as "not available".
RUN case "$(dpkg --print-architecture)" in \
      amd64) aws_arch=x86_64 ;; \
      arm64) aws_arch=aarch64 ;; \
      *) aws_arch="" ;; \
    esac && \
    if [ -n "$aws_arch" ] && \
       curl --retry 3 --retry-delay 5 -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}.zip" -o /tmp/awscliv2.zip; then \
      unzip -q /tmp/awscliv2.zip -d /tmp && \
      /tmp/aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli; \
    else \
      echo "WARNING: AWS CLI download unavailable; continuing without it." >&2; \
    fi && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

RUN install -m 0755 -d /var/run/sshd && \
    printf '%s\n' 'PasswordAuthentication no' 'ChallengeResponseAuthentication no' 'UsePAM no' > /etc/ssh/sshd_config.d/disable_password_auth.conf && \
    if ! id -u ubuntu >/dev/null 2>&1; then useradd -m -s /bin/bash ubuntu; fi && \
    groupadd -f docker && \
    usermod -aG docker,sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    echo "ubuntu:ubuntu" | chpasswd && \
    install -d -o ubuntu -g ubuntu "${NVM_DIR}" "${GOPATH}"

RUN git clone --depth 1 --branch "v${NVM_VERSION}" https://github.com/nvm-sh/nvm.git "${NVM_DIR}" && \
    chown -R ubuntu:ubuntu "${NVM_DIR}" "${GOPATH}"

# Seed nvm's tree with the official Node build rather than running `nvm install`,
# which downloads from nodejs.org. nvm then reports the version as installed and
# `nvm use` works offline.
COPY --from=node_src --chown=ubuntu:ubuntu /usr/local/ ${NVM_DIR}/versions/node/v${NODE_VERSION}/

RUN install -d -o ubuntu -g ubuntu "${NVM_DIR}/alias" && \
    echo "${NODE_VERSION}" > "${NVM_DIR}/alias/default" && \
    chown ubuntu:ubuntu "${NVM_DIR}/alias/default" && \
    ln -sfn "${NVM_DIR}/versions/node/v${NODE_VERSION}/bin/node" /usr/local/bin/node && \
    ln -sfn "${NVM_DIR}/versions/node/v${NODE_VERSION}/bin/npm" /usr/local/bin/npm && \
    ln -sfn "${NVM_DIR}/versions/node/v${NODE_VERSION}/bin/npx" /usr/local/bin/npx && \
    node --version | grep -qx "v${NODE_VERSION}" && \
    su ubuntu -c "bash -lc 'set -e; source ${NVM_DIR}/nvm.sh; nvm use default >/dev/null; node --version'"

RUN { \
      echo 'export NVM_DIR="$HOME/.nvm"'; \
      echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'; \
      echo 'export GOPATH="$HOME/go"'; \
      echo 'export PATH="$NVM_DIR/versions/node/v24.11.1/bin:/usr/local/go/bin:$GOPATH/bin:$PATH"'; \
    } >> /home/ubuntu/.bashrc && \
    chown ubuntu:ubuntu /home/ubuntu/.bashrc

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

WORKDIR /home/ubuntu
USER ubuntu
