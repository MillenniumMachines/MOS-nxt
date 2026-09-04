#!/usr/bin/env node
/**
 * Regression gate for ui/src/utils/nxtWcsZMath.ts
 *
 * Usage: node dist/check-wcs-z-math.mjs
 */
"use strict";

import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const mathTs = path.join(ROOT, "ui/src/utils/nxtWcsZMath.ts");

function runWithStripTypes() {
	return spawnSync(
		process.execPath,
		[
			"--experimental-strip-types",
			"--input-type=module",
			"-e",
			`import { runNxtWcsZMathSelfTest } from ${JSON.stringify(mathTs)};\nrunNxtWcsZMathSelfTest();\nconsole.log("check-wcs-z-math: ok");\n`,
		],
		{ cwd: ROOT, encoding: "utf8" }
	);
}

function runWithTsx() {
	return spawnSync(
		"npx",
		[
			"--yes",
			"tsx",
			"--eval",
			`import { runNxtWcsZMathSelfTest } from ${JSON.stringify(mathTs)}; runNxtWcsZMathSelfTest(); console.log("check-wcs-z-math: ok");`,
		],
		{ cwd: ROOT, encoding: "utf8", env: process.env }
	);
}

function main() {
	let result = runWithStripTypes();
	if (result.status !== 0) {
		const stripErr = (result.stderr || result.stdout || "").trim();
		if (/experimental-strip-types|Unknown|Cannot find module|ERR/.test(stripErr)) {
			result = runWithTsx();
		}
	}
	if (result.status !== 0) {
		const msg = (result.stderr || result.stdout || "unknown error").trim();
		console.error("check-wcs-z-math:", msg);
		process.exit(1);
	}
	console.log("check-wcs-z-math: ok");
}

main();
