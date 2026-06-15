#!/usr/bin/env node
/**
 * Fail if any tracked text file contains CR (CRLF or lone CR).
 * RRF macro errors can cite wrong line numbers when CRLF slips into .g files.
 *
 * Usage (from repo root):
 *   node dist/check-line-endings.mjs
 *
 * Exit 0 = pass, 1 = CRLF found, 2 = usage/runtime error.
 */
"use strict";

import { execSync } from "child_process";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");

const BINARY_EXT = new Set([
	".pyc",
	".png",
	".jpg",
	".jpeg",
	".gif",
	".webp",
	".ico",
	".zip",
	".pdf",
	".woff",
	".woff2",
	".ttf",
	".eot",
]);

function listTrackedFiles() {
	try {
		const buf = execSync("git ls-files -z", { cwd: ROOT, encoding: "buffer" });
		return buf
			.toString("utf8")
			.split("\0")
			.filter(Boolean)
			.map((rel) => path.join(ROOT, rel));
	} catch {
		return null;
	}
}

function isBinaryPath(filePath) {
	return BINARY_EXT.has(path.extname(filePath).toLowerCase());
}

function hasCarriageReturn(filePath) {
	const buf = fs.readFileSync(filePath);
	for (let i = 0; i < buf.length; i++) {
		if (buf[i] === 0x0d) {
			return true;
		}
	}
	return false;
}

function main() {
	const tracked = listTrackedFiles();
	if (tracked == null) {
		console.error("check-line-endings: not a git repository (git ls-files failed)");
		process.exit(2);
	}

	const violations = [];
	for (const abs of tracked) {
		if (!fs.existsSync(abs) || !fs.statSync(abs).isFile()) {
			continue;
		}
		if (isBinaryPath(abs)) {
			continue;
		}
		if (hasCarriageReturn(abs)) {
			violations.push(path.relative(ROOT, abs).split(path.sep).join("/"));
		}
	}

	if (violations.length) {
		console.error("check-line-endings: CRLF or CR found in tracked text file(s):");
		for (const f of violations.sort()) {
			console.error(`  ${f}`);
		}
		console.error(
			"check-line-endings: normalize with: sed -i 's/\\r$//' <file>  (or re-checkout after .gitattributes)"
		);
		process.exit(1);
	}

	console.log(`check-line-endings: OK (${tracked.length} tracked path(s) scanned)`);
}

main();
