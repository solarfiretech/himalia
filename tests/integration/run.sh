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

# Force auth ON for integration
export HIMALIA_API_KEY="${HIMALIA_API_KEY:-test-api-key}"

# Ensure clean start
docker compose down -v >/dev/null 2>&1 || true

echo "[1/7] Build and start stack"
docker compose up --build -d

echo "[2/7] Wait for API health (inside container)"
python - <<'PY'
import time, subprocess, sys

deadline = time.time() + 180
last_err = None

cmd = [
    "docker",
    "compose",
    "exec",
    "-T",
    "core",
    "python",
    "-c",
    "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:5000/api/v1/health', timeout=2).read())",
]

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

echo "[3/7] Security baseline: API key required for device endpoints"
python - <<'PY'
import json, os, subprocess, sys
import shlex

API_KEY = os.environ.get('HIMALIA_API_KEY')
if not API_KEY:
    raise SystemExit('HIMALIA_API_KEY not set for integration test')

def curl(args):
    cmd = ["docker", "compose", "exec", "-T", "core", "sh", "-lc"]
    cmd.append(shlex.join(args))
    return subprocess.check_output(cmd, stderr=subprocess.STDOUT).decode('utf-8', errors='replace')

# Without key should be 401
out = curl(["python", "-c", "import urllib.request, urllib.error;\n\n" \
            "req=urllib.request.Request('http://127.0.0.1:5000/api/v1/devices');\n" \
            "\n" \
            "try:\n" \
            "  urllib.request.urlopen(req, timeout=3)\n" \
            "  print('UNEXPECTED_OK')\n" \
            "except urllib.error.HTTPError as e:\n" \
            "  print(e.code)\n" ])
if '401' not in out:
    raise SystemExit(f"Expected 401 without API key, got: {out}")

print("401 verified")
PY

echo "[4/7] Device CRUD (inside container)"
docker compose exec -T core python - <<'PY'
import json
import os
import urllib.request
import urllib.error

API_KEY = os.environ.get("HIMALIA_API_KEY")

base = "http://127.0.0.1:5000/api/v1"

payload = {
    "name": "IT-CAM-01",
    "type": "camera_ip_snapshot",
    "endpoint": "http://example.local/snap.jpg",
    "auth_mode": "basic",
    "auth_username": "u",
    "auth_password": "p",
}

req = urllib.request.Request(
    base + "/devices",
    data=json.dumps(payload).encode("utf-8"),
    method="POST",
    headers={"Content-Type": "application/json", "X-API-Key": API_KEY},
)
with urllib.request.urlopen(req, timeout=5) as resp:
    assert resp.status == 201
    dev = json.loads(resp.read().decode("utf-8"))
    dev_id = dev["id"]
    assert dev["has_auth_password"] is True
    assert "auth_password" not in dev

# GET list
req2 = urllib.request.Request(base + "/devices", headers={"X-API-Key": API_KEY})
with urllib.request.urlopen(req2, timeout=5) as resp:
    data = json.loads(resp.read().decode("utf-8"))
    assert data["count"] >= 1

# DELETE
req3 = urllib.request.Request(base + f"/devices/{dev_id}", method="DELETE", headers={"X-API-Key": API_KEY})
with urllib.request.urlopen(req3, timeout=5) as resp:
    assert resp.status == 204

print("Device CRUD OK")
PY

echo "[5/7] Persistence markers (DB/Node-RED/OpenPLC dirs)"
docker compose exec -T core sh -lc 'echo hello > /data/db/_marker_db.txt'
docker compose exec -T core sh -lc 'echo hello > /data/nodered/_marker_nodered.txt'
docker compose exec -T core sh -lc 'echo hello > /data/openplc/_marker_openplc.txt'

echo "[6/7] Restart and verify markers persist"
docker compose restart core
sleep 5
docker compose exec -T core sh -lc 'test -f /data/db/_marker_db.txt'
docker compose exec -T core sh -lc 'test -f /data/nodered/_marker_nodered.txt'
docker compose exec -T core sh -lc 'test -f /data/openplc/_marker_openplc.txt'

echo "[7/7] Shutdown hook markers in logs (OpenPLC save)"
docker compose stop core
LOGS="$(docker compose logs --no-color core | tail -n 800)"
echo "$LOGS" | grep -q "OPENPLC_SAVE_START" || (echo "Missing OPENPLC_SAVE_START in logs" && exit 1)
echo "$LOGS" | grep -q "OPENPLC_SAVE_END" || (echo "Missing OPENPLC_SAVE_END in logs" && exit 1)

docker compose down -v

echo "== Integration tests passed =="
