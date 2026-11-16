#!/usr/bin/env node
/**
 * Regression check for G6512.1 touch sampling (issue #53).
 *
 * 1. Mirrors the sampling rule the macro must implement (sampleSurface) and
 *    verifies it against fixed cases.
 * 2. Asserts on the text of macros/probing/G6512.1.g so the macro keeps to that rule.
 *
 * Usage (from repo root):
 *   node dist/check-g6512-1-sampling.mjs [macro-path]
 *
 * The optional path checks another copy of the macro (default macros/probing/G6512.1.g).
 *
 * Exit 0 = pass, 1 = failures.
 */
"use strict";

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const MACRO = process.argv[2]
	? path.resolve(process.argv[2])
	: path.join(ROOT, "macros", "probing", "G6512.1.g");
const EPS = 1e-9;
const TAG = "check-g6512-1-sampling";

function dist3(a, b) {
	return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
}

/**
 * Mirror of the macro's per-set statistics: Welford running mean and sum of
 * squared deviations, weighted by the fine-touch count, then the sample
 * standard deviation (n - 1). `f` rounds after each operation; pass
 * Math.fround to model RRF's 32-bit floats.
 */
function welford(batch, f = (x) => x) {
	const mean = [0, 0, 0];
	const ss = [0, 0, 0];
	batch.forEach((p, i) => {
		const n = i + 1;
		for (let k = 0; k < 3; k++) {
			const delta = f(p[k] - mean[k]);
			mean[k] = f(mean[k] + f(delta / n));
			ss[k] = f(ss[k] + f(delta * f(p[k] - mean[k])));
		}
	});
	const m = batch.length;
	const sd = ss.map((s) => (m > 1 ? f(Math.sqrt(f(Math.max(0, s) / (m - 1)))) : null));
	return { mean, sd };
}

/** Two-pass reference for the sample standard deviation. */
function twoPassSd(values) {
	const m = values.reduce((s, v) => s + v, 0) / values.length;
	return Math.sqrt(values.reduce((s, v) => s + (v - m) ** 2, 0) / (values.length - 1));
}

/**
 * Mirror of the G6512.1 sampling rule.
 * @param {{touches: Array<{pos: number[], triggered: boolean}>, limitMm: number, outerRetries: number, fineCount: number}} opts
 */
