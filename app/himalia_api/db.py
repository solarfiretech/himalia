from __future__ import annotations

from contextlib import contextmanager
from typing import Iterator, Optional

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from sqlalchemy.orm import sessionmaker, Session

from .config import Settings


_engine: Optional[Engine] = None
_SessionLocal: Optional[sessionmaker] = None


def init_db(settings: Settings) -> None:
    """Initialize global SQLAlchemy engine/session factory."""
    global _engine, _SessionLocal

    connect_args = {}
    if settings.db_url.startswith("sqlite:"):
        # Needed for multithreaded Flask dev server access.
        connect_args = {"check_same_thread": False}

    _engine = create_engine(
        settings.db_url,
        future=True,
        pool_pre_ping=True,
        connect_args=connect_args,
    )
    _SessionLocal = sessionmaker(bind=_engine, autoflush=False, autocommit=False, future=True)


def get_engine() -> Engine:
    if _engine is None:
        raise RuntimeError("DB engine not initialized")
    return _engine


def get_session() -> Session:
    if _SessionLocal is None:
        raise RuntimeError("DB session factory not initialized")
    return _SessionLocal()


@contextmanager
def session_scope() -> Iterator[Session]:
    """Provide a transactional scope around a series of operations."""
    session = get_session()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def ping_db() -> bool:
    """Lightweight connectivity check."""
    try:
        engine = get_engine()
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
