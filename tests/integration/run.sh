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

echo "[1/8] Build and start stack"
docker compose up --build -d

echo "[2/8] Wait for API health (inside container)"
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

echo "[3/8] Node-RED / Node.js versions (inside container)"
docker compose exec -T core sh -lc 'node --version | grep -E "^v[0-9]+\\.[0-9]+\\.[0-9]+"'
docker compose exec -T core sh -lc 'npm --version | grep -E "^[0-9]+\\.[0-9]+\\.[0-9]+"'
docker compose exec -T core sh -lc 'node-red --version >/dev/null && node-red --version'

echo "[4/8] OpenPLC Runtime REST API auth flow + ping (inside container)"
docker compose exec -T core python - <<'PY'
import json
import os
import ssl
import time
import urllib.request
import urllib.error

BASE_URL = "https://localhost:8443/api"

USERNAME = os.environ.get("OPENPLC_TEST_USERNAME", "tgack")
PASSWORD = os.environ.get("OPENPLC_TEST_PASSWORD", "TGqa090499")
ROLE = os.environ.get("OPENPLC_TEST_ROLE", "admin")

ctx = ssl._create_unverified_context()

def request(method: str, path: str, body=None, headers=None, timeout=5):
    url = BASE_URL + path
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method)
    hdrs = headers or {}
    if body is not None:
        hdrs.setdefault("Content-Type", "application/json")
    for k, v in hdrs.items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            return resp.status, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")
        return e.code, raw

def must_json(raw: str):
    try:
        return json.loads(raw)
    except Exception:
        raise SystemExit(f"Expected JSON but got: {raw[:400]}")

def wait_for_openplc_api(deadline_seconds=180):
    deadline = time.time() + deadline_seconds
    last = None
    # Any HTTP response indicates the server is up; we do not require success here.
    probe_body = {"username": "_probe_", "password": "_probe_"}
    while time.time() < deadline:
        try:
            code, raw = request("POST", "/login", body=probe_body, timeout=3)
            print(f"OpenPLC API reachable (login probe HTTP {code})")
            return
        except Exception as e:
            last = e
            time.sleep(2)
    raise SystemExit(f"OpenPLC API not reachable within timeout: {last}")

wait_for_openplc_api()

# 1) Create first user (no auth required for first user)
code, raw = request("POST", "/create-user", body={"username": USERNAME, "password": PASSWORD, "role": ROLE})
if code == 201:
    data = must_json(raw)
    if data.get("msg") != "User created" or "id" not in data:
        raise SystemExit(f"create-user: unexpected success payload: {data}")
    print(f"create-user: OK (id={data.get('id')})")
elif code in (401, 409):
    # 401 can occur if a first user already exists; 409 if username already exists.
    # For integration testing we proceed to login.
    print(f"create-user: already-initialized (HTTP {code})")
else:
    raise SystemExit(f"create-user failed: HTTP {code} body={raw[:400]}")

# 2) Login
code, raw = request("POST", "/login", body={"username": USERNAME, "password": PASSWORD})
if code != 200:
    raise SystemExit(f"login failed: HTTP {code} body={raw[:400]}")
data = must_json(raw)
token = data.get("access_token")
if not token or not isinstance(token, str):
    raise SystemExit(f"login: missing access_token in response: {data}")
print("login: OK (token received)")

# 3) Ping
code, raw = request("GET", "/ping", headers={"Authorization": f"Bearer {token}"})
if code != 200:
    raise SystemExit(f"ping failed: HTTP {code} body={raw[:400]}")
data = must_json(raw)
if data.get("status") != "pong":
    raise SystemExit(f"ping: unexpected response: {data}")
print("ping: OK (pong)")
PY

echo "[5/8] Persistence markers (DB/Node-RED/OpenPLC dirs)"
docker compose exec -T core sh -lc 'echo hello > /data/db/_marker_db.txt'
docker compose exec -T core sh -lc 'echo hello > /data/nodered/_marker_nodered.txt'
docker compose exec -T core sh -lc 'echo hello > /data/openplc/_marker_openplc.txt'

echo "[6/8] Restart and verify markers persist"
docker compose restart core
sleep 5
docker compose exec -T core sh -lc 'test -f /data/db/_marker_db.txt'
docker compose exec -T core sh -lc 'test -f /data/nodered/_marker_nodered.txt'
docker compose exec -T core sh -lc 'test -f /data/openplc/_marker_openplc.txt'

echo "[7/8] Shutdown hook markers in logs (OpenPLC save)"
docker compose stop core
LOGS="$(docker compose logs --no-color core | tail -n 800)"
echo "$LOGS" | grep -q "OPENPLC_SAVE_START" || (echo "Missing OPENPLC_SAVE_START in logs" && exit 1)
echo "$LOGS" | grep -q "OPENPLC_SAVE_END" || (echo "Missing OPENPLC_SAVE_END in logs" && exit 1)

echo "[8/8] Cleanup"
docker compose down -v

echo "== Integration tests passed =="
