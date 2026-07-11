#!/usr/bin/env node
/**
 * Port Jake MOS probing execute macros into nxt with nxt naming conventions.
 */
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'

const jakeDir = process.argv[2] || '/media/kad/data/repositories/jakes-mos-updates'
const nextDir = process.argv[3] || process.cwd()

const probingFiles = [
  'G6513.g',
  'G6512.1.g',
  'G6512.2.g',
  'G6500.1.g',
  'G6501.1.g',
  'G6502.1.g',
  'G6503.1.g',
  'G6504.1.g',
  'G6505.1.g',
  'G6508.1.g',
  'G6510.1.g',
  'G6520.1.g'
]

const utilityFiles = [
  { src: 'M5010.g', dest: 'utilities/M5010.g' },
  { src: 'M5012.g', dest: 'utilities/M5012.g' },
  { src: 'M7601.g', dest: 'utilities/M7601.g' }
]

const subs = [
  [/global\.mosMI/g, 'global.nxtAbsPos'],
  [/global\.mosProbeToolID/g, 'global.nxtProbeToolID'],
  [/global\.mosPTID/g, 'global.nxtProbeToolID'],
  [/global\.mosFeatTouchProbe/g, 'global.nxtFeatureTouchProbe'],
  [/global\.mosTPID/g, 'global.nxtTouchProbeID'],
  [/global\.mosReservedFrom/g, 'global.nxtReservedFrom'],
  [/global\.mosEM/g, 'global.nxtExpertMode'],
  [/global\.mosTM/g, 'global.nxtTutorialMode'],
  [/global\.mosWS/g, 'global.nxtWS'],
  [/mosProbeToolID/g, 'nxtProbeToolID'],
  [/mosFeatTouchProbe/g, 'nxtFeatureTouchProbe'],
  [/mosTPID/g, 'nxtTouchProbeID'],
  [/MillenniumOS:/g, 'nxt:'],
  [/mos-user-tools-sync\.g/g, 'nxt-user-tools-sync.g']
]

function portContent(text) {
  let out = text
  for (const [from, to] of subs) {
    out = out.replace(from, to)
  }
  return out
}

for (const name of probingFiles) {
  const src = join(jakeDir, name)
  if (!existsSync(src)) {
    console.error(`missing: ${src}`)
    process.exit(1)
  }
  const dest = join(nextDir, 'macros/probing', name)
  writeFileSync(dest, portContent(readFileSync(src, 'utf8')))
  console.log(`ported ${name}`)
}

for (const { src, dest } of utilityFiles) {
  const srcPath = join(jakeDir, src)
  if (!existsSync(srcPath)) {
    console.error(`missing: ${srcPath}`)
    process.exit(1)
  }
  const destPath = join(nextDir, 'macros', dest)
  writeFileSync(destPath, portContent(readFileSync(srcPath, 'utf8')))
  console.log(`ported ${src} -> ${dest}`)
}
