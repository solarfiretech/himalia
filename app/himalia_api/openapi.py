from __future__ import annotations


def build_openapi() -> dict:
    # Minimal draft; expand as endpoints are added.
    return {
        "openapi": "3.0.3",
        "info": {
            "title": "Himalia API",
            "version": "0.0.2",
        },
        "paths": {
            "/api/v1/health": {
                "get": {
                    "summary": "Health check",
                    "responses": {"200": {"description": "OK"}},
                }
            },
            "/api/v1/devices": {
                "get": {"summary": "List devices", "responses": {"200": {"description": "OK"}}},
                "post": {"summary": "Create device", "responses": {"201": {"description": "Created"}}},
            },
            "/api/v1/devices/{id}": {
                "get": {"summary": "Get device", "responses": {"200": {"description": "OK"}, "404": {"description": "Not found"}}},
                "put": {"summary": "Replace device", "responses": {"200": {"description": "OK"}}},
                "patch": {"summary": "Update device", "responses": {"200": {"description": "OK"}}},
                "delete": {"summary": "Delete device", "responses": {"204": {"description": "No content"}}},
            },
        },
    }
