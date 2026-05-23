/**
 * Unit tests for nxtUserVarsPersistence (run via ui/scripts/run-user-vars-persistence-tests.mjs).
 */
import {
  buildInitialConfigDraft,
  buildNxtUserVarsGcode,
  emptyConfigDraft,
  readConfigBool,
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

  if (!readConfigBool(1) || !readConfigBool(true)) {
    throw new Error('readConfigBool should accept 1 and true')
  }

  const vec = readConfigVector(new Map([[0, 1], [1, 2], [2, 3]]))
  if (!vec || vec.join(',') !== '1,2,3') {
    throw new Error('readConfigVector Map normalization failed')
  }

  const snap = snapshotConfigFromOm({
    nxtFeatureTouchProbe: 1,
    nxtSpindleID: 0,
    nxtToolSetterPos: { 0: 10, 1: 20, 2: -5 }
  })
  if (!snap.nxtFeatureTouchProbe || snap.nxtSpindleID !== 0) {
    throw new Error('snapshotConfigFromOm failed')
  }

  const fromMos = buildInitialConfigDraft(
    { mosSID: 0, mosTPID: 1, mosFeatTouchProbe: true },
    { spindles: [{ id: 0 }], probes: [{ id: 1, type: 5 }] }
  )
  if (fromMos.nxtSpindleID !== 0 || fromMos.nxtTouchProbeID !== 1 || !fromMos.nxtFeatureTouchProbe) {
    throw new Error('buildInitialConfigDraft MOS mapping failed')
  }
}
