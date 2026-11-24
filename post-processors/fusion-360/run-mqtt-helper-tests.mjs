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

// next_tool: the next different tool in the file, null after the last change
{
  const tools = [
    { number: 5, description: "6mm Endmill" },
    { number: 5, description: "6mm Endmill" },  // same tool, no change
    { number: 3, description: "Drill" },
  ];
  const { post } = loadPost({ props: MQTT_ON });
  post.getNumberOfSections = () => tools.length;
  post.getSection = (i) => ({ getTool: () => tools[i] });
  post.getCurrentSectionId = () => 0;
  assert.equal(post.mqttNextTool(5).number, 3, "skips sections with the same tool");
  post.getCurrentSectionId = () => 2;
  assert.equal(post.mqttNextTool(3), null, "nothing after the last section");
  post.getSection = () => { throw new Error("no sections"); };
  post.getCurrentSectionId = () => 0;
  assert.equal(post.mqttNextTool(5), undefined, "unknown when the API fails");
}
{
  const { post, out } = loadPost({ props: MQTT_ON, outputPath: "/cam/part.gcode" });
  post.writeMqttToolPublish(5, null, "6mm Endmill", { number: 3, description: 'Spot "Drill" (90)' });
  post.writeMqttToolPublish(3, 5, "Drill", null);
  const [first, last] = codeLines(out).map(payloadOf);
  assert.deepEqual(first, { event: "start", tool_number: 5, tool_name: "6mm Endmill", next_tool: 3,
                            next_tool_name: "Spot Drill 90", job_file: "part.gcode" });
  assert.equal(last.next_tool, null);
  assert.equal(last.next_tool_name, undefined);
  const line = codeLines(out)[0];
  assert.ok(line.includes('""tool_name"":""6mm Endmill"",""next_tool"":3,""next_tool_name""'), line);
}
{
  // next_tool_name gives way before tool_name.
  const render = (dev, nextName) =>
    loadPost({ props: { ...MQTT_ON, mqttDeviceId: dev } }).post.mqttRenderToolLine(
      "change", 2, 1, "part.gcode", "6mm Endmill", 7, nextName);
  const base = render("d", "").length;
  const line = render("d".repeat(240 - base + 1), "Long Next Tool Name For Test");
  assert.ok(line.length <= 240);
  assert.ok(!line.includes("next_tool_name"), line);
  assert.ok(line.includes('""tool_name"":""6mm Endmill"",""previous_tool"":1,""next_tool"":7,'), line);
}

// Op events on duet/<device>/op: one per section, then an end event
{
  const opPayload = (line) => {
    const m = /^M118 P6 S"(.*)" T"duet\/milo\/op"$/.exec(line);
    assert.ok(m, `not an op publish: ${line}`);
    return JSON.parse(m[1].replace(/""/g, '"'));
  };
  const sections = [
    { comment: "Adaptive", tool: 5 },
    { comment: "Profile (finish)", tool: 5 },
    { comment: "Drilling", tool: 3 },
  ];
  const { post, out } = loadPost({ props: MQTT_ON, outputPath: "/cam/part.gcode" });
  const section = (s) => ({
    hasParameter: (k) => k === "operation-comment",
    getParameter: () => s.comment,
    getTool: () => ({ number: s.tool }),
  });
  post.getNumberOfSections = () => sections.length;
  post.getSection = (i) => section(sections[i]);
  for (let i = 0; i < sections.length; i++) {
    post.getCurrentSectionId = () => i;
    post.currentSection = section(sections[i]);
    post.tool = { number: sections[i].tool };
    post.writeMqttOpPublish();
  }
  post.writeMqttEndPublish();
  const events = codeLines(out).map(opPayload);
  assert.deepEqual(events[0], { event: "op", op_index: 1, op_count: 3, op_name: "Adaptive", tool_number: 5,
                                next_op_name: "Profile finish", next_op_tool: 5, job_file: "part.gcode" });
  assert.equal(events[1].next_op_tool, 3);
  assert.equal(events[2].next_op_name, null);
  assert.equal(events[2].next_op_tool, undefined);
  assert.deepEqual(events[3], { event: "end", op_count: 3, job_file: "part.gcode" });
  assert.ok(codeLines(out)[0].includes('""op_name"":""Adaptive"",""tool_number"":5,""next_op_name""'));
}
{
  const { post, out } = loadPost();  // telemetry off: no op or end events
  post.writeMqttOpPublish();
  post.writeMqttEndPublish();
  assert.deepEqual(out, []);
}

// Tool details on duet/<device>/tooldef, one line per tool after the connect
{
  const { post, out } = loadPost({ props: MQTT_ON });
  const tools = [
    { number: 5, description: "6mm Endmill", diameter: 6, numberOfFlutes: 3, spindleRPM: 18000 },
    { number: 21, description: 'Spot "Drill" (90)', diameter: 6.35, numberOfFlutes: 2, spindleRPM: 10000.4 },
    { number: 9, description: "", diameter: 0, numberOfFlutes: 0, spindleRPM: 0 },
  ];
  post.getToolTable = () => ({ getNumberOfTools: () => tools.length, getTool: (i) => tools[i] });
  post.writeMqttToolDefs();
  const defs = codeLines(out).map((line) => {
    const m = /^M118 P6 S"(.*)" T"duet\/milo\/tooldef"$/.exec(line);
    assert.ok(m, line);
    return JSON.parse(m[1].replace(/""/g, '"'));
  });
  assert.deepEqual(defs, [
    { event: "tool", tool_number: 5, tool_name: "6mm Endmill", diameter: 6, flutes: 3, rpm: 18000 },
    { event: "tool", tool_number: 21, tool_name: "Spot Drill 90", diameter: 6.35, flutes: 2, rpm: 10000 },
    { event: "tool", tool_number: 9 },
  ]);
  assert.equal(post.mqttNumber(1.5875), 1.587);
}
{
  const { post, out } = loadPost();  // telemetry off
  post.writeMqttToolDefs();
  assert.deepEqual(out, []);
}

console.log("mqtt helper tests: ok");
