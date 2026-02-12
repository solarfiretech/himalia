#!/usr/bin/env sh
set -eu

echo "OPENPLC_SAVE_START"

# Default to fast compression to ensure shutdown snapshots complete within Docker's stop timeout.
# Override with OPENPLC_GZIP_OPTS (e.g. "-6" or "-9") if desired.
GZIP_OPTS="${OPENPLC_GZIP_OPTS:--1}"
export GZIP="${GZIP_OPTS}"

# Persistent storage root (Docker volume mounted at /data)
# Requirement: only save if this directory already exists.
PERSIST_ROOT="/data/openplc"

# OpenPLC runtime root
OPENPLC_DIR="/opt/himalia/openplc/openplc-runtime"

# OpenPLC web API runtime state directory (tmpfs-backed under /run)
WEBAPI_RUN_DIR="/run/runtime"

# Snapshot archives in persistent storage
OPENPLC_ARCHIVE="${PERSIST_ROOT}/openplc-runtime-state.tgz"
WEBAPI_ARCHIVE="${PERSIST_ROOT}/openplc-webapi-runtime.tgz"

if [ ! -d "${PERSIST_ROOT}" ]; then
  echo "[openplc-save] Persistent storage root missing: ${PERSIST_ROOT} (skipping save)"
  echo "OPENPLC_SAVE_END"
  exit 0
fi

# -----------------------------
# 1) Save OpenPLC runtime state
# -----------------------------
if [ -d "${OPENPLC_DIR}" ]; then
  TMP_LIST="$(mktemp)"
  TMP_ARCHIVE="${OPENPLC_ARCHIVE}.tmp"

  cleanup() {
    rm -f "${TMP_LIST}" "${TMP_ARCHIVE}" 2>/dev/null || true
  }
  trap cleanup EXIT

  add_item() {
    # Adds a relative path to the tar list if it exists.
    # $1: relative path under ${OPENPLC_DIR}
    if [ -e "${OPENPLC_DIR}/$1" ]; then
      printf '%s\n' "$1" >> "${TMP_LIST}"
    else
      echo "[openplc-save] WARN: Not found (skipping): ${OPENPLC_DIR}/$1"
    fi
  }

  # Save any compiled PLC shared libraries (filename contains a timestamp)
  found_lib=0
  for f in "${OPENPLC_DIR}"/build/libplc_*.so; do
    if [ -f "$f" ]; then
      rel="${f#${OPENPLC_DIR}/}"
      printf '%s\n' "${rel}" >> "${TMP_LIST}"
      found_lib=1
    fi
  done
  if [ "${found_lib}" -eq 0 ]; then
    echo "[openplc-save] WARN: No build/libplc_*.so found under ${OPENPLC_DIR}/build"
  fi

  # Persist the required config + generated artifacts
  add_item "plugins.conf"
  add_item "core/src/drivers/plugins/python/modbus_master/modbus_master.json"
  add_item "core/generated"

  if [ ! -s "${TMP_LIST}" ]; then
    echo "[openplc-save] Nothing to save (no listed items exist)."
  else
    echo "[openplc-save] Writing snapshot archive: ${OPENPLC_ARCHIVE}"

    start_ts="$(date +%s)"

    # Create archive from the runtime directory root.
    # --numeric-owner avoids name->id mapping surprises.
    tar -czf "${TMP_ARCHIVE}" --numeric-owner -C "${OPENPLC_DIR}" -T "${TMP_LIST}"

    end_ts="$(date +%s)"
    elapsed="$((end_ts - start_ts))"
    size_bytes="$(stat -c '%s' "${TMP_ARCHIVE}" 2>/dev/null || echo 0)"
    echo "[openplc-save] Snapshot archive created (tmp): ${TMP_ARCHIVE} (${size_bytes} bytes) in ${elapsed}s"

    # Atomic replace
    mv -f "${TMP_ARCHIVE}" "${OPENPLC_ARCHIVE}"

    # Best-effort fsync for the volume
    sync 2>/dev/null || true

    # Optional: keep a human-readable manifest alongside the archive
    {
      echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo "openplc_dir=${OPENPLC_DIR}"
      echo "archive=${OPENPLC_ARCHIVE}"
      echo "items:"
      sed 's/^/  - /' "${TMP_LIST}"
    } > "${PERSIST_ROOT}/openplc-runtime-state.manifest.txt" 2>/dev/null || true
  fi
else
  echo "[openplc-save] WARN: OpenPLC runtime directory missing: ${OPENPLC_DIR} (skipping runtime save)"
fi

# ----------------------------------------
# 2) Save OpenPLC web API /run/runtime state
# ----------------------------------------
if [ -d "${WEBAPI_RUN_DIR}" ]; then
  TMP_ARCHIVE2="${WEBAPI_ARCHIVE}.tmp"
  echo "[openplc-save] Saving web API runtime state ${WEBAPI_RUN_DIR} -> ${WEBAPI_ARCHIVE}"

  start_ts2="$(date +%s)"

  # Archive includes the directory name 'runtime' and all contents (including hidden files).
  tar -czf "${TMP_ARCHIVE2}" --numeric-owner -C "/run" "runtime"

  end_ts2="$(date +%s)"
  elapsed2="$((end_ts2 - start_ts2))"
  echo "[openplc-save] Web API runtime snapshot build complete in ${elapsed2}s (tmp=$(ls -lah "${TMP_ARCHIVE2}" 2>/dev/null | awk '{print $5}' || echo '?'))"
  mv -f "${TMP_ARCHIVE2}" "${WEBAPI_ARCHIVE}"

  {
    echo "timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "source=${WEBAPI_RUN_DIR}"
    echo "archive=${WEBAPI_ARCHIVE}"
    echo "note=includes hidden files"
  } > "${PERSIST_ROOT}/openplc-webapi-runtime.manifest.txt" 2>/dev/null || true
else
  echo "[openplc-save] WARN: Web API runtime directory missing: ${WEBAPI_RUN_DIR} (skipping web API state save)"
fi

echo "OPENPLC_SAVE_END"
