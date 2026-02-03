# Himalia

Single-container **core** appliance that runs:
- Flask Web API (Python 3)
- Node-RED (+ FlowFuse Dashboard)
- OpenPLC v4
- cron scheduler

Optional (final increment): separate **Ollama** container.

## Quick start (development)

1. Copy env:
   - `cp .env.example .env`
2. Start:
   - `docker compose up --build`

## Quick start (beta)

1. Set `HIMALIA_IMAGE_TAG` in `.env` to the beta tag you were given (e.g., `beta-20260131-<sha>`).
2. Start:
   - `docker compose -f compose.beta.yaml up`

## Data persistence

All persistent state is stored in the named volume mounted at `/data`:
- `/data/db`       SQLite DB
- `/data/nodered`  Node-RED userDir (flows + palette modules)
- `/data/openplc`  OpenPLC programs/state (via your save/restore scripts)
- `/data/log`      Optional logs

## Services / ports (defaults)

- API:      http://localhost:5000
- Node-RED: http://localhost:1880
- OpenPLC:  http://localhost:8080 (confirm runtime port)

## CI/CD

Workflows live in `.github/workflows/`:
- `ci.yml` (test + build, no push)
- `publish-dev-image.yml` (push private dev tags)
- `publish-beta-image.yml` (manual beta publish)
- `publish-release-image.yml` (push on GitHub Release)


## Development commands

- `make up` / `make down`
- `make test-unit`
- `make test-integration`

## Governance
See `docs/github-governance.md` for branch protection and environment approval setup.


## API Authentication

All /api/v1 endpoints (except /health and /openapi.json) require `X-API-Key` when `HIMALIA_API_KEY` is set.

