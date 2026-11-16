#!/usr/bin/env python3
"""Tests for the MQTT tool telemetry in nxt_machine_post.py, without FreeCAD.

FreeCAD's modules are replaced with small stubs so the post imports under plain
python3. That covers the payload helpers and the tool-change and per-file event
logic. Run: python3 post-processors/freecad/test_mqtt_helpers.py
"""
from __future__ import annotations

import importlib.util
import sys
import types
import unittest
from pathlib import Path as FsPath

_HERE = FsPath(__file__).resolve().parent


# ----------------------------------------------------------------------
# FreeCAD stubs, just enough for nxt_machine_post.py to import.
# ----------------------------------------------------------------------
class _StubPostProcessor:
    def __init__(self, job=None, **_kwargs):
        self._job = job
        self.values = {}

    def _convert_start_section(self, section_name, sublist):
        pass

    def _convert_tool_change(self, command):
        return "M6"

    def get_file_extension(self):
        return self.values.get("FILE_EXTENSION", "gcode")


class _StubFilenameGenerator:
    """Mimics FreeCAD's FilenameGenerator: <template>[-<subpart>][-<n>].<ext>."""

    template = "/cam/out/Part"
    fail = False

    def __init__(self, job, file_extension=None):
        if self.fail:
            raise RuntimeError("no active document")
        self.extension = f".{file_extension}"
        self.subpartname = ""

    def set_subpartname(self, name):
        self.subpartname = name

    def generate_filenames(self):
        sequence = 0
        while True:
            subpart = f"-{self.subpartname}" if self.subpartname else ""
            number = f"-{sequence}" if sequence else ""
            yield f"{self.template}{subpart}{number}{self.extension}"
            sequence += 1


def _stub_module(name, **attrs):
    module = types.ModuleType(name)
    module.__dict__.update(attrs)
    sys.modules[name] = module
    return module


_log = types.SimpleNamespace(debug=lambda *a: None, error=lambda *a: None, warning=lambda *a: None)
_stub_module("FreeCAD", Qt=types.SimpleNamespace(translate=lambda _ctx, text: text))
_stub_module("Path", Log=_log)
_stub_module("Path.Post")
_stub_module("Path.Post.Processor", PostProcessor=_StubPostProcessor)
_stub_module("Path.Post.Utils", FilenameGenerator=_StubFilenameGenerator)
_stub_module("Constants")

_spec = importlib.util.spec_from_file_location("nxt_machine_post", _HERE / "nxt_machine_post.py")
post = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(post)


def _decode(line):
    """The payload of an M118 line with RRF's doubled quotes undone."""
    return line.split(' S"', 1)[1].rsplit('" T"', 1)[0].replace('""', '"')


# ----------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------
class TestJobFileName(unittest.TestCase):
    def test_basename_from_path(self):
        self.assertEqual(
            post.mqtt_job_file_name("/cam/Golf/Putter/01 Putter - Op1.gcode"),
            "01 Putter - Op1.gcode",
        )
        self.assertEqual(post.mqtt_job_file_name(r"C:\cam\part.gcode"), "part.gcode")

    def test_first_usable_candidate_wins(self):
        self.assertEqual(
            post.mqtt_job_file_name("Op1.gcode", "/tmp/part.gcode"), "Op1.gcode"
        )
        self.assertEqual(
            post.mqtt_job_file_name("", "/tmp/8910.gcode", "Part.gcode"), "Part.gcode"
        )

    def test_unusable_names_fall_back(self):
        for name in ("8910", "/tmp/8910", "/tmp/8910.gcode", "-", "", None):
            with self.subTest(name=name):
                self.assertEqual(post.mqtt_job_file_name(name), "job.gcode")

    def test_unsafe_characters_dropped_and_length_capped(self):
        self.assertEqual(post.mqtt_job_file_name('pa"rt{1}.gcode'), "part1.gcode")
        self.assertEqual(len(post.mqtt_job_file_name("a" * 100 + ".gcode")), 64)


class TestConnectLines(unittest.TestCase):
    def test_waits_are_seconds_and_values_quoted(self):
        lines = post.mqtt_connect_lines("milo", "mqtt.lan", 1883)
        self.assertEqual(
            lines[1:],
            ["G4 S2", 'M586.4 C"milo"', 'M586 P4 H"mqtt.lan" R1883 S1', "G4 S3"],
        )

    def test_comment_has_no_nested_parentheses(self):
        comment = post.mqtt_connect_lines("milo", "mqtt.lan", 1883)[0]
        self.assertEqual((comment.count("("), comment.count(")")), (1, 1))
        self.assertTrue(comment.startswith("(") and comment.endswith(")"))

    def test_host_cannot_break_out_of_quotes(self):
        self.assertEqual(post.mqtt_sanitize_host(' mqtt"; M112 '), "mqttM112")
        self.assertEqual(post.mqtt_sanitize_host("192.168.1.5"), "192.168.1.5")


