from __future__ import annotations

import os
from pathlib import Path


def upgrade_head(db_url: str) -> None:
    """Run alembic upgrade head.

    This is intentionally safe for dev/test startup. In production, migrations are
    also run in /etc/cont-init.d/15-db-migrate.
    """

    # Avoid accidental network DB migrations; Himalia currently targets SQLite.
    if not db_url.startswith("sqlite:"):
        raise RuntimeError(f"Refusing to auto-migrate non-sqlite DB URL: {db_url}")

    try:
        from alembic import command
        from alembic.config import Config
    except Exception as e:
        raise RuntimeError("alembic is not installed") from e

    app_dir = Path(__file__).resolve().parent.parent  # .../app
    cfg_path = app_dir / "alembic.ini"
    if not cfg_path.exists():
        raise RuntimeError(f"Missing alembic.ini at {cfg_path}")

    cfg = Config(str(cfg_path))

    # Ensure alembic uses the provided DB URL
    os.environ["HIMALIA_DB_URL"] = db_url

    command.upgrade(cfg, "head")
