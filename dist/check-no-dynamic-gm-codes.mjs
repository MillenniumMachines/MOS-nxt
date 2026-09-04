#!/usr/bin/env node
/**
 * Fail if macros use dynamic G/M command numbers (G{…} / M{…}).
 * RRF only allows dynamic numbers on T-codes (T{expr}).
 *
 * Usage (from repo root):
 *   node dist/check-no-dynamic-gm-codes.mjs
 *   node dist/check-no-dynamic-gm-codes.mjs macros
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

/** Executable line starts with G{ or M{ (optional leading whitespace). */
const DYNAMIC_GM = /^\s*[GM]\{/;

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
		if (!DYNAMIC_GM.test(codePart)) continue;

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
			`check-no-dynamic-gm-codes: OK (${files.length} file(s); no G{/M{ command numbers)`
		);
		process.exit(0);
	}

	console.error(
		"check-no-dynamic-gm-codes: FAIL — RRF allows dynamic numbers only on T-codes:\n"
	);
	for (const v of all) {
		console.error(`  ${v.file}:${v.line}: ${v.preview}`);
	}
	console.error(
		`\n${all.length} violation(s). Use literal G54…G59.3 or M98 P"nxt-select-wcs.g" W{n}.`
	);
	console.error("See docs/RRF_META_PITFALLS.md §1d.");
	process.exit(1);
}

main();
