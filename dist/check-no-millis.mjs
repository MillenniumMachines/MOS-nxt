#!/usr/bin/env node
/**
 * Fail if macros call millis() — not a valid RRF meta function.
 * Use state.upTime * 1000 + state.msUpTime instead.
 *
 * Usage (from repo root):
 *   node dist/check-no-millis.mjs
 *   node dist/check-no-millis.mjs macros
 *
 * Exit 0 = pass, 1 = violations found.
 */
"use strict";

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const DEFAULT_DIRS = ["macros"];

const MILLIS_CALL = /\bmillis\s*\(/;

function parseArgs(argv) {
	const dirs = [];
	for (let i = 2; i < argv.length; i++) {
		if (!argv[i].startsWith("-")) {
			dirs.push(argv[i]);
		}
	}
	return { dirs: dirs.length > 0 ? dirs : [...DEFAULT_DIRS] };
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

function checkFile(filePath) {
	const rel = path.relative(ROOT, filePath).split(path.sep).join("/");
	const text = fs.readFileSync(filePath, "utf8");
	const lines = text.split(/\r?\n/);
	const violations = [];

	for (let i = 0; i < lines.length; i++) {
		const raw = lines[i];
		const trimmed = raw.trim();
		if (trimmed.length === 0 || trimmed.startsWith(";")) continue;

		const semi = raw.indexOf(";");
		const codePart = semi >= 0 ? raw.slice(0, semi) : raw;
		if (!MILLIS_CALL.test(codePart)) continue;

		violations.push({
			file: rel,
			line: i + 1,
			preview: trimmed.slice(0, 100) + (trimmed.length > 100 ? "…" : ""),
		});
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
			collectGFiles(abs, files);
		}
	}

	let all = [];
	for (const f of files) {
		all = all.concat(checkFile(f));
	}

	if (all.length === 0) {
		console.log(
			`check-no-millis: OK (${files.length} file(s); no millis() calls)`
		);
		process.exit(0);
	}

	console.error(
		"check-no-millis: FAIL — millis() is not a valid RRF meta function:\n"
	);
	for (const v of all) {
		console.error(`  ${v.file}:${v.line}: ${v.preview}`);
	}
	console.error(
		`\n${all.length} violation(s). Use { state.upTime * 1000 + state.msUpTime }.`
	);
	console.error("See docs/RRF_META_PITFALLS.md §1e.");
	process.exit(1);
}

main();
