from himalia_api import create_app


def test_health_endpoint_includes_db_status():
    app = create_app()
    client = app.test_client()

    resp = client.get("/api/v1/health")
    assert resp.status_code in (200, 503)

    body = resp.get_json()
    assert body["status"] == "ok"
    assert body["db"] in ("ok", "error")
