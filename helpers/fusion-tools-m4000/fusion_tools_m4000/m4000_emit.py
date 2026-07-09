from __future__ import annotations

import math
import warnings
from dataclasses import dataclass
from typing import Literal

# Matches ui/src/utils/nxtUserToolsFile.ts (nxt-user-tools-sync.g)
NXT_USER_TOOLS_LOAD_DEPTH_OPEN = [
    "if { !exists(global.nxtUserToolsLoadDepth) }",
    "    global nxtUserToolsLoadDepth = 0",
    "set global.nxtUserToolsLoadDepth = { global.nxtUserToolsLoadDepth + 1 }",
    "",
]

NXT_USER_TOOLS_LOAD_DEPTH_CLOSE = [
    "set global.nxtUserToolsLoadDepth = { global.nxtUserToolsLoadDepth - 1 }",
    "",
]


def fmt_axis(n: float) -> str:
    """Format a numeric axis/param like nxt `fmtAxis`."""
    if not math.isfinite(n):
        return "0"
    s = f"{n:.6f}".rstrip("0").rstrip(".")
    if s in ("", "-0"):
        return "0"
    return s


def sanitize_m4000_description(raw: str, tool_index: int) -> str:
    """M4000 S\"...\" — avoid raw double quotes inside the string."""
    s = raw.strip()
    if not s:
        s = f"T{tool_index}"
    return s.replace('"', "'")


def _geometry(tool: dict) -> dict:
    g = tool.get("geometry")
    return g if isinstance(g, dict) else {}


def _post_process(tool: dict) -> dict:
    pp = tool.get("post-process")
    return pp if isinstance(pp, dict) else {}


def _tc_capable_from_post_process(
    pp: dict,
    *,
    hand_load_all: bool,
    mark_atc_capable: bool,
) -> int | None:
    """Return 0, 1, or None (omit C — firmware default is 1)."""
    if hand_load_all:
        return 0
    if mark_atc_capable:
        return 1
    if pp.get("manual-tool-change") is True:
        return 0
    return None


def _pocket_number(pp: dict) -> int | None:
    p_raw = pp.get("number")
    if isinstance(p_raw, bool):
        return None
    if isinstance(p_raw, int):
        return p_raw
    if isinstance(p_raw, float) and math.isfinite(p_raw) and p_raw.is_integer():
        return int(p_raw)
    return None


BullNoseRadiusMode = Literal["corner", "diameter"]


def compute_cam_radius(
    tool_type: str | None,
    geometry: dict,
    *,
    bull_nose_mode: BullNoseRadiusMode,
) -> float:
    """Compute M4000 R (CAM radius in mm) from Fusion geometry."""
    dc = geometry.get("DC")
    diameter = float(dc) if isinstance(dc, (int, float)) and math.isfinite(dc) else None

    t = (tool_type or "").strip().lower()

    if t == "bull nose end mill":
        re_val = geometry.get("RE")
        re = (
            float(re_val)
            if isinstance(re_val, (int, float)) and math.isfinite(re_val)
            else None
        )
        if bull_nose_mode == "diameter":
            return (diameter / 2.0) if diameter is not None else 0.0
        if re is not None and re > 0:
            return re
        return (diameter / 2.0) if diameter is not None else 0.0

    if diameter is None:
        return 0.0
    return diameter / 2.0


def optional_nof(geometry: dict) -> int | None:
    """Fusion geometry.NOF (number of flutes), or None if absent/invalid."""
    nof = geometry.get("NOF")
    if isinstance(nof, bool):
        return None
    if isinstance(nof, int):
        return nof
    if isinstance(nof, float) and math.isfinite(nof) and nof.is_integer():
        return int(nof)
    return None


def optional_lcf_mm(geometry: dict) -> float | None:
    """Fusion geometry.LCF (flute length mm), or None if absent/invalid."""
    lcf = geometry.get("LCF")
    if isinstance(lcf, (int, float)) and math.isfinite(lcf):
        return float(lcf)
    return None


