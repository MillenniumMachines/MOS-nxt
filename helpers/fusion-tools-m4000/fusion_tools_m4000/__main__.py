from __future__ import annotations

import argparse
import sys
import warnings
from pathlib import Path

from fusion_tools_m4000.m4000_emit import EmitOptions, build_gcode_document
from fusion_tools_m4000.parser import load_fusion_tools_archive


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Convert Fusion 360 .tools export to nxt M4000 lines.",
    )
    parser.add_argument(
        "tools_file",
        type=Path,
        help="Path to exported Fusion .tools file (ZIP with tools.json)",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=str,
        default="tool_load.g",
        help='Output path (default: tool_load.g); use "-" for stdout',
    )
    parser.add_argument(
        "--wrap-load-depth",
        action="store_true",
        help="Wrap output with nxtUserToolsLoadDepth block (nxt nxt-user-tools.g)",
    )
    parser.add_argument(
        "--enrich-description",
        action="store_true",
        help='Append CR= fragment inside S"..." when geometry.RE exists',
    )
    parser.add_argument(
        "--bull-nose-radius",
        choices=("corner", "diameter"),
        default="corner",
        help="For bull nose tools: use geometry.RE (corner) or DC/2 (diameter)",
    )
    parser.add_argument(
        "--hand-load-all",
        action="store_true",
        help="Emit C0 on every tool (hand-load / no ATC)",
    )
    parser.add_argument(
        "--mark-atc-capable",
        action="store_true",
        help="Emit C1 on every tool (ATC-capable)",
    )

    args = parser.parse_args(argv)

    warnings.simplefilter("default", UserWarning)

    tools = load_fusion_tools_archive(args.tools_file)
    opts = EmitOptions(
        wrap_load_depth=args.wrap_load_depth,
        enrich_description=args.enrich_description,
        bull_nose_mode=args.bull_nose_radius,
        hand_load_all=args.hand_load_all,
        mark_atc_capable=args.mark_atc_capable,
    )
    body = build_gcode_document(tools, options=opts)

    if args.output == "-":
        sys.stdout.write(body)
        return 0

    out_path = Path(args.output).expanduser()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(body, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
