#!/usr/bin/env node
/**
 * Re-pack the sd/ tree into a DWC plugin zip with stable entry names.
 *
 * PollConnector only installs entries where name.startsWith("sd/") (forward slash).
 * Archiver's async directory() can race or produce entries some clients mishandle.
 * This pass removes any existing sd/* entries and re-adds files from the staging tree.
 *
 * Usage: DWC_REPO_PATH=<dwc-root> node merge-sd-into-plugin-zip.cjs <plugin.zip> <staging-dir>
 *   staging-dir must contain ./sd/sys/... (same layout as passed to npm run build-plugin).
 */
"use strict";

const fs = require("fs");
const path = require("path");

const dwcRoot = process.env.DWC_REPO_PATH;
const zipPath = process.argv[2];
const stagingDir = process.argv[3];

if (!dwcRoot || !zipPath || !stagingDir) {
	console.error(
		"usage: DWC_REPO_PATH=<path-to-DuetWebControl> node merge-sd-into-plugin-zip.cjs <plugin.zip> <staging-dir>"
	);
	process.exit(1);
}

const JSZip = require(path.join(dwcRoot, "node_modules", "jszip"));

const sdRoot = path.join(stagingDir, "sd");
if (!fs.existsSync(sdRoot)) {
	console.error(`merge-sd-into-plugin-zip: no sd/ under staging: ${sdRoot}`);
	process.exit(1);
}

function walkFiles(dir, relInsideSd, out) {
	for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
		const abs = path.join(dir, ent.name);
		const zr = relInsideSd ? `${relInsideSd}/${ent.name}` : ent.name;
		if (ent.isDirectory()) {
			walkFiles(abs, zr, out);
		} else if (ent.isFile()) {
			out.push({ abs, zipName: "sd/" + zr.split(path.sep).join("/") });
		}
	}
}

(async () => {
	const buf = fs.readFileSync(zipPath);
	const zip = await JSZip.loadAsync(buf);

	for (const name of Object.keys(zip.files)) {
		if (/^sd(\/|$)/i.test(name)) {
			zip.remove(name);
		}
	}

	const files = [];
	walkFiles(sdRoot, "", files);
	if (files.length === 0) {
		console.error("merge-sd-into-plugin-zip: staged sd/ tree has no files");
		process.exit(1);
	}

	for (const { abs, zipName } of files) {
		zip.file(zipName, fs.readFileSync(abs));
	}

	const out = await zip.generateAsync({
		type: "nodebuffer",
		compression: "DEFLATE",
		compressionOptions: { level: 6 },
	});
	fs.writeFileSync(zipPath, out);
	console.log(`merge-sd-into-plugin-zip: wrote ${files.length} sd/ file(s) into ${zipPath}`);
})().catch((e) => {
	console.error(e);
	process.exit(1);
});
