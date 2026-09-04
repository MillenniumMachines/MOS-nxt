#!/usr/bin/env node
/**
 * Offline regression for workpiece XY skew / G68 rotation maths.
 * Mirrors G6500–G6503 / G6506 atan2 → deg, wrap to (−90, 90], chord length.
 *
 * Usage: node dist/check-rotation-skew-math.mjs
 */
"use strict";

function atan2Deg(dy, dx) {
	return (Math.atan2(dy, dx) * 180) / Math.PI;
}

/** Fold edge/chord angle into (−90, 90] so reversed hit order does not yield ~±180°. */
function wrapSkewDeg(theta) {
	let t = theta;
	while (t > 90) t -= 180;
	while (t <= -90) t += 180;
	return t;
}

function hypot(vx, vy) {
	return Math.hypot(vx, vy);
}

function assertClose(label, actual, expected, eps = 1e-9) {
	if (Math.abs(actual - expected) > eps) {
		throw new Error(`${label}: got ${actual}, expected ${expected}`);
	}
}

function main() {
	// G6506: edge A→B with small +dy, large +dx → small +θ (CCW from +X).
	// RRF ≥3.6.1 G68 R is anticlockwise — pass θ through unchanged.
	const edgeDx = 40;
	const edgeDy = 40 * Math.tan((2 * Math.PI) / 180); // ~2°
	const edgeTheta = atan2Deg(edgeDy, edgeDx);
	assertClose("G6506 ~+2°", edgeTheta, 2, 1e-6);

	// Reversed hit order → ~±178° before wrap → same line orientation (+2°) after wrap.
	const rev = atan2Deg(-edgeDy, -edgeDx);
	assertClose("reversed raw near ±180", Math.abs(Math.abs(rev) - 178) < 3 ? 1 : 0, 1, 0);
	assertClose("reversed wrapped", wrapSkewDeg(rev), 2, 1e-6);

	// Pocket X-chord: rectangle rotated +α; ±X hits along short chord ≈ α.
	const alpha = 3; // deg
	const aRad = (alpha * Math.PI) / 180;
	const halfW = 25;
	// Ideal +X / −X wall midpoints for axis-aligned box, then rotate by α about origin.
	const plus = { x: halfW * Math.cos(aRad), y: halfW * Math.sin(aRad) };
	const minus = { x: -halfW * Math.cos(aRad), y: -halfW * Math.sin(aRad) };
	const vx = plus.x - minus.x;
	const vy = plus.y - minus.y;
	assertClose("X-chord θ", wrapSkewDeg(atan2Deg(vy, vx)), alpha, 1e-6);

	// Y-chord of the same rectangle is α+90° (must remapped before comparing to X θ).
	const halfH = 15;
	const yPlus = { x: -halfH * Math.sin(aRad), y: halfH * Math.cos(aRad) };
	const yMinus = { x: halfH * Math.sin(aRad), y: -halfH * Math.cos(aRad) };
	const wx = yPlus.x - yMinus.x;
	const wy = yPlus.y - yMinus.y;
	const yChord = wrapSkewDeg(atan2Deg(wy, wx));
	assertClose("Y-chord raw-ish", wrapSkewDeg(yChord - 90), alpha, 1e-6);

	// Width: projected |vx| underestimates true wall spacing when skewed.
	const projected = Math.abs(vx);
	const trueWidth = hypot(vx, vy);
	assertClose("true width = 2*halfW", trueWidth, 2 * halfW, 1e-9);
	if (!(projected < trueWidth + 1e-9)) {
		throw new Error("expected projected width ≤ chord length under skew");
	}
	assertClose("projected at 3°", projected, trueWidth * Math.cos(aRad), 1e-9);

	// Midpoint average center (pocket/block) equals origin for symmetric rotated rectangle.
	const m1x = (plus.x + minus.x) / 2;
	const m1y = (plus.y + minus.y) / 2;
	const m2x = (yPlus.x + yMinus.x) / 2;
	const m2y = (yPlus.y + yMinus.y) / 2;
	assertClose("center X", (m1x + m2x) / 2, 0, 1e-12);
	assertClose("center Y", (m1y + m2y) / 2, 0, 1e-12);

	// Circular mean (M6522): 179° and −179° → ~±180, not ~0.
	const r1 = (179 * Math.PI) / 180;
	const r2 = (-179 * Math.PI) / 180;
	const mean = (Math.atan2((Math.sin(r1) + Math.sin(r2)) / 2, (Math.cos(r1) + Math.cos(r2)) / 2) * 180) / Math.PI;
	assertClose("circular mean near ±180", Math.abs(Math.abs(mean) - 180) < 1e-6 ? 180 : mean, 180, 1e-6);

	console.log("check-rotation-skew-math: ok");
}

try {
	main();
} catch (e) {
	console.error("check-rotation-skew-math:", e.message || e);
	process.exit(1);
}
