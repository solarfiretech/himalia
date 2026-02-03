import os
import sys
from pathlib import Path

# Ensure ./app is on sys.path so `import himalia_api` works when running pytest from repo root.
REPO_ROOT = Path(__file__).resolve().parent.parent
APP_DIR = REPO_ROOT / "app"
if str(APP_DIR) not in sys.path:
    sys.path.insert(0, str(APP_DIR))
