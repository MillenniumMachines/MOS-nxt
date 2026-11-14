#!/usr/bin/env node
/**
 * Regression check for G6512 touch sampling (issue #52).
 *
 * 1. Mirrors the sampling rule the macro must implement (sampleG6512) and
 *    verifies it against fixed cases.
 * 2. Asserts on the text of macros/probing/G6512.g so the macro keeps to that rule.
 *
 * Usage (from repo root):
 *   node dist/check-g6512-sampling.mjs [macro-path]
 *
 * The optional path checks another copy of the macro (default macros/probing/G6512.g).
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
	: path.join(ROOT, "macros", "probing", "G6512.g");
const EPS = 1e-9;
const TAG = "check-g6512-sampling";

/**
 * Mirror of when G6512 has a fast first touch: only without F, and only when
 * the rough feed is above the fine feed after the touch-probe caps. A slower
 * first touch (misconfigured probe) or any call with F counts every touch.
 * @param {{roughSpeed: number, fineSpeed: number, fGiven: boolean}} opts feeds after the caps
 */
function fastFirstOf(opts) {
	const { roughSpeed, fineSpeed, fGiven } = opts;
	return !fGiven && roughSpeed > fineSpeed;
}

/**
 * Mirror of the feed of the first touch of a set (var.speed before the inner loop). It is the
 * rough feed for the fast touch and wherever there is no faster first touch (F given, equal
 * feeds, rough below fine: the base behaviour); the fine feed only in a retry set after a fast touch.
 * @param {{roughSpeed: number, fineSpeed: number, fGiven: boolean, set: number}} opts set is 0 for the first set
 */
function firstFeedOf(opts) {
	const { roughSpeed, fineSpeed, set } = opts;
	const fastFirst = fastFirstOf(opts);
	const fastLeft = fastFirst && set === 0;
	return fastLeft || !fastFirst ? roughSpeed : fineSpeed;
}

/**
 * Mirror of the G6512 sampling rule. A faster first touch only locates the
 * surface: it is dropped from the pair check and the average.
 * @param {{touches: number[], fastFirst: boolean, limitMm: number, outerRetries: number, count: number}} opts
 */
function sampleG6512(opts) {
	const { touches, fastFirst, limitMm, outerRetries, count } = opts;
	const tolOn = limitMm > 0;
	const n = tolOn ? 3 : Math.max(1, count);
	const maxAttempts = tolOn ? outerRetries + 1 : 1;
	let used = 0;
	let failedPair = null;
	let attempts = 0;

	for (let a = 0; a < maxAttempts; a++) {
		attempts++;
		if (a === 0 && fastFirst) used++; // dropped from everything
		const batch = [];
		for (let i = 0; i < n; i++) batch.push(touches[used++]);
		let pass = true;
		if (tolOn) {
			for (let i = 0; i < n - 1; i++) {
				if (Math.abs(batch[i] - batch[i + 1]) > limitMm) {
					pass = false;
					failedPair = `${i + 1}-${i + 2}`;
				}
			}
		}
		if (pass) {
			const result = batch.reduce((s, v) => s + v, 0) / n;
			return { ok: true, result, attempts, touchesUsed: used, failedPair: null };
		}
	}
	return { ok: false, result: null, attempts, touchesUsed: used, failedPair };
}

const failures = [];
function expect(name, cond, detail) {
	if (!cond) failures.push(`mirror case "${name}": ${detail}`);
}
const near = (a, b) => typeof a === "number" && Math.abs(a - b) < EPS;
const base = { fastFirst: true, limitMm: 0.075, outerRetries: 1, count: 3 };

