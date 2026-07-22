#!/usr/bin/env node
/**
 * Offline regression for G6512 tip/deflection compensation formulas.
 * Mirrors macros/probing/G6512.g (µm-space math collapsed to mm here).
 *
 * Usage: node dist/check-g6512-deflection-math.mjs
 */
"use strict";

function compensate({ trigger, direction, tipRadius, deflection, axis }) {
	// axis: 0=X 1=Y 2=Z 3=A
	if (axis === 3) return trigger;
	if (axis === 2) return trigger - direction * deflection;
	return trigger + direction * (tipRadius - deflection);
}

function assertClose(label, actual, expected, eps = 1e-9) {
	if (Math.abs(actual - expected) > eps) {
		throw new Error(`${label}: got ${actual}, expected ${expected}`);
	}
}

function main() {
	const R = 1.5;
	const D = 0.025;
	const T = 10;

	// +X / +Y
	assertClose("+X", compensate({ trigger: T, direction: 1, tipRadius: R, deflection: D, axis: 0 }), T + (R - D));
	assertClose("+Y", compensate({ trigger: T, direction: 1, tipRadius: R, deflection: D, axis: 1 }), T + (R - D));
	// −X / −Y (previous bug subtracted D without direction → short by 2D)
	assertClose("-X", compensate({ trigger: T, direction: -1, tipRadius: R, deflection: D, axis: 0 }), T - (R - D));
	assertClose("-Y", compensate({ trigger: T, direction: -1, tipRadius: R, deflection: D, axis: 1 }), T - (R - D));

	// Z tip-center only
	assertClose("+Z", compensate({ trigger: 50, direction: 1, tipRadius: R, deflection: 0.02, axis: 2 }), 49.98);
	assertClose("-Z", compensate({ trigger: 50, direction: -1, tipRadius: R, deflection: 0.02, axis: 2 }), 50.02);

	// A uncompensated
	assertClose("A", compensate({ trigger: 12.3, direction: 1, tipRadius: R, deflection: D, axis: 3 }), 12.3);

	// External block [0, 76.2]: physical triggers include tip + deflection overtravel
	const physLeft = 0 - R + D; // approach +X into −X face
	const physRight = 76.2 + R - D; // approach −X into +X face
	const measLeft = compensate({
		trigger: physLeft,
		direction: 1,
		tipRadius: R,
		deflection: 0,
		axis: 0,
	});
	const measRight = compensate({
		trigger: physRight,
		direction: -1,
		tipRadius: R,
		deflection: 0,
		axis: 0,
	});
	const measured = Math.abs(measRight - measLeft);
	assertClose("external span short", measured, 76.2 - 2 * D);
	const calD = (76.2 - measured) / 2;
	assertClose("cal D", calD, D);

	const fixedLeft = compensate({
		trigger: physLeft,
		direction: 1,
		tipRadius: R,
		deflection: D,
		axis: 0,
	});
	const fixedRight = compensate({
		trigger: physRight,
		direction: -1,
		tipRadius: R,
		deflection: D,
		axis: 0,
	});
	assertClose("recovered span", Math.abs(fixedRight - fixedLeft), 76.2);
	assertClose("center unbiased", (fixedLeft + fixedRight) / 2, 76.2 / 2);
	assertClose("left surface", fixedLeft, 0);
	assertClose("right surface", fixedRight, 76.2);

	// Toolsetter path: no tip/defl → identity
	assertClose(
		"toolsetter",
		compensate({ trigger: -12.5, direction: -1, tipRadius: 0, deflection: 0, axis: 2 }),
		-12.5
	);

	console.log("check-g6512-deflection-math: ok");
}

try {
	main();
} catch (e) {
	console.error("check-g6512-deflection-math:", e.message || e);
	process.exit(1);
}
