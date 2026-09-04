#!/usr/bin/env node
/**
 * Rename nxt-owned MOS globals (mosTT, mosWPCtrPos, …) to nxt* in firmware macros.
 * Does NOT touch nxt-mos-import.g (reads legacy mos* as migration source).
 */
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'

const root = process.argv[2] || process.cwd()
const macrosDir = join(root, 'macros')
const skipFiles = new Set(['nxt-mos-import.g', 'nxt-mos-globals-align.g'])

/** Longer names first to avoid accidental partial overlap. */
const subs = [
  ['global.mosDfltWPCtrPos', 'global.nxtDfltWPCtrPos'],
  ['global.mosDfltWPCnrPos', 'global.nxtDfltWPCnrPos'],
  ['global.mosDfltWPCnrDeg', 'global.nxtDfltWPCnrDeg'],
  ['global.mosDfltWPCnrNum', 'global.nxtDfltWPCnrNum'],
  ['global.mosDfltWPDimsErr', 'global.nxtDfltWPDimsErr'],
  ['global.mosDfltWPSfcAxis', 'global.nxtDfltWPSfcAxis'],
  ['global.mosDfltWPSfcPos', 'global.nxtDfltWPSfcPos'],
  ['global.mosDfltWPDims', 'global.nxtDfltWPDims'],
  ['global.mosDfltWPDeg', 'global.nxtDfltWPDeg'],
  ['global.mosDfltWPRad', 'global.nxtDfltWPRad'],
  ['global.mosWPCtrPos', 'global.nxtWPCtrPos'],
  ['global.mosWPCnrPos', 'global.nxtWPCnrPos'],
  ['global.mosWPCnrDeg', 'global.nxtWPCnrDeg'],
  ['global.mosWPCnrNum', 'global.nxtWPCnrNum'],
  ['global.mosWPDimsErr', 'global.nxtWPDimsErr'],
  ['global.mosWPSfcAxis', 'global.nxtWPSfcAxis'],
  ['global.mosWPSfcPos', 'global.nxtWPSfcPos'],
  ['global.mosWPDims', 'global.nxtWPDims'],
  ['global.mosWPDeg', 'global.nxtWPDeg'],
  ['global.mosWPRad', 'global.nxtWPRad'],
  ['global.mosManualProbeDistances', 'global.nxtManualProbeDistances'],
  ['global.mosManualProbeSlowIdx', 'global.nxtManualProbeSlowIdx'],
  ['global.mosManualProbeFeeds', 'global.nxtManualProbeFeeds'],
  ['global.mosOT', 'global.nxtOvertravel'],
  ['global.mosCL', 'global.nxtClearance'],
  ['global.mosProbeAngleTol', 'global.nxtProbeAngleTol'],
  ['global.mosProbeRetryTotal', 'global.nxtProbeRetryTotal'],
  ['global.mosProbeRetryStep', 'global.nxtProbeRetryStep'],
  ['global.mosProbePointTotal', 'global.nxtProbePointTotal'],
  ['global.mosProbePointStep', 'global.nxtProbePointStep'],
  ['global.mosProbeSurfaceTotal', 'global.nxtProbeSurfaceTotal'],
  ['global.mosProbeSurfaceStep', 'global.nxtProbeSurfaceStep'],
  ['global.mosDialogDisplayed', 'global.nxtDialogDisplayed'],
  ['global.mosTT', 'global.nxtTT'],
  ['global.mosET', 'global.nxtET'],
  ['global mosTT', 'global nxtTT'],
  ['global mosET', 'global nxtET'],
  ['global.mosMPD', 'global.nxtManualProbeDistances'],
  ['global.mosMPSI', 'global.nxtManualProbeSlowIdx'],
  ['global.mosMPS', 'global.nxtManualProbeFeeds'],
  ['global.mosOT', 'global.nxtOvertravel'],
  ['global.mosCL', 'global.nxtClearance'],
  ['global.mosAngleTol', 'global.nxtProbeAngleTol'],
  ['global.mosPRRT', 'global.nxtProbeRetryTotal'],
  ['global.mosPRRS', 'global.nxtProbeRetryStep'],
  ['global.mosPRPT', 'global.nxtProbePointTotal'],
  ['global.mosPRPS', 'global.nxtProbePointStep'],
  ['global.mosPRST', 'global.nxtProbeSurfaceTotal'],
  ['global.mosPRSS', 'global.nxtProbeSurfaceStep'],
  ['global.mosDD', 'global.nxtDialogDisplayed'],
  ['global.mosDebug', 'global.nxtDebug'],
]

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name)
    if (statSync(p).isDirectory()) {
      walk(p, out)
    } else if (name.endsWith('.g') && !skipFiles.has(name)) {
      out.push(p)
    }
  }
  return out
}

let changed = 0
for (const file of walk(macrosDir)) {
  let text = readFileSync(file, 'utf8')
  const before = text
  for (const [from, to] of subs) {
    text = text.split(from).join(to)
  }
  if (text !== before) {
    writeFileSync(file, text)
    changed++
    console.log('updated', file.replace(root + '/', ''))
  }
}

console.log(`align-mos-nxt-globals: ${changed} file(s) updated`)
