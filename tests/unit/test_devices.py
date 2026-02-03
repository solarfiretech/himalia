import os

import pytest

from himalia_api import create_app


@pytest.fixture(autouse=True)
def _set_test_env(monkeypatch, tmp_path):
    # Isolated DB per test
    db_file = tmp_path / "test.sqlite3"
    monkeypatch.setenv("HIMALIA_DB_URL", f"sqlite:///{db_file}")
    # Auth enabled by default
    monkeypatch.setenv("HIMALIA_API_KEY", "test-api-key")
    yield


@pytest.fixture()
def client():
    app = create_app()
    return app.test_client()


def _headers(key="test-api-key"):
    return {"X-API-Key": key}


def test_auth_required_for_devices(client):
    resp = client.get("/api/v1/devices")
    assert resp.status_code == 401

    resp2 = client.get("/api/v1/devices", headers=_headers())
    assert resp2.status_code == 200


def test_create_list_get_delete_device(client):
    payload = {
        "name": "Cam 1",
        "type": "camera_ip_snapshot",
        "endpoint": "http://example.local/snap.jpg",
        "auth_mode": "basic",
        "auth_username": "u",
        "auth_password": "p",
        "poll_interval_s": 30,
        "timeout_ms": 1500,
        "tags": ["line1"],
        "notes": "test",
    }

    create = client.post("/api/v1/devices", json=payload, headers=_headers())
    assert create.status_code == 201
    body = create.get_json()
    assert body["id"]
    assert body["name"] == "Cam 1"
    assert body["has_auth_password"] is True
    assert "auth_password" not in body

    dev_id = body["id"]

    lst = client.get("/api/v1/devices", headers=_headers())
    assert lst.status_code == 200
    lst_body = lst.get_json()
    assert lst_body["count"] == 1

    get = client.get(f"/api/v1/devices/{dev_id}", headers=_headers())
    assert get.status_code == 200

    delete = client.delete(f"/api/v1/devices/{dev_id}", headers=_headers())
    assert delete.status_code == 204


def test_put_resets_optional_fields(client):
    # Create with non-default optionals
    create = client.post(
        "/api/v1/devices",
        json={
            "name": "Cam 2",
            "type": "camera_ip_snapshot",
            "endpoint": "https://example.local/snap.jpg",
            "enabled": False,
            "auth_mode": "basic",
            "auth_username": "u",
            "auth_password": "p",
            "poll_interval_s": 10,
            "timeout_ms": 6000,
            "tags": ["a", "b"],
            "notes": "hello",
        },
        headers=_headers(),
    )
    dev_id = create.get_json()["id"]

    # PUT with only required fields should reset optional fields to defaults/null
    put = client.put(
        f"/api/v1/devices/{dev_id}",
        json={
            "name": "Cam 2 new",
            "type": "camera_ip_snapshot",
            "endpoint": "https://example.local/snap2.jpg",
        },
        headers=_headers(),
    )
    assert put.status_code == 200
    body = put.get_json()

    assert body["name"] == "Cam 2 new"
    assert body["enabled"] is True
    assert body["auth_mode"] == "none"
    assert body["auth_username"] is None
    assert body["has_auth_password"] is False
    assert body["poll_interval_s"] == 60
    assert body["timeout_ms"] == 5000
    assert body["tags"] == []
    assert body["notes"] is None


def test_patch_updates_only_specified_fields(client):
    create = client.post(
        "/api/v1/devices",
        json={
            "name": "Cam 3",
            "type": "camera_ip_snapshot",
            "endpoint": "http://example.local/snap.jpg",
        },
        headers=_headers(),
    )
    dev_id = create.get_json()["id"]

    patch = client.patch(
        f"/api/v1/devices/{dev_id}",
        json={"enabled": False, "poll_interval_s": 120},
        headers=_headers(),
    )
    assert patch.status_code == 200
    body = patch.get_json()
    assert body["enabled"] is False
    assert body["poll_interval_s"] == 120
    assert body["timeout_ms"] == 5000
