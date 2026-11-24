#!/usr/bin/env python3
"""Tests for nxt_machine_post.py that run without FreeCAD.

FreeCAD's modules are replaced with small stubs so the post imports under plain
python3. Covers the MQTT tool telemetry (payload helpers, tool-change and
per-file event logic) and the tool-number check.
Run: python3 post-processors/freecad/test_nxt_machine.py

Do not name this file *_post.py: FreeCAD imports every such file on its post
search path as a post processor, and these stubs would replace FreeCAD's modules.
"""
from __future__ import annotations

import importlib.util
import json
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
        self._machine = None
        self.values = {}

    def get_sanity_checks(self, job):
        return []

    def _create_squawk(self, squawk_type, note):
        return {"squawkType": squawk_type, "Note": note}

    def _convert_start_section(self, section_name, sublist):
        pass

    def _convert_tool_change(self, command):
        return "M6"

    def _expand_prefix(self, postables):
        pass

    def _convert_item_commands(self, item, gcode_lines):
        gcode_lines.append(f"(item {item.label})")

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
    def test_disables_first_waits_are_seconds_and_values_quoted(self):
        lines = post.mqtt_connect_lines("milo", "mqtt.lan", 1883)
        self.assertEqual(
            lines[1:],
            ["M586 P4 S0", "G4 S2", 'M586.4 C"milo"', 'M586 P4 H"mqtt.lan" R1883 S1', "G4 S3"],
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

    def test_tool_name_follows_tool_number(self):
        line = post.mqtt_tool_publish_line("milo", "change", 2, 1, "part.gcode", "6mm Endmill")
        self.assertEqual(
            _decode(line),
            '{"event":"change","tool_number":2,"tool_name":"6mm Endmill",'
            '"previous_tool":1,"job_file":"part.gcode"}',
        )

    def test_tool_name_is_compacted_first(self):
        # A device ID that leaves no room for the name but fits everything else.
        base = len(post.mqtt_tool_publish_line("d", "change", 2, 1, "part.gcode"))
        device = "d" * (post.MQTT_M118_MAX - base + 1)
        name = "Long Tool Name For Compacting 32"
        line = post.mqtt_tool_publish_line(device, "change", 2, 1, "part.gcode", name)
        self.assertLessEqual(len(line), post.MQTT_M118_MAX)
        self.assertNotIn('"tool_name"', _decode(line))
        self.assertIn('"previous_tool":1,"job_file":"part.gcode"', _decode(line))

        # A little more room: the name is shortened rather than dropped.
        line = post.mqtt_tool_publish_line(device[:-40], "change", 2, 1, "part.gcode", name)
        self.assertLessEqual(len(line), post.MQTT_M118_MAX)
        self.assertRegex(_decode(line), r'"tool_name":"Long Tool[^"]*~","previous_tool":1,')

    def test_tool_name_matches_m4000(self):
        for label in ("6mm Endmill", "Drill 3.3: tap M4, 118=deg", "x" * 40):
            with self.subTest(label=label):
                self.assertEqual(post.mqtt_tool_name(label), post.rrf_safe_string(label[:32]))
        # Characters M4000 drops (and its doubled quotes) never reach the payload.
        self.assertEqual(post.mqtt_tool_name('1/4" Endmill (3F) {x}'), "14 Endmill 3F x")
        self.assertEqual(post.mqtt_tool_name(None), "")

    def test_next_tool(self):
        line = post.mqtt_tool_publish_line(
            "milo", "change", 2, 1, "part.gcode", "6mm Endmill", 7, "Spot Drill"
        )
        self.assertEqual(
            _decode(line),
            '{"event":"change","tool_number":2,"tool_name":"6mm Endmill","previous_tool":1,'
            '"next_tool":7,"next_tool_name":"Spot Drill","job_file":"part.gcode"}',
        )

    def test_last_tool_has_null_next_tool(self):
        line = post.mqtt_tool_publish_line("milo", "change", 2, 1, "part.gcode", "", None, "x")
        self.assertIn('"next_tool":null,"job_file"', _decode(line))
        self.assertNotIn("next_tool_name", _decode(line))

    def test_next_tool_name_is_compacted_before_tool_name(self):
        base = len(post.mqtt_tool_publish_line("d", "change", 2, 1, "part.gcode", "6mm Endmill", 7))
        device = "d" * (post.MQTT_M118_MAX - base + 1)
        line = post.mqtt_tool_publish_line(
            device, "change", 2, 1, "part.gcode", "6mm Endmill", 7, "Long Next Tool Name For Test"
        )
        self.assertLessEqual(len(line), post.MQTT_M118_MAX)
        self.assertNotIn("next_tool_name", _decode(line))
        self.assertIn('"tool_name":"6mm Endmill","previous_tool":1,"next_tool":7,', _decode(line))

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

    def test_tool_names_come_from_tool_controllers(self):
        pp = _make_post()
        postables = [("allitems", [_tc_item(5, '6mm "Flat" Endmill'), _tc_item(3, "Drill")])]
        pp._expand_prefix(postables)
        pp._convert_start_section("allitems", [])
        first = _decode(pp._convert_tool_change(_Command(5)).split("\n")[2])
        self.assertIn('"tool_number":5,"tool_name":"6mm Flat Endmill"', first)
        second = _decode(pp._convert_tool_change(_Command(3)).split("\n")[2])
        self.assertIn('"tool_number":3,"tool_name":"Drill"', second)
        # A tool with no controller in the job publishes without a name.
        third = _decode(pp._convert_tool_change(_Command(9)).split("\n")[2])
        self.assertNotIn("tool_name", third)

    def test_next_tool_follows_each_files_tool_order(self):
        pp = _make_post()
        first = [_tc_item(5, "6mm Endmill"), _tc_item(5, "6mm Endmill"), _tc_item(3, "Drill"),
                 _tc_item(9, "Chamfer")]
        second = [_tc_item(9, "Chamfer"), _tc_item(5, "6mm Endmill")]
        pp._expand_prefix([("T5", first), ("T9", second)])

        def publish(tool):
            lines = pp._convert_tool_change(_Command(tool)).split("\n")
            return _decode(lines[2]) if len(lines) > 2 else None

        pp._convert_start_section("T5", first)
        self.assertIn('"next_tool":3,"next_tool_name":"Drill"', publish(5))
        self.assertIsNone(publish(5))  # the loaded tool again: no event
        self.assertIn('"next_tool":9,"next_tool_name":"Chamfer"', publish(3))
        self.assertIn('"next_tool":null', publish(9))

        pp._convert_start_section("T9", second)  # each output file has its own order
        line = publish(9)
        self.assertIn('"event":"start","tool_number":9,', line)
        self.assertIn('"next_tool":5,"next_tool_name":"6mm Endmill"', line)
        self.assertIn('"next_tool":null', publish(5))

    def test_next_tool_left_out_when_unknown(self):
        pp = _make_post()
        sublist = [_tc_item(5, "6mm Endmill"), _tc_item(3, "Drill")]
        pp._expand_prefix([("allitems", sublist)])
        pp._convert_start_section("allitems", sublist)
        line = _decode(pp._convert_tool_change(_Command(8)).split("\n")[2])  # not in the order
        self.assertNotIn("next_tool", line)

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


class TestOpEvents(unittest.TestCase):
    def setUp(self):
        _StubFilenameGenerator.template = "/cam/out/Part"
        _StubFilenameGenerator.fail = False

    def test_op_line(self):
        line = post.mqtt_op_publish_line("milo", 3, 7, "Adaptive", 5, "Profile", 3, "part.gcode")
        self.assertTrue(line.endswith(' T"duet/milo/op"'))
        self.assertEqual(
            _decode(line),
            '{"event":"op","op_index":3,"op_count":7,"op_name":"Adaptive","tool_number":5,'
            '"next_op_name":"Profile","next_op_tool":3,"job_file":"part.gcode"}',
        )

    def test_last_op_and_end(self):
        line = post.mqtt_op_publish_line("milo", 7, 7, "Chamfer", 9, None, 4, "part.gcode")
        self.assertIn('"next_op_name":null,"job_file"', _decode(line))
        self.assertEqual(
            _decode(post.mqtt_end_publish_line("milo", 7, "part.gcode")),
            '{"event":"end","op_count":7,"job_file":"part.gcode"}',
        )

    def test_op_names_lose_what_rrf_cannot_hold(self):
        self.assertEqual(post.mqtt_text('Pocket (rough) "A"', 40), "Pocket rough A")
        self.assertEqual(len(post.mqtt_text("x" * 60, 40)), 40)

    def test_op_line_is_compacted(self):
        base = len(post.mqtt_op_publish_line("d", 3, 7, "Adaptive", 5, "Profile", 3, "part.gcode"))
        device = "d" * (post.MQTT_M118_MAX - base + 1)
        line = post.mqtt_op_publish_line(
            device, 3, 7, "Adaptive", 5, "A Long Next Operation Name", 3, "part.gcode"
        )
        self.assertLessEqual(len(line), post.MQTT_M118_MAX)
        self.assertRegex(
            _decode(line), r'"op_name":"Adaptive","tool_number":5,"next_op_name":"[^"]*~"'
        )

    def test_current_op_name_outlasts_the_next(self):
        line = post.mqtt_op_publish_line(
            "d" * 100, 2, 7, "A Very Long Operation Name For The Test 1", 5,
            "Another Very Long Operation Name Here 22", 3, "a-long-job-file-name-for-testing.gcode",
        )
        self.assertLessEqual(len(line), post.MQTT_M118_MAX)
        self.assertRegex(_decode(line), r'"op_name":"A Very L[^"]*~"')
        self.assertNotIn("next_op_name", _decode(line))

    def _run(self, pp, sublist):
        pp._expand_prefix([("allitems", sublist)])
        pp._convert_start_section("allitems", sublist)
        lines = []
        for item in sublist:
            pp._convert_item_commands(item, lines)
        return lines

    def test_events_around_each_operation(self):
        sublist = [_tc_item(5, "6mm Endmill"), _op_item("Adaptive", 5),
                   _op_item("Profile (finish)", 5), _tc_item(3, "Drill"), _op_item("Drilling", 3)]
        lines = self._run(_make_post(), sublist)
        ops = [i for i, line in enumerate(lines) if line.endswith('T"duet/milo/op"')]
        self.assertEqual(len(ops), 4)
        events = [json.loads(_decode(lines[i])) for i in ops]
        self.assertEqual(events[0], {
            "event": "op", "op_index": 1, "op_count": 3, "op_name": "Adaptive", "tool_number": 5,
            "next_op_name": "Profile finish", "next_op_tool": 5, "job_file": "Part.gcode",
        })
        self.assertEqual(events[1]["next_op_tool"], 3)
        self.assertEqual((events[2]["op_index"], events[2]["next_op_name"]), (3, None))
        self.assertEqual(events[3], {"event": "end", "op_count": 3, "job_file": "Part.gcode"})
        # Each op event comes right before its operation; the end event after the last.
        self.assertEqual(lines[ops[0] + 1], "(item Adaptive)")
        self.assertEqual(lines[ops[2] + 1], "(item Drilling)")
        self.assertEqual(lines[ops[3] - 2], "(item Drilling)")

    def test_no_op_events_with_mqtt_off(self):
        lines = self._run(_make_post(MQTT_TELEMETRY=False), [_op_item("Adaptive", 5)])
        self.assertEqual(lines, ["(item Adaptive)"])


# ----------------------------------------------------------------------
# Tool numbers
# ----------------------------------------------------------------------
def _tc_item(number, label):
    return types.SimpleNamespace(
        item_type="tool_controller", data={"tool_number": number}, label=f"TC: {label}"
    )


def _op_item(label, tool):
    tc = types.SimpleNamespace(data={"tool_number": tool})
    return types.SimpleNamespace(item_type="operation", label=label, data={"tool_controller": tc})


def _op(number, label, active=True):
    tc = types.SimpleNamespace(ToolNumber=number, Label=label)
    return types.SimpleNamespace(Active=active, ToolController=tc)


class TestToolNumbers(unittest.TestCase):
    def test_problem(self):
        for number in (0, 1, 48):
            with self.subTest(number=number):
                self.assertIsNone(post.nxt_tool_number_problem(number))
        self.assertIn("touch probe", post.nxt_tool_number_problem(49))
        for number in (50, 101, -1):
            with self.subTest(number=number):
                self.assertIn("outside", post.nxt_tool_number_problem(number))

    def test_message_lists_only_bad_tools(self):
        self.assertEqual(post.nxt_tool_number_message([(1, "a"), (48, "b")]), "")
        message = post.nxt_tool_number_message([(52, "Facemill"), (3, "Drill"), (49, "Probe")])
        self.assertIn("0 to 48", message)
        self.assertIn("Probe (T49), Facemill (T52)", message)
        self.assertNotIn("Drill", message)

    def test_posting_refuses_bad_number(self):
        pp = _make_post(MQTT_TELEMETRY=False)
        postables = [("allitems", [_tc_item(5, "6mm Endmill"), _tc_item(52, "Facemill")])]
        with self.assertRaisesRegex(ValueError, r"Facemill \(T52\)"):
            pp._check_tool_numbers(postables)

    def test_posting_accepts_good_numbers(self):
        pp = _make_post(MQTT_TELEMETRY=False)
        pp._check_tool_numbers([("allitems", [_tc_item(0, "a"), _tc_item(48, "b")])])

    def test_sanity_check_warns(self):
        pp = _make_post(MQTT_TELEMETRY=False)
        job = types.SimpleNamespace(
            Operations=types.SimpleNamespace(
                Group=[_op(5, "6mm Endmill"), _op(52, "Facemill"), _op(60, "Unused", active=False)]
            )
        )
        issues = pp.get_sanity_checks(job)
        self.assertEqual(len(issues), 1)
        self.assertEqual(issues[0]["squawkType"], "WARNING")
        self.assertIn("Facemill (T52)", issues[0]["Note"])
        self.assertNotIn("Unused", issues[0]["Note"])

    def test_sanity_check_quiet_when_fine(self):
        pp = _make_post(MQTT_TELEMETRY=False)
        job = types.SimpleNamespace(Operations=types.SimpleNamespace(Group=[_op(5, "6mm")]))
        self.assertEqual(pp.get_sanity_checks(job), [])


if __name__ == "__main__":
    unittest.main()
