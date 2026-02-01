#!/usr/bin/env bash
set -euo pipefail

dump_debug() {
  echo "==== DEBUG: docker compose ps ===="
  docker compose ps || true

  echo "==== DEBUG: core logs (tail) ===="
  docker compose logs --no-color --tail=300 core || true

  echo "==== DEBUG: recent s6 services list (if available) ===="
  docker compose exec -T core sh -lc 'ls -la /etc/services.d || true' || true

  echo "==== DEBUG: processes (core) ===="
  docker compose exec -T core sh -lc 'ps aux || true' || true
}

trap dump_debug ERR


echo "== Himalia integration tests =="

# Ensure clean start
docker compose down -v >/dev/null 2>&1 || true

echo "[1/6] Build and start stack"
docker compose up --build -d

echo "[2/6] Wait for API health (inside container)"
python - <<'PY'
import time, subprocess, sys

deadline = time.time() + 180
last_err = None

cmd = ["docker", "compose", "exec", "-T", "core", "python", "-c",
       "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:5000/api/v1/health', timeout=2).read())"]

while time.time() < deadline:
    try:
        subprocess.check_output(cmd, stderr=subprocess.STDOUT)
        print("Health OK")
        sys.exit(0)
    except Exception as e:
        last_err = e
        time.sleep(2)

print("Health check failed:", last_err)
sys.exit(1)
PY

echo "[3/6] Persistence markers (DB/Node-RED/OpenPLC dirs)"
docker compose exec -T core sh -lc 'echo hello > /data/db/_marker_db.txt'
docker compose exec -T core sh -lc 'echo hello > /data/nodered/_marker_nodered.txt'
docker compose exec -T core sh -lc 'echo hello > /data/openplc/_marker_openplc.txt'

echo "[4/6] Restart and verify markers persist"
docker compose restart core
sleep 5
docker compose exec -T core sh -lc 'test -f /data/db/_marker_db.txt'
docker compose exec -T core sh -lc 'test -f /data/nodered/_marker_nodered.txt'
docker compose exec -T core sh -lc 'test -f /data/openplc/_marker_openplc.txt'

echo "[5/6] Shutdown hook markers in logs (OpenPLC save)"
docker compose stop core
LOGS="$(docker compose logs --no-color core | tail -n 800)"
echo "$LOGS" | grep -q "OPENPLC_SAVE_START" || (echo "Missing OPENPLC_SAVE_START in logs" && exit 1)
echo "$LOGS" | grep -q "OPENPLC_SAVE_END" || (echo "Missing OPENPLC_SAVE_END in logs" && exit 1)

echo "[6/6] Cleanup"
docker compose down -v

echo "== Integration tests passed =="
