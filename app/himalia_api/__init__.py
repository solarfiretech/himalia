from flask import Flask
from flask_cors import CORS

def create_app() -> Flask:
    app = Flask(__name__)
    CORS(app)

    @app.get("/api/v1/health")
    def health():
        return {"status": "ok"}, 200

    return app
