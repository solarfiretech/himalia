#!/usr/bin/env bash
set -euo pipefail

echo "== Himalia integration tests =="

# Ensure clean start
docker compose down -v >/dev/null 2>&1 || true

echo "[1/6] Build and start stack"
docker compose up --build -d

echo "[2/6] Wait for API health"
python - <<'PY'
import time, urllib.request, sys
url = "http://127.0.0.1:5000/api/v1/health"
deadline = time.time() + 120
last_err = None
while time.time() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=2) as r:
            if r.status == 200:
                print("Health OK")
                sys.exit(0)
    except Exception as e:
        last_err = e
    time.sleep(2)
print("Health check failed:", last_err)
sys.exit(1)
PY

echo "[3/6] Persistence markers (DB/Node-RED/OpenPLC dirs)"
docker exec himalia-core sh -lc 'echo hello > /data/db/_marker_db.txt'
docker exec himalia-core sh -lc 'echo hello > /data/nodered/_marker_nodered.txt'
docker exec himalia-core sh -lc 'echo hello > /data/openplc/_marker_openplc.txt'

echo "[4/6] Restart and verify markers persist"
docker compose restart core
sleep 5
docker exec himalia-core sh -lc 'test -f /data/db/_marker_db.txt'
docker exec himalia-core sh -lc 'test -f /data/nodered/_marker_nodered.txt'
docker exec himalia-core sh -lc 'test -f /data/openplc/_marker_openplc.txt'

echo "[5/6] Shutdown hook markers in logs (OpenPLC save)"
docker compose stop core
LOGS="$(docker compose logs --no-color core | tail -n 800)"
echo "$LOGS" | grep -q "OPENPLC_SAVE_START" || (echo "Missing OPENPLC_SAVE_START in logs" && exit 1)
echo "$LOGS" | grep -q "OPENPLC_SAVE_END" || (echo "Missing OPENPLC_SAVE_END in logs" && exit 1)

echo "[6/6] Cleanup"
docker compose down -v

echo "== Integration tests passed =="
