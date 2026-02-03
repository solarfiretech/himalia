import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    """Runtime configuration.

    Contract defaults:
      - Persistent DB path: /data/db/himalia.sqlite3
      - API auth is enabled when HIMALIA_API_KEY is set (non-empty)
    """

    api_key: str
    db_url: str
    openapi_enabled: bool

    @property
    def auth_enabled(self) -> bool:
        return bool(self.api_key)


def load_settings() -> Settings:
    api_key = os.getenv("HIMALIA_API_KEY", "change-me").strip()

    # SQLite path per spec: /data/db/himalia.sqlite3
    db_url = os.getenv("HIMALIA_DB_URL", "sqlite:////data/db/himalia.sqlite3").strip()

    openapi_enabled = os.getenv("HIMALIA_OPENAPI_ENABLED", "true").strip().lower() not in {
        "0",
        "false",
        "no",
    }

    return Settings(
        api_key=api_key,
        db_url=db_url,
        openapi_enabled=openapi_enabled,
    )
