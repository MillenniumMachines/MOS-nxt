#!/usr/bin/env node
/**
 * Pure-logic mirrors of nxt.cps MQTT helpers (job_file + event naming).
 * Keeps Fusion post payload rules covered without the Autodesk CPS runtime.
 */
import assert from "node:assert/strict";

function mqttTrimString(s) {
  if (s === undefined || s === null) return "";
  return String(s).replace(/^\s+|\s+$/g, "");
}

function mqttSanitizeJobFile(name) {
  return mqttTrimString(name).replace(/[^0-9a-zA-Z._\- /]/gi, "").substring(0, 64);
}

function mqttLooksLikeJobFileName(s) {
  const t = mqttTrimString(s);
  if (!t) return false;
  if (/^[0-9]+$/.test(t)) return false;
  if (/^[0-9]+\.(gcode|g|gc|nc|tap|cnc)$/i.test(t)) return false;
  return true;
}

function mqttBasenameFromPath(path) {
  const p = mqttTrimString(path);
  if (!p) return "";
  const normalized = p.replace(/\\/g, "/");
  const slash = normalized.lastIndexOf("/");
  return slash >= 0 ? normalized.substring(slash + 1) : normalized;
}

function mqttJobFileName({ outputPath, programName, programComment, override }) {
  let name = mqttBasenameFromPath(override || "");
  if (!mqttLooksLikeJobFileName(name)) name = "";
  if (!name) name = mqttBasenameFromPath(outputPath);
  if (!mqttLooksLikeJobFileName(name)) name = "";
  if (!name && programName && mqttLooksLikeJobFileName(programName)) {
    name = String(programName);
  }
  if (!name && programComment && mqttLooksLikeJobFileName(programComment)) {
    name = String(programComment);
  }
  if (!name) name = "job.gcode";
  return mqttSanitizeJobFile(name) || "job.gcode";
}

function mqttEventName(mqttToolEventCount, previousTool) {
  const hasPrev = previousTool !== undefined && previousTool !== null && previousTool >= 0;
  return mqttToolEventCount === 0 && !hasPrev ? "start" : "change";
}

assert.equal(
  mqttJobFileName({
    outputPath: "/cam/Golf/Putter/01 Putter - 3 axis - Op1.gcode",
    programName: "8910",
  }),
  "01 Putter - 3 axis - Op1.gcode"
);
assert.equal(
  mqttJobFileName({ outputPath: "/tmp/8910.gcode", programName: "8910" }),
  "job.gcode"
);
assert.equal(
  mqttJobFileName({
    outputPath: "/tmp/8910.gcode",
    programName: "8910",
    override: "01 Putter - 3 axis - Op1.gcode",
  }),
  "01 Putter - 3 axis - Op1.gcode"
);
assert.equal(
  mqttJobFileName({ outputPath: "", programName: "8910" }),
  "job.gcode"
);
assert.equal(
  mqttJobFileName({ outputPath: "", programName: "part.nc" }),
  "part.nc"
);
assert.equal(mqttEventName(0, null), "start");
assert.equal(mqttEventName(0, 1), "change");
assert.equal(mqttEventName(1, null), "change");
assert.equal(mqttEventName(1, 2), "change");

console.log("mqtt helper tests: ok");
