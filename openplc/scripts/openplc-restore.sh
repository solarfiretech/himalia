#!/usr/bin/env sh
set -eu

echo "OPENPLC_RESTORE_START"

# Persistent storage root (Docker volume mounted at /data)
# Requirement: only restore if this directory already exists.
PERSIST_ROOT="/data/openplc"

# OpenPLC runtime root
OPENPLC_DIR="/opt/himalia/openplc/openplc-runtime"

# OpenPLC web API runtime state directory (tmpfs-backed under /run)
WEBAPI_RUN_DIR="/run/runtime"

# Snapshot archives in persistent storage
OPENPLC_ARCHIVE="${PERSIST_ROOT}/openplc-runtime-state.tgz"
WEBAPI_ARCHIVE="${PERSIST_ROOT}/openplc-webapi-runtime.tgz"

# Clean up any interrupted/partial archives from prior shutdowns.
rm -f "${OPENPLC_ARCHIVE}.tmp" "${WEBAPI_ARCHIVE}.tmp" 2>/dev/null || true

if [ ! -d "${PERSIST_ROOT}" ]; then
  echo "[openplc-restore] Persistent storage root missing: ${PERSIST_ROOT} (skipping restore)"
  echo "OPENPLC_RESTORE_END"
  exit 0
fi

# -------------------------------
# 1) Restore OpenPLC runtime state
# -------------------------------
if [ -f "${OPENPLC_ARCHIVE}" ]; then
  if [ ! -d "${OPENPLC_DIR}" ]; then
    echo "[openplc-restore] OpenPLC runtime directory missing: ${OPENPLC_DIR} (cannot restore runtime state)"
  else
    echo "[openplc-restore] Restoring runtime snapshot ${OPENPLC_ARCHIVE} -> ${OPENPLC_DIR}"

    # Pre-clean to avoid stale artifacts (especially timestamped libplc_*.so names)
    rm -rf "${OPENPLC_DIR}/core/generated" 2>/dev/null || true
    rm -f "${OPENPLC_DIR}"/build/libplc_*.so 2>/dev/null || true

    # Extract snapshot into the runtime directory.
    # --no-same-owner avoids chown attempts if archive ownership differs.
    tar -xzf "${OPENPLC_ARCHIVE}" --no-same-owner -C "${OPENPLC_DIR}"
  fi
else
  echo "[openplc-restore] No runtime snapshot archive found at ${OPENPLC_ARCHIVE} (nothing to restore)"
fi

# -------------------------------------------
# 2) Restore OpenPLC web API /run/runtime state
# -------------------------------------------
if [ -f "${WEBAPI_ARCHIVE}" ]; then
  echo "[openplc-restore] Restoring web API runtime snapshot ${WEBAPI_ARCHIVE} -> /run"

  # Ensure /run exists; it should, but be defensive.
  mkdir -p "/run"

  # Remove existing /run/runtime to avoid stale files (including hidden files).
  if [ -d "${WEBAPI_RUN_DIR}" ]; then
    rm -rf "${WEBAPI_RUN_DIR}" 2>/dev/null || true
  fi

  tar -xzf "${WEBAPI_ARCHIVE}" --no-same-owner -C "/run"
else
  echo "[openplc-restore] No web API snapshot archive found at ${WEBAPI_ARCHIVE} (nothing to restore)"
fi

echo "OPENPLC_RESTORE_END"
