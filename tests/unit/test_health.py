from himalia_api import create_app

def test_health_endpoint():
    app = create_app()
    client = app.test_client()
    resp = client.get("/api/v1/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ok"
