from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, List, Tuple
from urllib.parse import urlparse


ALLOWED_DEVICE_TYPES = {"camera_ip_snapshot", "camera_rtsp"}
ALLOWED_AUTH_MODES = {"none", "basic", "digest", "bearer"}


@dataclass
class ValidationResult:
    cleaned: Dict[str, Any]
    errors: List[str]


def _is_bool(v: Any) -> bool:
    return isinstance(v, bool)


def _is_int(v: Any) -> bool:
    return isinstance(v, int) and not isinstance(v, bool)


def _validate_endpoint(device_type: str, endpoint: str) -> str | None:
    try:
        p = urlparse(endpoint)
    except Exception:
        return "endpoint must be a valid URL"

    scheme = (p.scheme or "").lower()

    if device_type == "camera_ip_snapshot":
        if scheme not in {"http", "https"}:
            return "endpoint scheme must be http or https for camera_ip_snapshot"
    elif device_type == "camera_rtsp":
        if scheme != "rtsp":
            return "endpoint scheme must be rtsp for camera_rtsp"

    return None


def validate_device_payload(
    data: Dict[str, Any],
    *,
    mode: str,
) -> ValidationResult:
    """Validate and normalize device payload.

    mode:
      - "create": POST
      - "put": full replacement
      - "patch": partial update

    PUT semantics: unspecified optional fields reset to defaults/null.
    PATCH semantics: unspecified fields unchanged; payload must include at least one field.
    """

    errors: List[str] = []
    cleaned: Dict[str, Any] = {}

    if not isinstance(data, dict):
        return ValidationResult(cleaned={}, errors=["body must be a JSON object"])

    required = {"name", "type", "endpoint"} if mode in {"create", "put"} else set()

    allowed_fields = {
        "name",
        "type",
        "enabled",
        "endpoint",
        "auth_mode",
        "auth_username",
        "auth_password",
        "poll_interval_s",
        "timeout_ms",
        "tags",
        "notes",
        # operational fields are not writable via API in Sprint 2
    }

    unknown = set(data.keys()) - allowed_fields
    if unknown:
        errors.append(f"unknown fields: {sorted(list(unknown))}")

    # PATCH requires at least one recognized field
    if mode == "patch":
        provided = set(data.keys()) & allowed_fields
        if not provided:
            errors.append("patch body must include at least one updatable field")

    # Defaults for create/put
    if mode in {"create", "put"}:
        cleaned["enabled"] = True
        cleaned["auth_mode"] = "none"
        cleaned["auth_username"] = None
        cleaned["auth_password"] = None
        cleaned["poll_interval_s"] = 60
        cleaned["timeout_ms"] = 5000
        cleaned["tags"] = []
        cleaned["notes"] = None

    # Required fields
    for k in required:
        if k not in data:
            errors.append(f"missing required field: {k}")

    # name
    if "name" in data:
        if not isinstance(data["name"], str) or not data["name"].strip():
            errors.append("name must be a non-empty string")
        else:
            cleaned["name"] = data["name"].strip()

    # type
    if "type" in data:
        if not isinstance(data["type"], str) or data["type"] not in ALLOWED_DEVICE_TYPES:
            errors.append(f"type must be one of {sorted(list(ALLOWED_DEVICE_TYPES))}")
        else:
            cleaned["type"] = data["type"]

    # enabled
    if "enabled" in data:
        if not _is_bool(data["enabled"]):
            errors.append("enabled must be boolean")
        else:
            cleaned["enabled"] = bool(data["enabled"])

    # endpoint
    if "endpoint" in data:
        if not isinstance(data["endpoint"], str) or not data["endpoint"].strip():
            errors.append("endpoint must be a non-empty string")
        else:
            cleaned["endpoint"] = data["endpoint"].strip()

    # auth
    if "auth_mode" in data:
        if data["auth_mode"] is None:
            cleaned["auth_mode"] = None
        elif not isinstance(data["auth_mode"], str) or data["auth_mode"] not in ALLOWED_AUTH_MODES:
            errors.append(f"auth_mode must be one of {sorted(list(ALLOWED_AUTH_MODES))} or null")
        else:
            cleaned["auth_mode"] = data["auth_mode"]

    if "auth_username" in data:
        if data["auth_username"] is None:
            cleaned["auth_username"] = None
        elif not isinstance(data["auth_username"], str):
            errors.append("auth_username must be string or null")
        else:
            cleaned["auth_username"] = data["auth_username"]

    if "auth_password" in data:
        if data["auth_password"] is None:
            cleaned["auth_password"] = None
        elif not isinstance(data["auth_password"], str):
            errors.append("auth_password must be string or null")
        else:
            cleaned["auth_password"] = data["auth_password"]

    # poll_interval_s
    if "poll_interval_s" in data:
        v = data["poll_interval_s"]
        if not _is_int(v):
            errors.append("poll_interval_s must be an integer")
        elif v < 1 or v > 3600:
            errors.append("poll_interval_s must be between 1 and 3600")
        else:
            cleaned["poll_interval_s"] = v

    # timeout_ms
    if "timeout_ms" in data:
        v = data["timeout_ms"]
        if not _is_int(v):
            errors.append("timeout_ms must be an integer")
        elif v < 100 or v > 60000:
            errors.append("timeout_ms must be between 100 and 60000")
        else:
            cleaned["timeout_ms"] = v

    # tags
    if "tags" in data:
        v = data["tags"]
        if v is None:
            cleaned["tags"] = []
        elif isinstance(v, list) and all(isinstance(x, str) for x in v):
            cleaned["tags"] = v
        else:
            errors.append("tags must be a list of strings")

    # notes
    if "notes" in data:
        v = data["notes"]
        if v is None:
            cleaned["notes"] = None
        elif not isinstance(v, str):
            errors.append("notes must be a string or null")
        else:
            cleaned["notes"] = v

    # Cross-field: endpoint scheme depends on type
    t = cleaned.get("type") if mode in {"create", "put"} else data.get("type")
    e = cleaned.get("endpoint") if mode in {"create", "put"} else data.get("endpoint")

    if ("type" in data or mode in {"create", "put"}) and ("endpoint" in data or mode in {"create", "put"}):
        # Determine device_type used for validation
        device_type = cleaned.get("type") if "type" in cleaned else data.get("type")
        endpoint = cleaned.get("endpoint") if "endpoint" in cleaned else data.get("endpoint")
        if isinstance(device_type, str) and isinstance(endpoint, str):
            err = _validate_endpoint(device_type, endpoint)
            if err:
                errors.append(err)

    return ValidationResult(cleaned=cleaned, errors=errors)