function mirrorCases() {
	let r = sampleG6512({ ...base, touches: [10.2, 10.0, 10.004, 10.002] });
	expect("fast touch excluded", r.ok && near(r.result, 10.002) && r.touchesUsed === 4, JSON.stringify(r));

	r = sampleG6512({ ...base, outerRetries: 0, touches: [10.1, 10.0, 10.001, 10.002] });
	expect("old bug passes now", r.ok, JSON.stringify(r));

	r = sampleG6512({ ...base, fastFirst: false, touches: [10.0, 10.004, 10.002] });
	expect("F given unchanged", r.ok && near(r.result, 10.002) && r.touchesUsed === 3, JSON.stringify(r));

	r = sampleG6512({ ...base, touches: [10.2, 10.0, 10.19, 10.0, 10.001, 10.0, 10.002] });
	expect(
		"retry has no fast touch",
		r.ok && r.attempts === 2 && near(r.result, 10.001) && r.touchesUsed === 7,
		JSON.stringify(r)
	);

	r = sampleG6512({ ...base, touches: [10.2, 10.0, 10.0, 10.6, 10.0, 10.0, 10.6] });
	expect("persistent fail", !r.ok && r.failedPair === "2-3" && r.attempts === 2, JSON.stringify(r));

	r = sampleG6512({ ...base, fastFirst: false, limitMm: 0, count: 1, touches: [12.345] });
	expect("quick find unchanged", r.ok && near(r.result, 12.345) && r.touchesUsed === 1, JSON.stringify(r));

	r = sampleG6512({ ...base, limitMm: 0, count: 2, touches: [9.9, 10.0, 10.2] });
	expect("limit 0 with fast", r.ok && near(r.result, 10.1) && r.touchesUsed === 3, JSON.stringify(r));

	expect("no F, faster first touch", fastFirstOf({ roughSpeed: 200, fineSpeed: 50, fGiven: false }) === true, "want true");
	expect("no F, slower first touch", fastFirstOf({ roughSpeed: 40, fineSpeed: 50, fGiven: false }) === false, "want false");
	expect("no F, equal feeds", fastFirstOf({ roughSpeed: 50, fineSpeed: 50, fGiven: false }) === false, "want false");
	// First-touch feed of each set. A probe with rough below fine (M558 F30:60, capped to 30/50)
	// keeps the base feeds and touch count: rough on the first touch of every set, no extra touch.
	const slow = { roughSpeed: 30, fineSpeed: 50, fGiven: false };
	expect("rough<fine feed, set 0", firstFeedOf({ ...slow, set: 0 }) === 30, "want rough 30");
	expect("rough<fine feed, retry set", firstFeedOf({ ...slow, set: 1 }) === 30, "want rough 30");
	r = sampleG6512({ ...base, fastFirst: fastFirstOf(slow), touches: [10.0, 10.004, 10.002] });
	expect("rough<fine touch count", r.ok && r.touchesUsed === 3, JSON.stringify(r));
	const fast = { roughSpeed: 200, fineSpeed: 50, fGiven: false };
	expect("fast feed, set 0", firstFeedOf({ ...fast, set: 0 }) === 200, "want rough 200");
	expect("fast feed, retry set", firstFeedOf({ ...fast, set: 1 }) === 50, "want fine 50");
	expect("F feed, retry set", firstFeedOf({ roughSpeed: 200, fineSpeed: 50, fGiven: true, set: 1 }) === 200, "want rough 200");
	// G6511 quick find: F200 on the touch probe, fine capped to 50 — still one counted touch
	expect("F given, caps run touch 1 faster", fastFirstOf({ roughSpeed: 200, fineSpeed: 50, fGiven: true }) === false, "want false");
}

