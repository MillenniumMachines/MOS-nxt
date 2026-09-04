#!/usr/bin/env node
/**
 * Fail if macros use M98 to run numbered meta files (M####.g / G####.g).
 * Those files live on 0:/sys/ after release sync and must be invoked as M#### / G####
 * so parameters like P are not stolen by M98's filename letter.
 *
 * Also fail a second P on the same M98 line (named helpers: M98 P"nxt-….g" P1).
 * M98 still reserves P for the filename; pass Q / I / W instead.
 *
 * Usage (from repo root):
 *   node dist/check-m98-numbered-meta.mjs
 *   node dist/check-m98-numbered-meta.mjs macros
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

/** Basename like M6520.g, G6508.1.g (optional subcode). */
const NUMBERED_META_BASENAME = /^[MG]\d+(?:\.\d+)?\.g$/i;

/** M98 P"…M6520.g" or M98 P"0:/sys/G6503.g" (any path; basename decides). */
const M98_P_STRING = /\bM98\b[^;\n]*?\bP\s*"([^"]+)"/gi;

/** Nested P after the filename (P1, P{…}, P0.1). */
const NESTED_M98_P = /\bP(?:\s*[0-9{.-]|\s*$)/;

function stripInlineComment(raw) {
	let out = "";
	let inStr = false;
	for (let i = 0; i < raw.length; i++) {
		const c = raw[i];
		if (c === '"') {
			inStr = !inStr;
			out += c;
			continue;
		}
		if (c === ";" && !inStr) {
			break;
		}
		out += c;
	}
	return out;
}

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

function basenameFromP(pArg) {
	const normalized = pArg.replace(/\\/g, "/");
	const parts = normalized.split("/");
	return parts[parts.length - 1] || normalized;
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
		const codeLine = stripInlineComment(raw);

		M98_P_STRING.lastIndex = 0;
		let m;
		while ((m = M98_P_STRING.exec(codeLine)) !== null) {
			const pArg = m[1];
			const base = basenameFromP(pArg);
			const preview = trimmed.slice(0, 100) + (trimmed.length > 100 ? "…" : "");
			if (NUMBERED_META_BASENAME.test(base)) {
				const code = base.replace(/\.g$/i, "");
				violations.push({
					file: rel,
					line: i + 1,
					kind: "numbered",
					pArg,
					code: code.toUpperCase(),
					preview,
				});
				continue;
			}
			const rest = codeLine.slice(m.index + m[0].length);
			if (NESTED_M98_P.test(rest)) {
				violations.push({
					file: rel,
					line: i + 1,
					kind: "nested-p",
					pArg,
					code: null,
					preview,
				});
			}
		}
	}

	return violations;
}

function main() {
	const { dirs } = parseArgs(process.argv);
	const files = [];
	for (const d of dirs) {
		collectGFiles(path.resolve(ROOT, d), files);
	}

	const all = [];
	for (const f of files) {
		all.push(...checkFile(f));
	}

	if (all.length === 0) {
		console.log(
			`check-m98-numbered-meta: OK (${files.length} file(s); no M98 → M####/G####; no nested P)`
		);
		process.exit(0);
	}

	console.error(
		"check-m98-numbered-meta: FAIL — numbered macros via M98, or nested P on M98:\n"
	);
	for (const v of all) {
		console.error(`  ${v.file}:${v.line}`);
		console.error(`    ${v.preview}`);
		if (v.kind === "nested-p") {
			console.error(
				`    → M98 cannot pass P (filename). Use Q, I, or W — not P\n`
			);
		} else {
			console.error(`    → use ${v.code} … (not M98 P"${v.pArg}")\n`);
		}
	}
	console.error(
		`check-m98-numbered-meta: ${all.length} violation(s). See .cursor/rules/rrf-numbered-meta-m98.mdc`
	);
	process.exit(1);
}

main();
