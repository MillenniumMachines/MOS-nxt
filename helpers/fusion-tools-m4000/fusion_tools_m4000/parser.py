from __future__ import annotations

import json
import zipfile
from pathlib import Path


def load_fusion_tools_archive(path: Path) -> list[dict]:
    """
    Read an Autodesk Fusion `.tools` file (ZIP with `tools.json`).
    Returns the `data` array of tool records.
    """
    path = path.expanduser().resolve()
    if not path.is_file():
        raise FileNotFoundError(path)

    with zipfile.ZipFile(path) as zf:
        names = zf.namelist()
        if "tools.json" not in names:
            raise ValueError(
                f"Expected tools.json inside {path}; got {names!r}"
            )
        raw = zf.read("tools.json")

    doc = json.loads(raw.decode("utf-8"))
    if not isinstance(doc, dict):
        raise ValueError("tools.json root must be an object")
    data = doc.get("data")
    if not isinstance(data, list):
        raise ValueError("tools.json must contain a 'data' array")
    return data
