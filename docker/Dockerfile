# syntax=docker/dockerfile:1.6
FROM python:3.11-slim-bookworm

ARG DEBIAN_FRONTEND=noninteractive

# Pin these for beta/release
ARG S6_OVERLAY_VERSION=3.2.0.2
ARG NODE_MAJOR=22
ARG NODE_RED_VERSION=4.1.4
ARG FLOWFUSE_DASHBOARD_VERSION=1.30.1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    python3 \
    python3-pip \
    python3-dev \
    sqlite3 \
    libsqlite3-dev \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    tzdata \
    ca-certificates \
    gnupg \
    xz-utils \
    procps \
    cron \
    && apt-get clean \
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
RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel

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

# Ensure s6 scripts are executable (GitHub checkouts may not preserve +x)
RUN chmod +x \
    /etc/cont-init.d/* \
    /etc/cont-finish.d/* \
    /etc/services.d/*/run \
 && chmod +x /opt/himalia/openplc/openplc-restore.sh /opt/himalia/openplc/openplc-save.sh || true


#RUN mkdir -p /etc/crontabs \
# && echo '* * * * * python /opt/himalia/app/poller.py >> /data/log/poller.log 2>&1' > /etc/crontabs/root
RUN mkdir -p /data/log \
 && printf "SHELL=/bin/sh\nPATH=/usr/local/bin:/usr/bin:/bin\n* * * * * root /usr/local/bin/python /opt/himalia/app/poller.py >> /data/log/poller.log 2>&1\n" \
    > /etc/cron.d/himalia-poller \
 && chmod 0644 /etc/cron.d/himalia-poller

# Install OpenPLC (optional - can be enabled if needed)
RUN git clone https://github.com/Autonomy-Logic/openplc-runtime.git /opt/himalia/openplc/openplc-runtime && \
	cd /opt/himalia/openplc/openplc-runtime && \
    git checkout development && \
    ./install.sh

EXPOSE 5000 1880 8080 8443 4840
ENTRYPOINT ["/init"]
