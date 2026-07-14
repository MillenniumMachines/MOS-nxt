#!/usr/bin/env node
/**
 * Enforce nxt global OM size hygiene (SBC ~8KB key=global budget).
 *
 * Usage (from repo root):
 *   node dist/check-om-global-budget.mjs
 *
 * Exit 0 = pass, 1 = violations.
 *
 * Checks:
 *   1) Structural hygiene (Custom gating, null session vectors, nxtTT fill, …)
 *   2) Known bloat patterns (e.g. nxtToolLife filled with 0.0 at boot)
 *   3) Estimated JSON size for lean boot + Custom-null worst case
 *
 * See docs/OM_GLOBAL_SIZE.md and .cursor/rules/om-global-size.mdc.
 */
"use strict";

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");

/** DSF/RRF discards key=global around this length (flags d99vno). */
const OM_GLOBAL_LIMIT = 8192;
/** Fail lean boot estimate above this (leave room for user-vars / runtime). */
const OM_LEAN_FAIL = 7000;
/** Fail lean + all Custom null declares above this. */
const OM_CUSTOM_FAIL = 7800;
/** Assumed MaxTools when expanding limits.tools in estimates. */
const ASSUME_TOOLS = 50;
/** Assumed max(#move.axes, 4) at nxt-vars load (often before M584). */
const ASSUME_AXES = 4;
/** Assumed min(limits.gpOutPorts, 8). */
const ASSUME_GPOUT = 8;

const failures = [];
const warnings = [];

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

/**
 * Collect `global name = rhs` assigns (bare or indented under if/else).
 * Skips `set global.` — those are overlays, not declares.
 */
function collectGlobalDeclares(body) {
	const out = [];
	const re = /^\s*global\s+(nxt\w+)\s*=\s*(.+?)\s*$/gm;
	let m;
	while ((m = re.exec(body)) !== null) {
		out.push({ name: m[1], rhs: m[2].trim() });
	}
	return out;
}