function sampleSurface(opts) {
	const { touches, limitMm, outerRetries, fineCount } = opts;
	const tolOn = limitMm > 0;
	const n = tolOn ? 3 : Math.max(1, fineCount);
	// The macro raises outerLimit to at least 1 for a negative outerRetries
	const maxAttempts = tolOn ? Math.max(1, outerRetries + 1) : 1;
	let used = 0;
	let failedPair = null;
	let deltaMm = null;
	let attempts = 0;
	// Reported statistics of each completed set with 2 or more fine touches
	const sets = [];

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
					sets,
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
		const stats = welford(batch);
		if (n > 1) sets.push({ n, mean: stats.mean, sd: stats.sd });
		if (pass) {
			const result = batch[n - 1].slice();
			for (let k = 0; k < 3; k++) {
				result[k] = stats.mean[k];
			}
			return { ok: true, result, attempts, failedPair: null, deltaMm: null, touchesUsed: used, sets };
		}
	}
	return { ok: false, result: null, attempts, failedPair, deltaMm, touchesUsed: used, sets };
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
	expect(
		"agree",
		r.ok && r.attempts === 1 && near(r.result[0], 10.002) &&
			r.sets.length === 1 && near(r.sets[0].sd[0], 0.002) && near(r.sets[0].sd[2], 0),
		JSON.stringify(r)
	);

	r = sampleSurface({
		...base,
		touches: [tx(10.0), tx(10.19), tx(10.0), tx(10.001), tx(10.0), tx(10.002)],
	});
	expect(
		"retry then pass",
		r.ok && r.attempts === 2 && near(r.result[0], 10.001) && r.sets.length === 2 &&
			near(r.sets[0].sd[0], twoPassSd([10.0, 10.19, 10.0])),
		JSON.stringify(r)
	);

	// Issue 53: the old weight 1/(iterations-1) dropped the first fine touch,
	// so this returned 10.000 with a variance of 0.
	r = sampleSurface({ ...base, limitMm: 0, touches: [tx(10.19), tx(10.0), tx(10.0)] });
	expect(
		"first fine touch counts in mean and sd",
		r.ok && near(r.result[0], 30.19 / 3) && near(r.sets[0].sd[0], twoPassSd([10.19, 10.0, 10.0])),
		JSON.stringify(r)
	);

	r = sampleSurface({ ...base, limitMm: 0, fineCount: 1, touches: [tx(10.0)] });
	expect("R1 reports no spread", r.ok && r.result[0] === 10.0 && r.sets.length === 0, JSON.stringify(r));

	const xs = [12.3456, 12.3471, 12.3449, 12.3502, 12.346];
	const ys = [-4.0012, -4.0001, -4.0035, -3.9998, -4.0007];
	r = sampleSurface({
		...base,
		limitMm: 0,
		fineCount: 5,
		touches: xs.map((x, i) => ({ pos: [x, ys[i], -5], triggered: true })),
	});
	const mean5 = (v) => v.reduce((s, x) => s + x, 0) / v.length;
	expect(
		"Welford matches two-pass",
		r.ok && near(r.result[0], mean5(xs)) && near(r.result[1], mean5(ys)) &&
			near(r.sets[0].sd[0], twoPassSd(xs)) && near(r.sets[0].sd[1], twoPassSd(ys)),
		JSON.stringify(r)
	);

	// RRF uses 32-bit floats. At 300 mm the mean and sd still come out
	// within 0.1 um of the exact values for the same touches.
	const f32 = [299.9981, 300.0013, 299.9995].map(Math.fround);
	const w = welford(f32.map((x) => [x, 0, 0]), Math.fround);
	expect(
		"float32 at 300 mm",
		Math.abs(w.mean[0] - mean5(f32)) < 1e-4 && Math.abs(w.sd[0] - twoPassSd(f32)) < 1e-4,
		JSON.stringify({ mean: w.mean[0], sd: w.sd[0], refMean: mean5(f32), refSd: twoPassSd(f32) })
	);

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

	r = sampleSurface({ ...base, outerRetries: -1, touches: [tx(10.0), tx(10.004), tx(10.002)] });
	expect("negative retries still sample once", r.ok && r.attempts === 1, JSON.stringify(r));

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

	// (g) every fine-touch mean/ss accumulation sits inside an `if { !var.isFast }` block
	const indentOf = (l) => l.match(/^\s*/)[0].replace(/	/g, "    ").length;
	const sumIdx = lines
		.map((l, i) => (/^\s*set\s+var\.(mean|ss)[XYZ]\s*=\s*\{\s*var\.(mean|ss)[XYZ]\s*\+/.test(l) ? i : -1))
		.filter((i) => i >= 0);
	if (sumIdx.length !== 6) {
		failures.push(`(g) expected 6 fine-touch mean/ss accumulator lines, found ${sumIdx.length}`);
	}
	for (const i of sumIdx) {
		let ok = false;
		for (let j = i - 1; j >= 0; j--) {
			if (lines[j].trim() === "" || indentOf(lines[j]) >= indentOf(lines[i])) continue;
			if (/^\s*if\s*\{\s*!\s*var\.isFast\s*\}\s*$/.test(lines[j])) {
				ok = true;
				break;
			}
			if (indentOf(lines[j]) === 0) break;
			// keep climbing: an enclosing block may be the isFast guard
			if (!/^\s*(if|while|elif|else)\b/.test(lines[j])) break;
		}
		if (!ok) failures.push(`(g) line ${i + 1} adds to a mean/ss accumulator outside an "if { !var.isFast }" block`);
	}

	// (h) the pair-distance expression uses all three axes in one sqrt( expression
	const pairLine = lines.find((l) => /var\s+pairDeltaMm\s*=/.test(l) || /set\s+var\.pairDeltaMm\s*=/.test(l));
	if (!pairLine || !/sqrt\(/.test(pairLine) || ![0, 1, 2].every((k) => pairLine.includes(`var.cP[${k}]`))) {
		failures.push("(h) pair-distance expression does not use var.cP[0], [1] and [2] in one sqrt( expression");
	}

	// (i) the not-triggered flag check in the touch loop is followed by a break
	const ntIdx = lines.findIndex((l) => /^\s*if\s*\{\s*var\.notTriggered\s*\}\s*$/.test(l));
	if (ntIdx < 0 || !(lines[ntIdx + 1] || "").trim().startsWith("break")) {
		failures.push('(i) "if { var.notTriggered }" is missing or not followed by break');
	}

	// (j) every G27 Z1 is immediately followed by the G38 cancel
	const parkIdx = lines.map((l, i) => (/^\s*G27 Z1\s*$/.test(l) ? i : -1)).filter((i) => i >= 0);
	if (parkIdx.length === 0) failures.push("(j) no G27 Z1 lines found");
	for (const i of parkIdx) {
		if (!/^\s*M98 P"nxt-g38-cancel\.g"\s*$/.test(lines[i + 1] || "")) {
			failures.push(`(j) G27 Z1 at line ${i + 1} is not immediately followed by M98 P"nxt-g38-cancel.g"`);
		}
	}
	// (k) the pair-limit comparison is directly followed by the line that fails the set
	const pairCmp = lines.findIndex((l) => /^\s*if\s*\{\s*var\.pairDeltaMm\s*>\s*var\.limitMm\s*\}\s*$/.test(l));
	if (pairCmp < 0 || !/^\s*set\s+var\.pairsOk\s*=\s*false\s*$/.test(lines[pairCmp + 1] || "")) {
		failures.push("(k) pair-limit comparison is missing or not directly followed by set var.pairsOk = false");
	}

	// (l) exactly one line sets the pass flag, directly under the pass condition
	const passIdx = lines.map((l, i) => (/^\s*set\s+var\.passed\s*=\s*true\s*$/.test(l) ? i : -1)).filter((i) => i >= 0);
	if (passIdx.length !== 1) {
		failures.push(`(l) expected exactly one "set var.passed = true" line, found ${passIdx.length}`);
	} else if (!/^\s*if\s*\{\s*!var\.tolOn\s*\|\|\s*var\.pairsOk\s*\}\s*$/.test(lines[passIdx[0] - 1] || "")) {
		failures.push("(l) set var.passed = true is not directly under if { !var.tolOn || var.pairsOk }");
	}

	// (m) the three result lines take the running mean of the fine touches
	for (const [k, ax] of [[0, "X"], [1, "Y"], [2, "Z"]]) {
		const re = new RegExp(String.raw`^\s*set\s+var\.result\[${k}\]\s*=\s*\{\s*var\.mean${ax}\s*\}\s*$`);
		if (!lines.some((l) => re.test(l))) {
			failures.push(`(m) result[${k}] is not var.mean${ax}`);
		}
	}

	// (n) the probe feed is selected by the fast/fine flag
	if (!/set\s+var\.curSpeed\s*=\s*\{\s*var\.isFast\s*\?\s*var\.roughSpeed\s*:\s*var\.fineSpeed\s*\}/.test(text)) {
		failures.push("(n) curSpeed is not selected by var.isFast ? var.roughSpeed : var.fineSpeed");
	}

	// (o) every abort after the first G38 line has a G27 Z1 within the 8 lines before it
	const firstG38 = lines.findIndex((l) => /^\s*G53\s+G38\./.test(l));
	if (firstG38 < 0) failures.push("(o) no G53 G38 line found");
	lines.forEach((l, i) => {
		if (firstG38 >= 0 && i > firstG38 && /^\s*abort\b/.test(l)) {
			if (!lines.slice(Math.max(0, i - 8), i).some((x) => /^\s*G27 Z1\s*$/.test(x))) {
				failures.push(`(o) abort at line ${i + 1} has no G27 Z1 within the 8 lines before it`);
			}
		}
	});

	// (p) the repeatability failure abort is present
	if (!lines.some((l) => /^\s*abort\s*\{\s*var\.failMsg\s*\}\s*$/.test(l))) {
		failures.push("(p) abort { var.failMsg } is missing");
	}

	// (q) the Welford update matches the mirror: delta from the old mean, mean
	// weighted by 1/fineN (not 1/(fineN - 1), the issue 53 bug), then ss from the
	// new mean. Each set starts from mean 0 and ss 0.
	const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/ /g, "\\s*");
	for (const [k, ax] of [[0, "X"], [1, "Y"], [2, "Z"]]) {
		const steps = [
			`var delta${ax} = { var.cP[${k}] - var.mean${ax} }`,
			`set var.mean${ax} = { var.mean${ax} + var.delta${ax} / var.fineN }`,
			`set var.ss${ax} = { var.ss${ax} + var.delta${ax} * (var.cP[${k}] - var.mean${ax}) }`,
		].map((s) => lines.findIndex((l) => new RegExp(`^\\s*${esc(s)}\\s*$`).test(l)));
		if (steps.some((i) => i < 0) || !(steps[0] < steps[1] && steps[1] < steps[2])) {
			failures.push(`(q) Welford update for ${ax} is missing or out of order (delta, mean, ss)`);
		}
		for (const v of [`mean${ax}`, `ss${ax}`]) {
			const resets = lines.filter((l) => new RegExp(`^\\s+set\\s+var\\.${v}\\s*=\\s*0\\.0\\s*$`).test(l));
			if (resets.length !== 1) failures.push(`(q) expected one per-set reset "set var.${v} = 0.0", found ${resets.length}`);
		}
	}

	// (r) the variance is reported only: sd uses n - 1 under a guard for 2 or
	// more fine touches, and no condition or abort reads ss
	const guard = lines.findIndex((l) => /^\s*if\s*\{\s*!var\.notTriggered\s*&&\s*var\.fineN\s*>\s*1\s*\}\s*$/.test(l));
	if (guard < 0) failures.push("(r) no if { !var.notTriggered && var.fineN > 1 } guard for the report");
	for (const ax of ["X", "Y", "Z"]) {
		const sd = lines.findIndex((l) => l.includes(`sqrt(max(0.0, var.ss${ax}) / (var.fineN - 1))`));
		if (sd < 0) {
			failures.push(`(r) no sd expression sqrt(max(0.0, var.ss${ax}) / (var.fineN - 1))`);
		} else if (guard < 0 || sd < guard || indentOf(lines[sd]) <= indentOf(lines[guard])) {
			failures.push(`(r) sd for ${ax} at line ${sd + 1} is not inside the fineN > 1 guard`);
		}
	}
	lines.forEach((l, i) => {
		if (/^\s*(if|elif|while|abort)\b/.test(l) && /var\.ss[XYZ]\b/.test(l)) {
			failures.push(`(r) line ${i + 1} uses var.ss in a condition or abort; the variance is report-only`);
		}
	});
}

mirrorCases();
macroAssertions();

if (failures.length) {
	for (const f of failures) console.error(`${TAG}: ${f}`);
	process.exit(1);
}
console.log(`${TAG}: ok`);