def enrichment_suffix(geometry: dict) -> str:
    """Append ` CR=…` inside S\"...\" when geometry.RE exists (flutes use M4000 F/L)."""
    parts: list[str] = []

    re_val = geometry.get("RE")
    if isinstance(re_val, (int, float)) and math.isfinite(re_val):
        parts.append(f"CR={fmt_axis(float(re_val))}")

    if not parts:
        return ""
    return " " + " ".join(parts)


def build_m4000_line(
    tool: dict,
    *,
    enrich_description: bool,
    bull_nose_mode: BullNoseRadiusMode,
    hand_load_all: bool = False,
    mark_atc_capable: bool = False,
) -> tuple[int, str]:
    """
    Returns (P, line). Raises ValueError if pocket number is missing.
    """
    pp = _post_process(tool)
    p = _pocket_number(pp)
    if p is None:
        raise ValueError("post-process.number must be an integer")

    geom = _geometry(tool)
    tool_type = tool.get("type")
    t_str = tool_type if isinstance(tool_type, str) else None

    if not t_str:
        warnings.warn(f"Tool P{p}: missing type; using diameter/2 for R", UserWarning)

    r = compute_cam_radius(t_str, geom, bull_nose_mode=bull_nose_mode)

    dc = geom.get("DC")
    if not isinstance(dc, (int, float)) or not math.isfinite(dc):
        warnings.warn(
            f"Tool P{p}: missing or invalid geometry.DC; R may be 0",
            UserWarning,
        )

    desc_raw = tool.get("description")
    desc = desc_raw if isinstance(desc_raw, str) else ""
    desc = sanitize_m4000_description(desc, p)
    if enrich_description:
        desc = desc + enrichment_suffix(geom)

    mid = f"M4000 P{p} R{fmt_axis(r)}"
    n_fl = optional_nof(geom)
    if n_fl is not None:
        mid += f" F{n_fl}"
    lf = optional_lcf_mm(geom)
    if lf is not None:
        mid += f" L{fmt_axis(lf)}"
    tc = _tc_capable_from_post_process(
        pp,
        hand_load_all=hand_load_all,
        mark_atc_capable=mark_atc_capable,
    )
    if tc == 0:
        mid += " C0"
    elif tc == 1:
        mid += " C1"
    line = mid + f' S"{desc}"'
    return p, line


@dataclass(frozen=True)
class EmitOptions:
    wrap_load_depth: bool = False
    enrich_description: bool = False
    bull_nose_mode: BullNoseRadiusMode = "corner"
    hand_load_all: bool = False
    mark_atc_capable: bool = False


def build_gcode_document(
    tools: list[dict],
    *,
    options: EmitOptions,
    header_comment: str = "; Generated by fusion_tools_m4000 — Fusion library → M4000",
) -> str:
    """Full file body (trailing newline)."""
    lines: list[str] = [header_comment, ""]

    if options.wrap_load_depth:
        lines.extend(NXT_USER_TOOLS_LOAD_DEPTH_OPEN)

    by_pocket: dict[int, str] = {}
    for rec in tools:
        if not isinstance(rec, dict):
            warnings.warn("Skipping non-object entry in tools.json data[]", UserWarning)
            continue
        try:
            p, m4000 = build_m4000_line(
                rec,
                enrich_description=options.enrich_description,
                bull_nose_mode=options.bull_nose_mode,
                hand_load_all=options.hand_load_all,
                mark_atc_capable=options.mark_atc_capable,
            )
        except ValueError as e:
            warnings.warn(f"Skipping tool: {e}", UserWarning)
            continue
        if p in by_pocket:
            warnings.warn(
                f"Duplicate pocket P{p}; keeping first Fusion entry only", UserWarning
            )
            continue
        by_pocket[p] = m4000

    for p in sorted(by_pocket):
        lines.append(by_pocket[p])

    if options.wrap_load_depth:
        lines.append("")
        lines.extend(NXT_USER_TOOLS_LOAD_DEPTH_CLOSE)

    text = "\n".join(lines)
    if not text.endswith("\n"):
        text += "\n"
    return text
