from __future__ import annotations

import unittest
from pathlib import Path

from fusion_tools_m4000.m4000_emit import EmitOptions, build_gcode_document
from fusion_tools_m4000.parser import load_fusion_tools_archive


def _core_milo_tools_path() -> Path | None:
    """Sibling repo layout: …/Milo-Code/fusion-tools-m4000/tests → Milo-Parts next to Milo-Code."""
    milo_code = Path(__file__).resolve().parents[2]
    candidate = (
        milo_code.parent
        / "Milo-Parts"
        / "Tooling"
        / "Fusion"
        / "Core Milo Tooling.tools"
    )
    return candidate if candidate.is_file() else None


class TestCoreMiloGolden(unittest.TestCase):
    def test_m4000_line_count_and_probe(self) -> None:
        path = _core_milo_tools_path()
        if path is None:
            self.skipTest("Core Milo Tooling.tools not found beside Milo-Code checkout")

        tools = load_fusion_tools_archive(path)
        body = build_gcode_document(tools, options=EmitOptions())
        lines = [ln for ln in body.splitlines() if ln.startswith("M4000 ")]
        self.assertEqual(len(lines), 19)
        probe = [ln for ln in lines if ln.startswith("M4000 P49 ")]
        self.assertEqual(len(probe), 1)
        self.assertIn('S"Touch Probe"', probe[0])
        self.assertIn("R1 ", probe[0])

    def test_bull_nose_corner_vs_diameter(self) -> None:
        path = _core_milo_tools_path()
        if path is None:
            self.skipTest("Core Milo Tooling.tools not found beside Milo-Code checkout")

        tools = load_fusion_tools_archive(path)
        corner = build_gcode_document(tools, options=EmitOptions())
        dia = build_gcode_document(
            tools, options=EmitOptions(bull_nose_mode="diameter")
        )
        self.assertIn("M4000 P7 R0.75 ", corner)
        self.assertIn("M4000 P7 R5 ", dia)


if __name__ == "__main__":
    unittest.main()
