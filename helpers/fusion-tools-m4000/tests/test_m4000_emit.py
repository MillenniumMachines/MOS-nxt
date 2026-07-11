from __future__ import annotations

import unittest

from fusion_tools_m4000.m4000_emit import (
    EmitOptions,
    build_gcode_document,
    build_m4000_line,
)


def _tool(
    pocket: int,
    *,
    desc: str = "Test Tool",
    tool_type: str = "flat end mill",
    dc: float = 6,
    **geometry_extra: float | int | bool,
) -> dict:
    geom: dict = {"DC": dc, **geometry_extra}
    return {
        "post-process": {"number": pocket},
        "description": desc,
        "type": tool_type,
        "geometry": geom,
    }


class TestBuildM4000Line(unittest.TestCase):
    def test_flutes_only_nof_and_lcf(self) -> None:
        _, ln = build_m4000_line(
            _tool(1, NOF=3, LCF=18),
            enrich_description=False,
            bull_nose_mode="corner",
        )
        self.assertEqual(ln, 'M4000 P1 R3 F3 L18 S"Test Tool"')

    def test_only_f_present(self) -> None:
        _, ln = build_m4000_line(
            _tool(2, NOF=2),
            enrich_description=False,
            bull_nose_mode="corner",
        )
        self.assertEqual(ln, 'M4000 P2 R3 F2 S"Test Tool"')
        self.assertNotIn(" L", ln)

    def test_only_l_present(self) -> None:
        _, ln = build_m4000_line(
            _tool(3, LCF=12.25),
            enrich_description=False,
            bull_nose_mode="corner",
        )
        self.assertEqual(ln, 'M4000 P3 R3 L12.25 S"Test Tool"')
        self.assertNotRegex(ln, r" F\d")

    def test_neither_when_missing_geometry(self) -> None:
        _, ln = build_m4000_line(
            _tool(49, desc="Touch Probe"),
            enrich_description=False,
            bull_nose_mode="corner",
        )
        self.assertEqual(ln, 'M4000 P49 R3 S"Touch Probe"')

    def test_nof_integer_float_accepted(self) -> None:
        _, ln = build_m4000_line(
            _tool(5, NOF=4.0),
            enrich_description=False,
            bull_nose_mode="corner",
        )
        self.assertEqual(ln, 'M4000 P5 R3 F4 S"Test Tool"')

    def test_nof_skipped_when_bool(self) -> None:
        _, ln = build_m4000_line(
            _tool(6, NOF=False, LCF=10),
            enrich_description=False,
            bull_nose_mode="corner",
        )
        self.assertEqual(ln, 'M4000 P6 R3 L10 S"Test Tool"')

    def test_nof_non_integer_float_skipped(self) -> None:
        _, ln = build_m4000_line(
            _tool(7, NOF=2.5),
            enrich_description=False,
            bull_nose_mode="corner",
        )
        self.assertNotIn(" F", ln.split(" S")[0])

    def test_enrichment_cr_only_no_f_equals_in_description(self) -> None:
        _, ln = build_m4000_line(
            _tool(8, NOF=2, LCF=21.5, RE=0),
            enrich_description=True,
            bull_nose_mode="corner",
        )
        self.assertIn('S"Test Tool CR=0"', ln)
        self.assertNotIn("F=", ln)

    def test_manual_tool_change_emits_c0(self) -> None:
        rec = _tool(3)
        rec["post-process"] = {"number": 3, "manual-tool-change": True}
        _, ln = build_m4000_line(
            rec,
            enrich_description=False,
            bull_nose_mode="corner",
        )
        self.assertIn(" C0", ln)

    def test_hand_load_all_flag(self) -> None:
        _, ln = build_m4000_line(
            _tool(4),
            enrich_description=False,
            bull_nose_mode="corner",
            hand_load_all=True,
        )
        self.assertIn(" C0", ln)


class TestBuildGcodeDocument(unittest.TestCase):
    def test_document_multiple_pockets_ordered(self) -> None:
        body = build_gcode_document(
            [
                _tool(2, NOF=1),
                _tool(1, LCF=5),
            ],
            options=EmitOptions(),
        )
        rows = [r for r in body.splitlines() if r.startswith("M4000 ")]
        self.assertTrue(rows[0].startswith("M4000 P1 R3 L5 "))
        self.assertTrue(rows[1].startswith("M4000 P2 R3 F1 "))


if __name__ == "__main__":
    unittest.main()
