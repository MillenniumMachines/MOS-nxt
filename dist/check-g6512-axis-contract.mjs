#!/usr/bin/env node
/**
 * Enforce G6512 call-site contract: exactly one of X|Y|Z|A on each invocation.
 *
 * G6512 aborts when zero or multiple axis words are supplied. Canned cycles must
 * position with G6550/G0 first, then probe with a single motion axis.
 *
 * Usage (from repo root):
 *   node dist/check-g6512-axis-contract.mjs
 *
 * Exit 0 = pass, 1 = violations.
 */
"use strict";

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const SCAN_ROOT = path.join(ROOT, "macros");

/** Match bare G6512 (not G6512.1 / G6512.2) up to end-of-line. */
const G6512_LINE = /^\s*G6512(?!\.\d)\b(.*)$/i;
const AXIS_WORD = /\b([XYZA])\s*\{/gi;

function collectGFiles(dir, out) {
	if (!fs.existsSync(dir)) return;
	for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
		const abs = path.join(dir, ent.name);
		if (ent.isDirectory()) {
			collectGFiles(abs, out);
		} else if (ent.isFile() && ent.name.endsWith(".g")) {
			out.push(abs);
		}
	}
}

function axisWordsOnCall(rest) {
	const axes = [];
	AXIS_WORD.lastIndex = 0;
	let m;
	while ((m = AXIS_WORD.exec(rest)) !== null) {
		axes.push(m[1].toUpperCase());
	}
	return axes;
}

function checkFile(filePath) {
	const rel = path.relative(ROOT, filePath).split(path.sep).join("/");
	const text = fs.readFileSync(filePath, "utf8");
	const lines = text.split(/\r?\n/);
	const violations = [];

	for (let i = 0; i < lines.length; i++) {
		const raw = lines[i];
		const trimmed = raw.trim();
		if (!trimmed || trimmed.startsWith(";")) continue;
		const m = trimmed.match(G6512_LINE);
		if (!m) continue;
		// Skip the definition header comment patterns already filtered; this is G6512.g itself
		// which also has USAGE comments only — real calls inside G6512 are G38.2.
		const axes = axisWordsOnCall(m[1]);
		if (axes.length !== 1) {
			violations.push({
				file: rel,
				line: i + 1,
				axes: axes.length === 0 ? "(none)" : axes.join("+"),
				preview: trimmed.slice(0, 100) + (trimmed.length > 100 ? "…" : ""),
			});
		}
	}
	return violations;
}

function main() {
	const files = [];
	collectGFiles(SCAN_ROOT, files);
	const all = [];
	for (const f of files) {
		all.push(...checkFile(f));
	}
	if (all.length) {
		console.error("check-g6512-axis-contract: G6512 requires exactly one of X|Y|Z|A:");
		for (const v of all) {
			console.error(`  ${v.file}:${v.line} axes=${v.axes}  ${v.preview}`);
		}
		process.exit(1);
	}
	console.log(
		`check-g6512-axis-contract: ok (${files.length} macros; all G6512 calls are single-axis)`
	);
}

main();
