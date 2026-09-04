#!/usr/bin/env node
/**
 * Regression gate for ui/src/utils/nxtCalibrationMath.ts
 * Runs runNxtCalibrationMathSelfTest() from the source module.
 *
 * Usage: node dist/check-calibration-math.mjs
 */
"use strict";

import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const mathTs = path.join(ROOT, "ui/src/utils/nxtCalibrationMath.ts");

function runWithStripTypes() {
	return spawnSync(
		process.execPath,
		[
			"--experimental-strip-types",
			"--input-type=module",
			"-e",
			`import { runNxtCalibrationMathSelfTest } from ${JSON.stringify(mathTs)};\nrunNxtCalibrationMathSelfTest();\nconsole.log("check-calibration-math: ok");\n`,
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
			`import { runNxtCalibrationMathSelfTest } from ${JSON.stringify(mathTs)}; runNxtCalibrationMathSelfTest(); console.log("check-calibration-math: ok");`,
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
		console.error("check-calibration-math:", msg);
		process.exit(1);
	}
	console.log("check-calibration-math: ok");
}

main();
