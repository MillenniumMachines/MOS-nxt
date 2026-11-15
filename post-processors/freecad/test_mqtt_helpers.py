#!/usr/bin/env python3
"""Unit tests for FreeCAD nxt_post MQTT helpers (no FreeCAD runtime required).

Extracts the MQTT helper block from nxt_post.py so we do not need FreeCAD.
"""
from __future__ import annotations

import re
import types
import unittest
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_SRC = (_HERE / "nxt_post.py").read_text(encoding="utf-8")

# Slice from MQTT_M118_MAX through mqtt_tool_publish_line (before Output class).
_start = _SRC.index("MQTT_M118_MAX = 240")
_end = _SRC.index("\n# Define output class.")
_ns: dict = {"re": re, "json": __import__("json"), "os": __import__("os")}
exec(_SRC[_start:_end], _ns)  # noqa: S102 — intentional load of local helpers


class TestMqttJobFileName(unittest.TestCase):
    def test_basename_from_path(self):
        self.assertEqual(
            _ns["mqtt_job_file_name"]("/cam/Golf/Putter/01 Putter - Op1.gcode"),
            "01 Putter - Op1.gcode",
        )

    def test_rejects_pure_numeric(self):
        self.assertEqual(_ns["mqtt_job_file_name"]("8910"), "job.gcode")
        self.assertEqual(_ns["mqtt_job_file_name"]("/tmp/8910"), "job.gcode")
        self.assertEqual(_ns["mqtt_job_file_name"]("/tmp/8910.gcode"), "job.gcode")

    def test_override_wins(self):
        self.assertEqual(
            _ns["mqtt_job_file_name"](
                "/tmp/8910.gcode", override="01 Putter - Op1.gcode"
            ),
            "01 Putter - Op1.gcode",
        )

    def test_empty_falls_back(self):
        self.assertEqual(_ns["mqtt_job_file_name"](""), "job.gcode")
        self.assertEqual(_ns["mqtt_job_file_name"](None), "job.gcode")


class TestMqttToolPublishLine(unittest.TestCase):
    def test_start_and_change_payloads(self):
        args = types.SimpleNamespace(
            mqtt_telemetry=True,
            mqtt_device_id="milo",
            mqtt_broker_host="mqtt.jarvis.lan",
            mqtt_broker_port=1883,
        )
        line0 = _ns["mqtt_tool_publish_line"](
            args, "start", 1, None, "01 Putter - Op1.gcode"
        )
        decoded0 = line0.replace('""', '"')
        self.assertIn('"event":"start"', decoded0)
        self.assertIn("01 Putter - Op1.gcode", line0)
        self.assertIn('T"duet/milo/tool"', line0)

        line1 = _ns["mqtt_tool_publish_line"](
            args, "change", 2, 1, "01 Putter - Op1.gcode"
        )
        decoded1 = line1.replace('""', '"')
        self.assertIn('"event":"change"', decoded1)
        self.assertIn('"previous_tool":1', decoded1)


class TestMqttLooksLikeJobFile(unittest.TestCase):
    def test_numeric_rejected(self):
        self.assertFalse(_ns["mqtt_looks_like_job_file_name"]("8910"))
        self.assertFalse(_ns["mqtt_looks_like_job_file_name"]("8910.gcode"))
        self.assertTrue(_ns["mqtt_looks_like_job_file_name"]("part.gcode"))


if __name__ == "__main__":
    unittest.main()
