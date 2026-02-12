from __future__ import annotations

import datetime as dt
import uuid

from flask import Blueprint, jsonify, request
from sqlalchemy import select

from ..models import Device, utcnow
from ..serializers import device_to_dict
from ..validation import validate_device_payload

bp = Blueprint("devices", __name__)


def _get_session():
    # Late import to avoid circulars
    from flask import g

    return g.db


@bp.post("/api/v1/devices")
def create_device():
    payload = request.get_json(silent=True)
    res = validate_device_payload(payload or {}, mode="create")
    if res.errors:
        return {"error": "validation_error", "details": res.errors}, 400

    dev = Device(
        id=str(uuid.uuid4()),
        name=res.cleaned["name"],
        type=res.cleaned["type"],
        enabled=res.cleaned["enabled"],
        endpoint=res.cleaned["endpoint"],
        auth_mode=res.cleaned.get("auth_mode"),
        auth_username=res.cleaned.get("auth_username"),
        auth_password=res.cleaned.get("auth_password"),
        poll_interval_s=res.cleaned["poll_interval_s"],
        timeout_ms=res.cleaned["timeout_ms"],
        tags=res.cleaned.get("tags"),
        notes=res.cleaned.get("notes"),
        created_at=utcnow(),
        updated_at=utcnow(),
    )

    s = _get_session()
    s.add(dev)
    s.commit()

    return device_to_dict(dev), 201


@bp.get("/api/v1/devices")
def list_devices():
    s = _get_session()
    rows = s.execute(select(Device).order_by(Device.created_at.asc())).scalars().all()
    return {"items": [device_to_dict(d) for d in rows], "count": len(rows)}, 200


@bp.get("/api/v1/devices/<device_id>")
def get_device(device_id: str):
    s = _get_session()
    dev = s.get(Device, device_id)
    if not dev:
        return {"error": "not_found"}, 404
    return device_to_dict(dev), 200


@bp.put("/api/v1/devices/<device_id>")
def put_device(device_id: str):
    payload = request.get_json(silent=True)
    res = validate_device_payload(payload or {}, mode="put")
    if res.errors:
        return {"error": "validation_error", "details": res.errors}, 400

    s = _get_session()
    dev = s.get(Device, device_id)
    if not dev:
        return {"error": "not_found"}, 404

    # Full replacement: reset unspecified optional fields to defaults/null
    dev.name = res.cleaned["name"]
    dev.type = res.cleaned["type"]
    dev.enabled = res.cleaned["enabled"]
    dev.endpoint = res.cleaned["endpoint"]

    dev.auth_mode = res.cleaned.get("auth_mode")
    dev.auth_username = res.cleaned.get("auth_username")
    dev.auth_password = res.cleaned.get("auth_password")

    dev.poll_interval_s = res.cleaned["poll_interval_s"]
    dev.timeout_ms = res.cleaned["timeout_ms"]
    dev.tags = res.cleaned.get("tags")
    dev.notes = res.cleaned.get("notes")

    dev.updated_at = utcnow()

    s.commit()
    return device_to_dict(dev), 200


@bp.patch("/api/v1/devices/<device_id>")
def patch_device(device_id: str):
    payload = request.get_json(silent=True)
    res = validate_device_payload(payload or {}, mode="patch")
    if res.errors:
        return {"error": "validation_error", "details": res.errors}, 400

    s = _get_session()
    dev = s.get(Device, device_id)
    if not dev:
        return {"error": "not_found"}, 404

    # Partial update
    for k, v in res.cleaned.items():
        setattr(dev, k, v)

    # If either type or endpoint changed, enforce scheme/type compatibility using updated values
    if "type" in res.cleaned or "endpoint" in res.cleaned:
        # Re-run validator in PUT mode against the merged state for endpoint/type coupling
        merged = {
            "name": dev.name,
            "type": dev.type,
            "endpoint": dev.endpoint,
            "enabled": dev.enabled,
            "auth_mode": dev.auth_mode,
            "auth_username": dev.auth_username,
            "auth_password": dev.auth_password,
            "poll_interval_s": dev.poll_interval_s,
            "timeout_ms": dev.timeout_ms,
            "tags": dev.tags or [],
            "notes": dev.notes,
        }
        check = validate_device_payload(merged, mode="put")
        if check.errors:
            s.rollback()
            return {"error": "validation_error", "details": check.errors}, 400

    dev.updated_at = utcnow()
    s.commit()

    return device_to_dict(dev), 200


@bp.delete("/api/v1/devices/<device_id>")
def delete_device(device_id: str):
    s = _get_session()
    dev = s.get(Device, device_id)
    if not dev:
        return {"error": "not_found"}, 404

    s.delete(dev)
    s.commit()
    return "", 204
