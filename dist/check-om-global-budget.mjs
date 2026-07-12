#!/usr/bin/env node
/**
 * Enforce nxt global OM size hygiene (SBC ~8KB key=global budget).
 *
 * Usage (from repo root):
 *   node dist/check-om-global-budget.mjs
 *
 * Exit 0 = pass, 1 = violations.
 *
 * See docs/OM_GLOBAL_SIZE.md and .cursor/rules/om-global-size.mdc.
 */
"use strict";

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");

const failures = [];

function read(rel) {
	const abs = path.join(ROOT, rel);
	if (!fs.existsSync(abs)) {
		failures.push(`missing required file: ${rel}`);
		return "";
	}
	return fs.readFileSync(abs, "utf8");
}

function stripComments(gcode) {
	return gcode
		.split(/\r?\n/)
		.map((line) => {
			const t = line.trim();
			if (t.startsWith(";")) return "";
			const semi = line.indexOf(";");
			return semi >= 0 ? line.slice(0, semi) : line;
		})
		.join("\n");
}

// --- nxt-vars.g: no always-on Custom platform keys ---
{
	const body = stripComments(read("macros/system/nxt-vars.g"));
	const re = /^\s*global\s+nxtCustom\w+/gm;
	const hits = body.match(re) || [];
	if (hits.length) {
		failures.push(
			`macros/system/nxt-vars.g must not declare Custom keys (found ${hits.length}): ` +
				hits.slice(0, 8).join(", ") +
				(hits.length > 8 ? "…" : "") +
				" — use nxt-custom-globals.g / per-key declare"
		);
	}
}

