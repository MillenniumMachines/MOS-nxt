#!/usr/bin/env node
/**
 * Fail if M6520 is invoked with bare axis letters (X/Y/Z/A without a number).
 * RRF numbered meta often does not bind exists(param.X) for bare letters;
 * M6520 only tests exists(), so callers must use X1 Y1 Z1 A1 (value ignored).
 *
 * Usage (from repo root):
 *   node dist/check-m6520-axis-flags.mjs
 *   node dist/check-m6520-axis-flags.mjs macros ui
 *
 * Exit 0 = pass, 1 = violations found.
 */
"use strict";

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const DEFAULT_DIRS = ["macros", "ui"];

/** M6520 … then a bare X/Y/Z/A not followed by a digit (word boundary). */
const BARE_AXIS_AFTER_M6520 = /\bM6520\b[^;\n]*?\b([XYZA])(?!\d)/g;

const TEXT_EXTS = new Set([".g", ".vue", ".ts", ".js", ".mjs", ".md"]);

function parseArgs(argv) {
	const dirs = [];
	for (let i = 2; i < argv.length; i++) {
		if (!argv[i].startsWith("-")) {
			dirs.push(argv[i]);
		}
	}
	return { dirs: dirs.length > 0 ? dirs : [...DEFAULT_DIRS] };
}

function collectFiles(dir, out) {
	if (!fs.existsSync(dir)) return;
	for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
		const abs = path.join(dir, ent.name);
		if (ent.isDirectory()) {
			if (ent.name === "node_modules" || ent.name === "generated") continue;
			collectFiles(abs, out);
		} else if (ent.isFile() && TEXT_EXTS.has(path.extname(ent.name))) {
			out.push(abs);
		}
	}
}

function stripQuotes(s) {
	return s.replace(/"[^"]*"/g, '""').replace(/'[^']*'/g, "''");
}

function checkFile(filePath) {
	const rel = path.relative(ROOT, filePath).split(path.sep).join("/");
	const text = fs.readFileSync(filePath, "utf8");
	const lines = text.split(/\r?\n/);
	const violations = [];
	const isGcode = path.extname(filePath) === ".g";

	for (let i = 0; i < lines.length; i++) {
		const raw = lines[i];
		const trimmed = raw.trim();
		if (trimmed.length === 0) continue;
		if (trimmed.startsWith(";") && isGcode) continue;

		let codePart = raw;
		if (isGcode) {
			const semi = raw.indexOf(";");
			if (semi >= 0) codePart = raw.slice(0, semi);
		}
		codePart = stripQuotes(codePart);

		if (!/\bM6520\b/.test(codePart)) continue;
		// G-code: only flag actual invocations (line starts with M6520 after ws)
		if (isGcode && !/^\s*M6520\b/.test(codePart)) continue;

		BARE_AXIS_AFTER_M6520.lastIndex = 0;
		let m;
		while ((m = BARE_AXIS_AFTER_M6520.exec(codePart)) !== null) {
			violations.push({
				file: rel,
				line: i + 1,
				letter: m[1],
				preview: trimmed.slice(0, 100) + (trimmed.length > 100 ? "…" : ""),
			});
		}
	}
	return violations;
}

function main() {
	const { dirs } = parseArgs(process.argv);
	const files = [];
	for (const d of dirs) {
		const abs = path.isAbsolute(d) ? d : path.join(ROOT, d);
		if (fs.existsSync(abs) && fs.statSync(abs).isFile()) {
			files.push(abs);
		} else {
			collectFiles(abs, files);
		}
	}

	let all = [];
	for (const f of files) {
		all = all.concat(checkFile(f));
	}

	if (all.length === 0) {
		console.log(
			`check-m6520-axis-flags: OK (${files.length} file(s); no bare X/Y/Z/A on M6520)`
		);
		process.exit(0);
	}

	console.error("check-m6520-axis-flags: FAIL — use X1/Y1/Z1/A1 (RRF meta presence flags):\n");
	for (const v of all) {
		console.error(`  ${v.file}:${v.line}: bare ${v.letter} — ${v.preview}`);
	}
	console.error(
		`\n${all.length} violation(s). See docs/RRF_META_PITFALLS.md §1c.`
	);
	process.exit(1);
}

main();
