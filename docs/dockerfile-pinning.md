# Dockerfile size reduction and dependency pinning

This repo uses:
- `python:3.11-slim-bookworm` base (smaller than Ubuntu)
- pinned major Node.js (`NODE_MAJOR`)
- pinned Node-RED and FlowFuse Dashboard versions
- pinned s6-overlay version

## Recommended by increment
- Dev: you may keep defaults while iterating.
- Beta: pin build args explicitly and start populating `app/constraints.txt`.
- Release: fully pin build args and all Python dependencies.

## Example pinned build
```sh
docker build -f docker/Dockerfile \
  --build-arg S6_OVERLAY_VERSION=3.2.0.2 \
  --build-arg NODE_MAJOR=20 \
  --build-arg NODE_RED_VERSION=3.1.15 \
  --build-arg FLOWFUSE_DASHBOARD_VERSION=1.14.0 \
  -t himalia-core:dev .
```