// --- nxt-boot.g: must not pre-fill nxtProbeResults with zero vectors ---
{
	const body = stripComments(read("macros/system/nxt-boot.g"));
	if (/nxtProbeResults\s*\[\s*iterations\s*\]\s*=\s*\{\s*vector\s*\(/i.test(body)) {
		failures.push(
			"macros/system/nxt-boot.g must not pre-fill nxtProbeResults rows with vector(...); leave null until a cycle writes"
		);
	}
	if (/nxtProbeResults\s*\[\s*\w+\s*\]\s*=\s*\{\s*vector\s*\([^)]*0\.0/i.test(body)) {
		failures.push(
			"macros/system/nxt-boot.g appears to expand nxtProbeResults with 0.0 vectors (OM bloat)"
		);
	}
}

// --- nxt-tooltable.g: null-filled nxtTT ---
{
	const body = stripComments(read("macros/system/nxt-tooltable.g"));
	if (/global\s+nxtTT\s*=\s*\{\s*vector\s*\(\s*limits\.tools\s*,\s*global\.nxtET\s*\)/i.test(body)) {
		failures.push(
			"macros/system/nxt-tooltable.g must not fill nxtTT with nxtET templates; use vector(limits.tools, null)"
		);
	}
	if (
		/global\s+nxtTT\s*=/.test(body) &&
		!/vector\s*\(\s*limits\.tools\s*,\s*null\s*\)/i.test(body)
	) {
		// Allow copy from mosTT; require null fill on fresh allocate
		if (!/global\s+nxtTT\s*=\s*\{\s*global\.mosTT\s*\}/.test(body)) {
			failures.push(
				"macros/system/nxt-tooltable.g: fresh nxtTT allocate should use vector(limits.tools, null)"
			);
		}
	}
}

// --- nxt.g: Custom globals gated; before user-vars; overrides last ---
{
	const body = read("macros/system/nxt.g");
	const customIdx = body.indexOf('M98 P"nxt-custom-globals.g"');
	const userIdx = body.indexOf('M98 P"nxt-user-vars.g"');
	const overIdx = body.indexOf('M98 P"nxt-user-overrides.g"');
	if (customIdx < 0) {
		failures.push('macros/system/nxt.g must M98 nxt-custom-globals.g when Custom is active');
	}
	if (!/nxt-custom\.requested/.test(body)) {
		failures.push("macros/system/nxt.g must gate Custom globals on nxt-custom.requested (or overlays)");
	}
	if (customIdx >= 0 && userIdx >= 0 && customIdx > userIdx) {
		failures.push("macros/system/nxt.g must load nxt-custom-globals.g before nxt-user-vars.g");
	}
	if (overIdx < 0) {
		failures.push("macros/system/nxt.g must M98 nxt-user-overrides.g when present");
	}
	if (userIdx >= 0 && overIdx >= 0 && overIdx < userIdx) {
		failures.push("macros/system/nxt.g must load nxt-user-overrides.g after nxt-user-vars.g");
	}
	// Probe WCS pack must gate on WP sentinel, not overtravel (align may set OT from MOS first).
	if (/!exists\s*\(\s*global\.nxtOvertravel\s*\)[\s\S]{0,120}nxt-probe-wcs\.g/.test(body)) {
		failures.push(
			"macros/system/nxt.g must not gate nxt-probe-wcs.g on nxtOvertravel — use !exists(global.nxtWPCtrPos)"
		);
	}
	if (!/!exists\s*\(\s*global\.nxtWPCtrPos\s*\)/.test(body) || !/nxt-probe-wcs\.g/.test(body)) {
		failures.push("macros/system/nxt.g must load nxt-probe-wcs.g when !exists(global.nxtWPCtrPos)");
	}
}

// --- nxt-tooltable.g owns mosTT→nxtTT; align must not duplicate ---
{
	const align = stripComments(read("macros/system/nxt-mos-globals-align.g"));
	if (/global\s+nxtTT\s*=/.test(align) || /set\s+global\.nxtTT\s*=/.test(align)) {
		failures.push(
			"macros/system/nxt-mos-globals-align.g must not copy mosTT→nxtTT — nxt-tooltable.g owns that"
		);
	}
}

// --- nxt-custom-globals.g: if !exists before each declare; include A ---
{
	const body = read("macros/system/nxt-custom-globals.g");
	if (!body) {
		/* missing already recorded */
	} else {
		if (!/global\s+nxtCustomAHomeAt/.test(body)) {
			failures.push("macros/system/nxt-custom-globals.g must declare A-axis Custom keys");
		}
		const lines = body.split(/\r?\n/);
		for (let i = 0; i < lines.length; i++) {
			const t = lines[i].trim();
			if (!/^global\s+nxtCustom\w+\s*=/.test(t)) continue;
			const prev = `${lines[i - 1] || ""} ${lines[i - 2] || ""}`;
			if (!/!exists\s*\(\s*global\.nxtCustom/.test(prev)) {
				failures.push(
					`macros/system/nxt-custom-globals.g:${i + 1} Custom declare must follow if { !exists(global.nxtCustom…) }`
				);
				break;
			}
		}
	}
}

// --- UI persistence: omit null Custom keys; prefer per-key declare ---
{
	const body = read("ui/src/utils/nxtUserVarsPersistence.ts");
	if (!/if \(v == null \|\| v === ''\) continue/.test(body)) {
		failures.push(
			"ui/src/utils/nxtUserVarsPersistence.ts must skip null/empty Custom values when building nxt-user-vars.g"
		);
	}
	if (/lines\.push\(`set global\.\$\{k\} = null`\)/.test(body)) {
		failures.push(
			"ui/src/utils/nxtUserVarsPersistence.ts must not emit set global.<custom> = null"
		);
	}
	if (!/must not persist null custom platform keys/i.test(body)) {
		failures.push(
			"ui/src/utils/nxtUserVarsPersistence.ts self-test must guard against persisting null Custom keys"
		);
	}
}

// --- nxt-vars.g: session vectors stay null; no duplicate probe-type sample keys ---
{
	const body = stripComments(read("macros/system/nxt-vars.g"));
	if (/global\s+nxtCalTravelCmd\s*=\s*\{\s*vector/i.test(body)) {
		failures.push("macros/system/nxt-vars.g must leave nxtCalTravelCmd null until G9000/M5014 (OM budget)");
	}
	if (/global\s+nxtProbeHitXY\s*=\s*\{\s*vector/i.test(body)) {
		failures.push("macros/system/nxt-vars.g must leave nxtProbeHitXY null until G6512 H= (OM budget)");
	}
	if (/global\s+nxtTouchProbeInnerSampleCount\s*=/.test(body)) {
		failures.push(
			"macros/system/nxt-vars.g must not declare nxtTouchProbeInnerSampleCount — use overrides if needed"
		);
	}
	if (/global\s+nxtToolSetterInnerSampleCount\s*=/.test(body)) {
		failures.push(
			"macros/system/nxt-vars.g must not declare nxtToolSetterInnerSampleCount — use overrides if needed"
		);
	}
	if (/global\s+nxtScyllaMotorVoltage\s*=/.test(body)) {
		failures.push("macros/system/nxt-vars.g must not declare deprecated nxtScyllaMotorVoltage");
	}
	if (/global\s+nxtBoardKitKey\s*=/.test(body)) {
		failures.push("macros/system/nxt-vars.g must not declare deprecated nxtBoardKitKey");
	}
	const globals = body.match(/^\s*global\s+nxt\w+/gm) || [];
	const WARN = 140;
	const FAIL = 180;
	if (globals.length > FAIL) {
		failures.push(
			`macros/system/nxt-vars.g declares ${globals.length} nxt globals (fail threshold ${FAIL}) — see docs/OM_GLOBAL_SIZE.md`
		);
	} else if (globals.length > WARN) {
		console.warn(
			`check-om-global-budget: warning — nxt-vars.g has ${globals.length} nxt globals (warn > ${WARN})`
		);
	}
}

if (failures.length) {
	console.error("check-om-global-budget: FAILED\n");
	for (const f of failures) {
		console.error(`  - ${f}`);
	}
	console.error("\nSee docs/OM_GLOBAL_SIZE.md");
	process.exit(1);
}

console.log("check-om-global-budget: OK");
