# syntax=docker/dockerfile:1.6
FROM python:3.11-slim-bookworm

ARG DEBIAN_FRONTEND=noninteractive

# Pin these for beta/release
ARG S6_OVERLAY_VERSION=3.2.0.2
ARG NODE_MAJOR=20
ARG NODE_RED_VERSION=3.1.15
ARG FLOWFUSE_DASHBOARD_VERSION=1.14.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils \
    sqlite3 \
    busybox \
  && rm -rf /var/lib/apt/lists/*

# Node.js (pinned major)
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
  && apt-get update && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

# Node-RED + FlowFuse Dashboard (pin versions)
RUN npm install -g --unsafe-perm node-red@${NODE_RED_VERSION} \
  && npm install -g --unsafe-perm @flowfuse/node-red-dashboard@${FLOWFUSE_DASHBOARD_VERSION} \
  && npm cache clean --force

WORKDIR /opt/himalia/app
COPY app/requirements.txt /opt/himalia/app/requirements.txt

# Upgrade packaging tooling (helps with resolver + TLS + wheels)
RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

# Harden pip network behavior for CI reliability
# - longer timeout
# - more retries
# - disable version check noise
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_DEFAULT_TIMEOUT=120

RUN pip install --no-cache-dir --retries 10 --timeout 120 -r requirements.txt

COPY app/ /opt/himalia/app/
COPY nodered/seed/flows.json /opt/himalia/seed/flows.json
COPY openplc/scripts/openplc-restore.sh /opt/himalia/openplc/openplc-restore.sh
COPY openplc/scripts/openplc-save.sh /opt/himalia/openplc/openplc-save.sh

# s6-overlay (pin exact version)
RUN curl -fsSL -o /tmp/s6-noarch.tar.xz \
      https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz \
 && curl -fsSL -o /tmp/s6-arch.tar.xz \
      https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz \
 && tar -C / -Jxpf /tmp/s6-noarch.tar.xz \
 && tar -C / -Jxpf /tmp/s6-arch.tar.xz \
 && rm -f /tmp/s6-noarch.tar.xz /tmp/s6-arch.tar.xz

COPY docker/rootfs/ /

RUN mkdir -p /etc/crontabs \
 && echo '* * * * * python /opt/himalia/app/poller.py >> /data/log/poller.log 2>&1' > /etc/crontabs/root

EXPOSE 5000 1880 8080
ENTRYPOINT ["/init"]
