#!/usr/bin/env node
/**
 * Regression check for G6512.1 touch sampling (issue #53).
 *
 * 1. Mirrors the sampling rule the macro must implement (sampleSurface) and
 *    verifies it against fixed cases.
 * 2. Asserts on the text of macros/probing/G6512.1.g so the macro keeps to that rule.
 *
 * Usage (from repo root):
 *   node dist/check-g6512-1-sampling.mjs
 *
 * Exit 0 = pass, 1 = failures.
 */
"use strict";

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const MACRO = path.join(ROOT, "macros", "probing", "G6512.1.g");
const EPS = 1e-9;
const TAG = "check-g6512-1-sampling";

function dist3(a, b) {
	return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
}

/**
 * Mirror of the G6512.1 sampling rule.
 * @param {{touches: Array<{pos: number[], triggered: boolean}>, limitMm: number, outerRetries: number, fineCount: number}} opts
 */
function sampleSurface(opts) {
	const { touches, limitMm, outerRetries, fineCount } = opts;
	const tolOn = limitMm > 0;
	const n = tolOn ? 3 : Math.max(1, fineCount);
	const maxAttempts = tolOn ? outerRetries + 1 : 1;
	let used = 0;
	let failedPair = null;
	let deltaMm = null;
	let attempts = 0;

	for (let a = 0; a < maxAttempts; a++) {
		attempts++;
		const batch = [];
		for (let i = 0; i < n; i++) {
			const t = touches[used++];
			if (!t.triggered) {
				return {
					ok: true,
					result: t.pos.slice(),
					attempts,
					failedPair: null,
					deltaMm: null,
					touchesUsed: used,
				};
			}
			batch.push(t.pos);
		}
		let pass = true;
		if (tolOn) {
			for (let i = 0; i < n - 1; i++) {
				const d = dist3(batch[i], batch[i + 1]);
				if (d > limitMm) {
					pass = false;
					failedPair = `${i + 1}-${i + 2}`;
					deltaMm = d;
				}
			}
		}
		if (pass) {
			const result = batch[n - 1].slice();
			for (let k = 0; k < 3; k++) {
				result[k] = batch.reduce((s, p) => s + p[k], 0) / n;
			}
			return { ok: true, result, attempts, failedPair: null, deltaMm: null, touchesUsed: used };
		}
	}
	return { ok: false, result: null, attempts, failedPair, deltaMm, touchesUsed: used };
}

const failures = [];
function expect(name, cond, detail) {
	if (!cond) failures.push(`mirror case "${name}": ${detail}`);
}
const near = (a, b) => typeof a === "number" && Math.abs(a - b) < EPS;
const tx = (x) => ({ pos: [x, 0, -5], triggered: true });
const base = { limitMm: 0.075, outerRetries: 1, fineCount: 3 };

function mirrorCases() {
	let r = sampleSurface({ ...base, touches: [tx(10.0), tx(10.004), tx(10.002)] });
	expect("agree", r.ok && r.attempts === 1 && near(r.result[0], 10.002), JSON.stringify(r));

	r = sampleSurface({
		...base,
		touches: [tx(10.0), tx(10.19), tx(10.0), tx(10.001), tx(10.0), tx(10.002)],
	});
	expect("retry then pass", r.ok && r.attempts === 2 && near(r.result[0], 10.001), JSON.stringify(r));

	r = sampleSurface({
		...base,
		touches: [tx(10.0), tx(10.0), tx(10.6), tx(10.0), tx(10.0), tx(10.6)],
	});
	expect(
		"persistent fail",
		!r.ok && r.failedPair === "2-3" && near(r.deltaMm, 0.6) && r.attempts === 2,
		JSON.stringify(r)
	);

	r = sampleSurface({ ...base, outerRetries: 0, touches: [tx(10.0), tx(10.0), tx(10.19)] });
	expect("issue 53 outlier", !r.ok, JSON.stringify(r));

	r = sampleSurface({ ...base, limitMm: 0, touches: [tx(10.0), tx(10.0), tx(10.6)] });
	expect("limit 0 averages", r.ok && near(r.result[0], 10.2), JSON.stringify(r));

	const pt = (rad) => {
		const a = (120 * Math.PI) / 180;
		return { pos: [rad * Math.cos(a), rad * Math.sin(a), 0], triggered: true };
	};
	r = sampleSurface({ ...base, outerRetries: 0, touches: [pt(5.0), pt(5.08), pt(5.08)] });
	expect("diagonal pair uses 3D distance", !r.ok && r.failedPair === "1-2", JSON.stringify(r));

	const ta = { pos: [10, 0, -5, 33.3], triggered: true };
	r = sampleSurface({ ...base, touches: [ta, ta, ta] });
	expect("keeps A", r.ok && r.result.length === 4 && r.result[3] === 33.3, JSON.stringify(r));

	r = sampleSurface({ ...base, touches: [{ pos: [12, 0, -5], triggered: false }] });
	expect(
		"E0 not triggered",
		r.ok && r.touchesUsed === 1 && r.result[0] === 12,
		JSON.stringify(r)
	);
}

function macroAssertions() {
	if (!fs.existsSync(MACRO)) {
		failures.push("macro assertions: macros/probing/G6512.1.g not found");
		return;
	}
	const text = fs.readFileSync(MACRO, "utf8");
	const lines = text.split(/\r?\n/);

	if (/1\.0\s*\/\s*\(\s*iterations\s*-\s*1\s*\)/.test(text)) {
		failures.push("(a) G6512.1.g still contains the 1.0/(iterations-1) averaging weight");
	}
	if (text.includes("maxProbeCount")) {
		failures.push("(b) G6512.1.g still contains maxProbeCount");
	}
	for (const g of [
		"global.nxtProbeMaxSampleSpreadMm",
		"global.nxtProbeSampleOuterRetries",
		"global.nxtProbeInnerSampleCount",
		"global.nxtTouchProbeID",
	]) {
		if (!text.includes(g)) failures.push(`(c) G6512.1.g does not reference ${g}`);
	}

	const rf = lines.findIndex((l) => l.includes("Repeatability failed"));
	if (rf < 0) {
		failures.push('(d) G6512.1.g has no line containing "Repeatability failed"');
	} else {
		const from = Math.max(0, rf - 5);
		const found = lines.slice(from, rf).some((l) => /^\s*G27 Z1\s*$/.test(l));
		if (!found) {
			failures.push('(d) no "G27 Z1" line within the 5 lines before "Repeatability failed"');
		}
	}

	if (!lines.some((l) => l.trim() === "var result = { global.nxtAbsPos }")) {
		failures.push("(e) G6512.1.g lacks the line: var result = { global.nxtAbsPos }");
	}
	const nonBlank = lines.filter((l) => l.trim() !== "");
	const last = nonBlank.length ? nonBlank[nonBlank.length - 1].trim() : "";
	if (last !== "set global.nxtAbsPos = { var.result }") {
		failures.push(`(e) last non-blank line is not "set global.nxtAbsPos = { var.result }" (got "${last}")`);
	}

	if (!/var\.sP\[0\] != var\.cP\[0\]/.test(text)) {
		failures.push("(f) G6512.1.g no longer matches /var.sP[0] != var.cP[0]/");
	}
}

mirrorCases();
macroAssertions();

if (failures.length) {
	for (const f of failures) console.error(`${TAG}: ${f}`);
	process.exit(1);
}
console.log(`${TAG}: ok`);
