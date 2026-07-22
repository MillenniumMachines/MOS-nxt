/**
 * Unit tests for nxtUserVarsPersistence (run via ui/scripts/run-user-vars-persistence-tests.mjs).
 */
import {
  applySingletonDefaults,
  buildInitialConfigDraft,
  buildNxtUserVarsGcode,
  emptyConfigDraft,
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

  if (!readConfigBool(1) || !readConfigBool(true)) {
    throw new Error('readConfigBool should accept 1 and true')
  }

  const vec = readConfigVector(new Map([[0, 1], [1, 2], [2, 3]]))
  if (!vec || vec.join(',') !== '1,2,3') {
    throw new Error('readConfigVector Map normalization failed')
  }

  const deflScalar = readConfigDeflectionXY(0.025)
  if (!deflScalar || deflScalar.join(',') !== '0.025,0.025,0.025') {
    throw new Error('readConfigDeflectionXY scalar normalize failed')
  }
  const deflVecXY = readConfigDeflectionXY({ 0: 0.01, 1: 0.02 })
  if (!deflVecXY || deflVecXY.join(',') !== '0.01,0.02,0.01') {
    throw new Error('readConfigDeflectionXY legacy XY→XYZ (Z=X) failed')
  }
  const deflVecXYZ = readConfigDeflectionXY({ 0: 0.01, 1: 0.02, 2: 0.03 })
  if (!deflVecXYZ || deflVecXYZ.join(',') !== '0.01,0.02,0.03') {
    throw new Error('readConfigDeflectionXY XYZ vector failed')
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
  if (!snap.nxtProbeDeflection || snap.nxtProbeDeflection.join(',') !== '0.01,0.02,0.03') {
    throw new Error('snapshotConfigFromOm deflection XYZ failed')
  }

  const deflGcode = buildNxtUserVarsGcode({
    ...emptyConfigDraft(),
    nxtProbeDeflection: [0.01, 0.02, 0.03]
  })
  if (!deflGcode.includes('set global.nxtProbeDeflection = {0.01, 0.02, 0.03}')) {
    throw new Error('buildNxtUserVarsGcode should persist deflection as XYZ vector')
  }

  const singleton = emptyConfigDraft()
  applySingletonDefaults(singleton, { spindles: [{ id: 0 }], probes: [] })
  if (singleton.nxtSpindleID !== 0) {
    throw new Error('applySingletonDefaults should pick sole spindle')
  }

  const fromMos = buildInitialConfigDraft(
    { mosSID: 0, mosTPID: 1, mosFeatTouchProbe: true, mosTPD: { 0: 0.03, 1: 0.04 } },
    { spindles: [{ id: 0 }], probes: [{ id: 1, type: 5 }] }
  )
  if (fromMos.nxtSpindleID !== 0 || fromMos.nxtTouchProbeID !== 1 || !fromMos.nxtFeatureTouchProbe) {
    throw new Error('buildInitialConfigDraft MOS mapping failed')
  }
  if (!fromMos.nxtProbeDeflection || fromMos.nxtProbeDeflection.join(',') !== '0.03,0.04,0.03') {
    throw new Error('buildInitialConfigDraft MOS deflection mapping failed')
  }
}