class TestPublishLine(unittest.TestCase):
    def test_start_has_no_previous_tool(self):
        line = post.mqtt_tool_publish_line("milo", "start", 1, None, "part.gcode")
        self.assertEqual(
            _decode(line), '{"event":"start","tool_number":1,"job_file":"part.gcode"}'
        )
        self.assertTrue(line.startswith('M118 P6 S"'))
        self.assertTrue(line.endswith(' T"duet/milo/tool"'))

    def test_change_has_previous_tool(self):
        line = post.mqtt_tool_publish_line("milo", "change", 2, 1, "part.gcode")
        self.assertIn('"previous_tool":1', _decode(line))

    def test_long_job_file_is_compacted_under_limit(self):
        line = post.mqtt_tool_publish_line("milo", "change", 2, 1, "x" * 400)
        self.assertLessEqual(len(line), post.MQTT_M118_MAX)
        self.assertIn('"previous_tool":1', _decode(line))

    def test_oversized_device_id_raises(self):
        with self.assertRaises(ValueError):
            post.mqtt_tool_publish_line("d" * 300, "start", 1)


# ----------------------------------------------------------------------
# Post behaviour
# ----------------------------------------------------------------------
class _Command:
    def __init__(self, tool):
        self.Parameters = {"T": float(tool)}


def _make_post(**values):
    job = types.SimpleNamespace(Document=types.SimpleNamespace(Label="Bracket"))
    pp = post.NxtMachine(job)
    pp.machine_state = types.SimpleNamespace(Tracked=[])
    pp.values = {
        "FILE_EXTENSION": "gcode",
        "MQTT_TELEMETRY": True,
        "MQTT_DEVICE_ID": "milo",
        "MQTT_BROKER_HOST": "mqtt.lan",
        "MQTT_BROKER_PORT": 1883,
        "MQTT_JOB_FILE": "",
    }
    pp.values.update(values)
    return pp


class TestToolChange(unittest.TestCase):
    def setUp(self):
        _StubFilenameGenerator.template = "/cam/out/Part"
        _StubFilenameGenerator.fail = False

    def test_disabled_emits_bare_t(self):
        pp = _make_post(MQTT_TELEMETRY=False)
        pp._convert_start_section("allitems", [])
        self.assertEqual(pp._convert_tool_change(_Command(5)), "T5")

    def test_start_then_change_then_repeat(self):
        pp = _make_post()
        pp._convert_start_section("allitems", [])

        first = pp._convert_tool_change(_Command(5)).split("\n")
        self.assertEqual(first[:2], ["T5", "(MQTT: publish tool change)"])
        self.assertEqual(
            _decode(first[2]), '{"event":"start","tool_number":5,"job_file":"Part.gcode"}'
        )

        second = pp._convert_tool_change(_Command(3)).split("\n")
        self.assertEqual(
            _decode(second[2]),
            '{"event":"change","tool_number":3,"previous_tool":5,"job_file":"Part.gcode"}',
        )

        # Same number again: RRF does nothing, so nothing is published.
        self.assertEqual(pp._convert_tool_change(_Command(3)), "T3")

    def test_each_output_file_starts_again(self):
        pp = _make_post()
        pp._convert_start_section("T5", [])
        self.assertIn('"event":"start"', _decode(pp._convert_tool_change(_Command(5))))
        self.assertEqual(pp._mqtt_job_file, "Part-T5.gcode")

        pp._convert_start_section("T3", [])
        line = pp._convert_tool_change(_Command(3)).split("\n")[2]
        self.assertIn('"event":"start"', _decode(line))
        self.assertNotIn("previous_tool", _decode(line))
        self.assertEqual(pp._mqtt_job_file, "Part-T3-1.gcode")

    def test_job_file_override_wins(self):
        pp = _make_post(MQTT_JOB_FILE="01 Putter - Op1.gcode")
        pp._convert_start_section("allitems", [])
        self.assertEqual(pp._mqtt_job_file, "01 Putter - Op1.gcode")

    def test_numeric_output_name_falls_back_to_document(self):
        _StubFilenameGenerator.template = "/cam/out/8910"
        pp = _make_post()
        pp._convert_start_section("allitems", [])
        self.assertEqual(pp._mqtt_job_file, "Bracket.gcode")

    def test_unknown_output_name_falls_back_to_document(self):
        _StubFilenameGenerator.fail = True
        pp = _make_post()
        pp._convert_start_section("allitems", [])
        self.assertEqual(pp._mqtt_job_file, "Bracket.gcode")

    def test_missing_settings_raise(self):
        for missing in ("MQTT_DEVICE_ID", "MQTT_BROKER_HOST"):
            with self.subTest(missing=missing):
                pp = _make_post(**{missing: ""})
                with self.assertRaises(ValueError):
                    pp._mqtt_settings()


if __name__ == "__main__":
    unittest.main()
