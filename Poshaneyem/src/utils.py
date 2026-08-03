import json
from pathlib import Path
from typing import Any

import numpy as np
import joblib


def ensure_dir(path: Path) -> Path:
    """Create a directory if it does not exist."""
    path.mkdir(parents=True, exist_ok=True)
    return path


def save_json(path: Path, data: Any) -> None:
    """Save Python data as JSON."""
    ensure_dir(path.parent)
    with path.open("w", encoding="utf-8") as handler:
        json.dump(data, handler, indent=2)


def load_json(path: Path) -> Any:
    """Load JSON data from disk."""
    with path.open("r", encoding="utf-8") as handler:
        return json.load(handler)


def save_joblib(path: Path, obj: Any) -> None:
    """Save a Python object with joblib."""
    ensure_dir(path.parent)
    joblib.dump(obj, path)


def load_joblib(path: Path) -> Any:
    """Load a joblib object from disk."""
    return joblib.load(path)


def normalize_path(value: str) -> str:
    """Normalize a filesystem path string to the local OS format."""
    return str(Path(value).expanduser().resolve())


def to_numpy(array) -> np.ndarray:
    """Convert array-like values to NumPy arrays."""
    return np.asarray(array)