function evalCountExpr(expr) {
	const e = String(expr).replace(/\s+/g, "");
	if (/^limits\.tools$/.test(e)) return ASSUME_TOOLS;
	if (/^min\(limits\.tools,50\)$/.test(e) || /^min\(50,limits\.tools\)$/.test(e)) {
		return Math.min(ASSUME_TOOLS, 50);
	}
	if (/^max\(#move\.axes,4\)$/.test(e) || /^max\(4,#move\.axes\)$/.test(e)) {
		return ASSUME_AXES;
	}
	if (/^min\(limits\.gpOutPorts,8\)$/.test(e) || /^min\(8,limits\.gpOutPorts\)$/.test(e)) {
		return ASSUME_GPOUT;
	}
	if (/^\d+$/.test(e)) return Number(e);
	// Unknown — treat as tools worst case for safety
	return ASSUME_TOOLS;
}

/** Split vector(COUNT, FILL) at the top-level comma (ignore commas inside max/min). */
function splitVectorCountFill(inner) {
	let depth = 0;
	for (let i = 0; i < inner.length; i++) {
		const c = inner[i];
		if (c === "(" || c === "{") depth++;
		else if (c === ")" || c === "}") depth--;
		else if (c === "," && depth === 0) {
			return [inner.slice(0, i).trim(), inner.slice(i + 1).trim()];
		}
	}
	return null;
}

/**
 * Rough UTF-8 length of one JSON object entry for key=global (DSF-style).
 * Intentionally pessimistic for filled numeric vectors.
 */
function estimateEntryBytes(name, rhs) {
	const key = JSON.stringify(name); // "\"nxtFoo\""
	const colon = 1;
	const r = rhs.trim();

	if (r === "null") {
		return key.length + colon + 4; // null
	}
	if (r === "true" || r === "false") {
		return key.length + colon + r.length;
	}
	if (/^-?\d+(\.\d+)?$/.test(r)) {
		return key.length + colon + r.length;
	}
	// Quoted string RHS: "off" or "" 
	const strM = r.match(/^"(.*)"$/);
	if (strM) {
		return key.length + colon + JSON.stringify(strM[1]).length;
	}

	// { vector(COUNT, FILL) } — COUNT may contain commas (max(#move.axes, 4))
	const vecOpen = r.match(/^\{\s*vector\s*\(/i);
	if (vecOpen) {
		const start = r.indexOf("(") + 1;
		let depth = 1;
		let end = -1;
		for (let i = start; i < r.length; i++) {
			const c = r[i];
			if (c === "(") depth++;
			else if (c === ")") {
				depth--;
				if (depth === 0) {
					end = i;
					break;
				}
			}
		}
		if (end > start) {
			const parts = splitVectorCountFill(r.slice(start, end));
			if (parts) {
				const n = evalCountExpr(parts[0]);
				const fill = parts[1].trim();
				let elem;
				if (fill === "null") elem = 4;
				else if (fill === "true" || fill === "false") elem = fill.length;
				else if (/^-?\d+(\.\d+)?$/.test(fill)) elem = fill.length;
				else elem = 8; // nested / unknown fill
				const arr = 2 + n * elem + Math.max(0, n - 1);
				return key.length + colon + arr;
			}
		}
	}

	// Compact literal arrays e.g. {0.0, 0.0} or nxtRGBCol nested
	if (r.startsWith("{") && r.endsWith("}")) {
		// Pessimistic: treat inner text length as JSON-ish
		return key.length + colon + Math.max(r.length, 8);
	}

	// Expression like { limits.tools - 1 }
	if (r.startsWith("{") && r.includes("limits.tools")) {
		return key.length + colon + String(ASSUME_TOOLS - 1).length;
	}

	return key.length + colon + Math.max(r.length, 4);
}

function estimateObjectBytes(entries) {
	// { … } plus commas between entries
	if (entries.length === 0) return 2;
	const body = entries.reduce((a, e) => a + e, 0);
	return 2 + body + Math.max(0, entries.length - 1);
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

// --- nxt-custom-globals.g: if !exists before each declare; A gated by sentinel ---
{
	const body = read("macros/system/nxt-custom-globals.g");
	if (!body) {
		/* missing already recorded */
	} else {
		if (!/global\s+nxtCustomAHomeAt/.test(body)) {
			failures.push("macros/system/nxt-custom-globals.g must declare A-axis Custom keys");
		}
		if (!/nxt-custom-a\.requested/.test(body)) {
			failures.push(
				"macros/system/nxt-custom-globals.g must gate nxtCustomA* on nxt-custom-a.requested (OM budget)"
			);
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

	// Known cliff: 50×0.0 tool-life (or any limits.tools numeric fill) at boot
	if (/global\s+nxtToolLife\s*=\s*\{\s*vector\s*\([^)]*,\s*0(?:\.0)?\s*\)/i.test(body)) {
		failures.push(
			"macros/system/nxt-vars.g must not fill nxtToolLife with vector(..., 0/0.0) at boot — use null + lazy allocate (OM ~8KB)"
		);
	}
	if (!/global\s+nxtToolLife\s*=\s*null\b/.test(body)) {
		failures.push(
			"macros/system/nxt-vars.g must declare global nxtToolLife = null (allocate on first use)"
		);
	}
	if (/vector\s*\(\s*(?:min\s*\(\s*)?limits\.tools[^)]*,\s*0(?:\.0)?\s*\)/i.test(body)) {
		failures.push(
			"macros/system/nxt-vars.g must not use vector(limits.tools, 0/0.0) — null-fill or leave scalar null (OM budget)"
		);
	}
	if (/global\s+nxtToolCache\s*=\s*\{\s*vector/i.test(body)) {
		failures.push(
			"macros/system/nxt-vars.g must not allocate nxtToolCache as vector(limits.tools) — use nxtToolCacheIdx + nxtToolCacheZ (OM ~8KB)"
		);
	}
	if (!/global\s+nxtToolCacheIdx\s*=/.test(body) || !/global\s+nxtToolCacheZ\s*=/.test(body)) {
		failures.push(
			"macros/system/nxt-vars.g must declare nxtToolCacheIdx and nxtToolCacheZ (scalar tool-length cache)"
		);
	}
	if (!/global\s+nxtPinStates\s*=\s*null\b/.test(body)) {
		failures.push(
			"macros/system/nxt-vars.g must declare global nxtPinStates = null (allocate in pause.g)"
		);
	}
	if (/global\s+nxtPinStates\s*=\s*\{\s*vector/i.test(body)) {
		failures.push(
			"macros/system/nxt-vars.g must not allocate nxtPinStates vector at boot — leave null (OM budget)"
		);
	}

	const globals = body.match(/^\s*global\s+nxt\w+/gm) || [];
	const WARN = 140;
	const FAIL = 180;
	if (globals.length > FAIL) {
		failures.push(
			`macros/system/nxt-vars.g declares ${globals.length} nxt globals (fail threshold ${FAIL}) — see docs/OM_GLOBAL_SIZE.md`
		);
	} else if (globals.length > WARN) {
		warnings.push(`nxt-vars.g has ${globals.length} nxt globals (warn > ${WARN})`);
	}
}

// --- Estimated JSON size (lean boot + Custom worst case) ---
{
	const varsBody = stripComments(read("macros/system/nxt-vars.g"));
	const customBody = stripComments(read("macros/system/nxt-custom-globals.g"));
	const ttBody = stripComments(read("macros/system/nxt-tooltable.g"));

	const leanDeclares = collectGlobalDeclares(varsBody);
	// Tool table always allocates nxtET + null nxtTT on first boot (when not copying mosTT)
	for (const d of collectGlobalDeclares(ttBody)) {
		if (d.name === "nxtTT" && /mosTT/i.test(d.rhs)) continue;
		leanDeclares.push(d);
	}
	const byName = new Map();
	for (const d of leanDeclares) {
		byName.set(d.name, d.rhs); // last wins
	}

	const leanEntries = [];
	const leanBreakdown = [];
	for (const [name, rhs] of byName) {
		const bytes = estimateEntryBytes(name, rhs);
		leanEntries.push(bytes);
		leanBreakdown.push({ name, rhs, bytes });
	}
	leanBreakdown.sort((a, b) => b.bytes - a.bytes);

	const customDeclares = collectGlobalDeclares(customBody);
	const customEntries = customDeclares.map((d) => estimateEntryBytes(d.name, d.rhs));

	const leanBytes = estimateObjectBytes(leanEntries);
	const customOnly = estimateObjectBytes(customEntries);
	// Combined ≈ one object with both sets of keys
	const combinedEntries = leanEntries.concat(customEntries);
	const customBootBytes = estimateObjectBytes(combinedEntries);

	if (leanBytes > OM_LEAN_FAIL) {
		failures.push(
			`estimated lean boot global JSON ~${leanBytes} bytes exceeds fail threshold ${OM_LEAN_FAIL} (hard limit ${OM_GLOBAL_LIMIT})`
		);
	}
	if (customBootBytes > OM_CUSTOM_FAIL) {
		failures.push(
			`estimated Custom boot global JSON ~${customBootBytes} bytes (lean+custom nulls) exceeds fail threshold ${OM_CUSTOM_FAIL} (hard limit ${OM_GLOBAL_LIMIT})`
		);
	}
	if (customBootBytes > OM_GLOBAL_LIMIT - 200) {
		warnings.push(
			`Custom boot estimate ~${customBootBytes} leaves <200 B headroom under ${OM_GLOBAL_LIMIT} — user-vars strings / runtime will tip over`
		);
	}

	// Always print estimate so CI/logs show trend
	const top = leanBreakdown
		.slice(0, 8)
		.map((e) => `${e.name}=${e.bytes}`)
		.join(", ");
	console.log(
		`check-om-global-budget: estimate lean≈${leanBytes}B customNulls≈${customOnly}B lean+custom≈${customBootBytes}B ` +
			`(limit ${OM_GLOBAL_LIMIT}; fail lean>${OM_LEAN_FAIL} custom>${OM_CUSTOM_FAIL})`
	);
	console.log(`check-om-global-budget: largest lean entries: ${top}`);
}

if (warnings.length) {
	for (const w of warnings) {
		console.warn(`check-om-global-budget: warning — ${w}`);
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
