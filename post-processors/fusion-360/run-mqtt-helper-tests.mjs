#!/usr/bin/env node
/**
 * Tests the MQTT telemetry code in nxt.cps itself, not a copy of it.
 *
 * The post is loaded in a node vm context. getProperty, getOutputPath, writeln,
 * writeComment and error are stubbed; every other Fusion global the post uses at
 * load time (createFormat, setCodePage, MM, ...) resolves to a no-op stub.
 *
 *   node post-processors/fusion-360/run-mqtt-helper-tests.mjs
 */
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const source = fs.readFileSync(path.join(here, "nxt.cps"), "utf8");

const MQTT_ON = {
  mqttTelemetryEnabled: true,
  mqttDeviceId: "milo",
  mqttBrokerHost: "192.168.2.12",
  mqttBrokerPort: 1883,
};

/** A fresh copy of the post, as Fusion loads one for each post run. */
function loadPost({ props = {}, outputPath = "", programName = "", programComment = "" } = {}) {
  const out = [];
  const errors = [];
  const base = {
    console, Math, String, Number, Array, Object, JSON, Date, RegExp, Error,
    parseInt, parseFloat, isNaN,
    FileSystem: undefined,
    getProperty: (name) => props[name],
    getOutputPath: () => outputPath,
    programName,
    programComment,
    writeln: (line) => out.push(String(line)),
    writeComment: (text) => out.push("(" + text + ")"),
    error: (message) => errors.push(String(message)),
  };
  const stub = function () {
    return stub;
  };
  const ctx = vm.createContext(
    new Proxy(base, {
      has: () => true,
      get: (target, key) => (key in target ? target[key] : typeof key === "symbol" ? undefined : stub),
      set: (target, key, value) => {
        target[key] = value;
        return true;
      },
    })
  );
  vm.runInContext(source, ctx, { filename: "nxt.cps" });
  return { post: ctx, out, errors };
}

/** Code lines only: no comments, no blank lines. */
const codeLines = (out) => out.filter((l) => l !== "" && !l.startsWith("("));

/** The JSON payload of an M118 P6 line. */
function payloadOf(line) {
  const m = /^M118 P6 S"(.*)" T"duet\/milo\/tool"$/.exec(line);
  assert.ok(m, `not an M118 P6 publish: ${line}`);
  return JSON.parse(m[1].replace(/""/g, '"'));
}

// job_file: prefer the output file name, never a bare program number
{
  const name = (opts) => loadPost(opts).post.mqttJobFileName();
  assert.equal(
    name({ outputPath: "/cam/Golf/Putter/01 Putter - 3 axis - Op1.gcode", programName: "8910" }),
    "01 Putter - 3 axis - Op1.gcode"
  );
  assert.equal(name({ outputPath: "C:\\cam\\part.gcode" }), "part.gcode");
  assert.equal(name({ outputPath: "/tmp/8910.gcode", programName: "8910" }), "job.gcode");
  assert.equal(
    name({ outputPath: "/tmp/8910.gcode", props: { mqttJobFile: "01 Putter - 3 axis - Op1.gcode" } }),
    "01 Putter - 3 axis - Op1.gcode"
  );
  assert.equal(name({ programName: "part.nc" }), "part.nc");
}

// Preamble: disable first, because the board refuses M586.4 while MQTT is enabled;
// the waits are G4 S (seconds), not G4 P (milliseconds)
{
  const { post, out, errors } = loadPost({ props: MQTT_ON });
  post.writeMqttConnectPreamble();
  assert.deepEqual(codeLines(out), [
    "M586 P4 S0",
    "G4 S2",
    'M586.4 C"milo"',
    'M586 P4 H"192.168.2.12" R1883 S1',
    "G4 S3",
  ]);
  assert.deepEqual(errors, []);
}
{
  const { post, out } = loadPost();
  post.writeMqttConnectPreamble();
  assert.deepEqual(out, [], "no MQTT lines when telemetry is off");
}
{
  const { post, out, errors } = loadPost({ props: { ...MQTT_ON, mqttBrokerHost: "" } });
  post.writeMqttConnectPreamble();
  assert.deepEqual(out, []);
  assert.equal(errors.length, 1, "a blank broker host is an error when posting");
}

// Tool events: "start" for the first tool of a post run, "change" after it
{
  const { post, out } = loadPost({ props: MQTT_ON, outputPath: "/cam/part.gcode" });
  post.writeMqttToolPublish(5);
  post.writeMqttToolPublish(7, 5);
  post.writeMqttToolPublish(5);
  const [first, second, third] = codeLines(out).map(payloadOf);
  assert.deepEqual(first, { event: "start", tool_number: 5, job_file: "part.gcode" });
  assert.deepEqual(second, { event: "change", tool_number: 7, previous_tool: 5, job_file: "part.gcode" });
  assert.equal(third.event, "change");
  assert.ok(codeLines(out).every((l) => l.length <= 240), "M118 lines stay within 240 characters");
}
{
  const { post, out } = loadPost({ props: MQTT_ON });
  post.writeMqttToolPublish(3, 2);
  assert.equal(payloadOf(codeLines(out)[0]).event, "change", "a known previous tool is a change");
}
{
  const { post, out } = loadPost({ props: MQTT_ON });
  post.writeMqttToolPublish(5);
  assert.equal(payloadOf(codeLines(out)[0]).event, "start", "each post run starts again");
}

// tool_name: the M4000 description, after tool_number, compacted before anything else
{
  const { post, out } = loadPost({ props: MQTT_ON, outputPath: "/cam/part.gcode" });
  post.writeMqttToolPublish(5, null, "6mm Endmill");
  post.writeMqttToolPublish(7, 5, '1/4" Endmill (3F) {x}');
  post.writeMqttToolPublish(9, 7);
  const lines = codeLines(out);
  assert.ok(lines[0].includes('""tool_number"":5,""tool_name"":""6mm Endmill""'), lines[0]);
  const [first, second, third] = lines.map(payloadOf);
  assert.deepEqual(first, { event: "start", tool_number: 5, tool_name: "6mm Endmill", job_file: "part.gcode" });
  assert.equal(second.tool_name, "14 Endmill 3F x");
  assert.equal(third.tool_name, undefined, "no description, no tool_name");
  assert.equal(post.mqttSanitizeToolName("x".repeat(40)), "x".repeat(32));
}
{
  // A device ID that leaves no room for the name but fits everything else.
  const { post } = loadPost({ props: { ...MQTT_ON, mqttDeviceId: "d" } });
  const base = post.mqttRenderToolLine("change", 2, 1, "part.gcode").length;
  const device = "d".repeat(240 - base + 1);
  const render = (dev, name) =>
    loadPost({ props: { ...MQTT_ON, mqttDeviceId: dev } }).post.mqttRenderToolLine("change", 2, 1, "part.gcode", name);
  const decode = (line) => JSON.parse(/ S"(.*)" T"/.exec(line)[1].replace(/""/g, '"'));
  const name = "Long Tool Name For Compacting 32";
  const dropped = render(device, name);
  assert.ok(dropped.length <= 240);
  assert.deepEqual(decode(dropped), { event: "change", tool_number: 2, previous_tool: 1, job_file: "part.gcode" });
  const shortened = render(device.slice(40), name);
  assert.ok(shortened.length <= 240);
  assert.match(decode(shortened).tool_name, /^Long Tool.*~$/);
  assert.equal(decode(shortened).job_file, "part.gcode");
}

console.log("mqtt helper tests: ok");
