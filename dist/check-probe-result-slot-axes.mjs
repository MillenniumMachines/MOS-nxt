#!/usr/bin/env node
/**
 * Single-axis probe cycles write only the probed axis into their result slot.
 *
 * G6504 (web), G6505 (pocket) and G6510 (single surface) each measure one axis.
 * The Probe Results panel pre-ticks every non-zero linear axis of a slot
 * (suggestPushAxesFromRow), and M6522 treats 0 as "not probed". A cycle that
 * also writes an axis it didn't probe, such as the start position, makes a
 * panel push overwrite that axis's origin (#45, the same symptom as #26).
 *
 * In each listed macro:
 *   - element writes `set global.nxtProbeResults[<slot>][<i>]` use
 *     <i> = var.probeAxis (the probed axis) or #move.axes (the rotation
 *     element), and at least one writes var.probeAxis;
 *   - whole-slot writes `set global.nxtProbeResults[<slot>] = ...` only create
 *     a zero-filled vector.
 *
 * Usage (from repo root):
 *   node dist/check-probe-result-slot-axes.mjs
 *
 * Exit 0 = pass, 1 = violations.
 */
"use strict";

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");

const SINGLE_AXIS_CYCLES = [
	"macros/probing/G6504.g",
	"macros/probing/G6505.g",
	"macros/probing/G6510.g",
];

/** set global.nxtProbeResults[<slot>] = <value>, or ...[<slot>][<index>] = <value> */
const SLOT_WRITE = /^set\s+global\.nxtProbeResults\[([^\]]+)\](?:\[([^\]]+)\])?\s*=\s*(.+)$/i;
const ZERO_VECTOR = /^\{\s*vector\([^,]+,\s*0(?:\.0*)?\s*\)\s*\}$/;
const PROBED_AXIS = "var.probeAxis";
const ROTATION = "#move.axes";

function checkFile(rel) {
	const abs = path.join(ROOT, rel);
	if (!fs.existsSync(abs)) {
		return [{ file: rel, line: 0, reason: "file not found", preview: "" }];
	}
	const lines = fs.readFileSync(abs, "utf8").split(/\r?\n/);
	const violations = [];
	let probedAxisWrites = 0;

	for (let i = 0; i < lines.length; i++) {
		const code = lines[i].split(";")[0].trim();
		const m = code.match(SLOT_WRITE);
		if (!m) continue;
		const index = m[2] === undefined ? null : m[2].trim();
		const value = m[3].trim();
		const at = { file: rel, line: i + 1, preview: code.slice(0, 100) };

		if (index === null) {
			if (!ZERO_VECTOR.test(value)) {
				violations.push({ ...at, reason: "whole-slot write must be a zero-filled vector" });
			}
		} else if (index === PROBED_AXIS) {
			probedAxisWrites++;
		} else if (index !== ROTATION) {
			violations.push({ ...at, reason: `writes element [${index}], not the probed axis` });
		}
	}

	if (probedAxisWrites === 0) {
		violations.push({ file: rel, line: 0, reason: "never writes the probed axis", preview: "" });
	}
	return violations;
}

function main() {
	const all = [];
	for (const rel of SINGLE_AXIS_CYCLES) {
		all.push(...checkFile(rel));
	}
	if (all.length) {
		console.error("check-probe-result-slot-axes: single-axis cycles must write only the probed axis:");
		for (const v of all) {
			console.error(`  ${v.file}:${v.line} ${v.reason}  ${v.preview}`);
		}
		process.exit(1);
	}
	console.log(
		`check-probe-result-slot-axes: ok (${SINGLE_AXIS_CYCLES.length} macros write only the probed axis)`
	);
}

main();
