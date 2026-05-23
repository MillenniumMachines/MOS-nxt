#!/usr/bin/env node
/**
 * Fail if any RepRapFirmware macro line exceeds MAX_LEN characters.
 * RRF reports "GCode command too long" when startup/config macros blow the limit.
 *
 * Usage (from repo root):
 *   node dist/check-gcode-line-length.mjs
 *   node dist/check-gcode-line-length.mjs --max 200 macros
 *
 * Exit 0 = pass, 1 = violations found.
 */
"use strict";

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");

const DEFAULT_MAX = 200;
const DEFAULT_DIRS = ["macros"];

function parseArgs(argv) {
	const args = { max: DEFAULT_MAX, dirs: [...DEFAULT_DIRS] };
	for (let i = 2; i < argv.length; i++) {
		if (argv[i] === "--max" && argv[i + 1]) {
			args.max = Number(argv[++i]);
			if (!Number.isFinite(args.max) || args.max < 80) {
				console.error("check-gcode-line-length: --max must be a number >= 80");
				process.exit(2);
			}
		} else if (!argv[i].startsWith("-")) {
			args.dirs.push(argv[i]);
		}
	}
	return args;
}

function isSkippableLine(trimmed) {
	return trimmed.length === 0 || trimmed.startsWith(";");
}

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

function checkFile(filePath, maxLen) {
	const rel = path.relative(ROOT, filePath).split(path.sep).join("/");
	const text = fs.readFileSync(filePath, "utf8");
	const lines = text.split(/\r?\n/);
	const violations = [];

	for (let i = 0; i < lines.length; i++) {
		const raw = lines[i];
		const trimmed = raw.trim();
		if (isSkippableLine(trimmed)) continue;
		if (raw.length > maxLen) {
			violations.push({
				line: i + 1,
				len: raw.length,
				preview: raw.slice(0, 80) + (raw.length > 80 ? "…" : ""),
			});
		}
	}

	return violations.map((v) => ({ file: rel, ...v }));
}

function main() {
	const { max, dirs } = parseArgs(process.argv);
	const scanRoots = dirs.map((d) => path.resolve(ROOT, d));
	const files = [];
	for (const root of scanRoots) {
		collectGFiles(root, files);
	}

	if (files.length === 0) {
		console.error("check-gcode-line-length: no .g files under " + dirs.join(", "));
		process.exit(2);
	}

	const all = [];
	for (const f of files.sort()) {
		all.push(...checkFile(f, max));
	}

	if (all.length === 0) {
		console.log(
			`check-gcode-line-length: OK (${files.length} file(s), max ${max} chars per line)`
		);
		process.exit(0);
	}

	console.error(
		`check-gcode-line-length: FAILED — ${all.length} line(s) exceed ${max} characters:\n`
	);
	for (const v of all) {
		console.error(`  ${v.file}:${v.line} (${v.len} chars)`);
		console.error(`    ${v.preview}\n`);
	}
	console.error(
		"Fix: split compound if/echo/abort into var steps. See docs/RRF_LINE_LENGTH.md"
	);
	process.exit(1);
}

main();
