# s6-overlay in Himalia

Himalia uses **s6-overlay** to supervise multiple long-running services in a single container.

## Layout used
- `/etc/cont-init.d/*` runs at container startup (initialization)
- `/etc/services.d/<service>/run` runs and supervises each service
- `/etc/cont-finish.d/*` runs at container shutdown (cleanup/save)

## Services
- `api`      -> gunicorn serving Flask app
- `nodered`  -> Node-RED with `--userDir /data/nodered`
- `openplc`  -> OpenPLC runtime (placeholder until implemented)
- `cron`     -> busybox `crond -f`

## OpenPLC save/restore
- Restore: `/etc/cont-init.d/20-openplc-restore`
- Save:    `/etc/cont-finish.d/90-openplc-save`

Replace the stub scripts in `openplc/scripts/` with your working versions.
