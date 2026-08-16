/**
 * Unit tests for nxtUserVarsPersistence (run via ui/scripts/run-user-vars-persistence-tests.mjs).
 */
import {
  applySingletonDefaults,
  buildInitialConfigDraft,
  buildNxtUserVarsGcode,
  emptyConfigDraft,
  liveProbeGeometryPresent,
  probeGeometryChanged,
  readConfigBool,
  readConfigDeflectionXY,
  readConfigVector,
  runNxtUserVarsPersistenceSelfTest,
  snapshotConfigFromOm
} from './nxtUserVarsPersistence'

export function runAllNxtUserVarsPersistenceTests(): void {
  runNxtUserVarsPersistenceSelfTest()

  const emptyGcode = buildNxtUserVarsGcode(emptyConfigDraft())
  if (emptyGcode.includes('nxtProbeInnerSampleCount')) {
    throw new Error('nxt-user-vars.g must not include probe repeatability keys')
  }
  if (!emptyGcode.includes('set global.nxtProbeToolID = { limits.tools - 1 }')) {
    throw new Error('nxt-user-vars.g should default nxtProbeToolID when unset')
  }
  if (!emptyGcode.includes('set global.nxtProbeDeflection = null')) {
    throw new Error('empty draft should persist nxtProbeDeflection as null')
  }
  if (emptyGcode.includes('set global.nxtProbeVirtualTsZ')) {
    throw new Error('empty draft must omit null nxtProbeVirtualTsZ')
  }

  const virtFromSetter = buildNxtUserVarsGcode({
    ...emptyConfigDraft(),
    nxtToolSetterPos: [10, 20, -5.5]
  })
  if (!virtFromSetter.includes('set global.nxtProbeVirtualTsZ = -5.5')) {
    throw new Error('buildNxtUserVarsGcode should persist mill virtual from setter Z')
  }
  const virtExplicit = buildNxtUserVarsGcode({
    ...emptyConfigDraft(),
    nxtToolSetterPos: [10, 20, -5.5],
    nxtProbeVirtualTsZ: -4.1
  })
  if (!virtExplicit.includes('set global.nxtProbeVirtualTsZ = -4.1')) {
    throw new Error('explicit nxtProbeVirtualTsZ should win over setter Z')
  }

  const snapVirt = snapshotConfigFromOm({ nxtProbeVirtualTsZ: -12 })
  if (snapVirt.nxtProbeVirtualTsZ !== -12) {
    throw new Error('snapshotConfigFromOm should read nxtProbeVirtualTsZ')
  }
  if (emptyGcode.includes('set global.nxtTouchProbeID = null')) {
    throw new Error('empty draft must omit null nxtTouchProbeID')
  }
  if (emptyGcode.includes('set global.nxtToolSetterID = null')) {
    throw new Error('empty draft must omit null nxtToolSetterID')
  }
  if (emptyGcode.includes('set global.nxtSpindleAccelSec = null')) {
    throw new Error('empty draft must omit null nxtSpindleAccelSec')
  }
  if (emptyGcode.includes('set global.nxtSpindleDecelSec = null')) {
    throw new Error('empty draft must omit null nxtSpindleDecelSec')
  }
  const withAccel = buildNxtUserVarsGcode({
    ...emptyConfigDraft(),
    nxtSpindleAccelSec: 2.5,
    nxtSpindleDecelSec: 3
  })
  if (!withAccel.includes('set global.nxtSpindleAccelSec = 2.5')) {
    throw new Error('buildNxtUserVarsGcode should persist nxtSpindleAccelSec when set')
  }
  if (!withAccel.includes('set global.nxtSpindleDecelSec = 3')) {
    throw new Error('buildNxtUserVarsGcode should persist nxtSpindleDecelSec when set')
  }
  if (!emptyGcode.includes('set global.nxtRGBType = 1')) {
    throw new Error('empty draft should persist nxtRGBType = 1 (RGB)')
  }
  if (!emptyGcode.includes('set global.nxtRGBOrder = 5')) {
    throw new Error('empty draft should persist nxtRGBOrder = 5 (GRB)')
  }
  if (!emptyGcode.includes('set global.nxtToolSetterV2 = false')) {
    throw new Error('empty draft should persist nxtToolSetterV2 = false')
  }
  if (!emptyGcode.includes('set global.nxtToolSetterRefDir = 0')) {
    throw new Error('empty draft should persist nxtToolSetterRefDir = 0 (+X)')
  }

  const rgbLegacy = buildNxtUserVarsGcode({
    ...emptyConfigDraft(),
    nxtRGBType: 3,
    nxtRGBOrder: 2
  })
  if (!rgbLegacy.includes('set global.nxtRGBType = 2')) {
    throw new Error('legacy nxtRGBType 3 must normalize to 2 (RGBW)')
  }
  if (!rgbLegacy.includes('set global.nxtRGBOrder = 2')) {
    throw new Error('buildNxtUserVarsGcode should persist nxtRGBOrder')
  }

  const snapRgb = snapshotConfigFromOm({ nxtRGBType: 3, nxtRGBOrder: 4 })
  if (snapRgb.nxtRGBType !== 2 || snapRgb.nxtRGBOrder !== 4) {
    throw new Error('snapshotConfigFromOm should normalize type 3→2 and keep order')
  }

  const withIds = buildNxtUserVarsGcode({
    ...emptyConfigDraft(),
    nxtTouchProbeID: 0,
    nxtToolSetterID: 1
  })
  if (!withIds.includes('set global.nxtTouchProbeID = 0')) {
    throw new Error('buildNxtUserVarsGcode should persist nxtTouchProbeID 0')
  }
  if (!withIds.includes('set global.nxtToolSetterID = 1')) {
    throw new Error('buildNxtUserVarsGcode should persist nxtToolSetterID 1')
  }

  if (!readConfigBool(1) || !readConfigBool(true)) {
    throw new Error('readConfigBool should accept 1 and true')
  }

  const vec = readConfigVector(new Map([[0, 1], [1, 2], [2, 3]]))
  if (!vec || vec.join(',') !== '1,2,3') {
    throw new Error('readConfigVector Map normalization failed')
  }

  const deflScalar = readConfigDeflectionXY(0.025)
  if (!deflScalar || deflScalar.join(',') !== '0.025,0.025,0') {
    throw new Error('readConfigDeflectionXY scalar normalize failed (Z must be 0)')
  }
  const deflVecXY = readConfigDeflectionXY({ 0: 0.01, 1: 0.02 })
  if (!deflVecXY || deflVecXY.join(',') !== '0.01,0.02,0') {
    throw new Error('readConfigDeflectionXY legacy XY→XYZ (Z=0) failed')
  }
  const deflVecXYZ = readConfigDeflectionXY({ 0: 0.01, 1: 0.02, 2: 0.03 })
  if (!deflVecXYZ || deflVecXYZ.join(',') !== '0.01,0.02,0') {
    throw new Error('readConfigDeflectionXY XYZ vector must force Z=0')
  }

  const snap = snapshotConfigFromOm({
    nxtFeatureTouchProbe: 1,
    nxtSpindleID: 0,
    nxtToolSetterPos: { 0: 10, 1: 20, 2: -5 },
    nxtProbeDeflection: { 0: 0.01, 1: 0.02, 2: 0.03 }
  })
  if (!snap.nxtFeatureTouchProbe || snap.nxtSpindleID !== 0) {
    throw new Error('snapshotConfigFromOm failed')
  }
  if (!snap.nxtProbeDeflection || snap.nxtProbeDeflection.join(',') !== '0.01,0.02,0') {
    throw new Error('snapshotConfigFromOm deflection XYZ failed (Z must be 0)')
  }

  const deflGcode = buildNxtUserVarsGcode({
    ...emptyConfigDraft(),
    nxtProbeDeflection: [0.01, 0.02, 0.03]
  })
  if (!deflGcode.includes('set global.nxtProbeDeflection = {0.01, 0.02, 0}')) {
    throw new Error('buildNxtUserVarsGcode should persist deflection with Z=0')
  }

  const singleton = emptyConfigDraft()
  applySingletonDefaults(singleton, { spindles: [{ id: 0 }], probes: [] })
  if (singleton.nxtSpindleID !== 0) {
    throw new Error('applySingletonDefaults should pick sole spindle')
  }

  const dual = emptyConfigDraft()
  applySingletonDefaults(dual, {
    spindles: [],
    probes: [
      { id: 0, type: 5 },
      { id: 1, type: 8 }
    ]
  })
  if (dual.nxtTouchProbeID !== 0 || dual.nxtToolSetterID !== 1) {
    throw new Error('applySingletonDefaults: null + OM [0,1] → touch 0, setter 1')
  }

  const sole = emptyConfigDraft()
  applySingletonDefaults(sole, { spindles: [], probes: [{ id: 3, type: 5 }] })
  if (sole.nxtTouchProbeID !== 3 || sole.nxtToolSetterID !== null) {
    throw new Error('applySingletonDefaults: single probe → only touch filled')
  }

  const keepZero = buildInitialConfigDraft(
    { nxtTouchProbeID: 0, nxtToolSetterID: 1 },
    { spindles: [], probes: [{ id: 0, type: 5 }, { id: 1, type: 8 }] }
  )
  if (keepZero.nxtTouchProbeID !== 0 || keepZero.nxtToolSetterID !== 1) {
    throw new Error('buildInitialConfigDraft must not clear probe role IDs 0/1')
  }

  const fromMos = buildInitialConfigDraft(
    { mosSID: 0, mosTPID: 1, mosFeatTouchProbe: true, mosTPD: { 0: 0.03, 1: 0.04 } },
    { spindles: [{ id: 0 }], probes: [{ id: 1, type: 5 }] }
  )
  if (fromMos.nxtSpindleID !== 0 || fromMos.nxtTouchProbeID !== 1 || !fromMos.nxtFeatureTouchProbe) {
    throw new Error('buildInitialConfigDraft MOS mapping failed')
  }
  if (!fromMos.nxtProbeDeflection || fromMos.nxtProbeDeflection.join(',') !== '0.03,0.04,0') {
    throw new Error('buildInitialConfigDraft MOS deflection mapping failed (Z must be 0)')
  }

  const emptyLive = emptyConfigDraft()
  const withGeom = {
    ...emptyConfigDraft(),
    nxtDeltaMachine: -6,
    nxtToolSetterPos: [10, 20, -5]
  }
  if (liveProbeGeometryPresent(emptyLive)) {
    throw new Error('empty live OM must not look like probe geometry is present')
  }
  if (probeGeometryChanged(emptyLive, withGeom)) {
    throw new Error('missing live OM geometry is not a Save change')
  }
  if (!probeGeometryChanged(withGeom, { ...withGeom, nxtDeltaMachine: -5 })) {
    throw new Error('delta change vs present live OM must be a geometry Save')
  }
}