function macroAssertions() {
	if (!fs.existsSync(MACRO)) {
		failures.push(`macro assertions: ${MACRO} not found`);
		return;
	}
	const text = fs.readFileSync(MACRO, "utf8");
	const lines = text.split(/\r?\n/);
	const indentOf = (l) => l.match(/^\s*/)[0].replace(/\t/g, "    ").length;
	const idxOf = (re) => lines.findIndex((l) => re.test(l));

	// (a) fastFirst starts false at the top level and is set only after the touch-probe cap block,
	// for a faster first touch (a slower first touch on a misconfigured probe must not add a touch)
	const capIdx = idxOf(/^\s*set\s+var\.fineSpeed\s*=\s*50\s*$/);
	const ffIdx = idxOf(/^var\s+fastFirst\s*=\s*false\s*$/);
	const ffSets = lines.map((l, i) => (/^\s*set\s+var\.fastFirst\b/.test(l) ? i : -1)).filter((i) => i >= 0);
	const ffSetRe = /^\s*set\s+var\.fastFirst\s*=\s*\{\s*var\.roughSpeed\s*>\s*var\.fineSpeed\s*\}\s*$/;
	if (ffIdx < 0) failures.push("(a) missing top-level line: var fastFirst = false");
	if (ffSets.length !== 1 || !ffSetRe.test(lines[ffSets[0]])) {
		failures.push("(a) the only set var.fastFirst must be: set var.fastFirst = { var.roughSpeed > var.fineSpeed }");
	} else if (capIdx < 0 || ffSets[0] < capIdx) {
		failures.push("(a) set var.fastFirst is not after the touch-probe cap block (set var.fineSpeed = 50)");
	}

	// (b) isFast
	if (!/^\s*var\s+isFast\s*=\s*\{\s*var\.fastLeft\s*&&\s*var\.touchIdx\s*==\s*0\s*\}\s*$/m.test(text)) {
		failures.push("(b) missing line: var isFast = { var.fastLeft && var.touchIdx == 0 }");
	}

	// (c) every assignment to sum, count, hitSumX, hitSumY or hitN (in any form) sits inside an
	// `if { !var.isFast }` block
	const accRe = /^\s*set\s+var\.(sum|count|hitSumX|hitSumY|hitN)\s*=/;
	const accIdx = lines.map((l, i) => (accRe.test(l) ? i : -1)).filter((i) => i >= 0);
	if (accIdx.length < 5) failures.push(`(c) expected 5 accumulation lines, found ${accIdx.length}`);
	for (const i of accIdx) {
		let min = indentOf(lines[i]);
		let ok = false;
		for (let j = i - 1; j >= 0; j--) {
			if (lines[j].trim() === "" || indentOf(lines[j]) >= min) continue;
			if (/^\s*if\s*\{\s*!\s*var\.isFast\s*\}\s*$/.test(lines[j])) {
				ok = true;
				break;
			}
			min = indentOf(lines[j]);
			if (min === 0) break;
		}
		if (!ok) failures.push(`(c) line ${i + 1} accumulates outside an "if { !var.isFast }" block`);
	}

	// (d) no innerIdx; the three pair-check branches test exactly sampleIdx 0, 1, 2 (not touchIdx)
	lines.forEach((l, i) => {
		if (l.includes("var.innerIdx")) failures.push(`(d) line ${i + 1} still uses var.innerIdx`);
		if (/^\s*(if|elif)\b.*var\.touchIdx/.test(l)) failures.push(`(d) line ${i + 1} branches on var.touchIdx`);
	});
	const pairConds = [
		/^\s*if\s*\{\s*var\.toleranceEnabled\s*&&\s*var\.sampleIdx\s*==\s*0\s*\}\s*$/,
		/^\s*elif\s*\{\s*var\.toleranceEnabled\s*&&\s*var\.sampleIdx\s*==\s*1\s*\}\s*$/,
		/^\s*elif\s*\{\s*var\.toleranceEnabled\s*&&\s*var\.sampleIdx\s*==\s*2\s*\}\s*$/,
	];
	const pairAt = pairConds.map((re) => idxOf(re));
	if (pairAt.some((i, k) => i < 0 || (k > 0 && i <= pairAt[k - 1]))) {
		failures.push("(d) pair-check conditions must be, in order: toleranceEnabled && var.sampleIdx == 0 (if), == 1 (elif), == 2 (elif)");
	}

	// The attempt loop, its body indent and the inner touch loop, shared by (e), (h), (i) and (j)
	const attemptIdx = idxOf(/^\s*while\s*\{\s*var\.attempt\s*</);
	const bodyIndent = attemptIdx < 0 ? -1 : indentOf(lines[attemptIdx]) + 4;
	let innerIdx = -1;
	if (attemptIdx >= 0) {
		for (let i = attemptIdx + 1; i < lines.length; i++) {
			if (lines[i].trim() === "") continue;
			if (indentOf(lines[i]) <= indentOf(lines[attemptIdx])) break;
			if (indentOf(lines[i]) === bodyIndent && /^\s*while\b/.test(lines[i])) {
				innerIdx = i;
				break;
			}
		}
	}
	// First line after the inner loop body (next non-blank line at or below the attempt body indent)
	let innerEnd = lines.length;
	if (innerIdx >= 0) {
		for (let i = innerIdx + 1; i < lines.length; i++) {
			if (lines[i].trim() !== "" && indentOf(lines[i]) <= bodyIndent) {
				innerEnd = i;
				break;
			}
		}
	}
	const isCode = (l) => l.trim() !== "" && !l.trim().startsWith(";");
	// Nearest enclosing line (lower indent), skipping blank and comment lines
	const parentOf = (i) => {
		for (let j = i - 1; j >= 0; j--) {
			if (isCode(lines[j]) && indentOf(lines[j]) < indentOf(lines[i])) return j;
		}
		return -1;
	};
	const fGuardRe = /^\s*if\s*\{\s*exists\s*\(\s*param\.F\s*\)\s*\}\s*$/;

	// (e) fastLeft cleared in the attempt loop body, after the inner touch loop
	if (attemptIdx < 0) {
		failures.push("(e) attempt loop not found");
	} else {
		let found = false;
		if (innerIdx >= 0) {
			for (let i = innerIdx + 1; i < lines.length; i++) {
				if (lines[i].trim() === "") continue;
				if (indentOf(lines[i]) <= indentOf(lines[attemptIdx])) break;
				if (indentOf(lines[i]) === bodyIndent && /^\s*set\s+var\.fastLeft\s*=\s*false\s*$/.test(lines[i])) {
					found = true;
					break;
				}
			}
		}
		if (!found) failures.push("(e) no set var.fastLeft = false after the inner touch loop inside the attempt loop");
		// Retry rule: declared once at the top level before the attempt loop, never re-armed; the only
		// set is the clear at the attempt-body indent after the inner touch loop
		const flDecl = idxOf(/^var\s+fastLeft\s*=\s*\{\s*var\.fastFirst\s*\}\s*$/);
		if (flDecl < 0 || flDecl > attemptIdx || indentOf(lines[attemptIdx]) !== 0) {
			failures.push("(e) var fastLeft = { var.fastFirst } must be a top-level line before the attempt loop");
		}
		lines.forEach((l, i) => {
			if (!/^\s*set\s+var\.fastLeft\b/.test(l)) return;
			const okForm =
				/^\s*set\s+var\.fastLeft\s*=\s*false\s*$/.test(l) &&
				innerIdx >= 0 &&
				i >= innerEnd &&
				indentOf(l) === bodyIndent &&
				parentOf(i) === attemptIdx;
			if (!okForm) failures.push(`(e) line ${i + 1}: the only set var.fastLeft allowed is "set var.fastLeft = false" in the attempt body after the inner loop`);
		});
	}

	// (f) speed selection: base feeds unless this is a retry set after a fast touch
	if (
		!/^\s*var\s+speed\s*=\s*\{\s*\(\s*var\.fastLeft\s*\|\|\s*!\s*var\.fastFirst\s*\)\s*\?\s*var\.roughSpeed\s*:\s*var\.fineSpeed\s*\}\s*$/m.test(text)
	) {
		failures.push("(f) missing line: var speed = { (var.fastLeft || !var.fastFirst) ? var.roughSpeed : var.fineSpeed }");
	}
	// The feed switches to fine after each touch, inside the inner loop body
	const fineSet = lines
		.map((l, i) => (/^\s*set\s+var\.speed\s*=\s*\{\s*var\.fineSpeed\s*\}\s*$/.test(l) ? i : -1))
		.filter((i) => i >= 0);
	if (!fineSet.some((i) => innerIdx >= 0 && i > innerIdx && i < innerEnd && indentOf(lines[i]) === bodyIndent + 4)) {
		failures.push("(f) no set var.speed = { var.fineSpeed } in the inner touch loop body");
	}

	// (g) fastFirst is set only under a top-level `if { !exists(param.F) }`, between `var fastFirst`
	// and `var fastLeft` (with F there is no fast touch, and G6511's F200 R1 L0 quick find, where the
	// caps lower fine to 50, stays at one touch; the feeds are never compared when F binds)
	const fastLeftIdx = idxOf(/^\s*var\s+fastLeft\s*=\s*\{\s*var\.fastFirst\s*\}\s*$/);
	if (fastLeftIdx < 0) {
		failures.push("(g) missing line: var fastLeft = { var.fastFirst }");
	} else {
		const i = ffSets.length === 1 ? ffSets[0] : -1;
		const p = i >= 0 ? parentOf(i) : -1;
		const ok =
			p >= 0 &&
			/^if\s*\{\s*!\s*exists\s*\(\s*param\.F\s*\)\s*\}\s*$/.test(lines[p]) &&
			ffIdx >= 0 &&
			ffIdx < p &&
			i < fastLeftIdx;
		if (!ok) {
			failures.push("(g) set var.fastFirst is not under a top-level if { !exists(param.F) } between var fastFirst and var fastLeft");
		}
	}

	// (h) with F, the first touch of every set runs at roughSpeed, as before: in the attempt body,
	// after `var speed = …` and before the inner loop, `set var.speed = { var.roughSpeed }`
	// nested under `if { exists(param.F) }`
	if (attemptIdx < 0 || innerIdx < 0) {
		failures.push("(h) attempt loop or inner touch loop not found");
	} else {
		const speedIdx = lines.findIndex(
			(l, i) => i > attemptIdx && i < innerIdx && indentOf(l) === bodyIndent && /^\s*var\s+speed\s*=/.test(l)
		);
		const ok = lines.some((l, i) => {
			if (!/^\s*set\s+var\.speed\s*=\s*\{\s*var\.roughSpeed\s*\}\s*$/.test(l)) return false;
			const p = parentOf(i);
			return (
				p >= 0 &&
				fGuardRe.test(lines[p]) &&
				indentOf(lines[p]) === bodyIndent &&
				speedIdx >= 0 &&
				speedIdx < p &&
				i < innerIdx
			);
		});
		if (!ok) {
			failures.push(
				"(h) no if { exists(param.F) } / set var.speed = { var.roughSpeed } in the attempt body between var speed and the inner loop"
			);
		}
	}

	// (i) the first set runs one extra touch while the fast touch is left
	const boundRe = /^\s*while\s*\{\s*var\.touchIdx\s*<\s*var\.retries\s*\+\s*\(\s*var\.fastLeft\s*\?\s*1\s*:\s*0\s*\)\s*\}\s*$/;
	if (innerIdx < 0 || !boundRe.test(lines[innerIdx])) {
		failures.push("(i) inner touch loop is not: while { var.touchIdx < var.retries + (var.fastLeft ? 1 : 0) }");
	}

	// (j) kept touches are numbered from 0 after the fast touch, inside the inner loop body
	const sampleRe = /^\s*var\s+sampleIdx\s*=\s*\{\s*var\.fastLeft\s*\?\s*var\.touchIdx\s*-\s*1\s*:\s*var\.touchIdx\s*\}\s*$/;
	const sampleOk = innerIdx >= 0 && lines.some((l, i) => sampleRe.test(l) && i > innerIdx && i < innerEnd);
	if (!sampleOk) {
		failures.push("(j) missing in the inner loop: var sampleIdx = { var.fastLeft ? var.touchIdx - 1 : var.touchIdx }");
	}
}

mirrorCases();
macroAssertions();

if (failures.length) {
	for (const f of failures) console.error(`${TAG}: ${f}`);
	process.exit(1);
}
console.log(`${TAG}: ok`);
