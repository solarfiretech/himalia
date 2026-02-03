from __future__ import annotations

import os

from flask import Flask, jsonify, request, g
from flask_cors import CORS

from .config import load_settings
from .db import init_db, get_session, ping_db
from .openapi import build_openapi
from .migrate import upgrade_head


def create_app() -> Flask:
    settings = load_settings()

    app = Flask(__name__)
    CORS(app)

    # Initialize DB engine/session factory
    init_db(settings)

    # Auto-migrate schema on startup for dev/test.
    # This is idempotent for SQLite and keeps local runs simple.
    if os.getenv("HIMALIA_MIGRATIONS_ON_STARTUP", "true").strip().lower() not in {"0", "false", "no"}:
        try:
            upgrade_head(settings.db_url)
        except Exception as e:
            # Do not prevent app start; health will show DB error if schema is unusable.
            app.logger.warning(f"DB migration step failed: {e}")

    # ---------------------------
    # Request lifecycle
    # ---------------------------
    @app.before_request
    def _auth_guard_and_db_session():
        # DB session per request
        g.db = get_session()

        # Auth
        if request.path.startswith("/api/v1/"):
            if request.path in {"/api/v1/health", "/api/v1/openapi.json"}:
                return None

            if settings.auth_enabled:
                provided = request.headers.get("X-API-Key", "")
                if provided != settings.api_key:
                    return jsonify({"error": "unauthorized"}), 401

        return None

    @app.teardown_request
    def _close_db_session(exc):
        db = getattr(g, "db", None)
        if db is not None:
            try:
                if exc is not None:
                    db.rollback()
            finally:
                db.close()

    # ---------------------------
    # Routes
    # ---------------------------
    @app.get("/api/v1/health")
    def health():
        db_ok = ping_db()
        status = 200 if db_ok else 503
        return {"status": "ok", "db": "ok" if db_ok else "error"}, status

    if settings.openapi_enabled:
        @app.get("/api/v1/openapi.json")
        def openapi():
            return build_openapi(), 200

    from .routes.devices import bp as devices_bp

    app.register_blueprint(devices_bp)

    # JSON 404
    @app.errorhandler(404)
    def _not_found(_):
        return {"error": "not_found"}, 404

    return app
