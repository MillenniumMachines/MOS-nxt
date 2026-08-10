#!/usr/bin/env node
/**
 * Fail if macros use RRF `^` as if it were exponentiation (e.g. `dx^2`).
 * In RepRapFirmware meta, `^` is string/array concatenation — use `dx*dx` or pow(dx,2).
 *
 * Usage (from repo root):
 *   node dist/check-rrf-caret-power.mjs
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

/** Numeric exponent after ^ inside a meta expression — not string concat with digits alone outside {}. */
const CARET_POWER = /\^[0-9]+/;

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

function stripStrings(expr) {
	return expr.replace(/"(?:[^"\\]|\\.)*"/g, '""').replace(/'(?:[^'\\]|\\.)*'/g, "''");
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

		// Only flag ^digits inside { … } meta expressions (math context)
		let searchFrom = 0;
		while (searchFrom < raw.length) {
			const open = raw.indexOf("{", searchFrom);
			if (open < 0) break;
			const close = raw.indexOf("}", open + 1);
			if (close < 0) break;
			const expr = stripStrings(raw.slice(open + 1, close));
			if (CARET_POWER.test(expr)) {
				violations.push({
					file: rel,
					line: i + 1,
					preview: trimmed.slice(0, 100) + (trimmed.length > 100 ? "…" : ""),
				});
				break;
			}
			searchFrom = close + 1;
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

	if (all.length === 0) {
		console.log(`check-rrf-caret-power: OK (${files.length} macros; no ^N power misuse in {…})`);
		process.exit(0);
	}

	console.error("check-rrf-caret-power: RRF ^ is concatenation, not power. Use x*x or pow(x,2):\n");
	for (const v of all) {
		console.error(`  ${v.file}:${v.line}: ${v.preview}`);
	}
	console.error(`\n${all.length} violation(s)`);
	process.exit(1);
}

main();
