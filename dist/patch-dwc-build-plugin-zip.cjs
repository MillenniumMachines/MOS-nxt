#!/usr/bin/env node
/**
 * DWC build-plugin.js only zips JS/CSS whose names start with `${pluginId}.`
 * Webpack may also emit split chunks (e.g. vendors~NeXT.<hash>.js, 12.NeXT.<hash>.js).
 * Those files must be in the plugin zip or __webpack_require__ hits undefined → minified ".call" errors.
 *
 * Usage: node patch-dwc-build-plugin-zip.cjs <path-to-DWC>/scripts/build-plugin.js
 */
"use strict";

const fs = require("fs");
const path = process.argv[2];
if (!path || !fs.existsSync(path)) {
  console.error("usage: node patch-dwc-build-plugin-zip.cjs <build-plugin.js>");
  process.exit(1);
}

let s = fs.readFileSync(path, "utf8");
const needle = "if (file.indexOf(pluginManifest.id + \".\") === 0) {";
const replacement =
  "if (file.indexOf(pluginManifest.id + \".\") === 0 || file.includes(\"~\" + pluginManifest.id) || file.indexOf(\".\" + pluginManifest.id + \".\") > 0) {";

const matches = s.split(needle).length - 1;
if (matches !== 2) {
  console.error(`patch-dwc-build-plugin-zip: expected 2 zip-loop matches, found ${matches} (DWC script changed?)`);
  process.exit(1);
}
s = s.split(needle).join(replacement);
fs.writeFileSync(path, s);
console.log("patch-dwc-build-plugin-zip: updated", path);
