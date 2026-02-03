from __future__ import annotations

from typing import Any

from .models import Device


def device_to_dict(dev: Device) -> dict[str, Any]:
    return {
        "id": dev.id,
        "name": dev.name,
        "type": dev.type,
        "enabled": dev.enabled,
        "endpoint": dev.endpoint,
        "auth_mode": dev.auth_mode,
        "auth_username": dev.auth_username,
        # Password is write-only
        "has_auth_password": bool(dev.auth_password),
        "poll_interval_s": dev.poll_interval_s,
        "timeout_ms": dev.timeout_ms,
        "tags": dev.tags if dev.tags is not None else [],
        "notes": dev.notes,
        "created_at": dev.created_at.isoformat(),
        "updated_at": dev.updated_at.isoformat(),
        "last_seen_at": dev.last_seen_at.isoformat() if dev.last_seen_at else None,
        "last_poll_at": dev.last_poll_at.isoformat() if dev.last_poll_at else None,
        "last_error": dev.last_error,
    }
