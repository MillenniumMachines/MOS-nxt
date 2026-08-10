<template>
  <v-card variant="outlined">
    <v-card-title class="d-flex align-center">
      <v-icon class="mr-2">mdi-ruler-square</v-icon>
      {{ $t('plugins.nxt.panels.calibration.caption') }}
      <v-spacer />
      <v-btn
        size="small"
        color="primary"
        variant="flat"
        :loading="saving"
        :disabled="uiFrozen || !isConnected || !canSaveCalibration"
        @click="saveCalibration"
      >
        {{ $t('plugins.nxt.panels.calibration.save') }}
      </v-btn>
    </v-card-title>
    <v-card-text>
      <v-alert type="info" density="compact" variant="outlined" class="mb-3">
        {{ $t('plugins.nxt.panels.calibration.intro') }}
      </v-alert>
      <v-alert type="info" density="compact" variant="tonal" class="mb-3">
        {{ $t('plugins.nxt.panels.calibration.blockOrientation') }}
      </v-alert>

      <v-alert v-if="!isConnected" type="warning" density="compact" variant="outlined" class="mb-3">
        {{ $t('plugins.nxt.panels.calibration.needConnection') }}
      </v-alert>

      <!-- Phase 0: static datum -->
      <v-card v-if="needsProbeDatumSetup" variant="outlined" class="mb-4 pa-3">
        <div class="text-subtitle-2 mb-2">{{ $t('plugins.nxt.panels.calibration.phase0Title') }}</div>
        <p class="text-caption text-grey mb-3">{{ phase0HintText }}</p>
        <div class="d-flex flex-wrap ga-2 mb-3">
          <v-chip size="small" :color="toolSetterPosSet ? 'success' : 'warning'" variant="outlined">
            {{ $t('plugins.nxt.panels.calibration.chipToolSetter') }}: {{ toolSetterPosDisplay }}
          </v-chip>
          <v-chip size="small" :color="touchProbeRefPosSet ? 'success' : 'warning'" variant="outlined">
            {{ $t('plugins.nxt.panels.calibration.chipRefPos') }}: {{ touchProbeRefPosDisplay }}
          </v-chip>
          <v-chip size="small" :color="deltaMachineSet ? 'success' : 'warning'" variant="outlined">
            {{ $t('plugins.nxt.panels.calibration.chipDelta') }}: {{ deltaMachineDisplay }}
          </v-chip>
        </div>
        <v-row density="compact">
          <v-col cols="12" md="4">
            <v-btn
              block
              color="primary"
              :disabled="uiFrozen || !isConnected"
              :loading="datumBusy"
              @click="runDatumSetup"
            >
              {{ $t('plugins.nxt.panels.calibration.runM5016') }}
            </v-btn>
          </v-col>
          <v-col cols="12" md="4">
            <v-btn
              block
              color="secondary"
              variant="outlined"
              :disabled="uiFrozen || !isConnected"
              :loading="probeLoadBusy"
              @click="parkAndLoadProbe"
            >
              {{ $t('plugins.nxt.panels.calibration.enableProbe') }}
            </v-btn>
          </v-col>
          <v-col cols="12" md="4">
            <v-btn
              block
              variant="tonal"
              :disabled="uiFrozen || !isConnected || !deltaMachineSet"
              :loading="saving"
              @click="saveCalibration"
            >
              {{ $t('plugins.nxt.panels.calibration.saveDatum') }}
            </v-btn>
          </v-col>
        </v-row>
      </v-card>

      <v-alert
        v-if="touchProbeReady && probeToolIdResolved != null && !probeToolLoaded"
        type="info"
        density="compact"
        variant="outlined"
        class="mb-3"
      >
        <div class="d-flex flex-wrap align-center justify-space-between ga-2">
          <span>
            {{ $t('plugins.nxt.panels.calibration.probeNotInstalled', [probeToolIdResolved]) }}
          </span>
          <v-btn
            size="small"
            color="primary"
            :loading="probeLoadBusy"
            :disabled="uiFrozen || !isConnected || probeLoadBusy"
            @click="parkAndLoadProbe"
          >
            {{ $t('plugins.nxt.panels.calibration.enableProbe') }}
          </v-btn>
        </div>
      </v-alert>

      <v-alert
        v-if="needsProbeDatumSetup"
        type="warning"
        density="compact"
        variant="outlined"
        class="mb-3"
      >
        {{ $t('plugins.nxt.panels.calibration.phase0BlocksProbe') }}
      </v-alert>

      <!-- Manual vs Probe mode -->
      <v-row v-if="probeModeSelectable" class="mb-3" density="compact">
        <v-col cols="12" sm="6" md="4">
          <v-btn-toggle v-model="calMode" mandatory density="compact" color="primary" divided>
            <v-btn value="manual">{{ $t('plugins.nxt.panels.calibration.modeManual') }}</v-btn>
            <v-btn value="probe">{{ $t('plugins.nxt.panels.calibration.modeProbe') }}</v-btn>
          </v-btn-toggle>
        </v-col>
      </v-row>

      <v-row class="mb-2" density="compact">
        <v-col cols="12" sm="4">
          <v-select
            v-model="selectedAxis"
            :items="axisSelectItems"
            item-title="title"
            item-value="value"
            :label="$t('plugins.nxt.panels.calibration.axis')"
            density="compact"
            variant="outlined"
            hide-details
          />
        </v-col>
        <v-col cols="12" sm="8" class="d-flex align-center flex-wrap ga-2">
          <v-chip size="small" variant="outlined">
            {{ $t('plugins.nxt.panels.calibration.currentSteps') }}:
            <strong class="ml-1">{{ currentStepsDisplay }}</strong>
          </v-chip>
          <v-chip size="small" variant="outlined">
            {{ $t('plugins.nxt.panels.calibration.currentBacklash') }}:
            <strong class="ml-1">{{ currentBacklashDisplay }}</strong>
          </v-chip>
          <v-chip size="small" variant="outlined">
            {{ $t('plugins.nxt.panels.calibration.currentDeflection') }}:
            <strong class="ml-1">{{ deflectionDisplay }}</strong>
          </v-chip>
        </v-col>
      </v-row>

      <!-- Rotary A section -->
      <v-card v-if="rotaryAvailable && selectedAxis === 'A'" variant="outlined" class="mb-4 pa-3">
        <div class="text-subtitle-2 mb-2">{{ $t('plugins.nxt.panels.calibration.rotarySection') }}</div>
        <p class="text-caption text-grey mb-3">{{ $t('plugins.nxt.panels.calibration.rotaryHint') }}</p>
        <v-row density="compact">
          <v-col cols="12" md="4">
            <v-btn block color="primary" variant="outlined" :disabled="uiFrozen" @click="runRotary(cmdM4912ProbeYFlatness())">
              {{ $t('plugins.nxt.panels.calibration.runM4912') }}
            </v-btn>
          </v-col>
          <v-col cols="12" md="4">
            <v-btn block color="primary" variant="outlined" :disabled="uiFrozen" @click="runRotary(cmdM4910ProbeYCenter())">
              {{ $t('plugins.nxt.panels.calibration.runM4910') }}
            </v-btn>
          </v-col>
          <v-col cols="12" md="4">
            <v-select
              v-model="rotaryWcs"
              :items="wcsOptions"
              item-title="text"
              item-value="value"
              density="compact"
              variant="outlined"
              hide-details
              :label="$t('plugins.nxt.panels.calibration.rotaryWcs')"
              class="mb-2"
            />
            <v-btn block color="primary" variant="outlined" :disabled="uiFrozen" @click="runRotary(cmdM4807ApplyY0(rotaryWcs))">
              {{ $t('plugins.nxt.panels.calibration.runM4807') }}
            </v-btn>
          </v-col>
        </v-row>
        <v-divider class="my-3" />
        <v-row density="compact">
          <v-col cols="6" md="3">
            <v-text-field v-model.number="aCommanded" type="number" step="0.001" density="compact" variant="outlined"
              :label="$t('plugins.nxt.panels.calibration.commanded')" hide-details />
          </v-col>
          <v-col cols="6" md="3">
            <v-text-field v-model.number="aActual" type="number" step="0.001" density="compact" variant="outlined"
              :label="$t('plugins.nxt.panels.calibration.actual')" hide-details />
          </v-col>
          <v-col cols="12" md="3" class="d-flex align-center">
            <span class="text-caption">{{ aStepsPreview }}</span>
          </v-col>
          <v-col cols="12" md="3">
            <v-btn block color="primary" :disabled="uiFrozen || aProposed == null" @click="applyASteps">
              {{ $t('plugins.nxt.panels.calibration.applyM4806') }}
            </v-btn>
          </v-col>
        </v-row>
      </v-card>

      <!-- Probe mode: deflection gate + G9000 -->
      <template v-if="calMode === 'probe'">
        <v-alert type="info" density="compact" variant="tonal" class="mb-3">
          {{ $t('plugins.nxt.panels.calibration.probeCapabilityHint') }}
        </v-alert>
        <v-alert
          v-if="selectedAxis === 'A'"
          type="warning"
          density="compact"
          variant="outlined"
          class="mb-3"
        >
          {{ $t('plugins.nxt.panels.calibration.axisANoLinearCal') }}
        </v-alert>
        <v-alert
          v-if="!probeDeflectionReady"
          type="info"
          density="compact"
          variant="outlined"
          class="mb-3"
        >
          {{ $t('plugins.nxt.panels.calibration.deflectionGateHint') }}
        </v-alert>
        <v-alert
          v-if="needsDeflectionRecheck"
          type="warning"
          density="compact"
          variant="outlined"
          class="mb-3"
        >
          {{ $t('plugins.nxt.panels.calibration.deflectionRecheckHint') }}
        </v-alert>

        <v-card variant="outlined" class="mb-4 pa-3">
          <div class="text-subtitle-2 mb-2">{{ $t('plugins.nxt.panels.calibration.probeModeTitle') }}</div>
          <p class="text-caption text-grey mb-3">{{ $t('plugins.nxt.panels.calibration.probeModeHint') }}</p>
          <v-row density="compact" class="mb-2">
            <v-col cols="12" md="4">
              <v-btn
                block
                color="primary"
                variant="outlined"
                :disabled="uiFrozen || !isConnected || selectedAxis === 'A'"
                @click="openPhase = '1'"
              >
                {{ $t('plugins.nxt.panels.calibration.gotoDeflection') }}
              </v-btn>
            </v-col>
            <v-col cols="12" md="4">
              <v-btn
                block
                variant="tonal"
                :disabled="!canConfirmExistingDeflection"
                @click="confirmExistingDeflection"
              >
                {{ $t('plugins.nxt.panels.calibration.confirmDeflection') }}
              </v-btn>
            </v-col>
            <v-col cols="12" md="4">
              <v-btn
                block
                color="primary"
                :disabled="!canRunG9000"
                :loading="g9000Busy"
                @click="runG9000"
              >
                {{ $t('plugins.nxt.panels.calibration.runG9000') }}
              </v-btn>
            </v-col>
          </v-row>

          <div v-if="travelClassification" class="mt-3">
            <v-alert
              :type="travelClassification.kind === 'mixed' ? 'warning' : 'success'"
              density="compact"
              variant="outlined"
              class="mb-2"
            >
              {{ travelClassification.summary }}
            </v-alert>
            <v-table density="compact" class="mb-2">
              <thead>
                <tr>
                  <th>{{ $t('plugins.nxt.panels.calibration.travelCmd') }}</th>
                  <th>{{ $t('plugins.nxt.panels.calibration.travelMeas') }}</th>
                  <th>{{ $t('plugins.nxt.panels.calibration.travelErr') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(leg, i) in travelLegs" :key="'leg' + i">
                  <td>{{ leg.commanded.toFixed(3) }}</td>
                  <td>{{ leg.measured.toFixed(4) }}</td>
                  <td>{{ (leg.measured - leg.commanded).toFixed(4) }}</td>
                </tr>
              </tbody>
            </v-table>
            <div class="d-flex flex-wrap ga-2">
              <v-btn
                size="small"
                color="primary"
                variant="outlined"
                :disabled="travelClassification.proposedBacklash == null || uiFrozen"
                @click="applyTravelBacklash"
              >
                {{ $t('plugins.nxt.panels.calibration.applyTravelBacklash') }}
              </v-btn>
            </div>
          </div>
        </v-card>
      </template>

      <v-expansion-panels
        v-if="calMode === 'manual' || calMode === 'probe'"
        v-model="openPhase"
        variant="accordion"
        class="mb-2"
      >
        <!-- Phase 1 — deflection (required when touch probe enabled) -->
        <v-expansion-panel value="1">
          <v-expansion-panel-title>{{ $t('plugins.nxt.panels.calibration.phase4Title') }}</v-expansion-panel-title>
          <v-expansion-panel-text>
            <p class="text-caption mb-2">{{ $t('plugins.nxt.panels.calibration.phase4Hint') }}</p>
            <p class="text-caption text-grey mb-2">{{ $t('plugins.nxt.panels.calibration.phase4RequiredHint') }}</p>

            <v-alert density="compact" variant="outlined" class="mb-3" type="info">
              {{ $t('plugins.nxt.panels.calibration.roughDzHint') }}
              <strong class="ml-1">{{ roughDzDisplay }}</strong>
            </v-alert>

            <!-- Probe mode: XY dual span + dive -->
            <template v-if="calMode === 'probe'">
              <p class="text-caption text-grey mb-2">{{ $t('plugins.nxt.panels.calibration.phase4ProbeHint') }}</p>
              <v-row density="compact">
                <v-col cols="12" md="4">
                  <v-select
                    v-model="p4DiveMm"
                    :items="p4DiveItems"
                    item-title="title"
                    item-value="value"
                    :label="$t('plugins.nxt.panels.calibration.zDiveDepth')"
                    density="compact"
                    variant="outlined"
                    hide-details
                  />
                </v-col>
                <v-col cols="12" md="4">
                  <v-btn
                    block
                    variant="outlined"
                    color="primary"
                    :disabled="!canRunM5017"
                    :loading="p4ProbeBusy"
                    @click="runProbeDeflectionSpan"
                  >
                    {{ $t('plugins.nxt.panels.calibration.runXyDeflectionSpans') }}
                  </v-btn>
                </v-col>
                <v-col cols="12" md="4">
                  <v-btn
                    block
                    color="primary"
                    :disabled="!canApplyXyDeflection"
                    @click="applyXyDeflection"
                  >
                    {{ $t('plugins.nxt.panels.calibration.applyDeflection') }}
                  </v-btn>
                </v-col>
              </v-row>
              <v-row density="compact" class="mt-2">
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="defMeasuredX != null ? defMeasuredX.toFixed(4) : ''"
                    density="compact"
                    variant="outlined"
                    :label="$t('plugins.nxt.panels.calibration.measuredSpanX')"
                    hide-details
                    readonly
                  />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="defMeasuredY != null ? defMeasuredY.toFixed(4) : ''"
                    density="compact"
                    variant="outlined"
                    :label="$t('plugins.nxt.panels.calibration.measuredSpanY')"
                    hide-details
                    readonly
                  />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field
                    v-model.number="defProposedZEdit"
                    type="number"
                    step="0.001"
                    density="compact"
                    variant="outlined"
                    :label="$t('plugins.nxt.panels.calibration.roughDzEdit')"
                    hide-details
                  />
                </v-col>
                <v-col cols="12" md="3" class="d-flex align-center">
                  <span class="text-caption">{{ xyDefPreview }}</span>
                </v-col>
              </v-row>
              <p v-if="probeTipRadiusDisplay" class="text-caption text-grey mt-1 mb-0">
                {{ $t('plugins.nxt.panels.calibration.tipRadiusUsed') }}:
                {{ probeTipRadiusDisplay }}
                <span v-if="xyShortfallDisplay"> — {{ xyShortfallDisplay }}</span>
              </p>
              <v-alert
                v-if="xyDeflectionImplausible"
                type="warning"
                density="compact"
                variant="outlined"
                class="mt-2"
              >
                {{ $t('plugins.nxt.panels.calibration.implausibleDeflectionHint') }}
              </v-alert>
            </template>

            <!-- Manual mode: single-axis entry (advanced) -->
            <template v-else>
              <v-row density="compact">
                <v-col cols="12" md="4">
                  <v-select
                    v-model="blockDeflectFace"
                    :items="blockFaceItems"
                    item-title="title"
                    item-value="value"
                    :label="$t('plugins.nxt.panels.calibration.blockFace')"
                    density="compact"
                    variant="outlined"
                    hide-details
                  />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="defActual"
                    type="number"
                    step="0.001"
                    density="compact"
                    variant="outlined"
                    :label="$t('plugins.nxt.panels.calibration.actualDim')"
                    hide-details
                    readonly
                  />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field
                    v-model.number="defMeasured"
                    type="number"
                    step="0.001"
                    density="compact"
                    variant="outlined"
                    :label="$t('plugins.nxt.panels.calibration.measuredSpan')"
                    hide-details
                  />
                </v-col>
                <v-col cols="12" md="2" class="d-flex align-center">
                  <span class="text-caption">{{ defPreview }}</span>
                </v-col>
                <v-col cols="12" md="3">
                  <v-btn block color="primary" :disabled="defProposed == null" @click="applyDeflection">
                    {{ $t('plugins.nxt.panels.calibration.applyDeflection') }}
                  </v-btn>
                </v-col>
              </v-row>
            </template>
          </v-expansion-panel-text>
        </v-expansion-panel>

        <!-- Phase 2 (manual only) — zero / away 8-16-24 / return -->
        <v-expansion-panel v-if="calMode === 'manual'" value="2" :disabled="touchProbeBlocksLaterPhases">
          <v-expansion-panel-title>{{ $t('plugins.nxt.panels.calibration.phase1Title') }}</v-expansion-panel-title>
          <v-expansion-panel-text>
            <p class="text-caption mb-2">{{ $t('plugins.nxt.panels.calibration.phase1Hint') }}</p>
            <p class="text-caption text-grey mb-2">{{ $t('plugins.nxt.panels.calibration.residualSignHint') }}</p>
            <v-row density="compact">
              <v-col cols="12" md="4">
                <v-select
                  v-model="p1FaceAway"
                  :items="p1FaceAwayItems"
                  item-title="title"
                  item-value="value"
                  :label="$t('plugins.nxt.panels.calibration.blockFaceAway')"
                  density="compact"
                  variant="outlined"
                  hide-details
                  :disabled="selectedAxis === 'A'"
                />
              </v-col>
              <v-col cols="12" md="4" class="d-flex align-center">
                <v-checkbox
                  v-model="p1Repeat3x"
                  density="compact"
                  hide-details
                  :label="$t('plugins.nxt.panels.calibration.repeat3x')"
                />
              </v-col>
              <v-col cols="12" md="4">
                <v-btn
                  block
                  color="primary"
                  :disabled="!canRunP1Motion || uiFrozen"
                  :loading="p1MotionBusy"
                  @click="runPhase1MotionTest"
                >
                  {{ $t('plugins.nxt.panels.calibration.runMotionTest') }}
                </v-btn>
              </v-col>
            </v-row>
            <p class="text-caption text-grey mt-2 mb-2">{{ $t('plugins.nxt.panels.calibration.runMotionTestHint') }}</p>

            <div v-if="calMode === 'manual' && travelClassification" class="mt-3">
              <v-alert
                :type="travelClassification.kind === 'mixed' ? 'warning' : 'success'"
                density="compact"
                variant="outlined"
                class="mb-2"
              >
                {{ travelClassification.summary }}
              </v-alert>
              <v-table density="compact" class="mb-2">
                <thead>
                  <tr>
                    <th>{{ $t('plugins.nxt.panels.calibration.travelCmd') }}</th>
                    <th>{{ $t('plugins.nxt.panels.calibration.travelMeas') }}</th>
                    <th>{{ $t('plugins.nxt.panels.calibration.travelErr') }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(leg, i) in travelLegs" :key="'p1leg' + i">
                    <td>{{ leg.commanded.toFixed(3) }}</td>
                    <td>{{ leg.measured.toFixed(4) }}</td>
                    <td>{{ (leg.measured - leg.commanded).toFixed(4) }}</td>
                  </tr>
                </tbody>
              </v-table>
              <div class="d-flex flex-wrap ga-2">
                <v-btn
                  size="small"
                  color="primary"
                  variant="outlined"
                  :disabled="travelClassification.proposedBacklash == null || uiFrozen || selectedAxis === 'A'"
                  @click="applyTravelBacklash"
                >
                  {{ $t('plugins.nxt.panels.calibration.applyTravelBacklash') }}
                </v-btn>
              </div>
            </div>
            <div class="d-flex justify-end mt-3">
              <v-btn variant="text" size="small" @click="skipPhase('2')">
                {{ $t('plugins.nxt.panels.calibration.skipPhase') }}
              </v-btn>
            </div>
          </v-expansion-panel-text>
        </v-expansion-panel>

        <!-- Phase 3 — dual-dimension steps (manual + probe; not A) -->
        <v-expansion-panel
          value="3"
          :disabled="touchProbeBlocksLaterPhases || selectedAxis === 'A'"
        >
          <v-expansion-panel-title>{{ $t('plugins.nxt.panels.calibration.phase2Title') }}</v-expansion-panel-title>
          <v-expansion-panel-text>
            <v-alert
              v-if="selectedAxis === 'A'"
              type="warning"
              density="compact"
              variant="outlined"
              class="mb-2"
            >
              {{ $t('plugins.nxt.panels.calibration.axisANoLinearCal') }}
            </v-alert>
            <p class="text-caption mb-2">{{ $t('plugins.nxt.panels.calibration.phase2Hint') }}</p>
            <v-row density="compact">
              <v-col cols="12" md="4">
                <v-select
                  v-model="blockFacePair"
                  :items="blockFacePairItems"
                  item-title="title"
                  item-value="value"
                  :label="$t('plugins.nxt.panels.calibration.blockFacePair')"
                  density="compact"
                  variant="outlined"
                  hide-details
                />
              </v-col>
              <v-col cols="6" md="4" class="d-flex align-center">
                <v-chip size="small" variant="outlined" class="mr-2">
                  {{ $t('plugins.nxt.panels.calibration.actual1') }}: {{ refDim1.toFixed(1) }} mm
                </v-chip>
                <v-chip size="small" variant="outlined">
                  {{ $t('plugins.nxt.panels.calibration.actual2') }}: {{ refDim2.toFixed(1) }} mm
                </v-chip>
              </v-col>
            </v-row>
            <v-row density="compact" class="mt-2">
              <v-col cols="6" md="3">
                <v-text-field
                  :model-value="p2Face1Left"
                  type="number"
                  step="0.001"
                  density="compact"
                  variant="outlined"
                  :label="$t('plugins.nxt.panels.calibration.face1Left')"
                  hide-details
                  readonly
                />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field
                  :model-value="p2Face1Right"
                  type="number"
                  step="0.001"
                  density="compact"
                  variant="outlined"
                  :label="$t('plugins.nxt.panels.calibration.face1Right')"
                  hide-details
                  readonly
                />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field
                  :model-value="p2Face2Left"
                  type="number"
                  step="0.001"
                  density="compact"
                  variant="outlined"
                  :label="$t('plugins.nxt.panels.calibration.face2Left')"
                  hide-details
                  readonly
                />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field
                  :model-value="p2Face2Right"
                  type="number"
                  step="0.001"
                  density="compact"
                  variant="outlined"
                  :label="$t('plugins.nxt.panels.calibration.face2Right')"
                  hide-details
                  readonly
                />
              </v-col>
            </v-row>
            <v-row density="compact" class="mt-1">
              <v-col cols="6" md="3">
                <v-text-field
                  :model-value="effectiveP2Measured1"
                  type="number"
                  step="0.001"
                  density="compact"
                  variant="outlined"
                  :label="$t('plugins.nxt.panels.calibration.measured1')"
                  hide-details
                  readonly
                />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field
                  :model-value="effectiveP2Measured2"
                  type="number"
                  step="0.001"
                  density="compact"
                  variant="outlined"
                  :label="$t('plugins.nxt.panels.calibration.measured2')"
                  hide-details
                  readonly
                />
              </v-col>
              <v-col v-if="calMode === 'manual'" cols="12" md="6" class="d-flex align-center">
                <v-checkbox
                  v-model="p2UseManualSpans"
                  density="compact"
                  hide-details
                  :label="$t('plugins.nxt.panels.calibration.manualSpanOverride')"
                />
              </v-col>
            </v-row>
            <v-row v-if="calMode === 'manual' && p2UseManualSpans" density="compact" class="mt-1">
              <v-col cols="6" md="3">
                <v-text-field v-model.number="p2Measured1" type="number" step="0.001" density="compact" variant="outlined"
                  :label="$t('plugins.nxt.panels.calibration.manualSpan1')" hide-details />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="p2Measured2" type="number" step="0.001" density="compact" variant="outlined"
                  :label="$t('plugins.nxt.panels.calibration.manualSpan2')" hide-details />
              </v-col>
            </v-row>
            <v-row v-if="calMode === 'manual'" density="compact" class="mt-2">
              <v-col cols="12" md="4">
                <v-text-field v-model.number="probeTarget" type="number" step="0.001" density="compact" variant="outlined"
                  :label="$t('plugins.nxt.panels.calibration.probeTarget')" hide-details
                  :disabled="!touchProbeReady" />
              </v-col>
              <v-col cols="6" md="4">
                <v-btn
                  block
                  variant="outlined"
                  :disabled="!touchProbeReady || uiFrozen || touchProbeBlocksLaterPhases || !probeToolLoaded"
                  @click="sendG6512"
                >
                  {{ $t('plugins.nxt.panels.calibration.runG6512Jog') }}
                </v-btn>
              </v-col>
            </v-row>
            <v-row density="compact" class="mt-1">
              <v-col cols="6" md="3">
                <v-btn
                  block
                  variant="outlined"
                  size="small"
                  :disabled="!canProbeCaptureFace"
                  :loading="p2CaptureBusy === 'l1'"
                  @click="onCaptureFace('l1')"
                >
                  {{ calMode === 'probe'
                    ? $t('plugins.nxt.panels.calibration.probeCaptureL1')
                    : $t('plugins.nxt.panels.calibration.captureL1') }}
                </v-btn>
              </v-col>
              <v-col cols="6" md="3">
                <v-btn
                  block
                  variant="outlined"
                  size="small"
                  :disabled="!canProbeCaptureFace"
                  :loading="p2CaptureBusy === 'r1'"
                  @click="onCaptureFace('r1')"
                >
                  {{ calMode === 'probe'
                    ? $t('plugins.nxt.panels.calibration.probeCaptureR1')
                    : $t('plugins.nxt.panels.calibration.captureR1') }}
                </v-btn>
              </v-col>
              <v-col cols="6" md="3">
                <v-btn
                  block
                  variant="outlined"
                  size="small"
                  :disabled="!canProbeCaptureFace"
                  :loading="p2CaptureBusy === 'l2'"
                  @click="onCaptureFace('l2')"
                >
                  {{ calMode === 'probe'
                    ? $t('plugins.nxt.panels.calibration.probeCaptureL2')
                    : $t('plugins.nxt.panels.calibration.captureL2') }}
                </v-btn>
              </v-col>
              <v-col cols="6" md="3">
                <v-btn
                  block
                  variant="outlined"
                  size="small"
                  :disabled="!canProbeCaptureFace"
                  :loading="p2CaptureBusy === 'r2'"
                  @click="onCaptureFace('r2')"
                >
                  {{ calMode === 'probe'
                    ? $t('plugins.nxt.panels.calibration.probeCaptureR2')
                    : $t('plugins.nxt.panels.calibration.captureR2') }}
                </v-btn>
              </v-col>
            </v-row>
            <p v-if="calMode === 'probe'" class="text-caption text-grey mt-1">
              {{ $t('plugins.nxt.panels.calibration.phase2ProbeCaptureHint') }}
            </p>
            <p v-if="calMode === 'manual'" class="text-caption text-grey mt-1">{{ $t('plugins.nxt.panels.calibration.runG6512JogHint') }}</p>
            <div class="d-flex align-center justify-space-between mt-3">
              <span class="text-caption">{{ p2Preview }}</span>
              <v-btn color="primary" :disabled="!canApplyP2" @click="applySteps(p2Proposed, 'p2')">
                {{ $t('plugins.nxt.panels.calibration.applySteps') }}
              </v-btn>
            </div>
            <div class="d-flex justify-end mt-3">
              <v-btn variant="text" size="small" @click="skipPhase('3')">
                {{ $t('plugins.nxt.panels.calibration.skipPhase') }}
              </v-btn>
            </div>
          </v-expansion-panel-text>
        </v-expansion-panel>

        <!-- Phase 4 — backlash refine (probe samples or typed means; both modes) -->
        <v-expansion-panel
          value="4"
          :disabled="touchProbeBlocksLaterPhases || selectedAxis === 'A'"
        >
          <v-expansion-panel-title>{{ $t('plugins.nxt.panels.calibration.phase3Title') }}</v-expansion-panel-title>
          <v-expansion-panel-text>
            <p class="text-caption mb-2">{{ $t('plugins.nxt.panels.calibration.phase3Hint') }}</p>
            <p v-if="calMode === 'probe'" class="text-caption text-grey mb-2">
              {{ $t('plugins.nxt.panels.calibration.phase3ProbeHint') }}
            </p>
            <v-alert
              v-if="selectedAxis === 'A'"
              type="warning"
              density="compact"
              variant="outlined"
              class="mb-2"
            >
              {{ $t('plugins.nxt.panels.calibration.axisANoLinearCal') }}
            </v-alert>
            <v-row density="compact">
              <v-col cols="6" md="3">
                <v-text-field v-model.number="blMeanPos" type="number" step="0.001" density="compact" variant="outlined"
                  :label="$t('plugins.nxt.panels.calibration.meanPositive')" hide-details
                  :disabled="selectedAxis === 'A'" />
              </v-col>
              <v-col cols="6" md="3">
                <v-text-field v-model.number="blMeanNeg" type="number" step="0.001" density="compact" variant="outlined"
                  :label="$t('plugins.nxt.panels.calibration.meanNegative')" hide-details
                  :disabled="selectedAxis === 'A'" />
              </v-col>
              <v-col cols="12" md="3" class="d-flex align-center">
                <span class="text-caption">{{ blPreview }}</span>
              </v-col>
              <v-col cols="12" md="3">
                <v-btn
                  block
                  color="primary"
                  :disabled="blProposed == null || selectedAxis === 'A' || uiFrozen"
                  @click="applyBacklash"
                >
                  {{ $t('plugins.nxt.panels.calibration.applyBacklash') }}
                </v-btn>
              </v-col>
            </v-row>
            <v-row density="compact" class="mt-2">
              <v-col cols="12" md="4">
                <v-btn
                  block
                  variant="outlined"
                  size="small"
                  :disabled="!canAddBacklashSample"
                  @click="addBacklashSample('pos')"
                >
                  {{ $t('plugins.nxt.panels.calibration.addSamplePos') }}
                </v-btn>
              </v-col>
              <v-col cols="12" md="4">
                <v-btn
                  block
                  variant="outlined"
                  size="small"
                  :disabled="!canAddBacklashSample"
                  @click="addBacklashSample('neg')"
                >
                  {{ $t('plugins.nxt.panels.calibration.addSampleNeg') }}
                </v-btn>
              </v-col>
              <v-col cols="12" md="4">
                <v-switch
                  v-model="showScatter"
                  density="compact"
                  hide-details
                  :label="$t('plugins.nxt.panels.calibration.showScatter')"
                />
              </v-col>
            </v-row>
            <svg
              v-if="showScatter && scatterPoints.length"
              class="mt-3"
              viewBox="0 0 320 120"
              width="100%"
              height="120"
              style="background: rgba(0,0,0,0.04); border-radius: 4px;"
            >
              <circle
                v-for="(pt, i) in scatterPoints"
                :key="'sc' + i"
                :cx="pt.x"
                :cy="pt.y"
                r="4"
                :fill="pt.dir === 'pos' ? '#1976D2' : '#E65100'"
              />
            </svg>
            <div class="d-flex justify-end mt-3">
              <v-btn variant="text" size="small" @click="skipPhase('4')">
                {{ $t('plugins.nxt.panels.calibration.skipPhase') }}
              </v-btn>
            </div>
          </v-expansion-panel-text>
        </v-expansion-panel>

        <!-- Phase 5 -->
        <v-expansion-panel value="5">
          <v-expansion-panel-title>{{ $t('plugins.nxt.panels.calibration.phase5Title') }}</v-expansion-panel-title>
          <v-expansion-panel-text>
            <p class="text-caption mb-2">{{ $t('plugins.nxt.panels.calibration.phase5Hint') }}</p>
            <v-btn variant="outlined" class="mb-2" :disabled="!isConnected" @click="sendCode('M6523 B0 C10')">
              {{ $t('plugins.nxt.panels.calibration.runM6523') }}
            </v-btn>
            <ul class="text-caption">
              <li>{{ $t('plugins.nxt.panels.calibration.verifyDim') }}</li>
              <li>{{ $t('plugins.nxt.panels.calibration.verifyBl') }}</li>
              <li>{{ $t('plugins.nxt.panels.calibration.verifyRep') }}</li>
            </ul>
            <v-alert v-if="statusMsg" :type="statusType" density="compact" variant="outlined" class="mt-3">
              {{ statusMsg }}
            </v-alert>
          </v-expansion-panel-text>
        </v-expansion-panel>
      </v-expansion-panels>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import { defineNxtComponent } from '../base/BaseComponent.vue'
import { readFirmwareGlobal } from '../../utils/nxtToolChangerOm'
import {
  roughStepsCorrection,
  dualDimensionStepsCorrection,
  backlashFromMeans,
  deflectionFromSpan,
  spanFromFaces,
  meanOf,
  classifyTravelCalibration,
  travelCommandedLegs,
  externalSpanShortfall,
  implausibleExternalDeflection,
  suspectTipDiameterAsRadius,
  probeTipDiameterMm,
  NXT_123_FACE_PAIRS,
  NXT_123_FACES,
  NXT_123_BLOCK_MM,
  NXT_123_AXIS_DEFAULTS,
  nxt123DefaultsForAxis,
  type Nxt123FacePairId,
  type Nxt123FaceId,
  type TravelClassification,
  type TravelLeg
} from '../../utils/nxtCalibrationMath'
import {
  isRotaryCalibrationAvailable,
  cmdM4806SetSteps,
  cmdM4910ProbeYCenter,
  cmdM4912ProbeYFlatness,
  cmdM4807ApplyY0
} from '../../utils/nxtRotaryCalibration'
import {
  snapshotConfigFromOm,
  readConfigVector,
  readConfigDeflectionXY,
  readConfigNumber,
  readConfigBool,
  isFactoryZeroDeflection,
  type NxtUserConfigDraft
} from '../../utils/nxtUserVarsPersistence'
import { persistNxtUserConfig } from '../../utils/nxtUserConfigPersist'
import { ensureSetFirmwareGlobal, formatOmRhs } from '../../utils/nxtOmEnsureSet'
import {
  applyCalSessionToPanel,
  clearWizardProgressKeepConfirm,
  pickCalSessionFromPanel,
  readNxtCalSession,
  reconcileDeflectionConfirm,
  writeNxtCalSession,
  type NxtCalSessionPanelFields
} from '../../utils/nxtCalSession'
import {
  enableNxtProbeTool,
  isNxtProbeToolLoaded,
  resolveNxtProbeToolId
} from '../../utils/nxtEnableProbe'

type AxisLetter = 'X' | 'Y' | 'Z' | 'A'

export default defineNxtComponent({
  name: 'CalibrationPanel',
  data() {
    return {
      selectedAxis: 'X' as AxisLetter,
      openPhase: '1' as string | null,
      calMode: 'manual' as 'manual' | 'probe',
      saving: false,
      datumBusy: false,
      probeLoadBusy: false,
      g9000Busy: false,
      statusMsg: '',
      statusType: 'info' as 'info' | 'success' | 'error' | 'warning',
      sessionDeflectionOk: false,
      needsDeflectionRecheck: false,
      /** Last confirmed/applied D fingerprint for session restore */
      confirmedDeflection: null as number[] | null,
      /** Skip axis/mode watchers while hydrating from nxtCalSession */
      calSessionHydrating: false,
      calSessionPersistTimer: null as ReturnType<typeof setTimeout> | null,
      travelLegs: [] as TravelLeg[],
      travelClassification: null as TravelClassification | null,
      // Phase 1 — zero / 8-16-24 / return (face away dir + optional 3×)
      p1FaceAway: 1 as 1 | -1,
      p1Repeat3x: false,
      p1MotionBusy: false,
      p4ProbeBusy: false,
      p4DiveMm: 10 as number,
      defMeasuredX: null as number | null,
      defMeasuredY: null as number | null,
      defProposedZEdit: null as number | null,
      p2CaptureBusy: null as null | 'l1' | 'r1' | 'l2' | 'r2',
      // Kept for axis-default sync / A rotary commanded elsewhere
      p1Commanded: NXT_123_AXIS_DEFAULTS.X.p1Commanded as number | null,
      // Phase 2 — X default pair 2″+3″ (3″∥X)
      blockFacePair: NXT_123_AXIS_DEFAULTS.X.facePair as Nxt123FacePairId,
      p2Face1Left: null as number | null,
      p2Face1Right: null as number | null,
      p2Face2Left: null as number | null,
      p2Face2Right: null as number | null,
      p2Measured1: null as number | null,
      p2Measured2: null as number | null,
      p2UseManualSpans: false,
      probeTarget: null as number | null,
      // Phase 3
      blMeanPos: null as number | null,
      blMeanNeg: null as number | null,
      blSamplesPos: [] as number[],
      blSamplesNeg: [] as number[],
      showScatter: false,
      // Phase 4 — X default: 3″ face
      blockDeflectFace: NXT_123_AXIS_DEFAULTS.X.primaryFace as Nxt123FaceId,
      defMeasured: null as number | null,
      // Undo
      prevSteps: null as number | null,
      prevBacklash: null as number | null,
      prevDeflection: null as number[] | null,
      // Pending for save
      pendingSteps: {} as Partial<Record<AxisLetter, number>>,
      pendingBacklash: {} as Partial<Record<AxisLetter, number>>,
      pendingDeflection: null as number[] | null,
      // Rotary
      rotaryWcs: 54,
      aCommanded: 90 as number | null,
      aActual: null as number | null,
      cmdM4912ProbeYFlatness,
      cmdM4910ProbeYCenter,
      cmdM4807ApplyY0
    }
  },
  computed: {
    rotaryAvailable(): boolean {
      const model = this.$store.state.machine.model
      return isRotaryCalibrationAvailable({
        modelPlugins: model?.plugins as any,
        settingsPlugins: this.$store.state.settings?.plugins as any,
        axes: model?.move?.axes as any
      })
    },
    axisSelectItems(): Array<{ value: AxisLetter; title: string }> {
      const items: Array<{ value: AxisLetter; title: string }> = [
        { value: 'X', title: 'X' },
        { value: 'Y', title: 'Y' },
        { value: 'Z', title: 'Z' }
      ]
      if (this.rotaryAvailable) {
        items.push({ value: 'A', title: 'A (rotary)' })
      }
      return items
    },
    axisIndex(): number {
      const map: Record<AxisLetter, number> = { X: 0, Y: 1, Z: 2, A: 3 }
      const axis = this.selectedAxis as AxisLetter
      return map[axis] ?? 0
    },
    currentAxisOm(): { stepsPerMm?: number; backlash?: number } | null {
      const axes = this.$store.state.machine.model.move?.axes
      if (!Array.isArray(axes)) return null
      return axes[this.axisIndex] ?? null
    },
    currentSteps(): number {
      if (this.selectedAxis === 'A') {
        const g = this.$store.state.machine.model.global
        const r = readFirmwareGlobal(g, 'rotaryAStepsPerMm')
        if (typeof r === 'number' && r > 0) return r
      }
      const s = this.currentAxisOm?.stepsPerMm
      return typeof s === 'number' && s > 0 ? s : 0
    },
    currentBacklash(): number {
      const b = this.currentAxisOm?.backlash
      return typeof b === 'number' ? b : 0
    },
    currentDeflection(): number[] | null {
      return readConfigDeflectionXY(
        readFirmwareGlobal(this.$store.state.machine.model.global, 'nxtProbeDeflection')
      )
    },
    currentStepsDisplay(): string {
      return this.currentSteps > 0 ? this.currentSteps.toFixed(4) : '—'
    },
    currentBacklashDisplay(): string {
      return this.currentBacklash.toFixed(4)
    },
    deflectionDisplay(): string {
      const v = this.currentDeflection
      if (v == null) return '—'
      const z = v.length >= 3 ? v[2] : v[0]
      return `X ${v[0].toFixed(4)} / Y ${v[1].toFixed(4)} / Z ${z.toFixed(4)}`
    },
    touchProbeReady(): boolean {
      const g = this.$store.state.machine.model.global
      return (
        readFirmwareGlobal(g, 'nxtFeatureTouchProbe') === true &&
        typeof readFirmwareGlobal(g, 'nxtTouchProbeID') === 'number'
      )
    },
    probeToolIdResolved(): number | null {
      return resolveNxtProbeToolId(this.$store.state.machine.model.global)
    },
    probeToolLoaded(): boolean {
      const cur = this.$store.state.machine.model?.state?.currentTool
      const idx = typeof cur === 'number' ? cur : null
      const toolNumRaw = this.currentTool?.number
      const toolNum = typeof toolNumRaw === 'number' ? toolNumRaw : null
      return isNxtProbeToolLoaded(idx, this.probeToolIdResolved, toolNum)
    },
    touchProbeId(): number | null {
      const v = readFirmwareGlobal(this.$store.state.machine.model.global, 'nxtTouchProbeID')
      return typeof v === 'number' ? v : null
    },
    p1FaceAwayItems(): Array<{ value: 1 | -1; title: string }> {
      const ax = this.selectedAxis
      return [
        {
          value: 1,
          title: this.$t('plugins.nxt.panels.calibration.faceAwayPlus', [ax]).toString()
        },
        {
          value: -1,
          title: this.$t('plugins.nxt.panels.calibration.faceAwayMinus', [ax]).toString()
        }
      ]
    },
    canRunP1Motion(): boolean {
      if (!this.isConnected || this.uiFrozen) return false
      if (this.selectedAxis === 'A') return false
      if (this.touchProbeBlocksLaterPhases) return false
      return this.p1FaceAway === 1 || this.p1FaceAway === -1
    },
    blockFacePairItems(): Array<{ value: Nxt123FacePairId; title: string }> {
      return (Object.keys(NXT_123_FACE_PAIRS) as Nxt123FacePairId[]).map((id) => ({
        value: id,
        title: this.$t(`plugins.nxt.panels.calibration.${NXT_123_FACE_PAIRS[id].labelKey}`).toString()
      }))
    },
    blockFaceItems(): Array<{ value: Nxt123FaceId; title: string }> {
      return (Object.keys(NXT_123_FACES) as Nxt123FaceId[]).map((id) => ({
        value: id,
        title: this.$t(`plugins.nxt.panels.calibration.${NXT_123_FACES[id].labelKey}`).toString()
      }))
    },
    refDim1(): number {
      return NXT_123_FACE_PAIRS[this.blockFacePair as Nxt123FacePairId].dim1
    },
    refDim2(): number {
      return NXT_123_FACE_PAIRS[this.blockFacePair as Nxt123FacePairId].dim2
    },
    defActual(): number {
      return NXT_123_FACES[this.blockDeflectFace as Nxt123FaceId].mm
    },
    effectiveP2Measured1(): number | null {
      if (
        !this.p2UseManualSpans &&
        this.p2Face1Left != null &&
        this.p2Face1Right != null
      ) {
        return spanFromFaces(this.p2Face1Left, this.p2Face1Right)
      }
      return this.p2Measured1
    },
    effectiveP2Measured2(): number | null {
      if (
        !this.p2UseManualSpans &&
        this.p2Face2Left != null &&
        this.p2Face2Right != null
      ) {
        return spanFromFaces(this.p2Face2Left, this.p2Face2Right)
      }
      return this.p2Measured2
    },
    p2Proposed(): number | null {
      if (this.effectiveP2Measured1 == null || this.effectiveP2Measured2 == null) return null
      return (
        dualDimensionStepsCorrection(
          this.currentSteps,
          this.refDim1,
          this.refDim2,
          this.effectiveP2Measured1,
          this.effectiveP2Measured2
        ).result?.newSteps ?? null
      )
    },
    p2Preview(): string {
      const r = dualDimensionStepsCorrection(
        this.currentSteps,
        this.refDim1,
        this.refDim2,
        this.effectiveP2Measured1 ?? 0,
        this.effectiveP2Measured2 ?? 0
      )
      if (r.errors.length) return r.errors[0]
      if (!r.result) return ''
      const w = r.warnings[0] ? ` — ${r.warnings[0]}` : ''
      return `→ ${r.result.newSteps.toFixed(4)}${w}`
    },
    canApplyP2(): boolean {
      return (
        this.p2Proposed != null &&
        this.selectedAxis !== 'A' &&
        !this.uiFrozen &&
        !this.touchProbeBlocksLaterPhases
      )
    },
    blProposed(): number | null {
      if (this.blMeanPos == null || this.blMeanNeg == null) return null
      return backlashFromMeans(this.blMeanPos, this.blMeanNeg)
    },
    blPreview(): string {
      if (this.blProposed == null) return ''
      return `→ ${this.blProposed.toFixed(4)} mm`
    },
    currentAxisDeflection(): number {
      const v = this.currentDeflection
      if (v == null) return 0
      if (this.selectedAxis === 'Y') return v.length >= 2 ? v[1] : 0
      if (this.selectedAxis === 'Z') return v.length >= 3 ? v[2] : v.length >= 1 ? v[0] : 0
      return v.length >= 1 ? v[0] : 0
    },
    defProposed(): number | null {
      if (this.defActual == null || this.defMeasured == null) return null
      if (this.selectedAxis === 'A') return null
      return (
        deflectionFromSpan(this.defMeasured, this.defActual, this.currentAxisDeflection).result
      )
    },
    defPreview(): string {
      if (this.defProposed == null) return ''
      return `→ ${this.defProposed.toFixed(4)} mm`
    },
    p4DiveItems(): Array<{ value: number; title: string }> {
      return [
        { value: 5, title: '5 mm' },
        { value: 8, title: '8 mm' },
        { value: 10, title: '10 mm' },
        { value: 12.7, title: '12.7 mm (½″)' }
      ]
    },
    roughDzFromOm(): number | null {
      return readConfigNumber(readFirmwareGlobal(this.globalOm, 'nxtCalDefZ'))
    },
    roughDzDisplay(): string {
      const z = this.defProposedZEdit ?? this.roughDzFromOm
      return z != null && Number.isFinite(z) ? `${z.toFixed(4)} mm` : '— (load probe / G6511)'
    },
    defProposedX(): number | null {
      if (this.defMeasuredX == null) return null
      const cur = this.currentDeflection
      const curX = cur != null && cur.length >= 1 ? cur[0] : 0
      return deflectionFromSpan(this.defMeasuredX, NXT_123_BLOCK_MM.inch3, curX).result
    },
    defProposedY(): number | null {
      if (this.defMeasuredY == null) return null
      const cur = this.currentDeflection
      const curY = cur != null && cur.length >= 2 ? cur[1] : 0
      return deflectionFromSpan(this.defMeasuredY, NXT_123_BLOCK_MM.inch2, curY).result
    },
    xyDefPreview(): string {
      const dx = this.defProposedX
      const dy = this.defProposedY
      const dz = this.defProposedZEdit ?? this.roughDzFromOm
      if (dx == null && dy == null && dz == null) return ''
      const xs = dx != null ? dx.toFixed(4) : '—'
      const ys = dy != null ? dy.toFixed(4) : '—'
      const zs = dz != null ? Number(dz).toFixed(4) : '—'
      return `→ {${xs}, ${ys}, ${zs}}`
    },
    probeTipRadiusFromOm(): number | null {
      return readConfigNumber(readFirmwareGlobal(this.globalOm, 'nxtProbeTipRadius'))
    },
    probeTipRadiusDisplay(): string {
      const r = this.probeTipRadiusFromOm
      if (r == null || !Number.isFinite(r)) return ''
      const dia = probeTipDiameterMm(r)
      return `${r.toFixed(3)} mm (ball ⌀ ${dia.toFixed(3)} mm)`
    },
    xyShortfallDisplay(): string {
      if (this.defMeasuredX == null || this.defMeasuredY == null) return ''
      const sx = externalSpanShortfall(this.defMeasuredX, NXT_123_BLOCK_MM.inch3)
      const sy = externalSpanShortfall(this.defMeasuredY, NXT_123_BLOCK_MM.inch2)
      return `shortfall X ${sx.toFixed(3)} / Y ${sy.toFixed(3)} mm`
    },
    xyDeflectionImplausible(): boolean {
      const tip = this.probeTipRadiusFromOm
      const tipSuspect = tip != null && suspectTipDiameterAsRadius(tip)
      const dxBad =
        this.defProposedX != null && implausibleExternalDeflection(this.defProposedX)
      const dyBad =
        this.defProposedY != null && implausibleExternalDeflection(this.defProposedY)
      return tipSuspect || dxBad || dyBad
    },
    canApplyXyDeflection(): boolean {
      return (
        this.defProposedX != null &&
        this.defProposedY != null &&
        !this.uiFrozen &&
        this.selectedAxis !== 'A'
      )
    },
    aProposed(): number | null {
      if (this.aCommanded == null || this.aActual == null) return null
      return roughStepsCorrection(this.currentSteps, this.aCommanded, this.aActual).result?.newSteps ?? null
    },
    aStepsPreview(): string {
      if (this.aProposed == null) return ''
      return `→ ${this.aProposed.toFixed(4)}`
    },
    wcsOptions(): Array<{ text: string; value: number }> {
      return [
        { text: 'G54', value: 54 },
        { text: 'G55', value: 55 },
        { text: 'G56', value: 56 },
        { text: 'G57', value: 57 },
        { text: 'G58', value: 58 },
        { text: 'G59', value: 59 },
        { text: 'G59.1', value: 591 },
        { text: 'G59.2', value: 592 },
        { text: 'G59.3', value: 593 }
      ]
    },
    scatterPoints(): Array<{ x: number; y: number; dir: 'pos' | 'neg' }> {
      const all = [
        ...this.blSamplesPos.map((v: number) => ({ v, dir: 'pos' as const })),
        ...this.blSamplesNeg.map((v: number) => ({ v, dir: 'neg' as const }))
      ]
      if (!all.length) return []
      const vals = all.map((a: { v: number; dir: 'pos' | 'neg' }) => a.v)
      const min = Math.min(...vals)
      const max = Math.max(...vals)
      const span = max - min || 1
      return all.map((a: { v: number; dir: 'pos' | 'neg' }, i: number) => ({
        x: 20 + (i / Math.max(all.length - 1, 1)) * 280,
        y: 100 - ((a.v - min) / span) * 80,
        dir: a.dir
      }))
    },
    isCustomPlatform(): boolean {
      const p = readFirmwareGlobal(this.$store.state.machine.model.global, 'nxtPlatformProfile')
      return p === 'custom'
    },
    globalOm(): unknown {
      return this.$store.state.machine.model.global
    },
    toolSetterPosVec(): number[] | null {
      const v = readConfigVector(readFirmwareGlobal(this.globalOm, 'nxtToolSetterPos'))
      return v && v.length >= 3 ? v : null
    },
    touchProbeRefPosVec(): number[] | null {
      const v = readConfigVector(readFirmwareGlobal(this.globalOm, 'nxtTouchProbeRefPos'))
      return v && v.length >= 3 ? v : null
    },
    toolSetterPosSet(): boolean {
      return this.toolSetterPosVec != null
    },
    touchProbeRefPosSet(): boolean {
      return this.touchProbeRefPosVec != null
    },
    deltaMachineSet(): boolean {
      return readConfigNumber(readFirmwareGlobal(this.globalOm, 'nxtDeltaMachine')) != null
    },
    toolSetterV2(): boolean {
      return readConfigBool(readFirmwareGlobal(this.globalOm, 'nxtToolSetterV2'))
    },
    phase0HintText(): string {
      if (this.toolSetterV2) {
        return this.$t('plugins.nxt.panels.calibration.phase0HintV2').toString()
      }
      return this.$t('plugins.nxt.panels.calibration.phase0Hint').toString()
    },
    toolSetterPosDisplay(): string {
      const v = this.toolSetterPosVec
      return v ? v.map((n: number) => n.toFixed(3)).join(', ') : '—'
    },
    touchProbeRefPosDisplay(): string {
      const v = this.touchProbeRefPosVec
      return v ? v.map((n: number) => n.toFixed(3)).join(', ') : '—'
    },
    deltaMachineDisplay(): string {
      const n = readConfigNumber(readFirmwareGlobal(this.globalOm, 'nxtDeltaMachine'))
      return n != null ? n.toFixed(4) : '—'
    },
    probeAndToolsetterConfigured(): boolean {
      const g = this.globalOm
      return (
        readConfigBool(readFirmwareGlobal(g, 'nxtFeatureTouchProbe')) &&
        readConfigBool(readFirmwareGlobal(g, 'nxtFeatureToolSetter')) &&
        readConfigNumber(readFirmwareGlobal(g, 'nxtTouchProbeID')) != null &&
        readConfigNumber(readFirmwareGlobal(g, 'nxtToolSetterID')) != null
      )
    },
    needsProbeDatumSetup(): boolean {
      if (!this.probeAndToolsetterConfigured) return false
      return !this.touchProbeRefPosSet || !this.deltaMachineSet
    },
    probeModeSelectable(): boolean {
      return this.touchProbeReady
    },
    rawDeflectionValue(): number[] | null {
      return readConfigDeflectionXY(readFirmwareGlobal(this.globalOm, 'nxtProbeDeflection'))
    },
    probeDeflectionReady(): boolean {
      if (this.sessionDeflectionOk) return true
      if (this.pendingDeflection != null) {
        const p = this.pendingDeflection
        if (
          p.length >= 3 &&
          (p[0] !== 0 || p[1] !== 0 || p[2] !== 0)
        ) {
          return true
        }
      }
      return false
    },
    /** Touch probe on and D not session-ready — block P1–P3 / G9000 / Save. */
    touchProbeBlocksLaterPhases(): boolean {
      return this.touchProbeReady && (!this.probeDeflectionReady || this.needsDeflectionRecheck)
    },
    canSaveCalibration(): boolean {
      if (this.touchProbeReady) {
        return this.probeDeflectionReady && !this.needsDeflectionRecheck
      }
      return true
    },
    canConfirmExistingDeflection(): boolean {
      const v = this.rawDeflectionValue
      if (v == null || v.length < 3) return false
      if (!Number.isFinite(v[0]) || !Number.isFinite(v[1]) || !Number.isFinite(v[2])) return false
      return !isFactoryZeroDeflection(v)
    },
    canRunG9000(): boolean {
      const xyReady =
        (this.selectedAxis === 'X' || this.selectedAxis === 'Y') && this.p4DiveMm > 0
      const zOk = this.selectedAxis === 'Z'
      return (
        this.calMode === 'probe' &&
        this.probeToolLoaded &&
        this.probeDeflectionReady &&
        !this.needsDeflectionRecheck &&
        this.isConnected &&
        !this.uiFrozen &&
        this.selectedAxis !== 'A' &&
        this.touchProbeReady &&
        (xyReady || zOk)
      )
    },
    canRunM5017(): boolean {
      return (
        this.calMode === 'probe' &&
        this.touchProbeReady &&
        this.probeToolLoaded &&
        this.isConnected &&
        !this.uiFrozen &&
        this.p4DiveMm > 0
      )
    },
    canProbeCaptureFace(): boolean {
      if (!this.isConnected) return false
      if (this.touchProbeBlocksLaterPhases) return false
      if (this.calMode !== 'probe') return true
      // Phase 3 approach assist (M5018) is XY-only; Z fine span remains deferred
      if (this.selectedAxis !== 'X' && this.selectedAxis !== 'Y') return false
      return (
        this.touchProbeReady &&
        this.probeToolLoaded &&
        !this.uiFrozen &&
        this.p4DiveMm > 0
      )
    },
    canAddBacklashSample(): boolean {
      return (
        this.isConnected &&
        !this.uiFrozen &&
        this.selectedAxis !== 'A' &&
        !this.touchProbeBlocksLaterPhases
      )
    },
    /** Deep-watched blob for debounced nxtCalSession persist */
    calSessionSnapshot(): NxtCalSessionPanelFields {
      return pickCalSessionFromPanel(this as unknown as NxtCalSessionPanelFields)
    }
  },
  watch: {
    selectedAxis(axis: AxisLetter) {
      if (this.calSessionHydrating) return
      this.apply123DefaultsForAxis(axis)
      this.schedulePersistCalSession()
    },
    probeModeSelectable(ready: boolean) {
      if (!ready && this.calMode === 'probe') {
        this.calMode = 'manual'
      }
    },
    calMode(mode: string) {
      if (this.calSessionHydrating) return
      if (mode === 'probe') {
        this.p2UseManualSpans = false
        this.openPhase = this.probeDeflectionReady && !this.needsDeflectionRecheck ? null : '1'
        void this.enforceDeflectionJobGate()
      } else if (mode === 'manual') {
        this.openPhase =
          this.touchProbeReady && (!this.probeDeflectionReady || this.needsDeflectionRecheck)
            ? '1'
            : '2'
      }
      this.schedulePersistCalSession()
    },
    calSessionSnapshot: {
      deep: true,
      handler(this: {
        calSessionHydrating: boolean
        schedulePersistCalSession: () => void
      }) {
        if (this.calSessionHydrating) return
        this.schedulePersistCalSession()
      }
    }
  },
  mounted() {
    this.hydrateCalSession()
    if (this.touchProbeReady && (!this.probeDeflectionReady || this.needsDeflectionRecheck)) {
      this.openPhase = '1'
    }
  },
  beforeUnmount() {
    this.flushPersistCalSession()
  },
  methods: {
    schedulePersistCalSession() {
      if (this.calSessionHydrating) return
      if (this.calSessionPersistTimer != null) {
        clearTimeout(this.calSessionPersistTimer)
      }
      this.calSessionPersistTimer = setTimeout(() => {
        this.calSessionPersistTimer = null
        this.flushPersistCalSession()
      }, 250)
    },
    flushPersistCalSession() {
      if (this.calSessionPersistTimer != null) {
        clearTimeout(this.calSessionPersistTimer)
        this.calSessionPersistTimer = null
      }
      if (this.calSessionHydrating) return
      try {
        writeNxtCalSession(pickCalSessionFromPanel(this as unknown as NxtCalSessionPanelFields))
      } catch {
        /* settings store may be unavailable during teardown */
      }
    },
    hydrateCalSession() {
      this.calSessionHydrating = true
      try {
        const snap = readNxtCalSession(this.$store.state.settings?.plugins)
        if (snap != null) {
          applyCalSessionToPanel(this as unknown as NxtCalSessionPanelFields, snap)
        }
        const live = this.rawDeflectionValue
        const gate = reconcileDeflectionConfirm({
          liveOm: live,
          confirmedDeflection: this.confirmedDeflection,
          sessionDeflectionOk: this.sessionDeflectionOk,
          needsDeflectionRecheck: this.needsDeflectionRecheck
        })
        this.sessionDeflectionOk = gate.sessionDeflectionOk
        this.needsDeflectionRecheck = gate.needsDeflectionRecheck
        if (this.travelLegs.length === 0) {
          const travelAxis = readFirmwareGlobal(this.globalOm, 'nxtCalTravelAxis')
          const axisStr =
            travelAxis != null && travelAxis !== '' ? String(travelAxis).toUpperCase() : ''
          if (axisStr === this.selectedAxis) {
            const cmd = this.readTravelVector('nxtCalTravelCmd')
            const meas = this.readTravelVector('nxtCalTravelMeas')
            if (this.travelVectorsReady(cmd, meas)) {
              this.applyTravelLegsFromVectors(cmd, meas)
            }
          }
        }
      } finally {
        this.calSessionHydrating = false
      }
    },
    markDeflectionConfirmed(vector: number[]) {
      this.confirmedDeflection = vector.slice(0, 3)
      this.sessionDeflectionOk = true
      this.needsDeflectionRecheck = false
      this.schedulePersistCalSession()
    },
    apply123DefaultsForAxis(axis: AxisLetter) {
      const d = nxt123DefaultsForAxis(axis)
      this.blockFacePair = d.facePair
      this.blockDeflectFace = d.primaryFace
      if (axis === 'A') {
        this.aCommanded = d.p1Commanded
      } else {
        this.p1Commanded = d.p1Commanded
      }
    },
    show(msg: string, type: 'info' | 'success' | 'error' | 'warning' = 'info') {
      this.statusMsg = msg
      this.statusType = type
      this.$store.dispatch('machine/showMessage', { type, message: msg })
    },
    async runRotary(code: string) {
      try {
        await this.sendCode(code)
        this.show(`Executed ${code}`, 'success')
      } catch (e: any) {
        this.show(e?.message ?? 'Command failed', 'error')
      }
    },
    async applyASteps() {
      if (this.aProposed == null) return
      if (!window.confirm(`Apply A steps ${this.aProposed.toFixed(4)} via M4806?`)) return
      this.prevSteps = this.currentSteps
      try {
        await this.sendCode(cmdM4806SetSteps(this.aProposed))
        this.pendingSteps.A = this.aProposed
        this.show('A steps applied (M4806)', 'success')
      } catch (e: any) {
        this.show(e?.message ?? 'M4806 failed', 'error')
      }
    },
    async applySteps(proposed: number | null, _src: string) {
      if (proposed == null || this.selectedAxis === 'A') return
      const axis = this.selectedAxis
      if (!window.confirm(`Apply M92 ${axis}${proposed.toFixed(4)}?`)) return
      this.prevSteps = this.currentSteps
      try {
        await this.sendCode(`M92 ${axis}${proposed}`)
        this.pendingSteps[axis] = proposed
        this.show(`Steps applied for ${axis}`, 'success')
        if (this.calMode === 'probe') {
          this.needsDeflectionRecheck = true
          this.sessionDeflectionOk = false
          this.openPhase = '1'
          this.show(this.$t('plugins.nxt.panels.calibration.deflectionRecheckHint').toString(), 'warning')
        }
      } catch (e: any) {
        this.show(e?.message ?? 'M92 failed', 'error')
      }
    },
    async applyBacklash() {
      if (this.blProposed == null) return
      const axis = this.selectedAxis
      if (!window.confirm(`Apply M425 ${axis}${this.blProposed.toFixed(4)}?`)) return
      this.prevBacklash = this.currentBacklash
      const axes = this.$store.state.machine.model.move?.axes ?? []
      const parts: string[] = []
      for (let i = 0; i < Math.min(axes.length, 4); i++) {
        const letter = (axes[i]?.letter ?? ['X', 'Y', 'Z', 'A'][i]) as string
        const val = letter === axis ? this.blProposed : (axes[i]?.backlash ?? 0)
        parts.push(`${letter}${val}`)
      }
      try {
        await this.sendCode(`M425 ${parts.join(' ')}`)
        this.pendingBacklash[axis] = this.blProposed
        this.show(`Backlash applied for ${axis}`, 'success')
      } catch (e: any) {
        this.show(e?.message ?? 'M425 failed', 'error')
      }
    },
    async applyDeflection() {
      if (this.defProposed == null) return
      const axis = this.selectedAxis
      if (axis === 'A') {
        this.show('A-axis has no linear probe deflection channel', 'warning')
        return
      }
      const cur = this.currentDeflection ?? [0, 0, 0]
      const next: number[] = [
        cur.length >= 1 ? cur[0] : 0,
        cur.length >= 2 ? cur[1] : 0,
        cur.length >= 3 ? cur[2] : cur.length >= 1 ? cur[0] : 0
      ]
      if (axis === 'X') next[0] = this.defProposed
      else if (axis === 'Y') next[1] = this.defProposed
      else if (axis === 'Z') next[2] = this.defProposed
      const label = `{${next[0].toFixed(4)}, ${next[1].toFixed(4)}, ${next[2].toFixed(4)}}`
      if (!window.confirm(`Set nxtProbeDeflection = ${label}?`)) return
      this.prevDeflection = cur
      try {
        await ensureSetFirmwareGlobal('nxtProbeDeflection', formatOmRhs(next), (c) => this.sendCode(c))
        this.pendingDeflection = next
        this.markDeflectionConfirmed(next)
        this.show(`Probe deflection updated ${label}`, 'success')
      } catch (e: any) {
        this.show(e?.message ?? 'Failed to set deflection', 'error')
      }
    },
    confirmExistingDeflection() {
      const v = this.rawDeflectionValue
      if (v == null) return
      const z = v.length >= 3 ? v[2] : v[0]
      if (isFactoryZeroDeflection(v)) {
        this.show(this.$t('plugins.nxt.panels.calibration.confirmZeroDeflection').toString(), 'error')
        this.openPhase = '1'
        return
      }
      this.markDeflectionConfirmed(v)
      this.show(
        `Using deflection X ${v[0].toFixed(4)} / Y ${v[1].toFixed(4)} / Z ${z.toFixed(4)} mm`,
        'success'
      )
    },
    skipPhase(phase: string) {
      if (phase === '1' || phase === '0') return
      const order =
        this.calMode === 'probe' ? ['1', '3', '4', '5'] : ['1', '2', '3', '4', '5']
      const i = order.indexOf(phase)
      if (i < 0 || i >= order.length - 1) {
        this.openPhase = '5'
        return
      }
      this.openPhase = order[i + 1]
    },
    async enforceDeflectionJobGate() {
      if (!this.touchProbeReady || !this.isConnected) return
      try {
        await this.sendCode('M4006')
      } catch (e: any) {
        this.openPhase = '1'
        this.show(
          e?.message ?? this.$t('plugins.nxt.panels.calibration.deflectionGateHint').toString(),
          'warning'
        )
      }
    },
    async runDatumSetup() {
      this.datumBusy = true
      try {
        await this.sendCode('M5016')
        this.show('Datum setup (M5016) finished — park and load probe, then Save', 'success')
      } catch (e: any) {
        this.show(e?.message ?? 'M5016 failed', 'error')
      } finally {
        this.datumBusy = false
      }
    },
    async parkAndLoadProbe() {
      const toolId = this.probeToolIdResolved
      if (toolId == null) {
        this.show(this.$t('plugins.nxt.panels.calibration.probeToolIdUnset').toString(), 'error')
        return
      }
      this.probeLoadBusy = true
      try {
        await enableNxtProbeTool((c: string) => this.sendCode(c), toolId)
        const rz = readConfigNumber(readFirmwareGlobal(this.globalOm, 'nxtCalDefZ'))
        if (rz != null) this.defProposedZEdit = rz
        this.show(
          this.$t('plugins.nxt.panels.calibration.enableProbeDone', [toolId]).toString(),
          'success'
        )
      } catch (e: any) {
        this.show(e?.message ?? 'Enable Probe failed', 'error')
      } finally {
        this.probeLoadBusy = false
      }
    },
    readTravelVector(key: string): number[] {
      const v = readConfigVector(readFirmwareGlobal(this.globalOm, key))
      if (!v || v.length < 3) return []
      const out = v.slice(0, 3).map((n: number) => Number(n))
      return out.every((n: number) => Number.isFinite(n)) ? out : []
    },
    travelVectorsReady(cmd: number[], meas: number[]): boolean {
      if (cmd.length < 3 || meas.length < 3) return false
      const expected = travelCommandedLegs()
      // Initial macro seed is {0,0,0}; wait until the longest slot is written.
      if (cmd[0] === expected[0] && cmd[1] === expected[1] && cmd[2] === expected[2]) {
        if (meas[0] === 0 && meas[1] === 0 && meas[2] === 0) return false
      }
      return true
    },
    applyTravelLegsFromVectors(cmd: number[], meas: number[]): void {
      this.travelLegs = [0, 1, 2].map((i: number) => ({
        commanded: cmd[i],
        measured: meas[i]
      }))
      this.travelClassification = classifyTravelCalibration(this.travelLegs, this.currentSteps)
      const eLong = meas[2] - cmd[2]
      this.show(
        `${this.travelClassification.summary} (${cmd[2]} mm err ${eLong >= 0 ? '+' : ''}${eLong.toFixed(4)} mm)`,
        'info'
      )
    },
    async loadTravelResultsFromGlobals(): Promise<boolean> {
      const maxAttempts = 12
      for (let attempt = 0; attempt < maxAttempts; attempt++) {
        const cmd = this.readTravelVector('nxtCalTravelCmd')
        const meas = this.readTravelVector('nxtCalTravelMeas')
        if (this.travelVectorsReady(cmd, meas)) {
          this.applyTravelLegsFromVectors(cmd, meas)
          return true
        }
        await new Promise((resolve: (v: void) => void) => setTimeout(resolve, 300))
      }
      const cmd = this.readTravelVector('nxtCalTravelCmd')
      const meas = this.readTravelVector('nxtCalTravelMeas')
      if (cmd.length >= 3 && meas.length >= 3) {
        this.applyTravelLegsFromVectors(cmd, meas)
        this.show('Travel globals loaded but longest slot may still be stale — check console echoes', 'warning')
        return true
      }
      const legs = travelCommandedLegs()
      this.show(
        `Travel test finished but globals are incomplete (need ${legs.join('/')})`,
        'warning'
      )
      return false
    },
    async runG9000() {
      if (!this.canRunG9000) return
      const axis = this.selectedAxis as AxisLetter
      if (axis === 'A') return
      if (!window.confirm(
        this.$t('plugins.nxt.panels.calibration.runG9000Confirm', [axis]).toString()
      )) {
        return
      }
      this.g9000Busy = true
      this.travelLegs = []
      this.travelClassification = null
      try {
        if (axis === 'X' || axis === 'Y') {
          // Save center, M5018 R0 (outside + find, stay out), G9000, return to center
          const sizeMm = nxt123DefaultsForAxis(axis).primaryMm
          const approachDir = -1
          const clearance = 15
          const toward = 1
          const centerBefore = this.axisMachinePosition()
          await this.sendCode(
            `M5018 ${axis}${approachDir} O${clearance} S${sizeMm} D${this.p4DiveMm} R0`
          )
          await this.sendCode(`G9000 ${axis}0 J0 H${toward}`)
          if (centerBefore != null) {
            await this.sendCode('G90')
            await this.sendCode(`G91 G0 Z${this.p4DiveMm}`)
            await this.sendCode('G90')
            await this.sendCode(`G53 G0 ${axis}${centerBefore}`)
          }
        } else {
          await this.sendCode(`G9000 ${axis}0`)
        }
        await this.loadTravelResultsFromGlobals()
      } catch (e: any) {
        this.show(e?.message ?? 'G9000 failed', 'error')
      } finally {
        this.g9000Busy = false
      }
    },
    async applyTravelBacklash() {
      const proposed = this.travelClassification?.proposedBacklash
      if (proposed == null) return
      const axis = this.selectedAxis
      if (axis === 'A') return
      if (!window.confirm(`Apply M425 ${axis}${proposed.toFixed(4)} from travel test?`)) return
      this.prevBacklash = this.currentBacklash
      const axes = this.$store.state.machine.model.move?.axes ?? []
      const parts: string[] = []
      for (let i = 0; i < Math.min(axes.length, 4); i++) {
        const letter = (axes[i]?.letter ?? ['X', 'Y', 'Z', 'A'][i]) as string
        const val = letter === axis ? proposed : (axes[i]?.backlash ?? 0)
        parts.push(`${letter}${val}`)
      }
      try {
        await this.sendCode(`M425 ${parts.join(' ')}`)
        this.pendingBacklash[axis] = proposed
        this.show(`Backlash ${proposed.toFixed(4)} mm applied for ${axis}`, 'success')
      } catch (e: any) {
        this.show(e?.message ?? 'M425 failed', 'error')
      }
    },
    async runPhase1MotionTest() {
      if (!this.canRunP1Motion) return
      const axis = this.selectedAxis as AxisLetter
      if (axis === 'A') return
      const dir = this.p1FaceAway
      const rPart = this.p1Repeat3x ? ' R3' : ''
      if (!window.confirm(
        this.$t('plugins.nxt.panels.calibration.runMotionTestConfirm', [axis, String(dir)]).toString()
      )) {
        return
      }
      this.p1MotionBusy = true
      this.travelLegs = []
      this.travelClassification = null
      try {
        await this.sendCode(`M5014 ${axis}0 D${dir}${rPart}`)
        await this.loadTravelResultsFromGlobals()
      } catch (e: any) {
        this.show(e?.message ?? 'M5014 motion test failed', 'error')
      } finally {
        this.p1MotionBusy = false
      }
    },
    async sendG6512() {
      if (this.probeTarget == null || this.touchProbeId == null || this.selectedAxis === 'A') return
      const axis = this.selectedAxis as AxisLetter
      if (axis !== 'X' && axis !== 'Y' && axis !== 'Z') return
      const code = `M5015 ${axis}${this.probeTarget} I${this.touchProbeId}`
      try {
        await this.sendCode(code)
        this.show(`Probe assist finished (${code}) — capture result`, 'info')
      } catch (e: any) {
        this.show(e?.message ?? 'M5015 / G6512 failed', 'error')
      }
    },
    axisMachinePosition(): number | null {
      const axes = this.$store.state.machine.model.move?.axes
      if (!Array.isArray(axes)) return null
      const ax = axes[this.axisIndex] as { machinePosition?: number; userPosition?: number } | undefined
      const mp = ax?.machinePosition
      if (typeof mp === 'number' && Number.isFinite(mp)) return mp
      const up = ax?.userPosition
      return typeof up === 'number' && Number.isFinite(up) ? up : null
    },
    async applyXyDeflection() {
      if (!this.canApplyXyDeflection || this.defProposedX == null || this.defProposedY == null) return
      const cur = this.currentDeflection ?? [0, 0, 0]
      const dzRaw = this.defProposedZEdit ?? this.roughDzFromOm
      const dz =
        dzRaw != null && Number.isFinite(dzRaw)
          ? Number(dzRaw)
          : cur.length >= 3
            ? cur[2]
            : 0
      const next: number[] = [this.defProposedX, this.defProposedY, dz]
      const label = `{${next[0].toFixed(4)}, ${next[1].toFixed(4)}, ${next[2].toFixed(4)}}`
      let confirmMsg = `Set nxtProbeDeflection = ${label}?`
      if (this.xyDeflectionImplausible) {
        confirmMsg =
          `Proposed deflection looks implausible (check tip RADIUS, not diameter). ` +
          `Still set nxtProbeDeflection = ${label}?`
      }
      if (!window.confirm(confirmMsg)) return
      this.prevDeflection = cur
      try {
        await ensureSetFirmwareGlobal('nxtProbeDeflection', formatOmRhs(next), (c) => this.sendCode(c))
        this.pendingDeflection = next
        this.markDeflectionConfirmed(next)
        this.show(`Probe deflection updated ${label}`, 'success')
      } catch (e: any) {
        this.show(e?.message ?? 'Failed to set deflection', 'error')
      }
    },
    async runProbeDeflectionSpan() {
      if (!this.canRunM5017) return
      if (!window.confirm(this.$t('plugins.nxt.panels.calibration.runM5017Confirm').toString())) {
        return
      }
      this.p4ProbeBusy = true
      try {
        await this.sendCode(`M5017 D${this.p4DiveMm} O5`)
        const sx = readConfigNumber(readFirmwareGlobal(this.globalOm, 'nxtCalDefSpanX'))
        const sy = readConfigNumber(readFirmwareGlobal(this.globalOm, 'nxtCalDefSpanY'))
        if (sx == null || sy == null || !Number.isFinite(sx) || !Number.isFinite(sy)) {
          this.show('M5017 finished but nxtCalDefSpanX/Y missing', 'warning')
          return
        }
        this.defMeasuredX = sx
        this.defMeasuredY = sy
        const rz = this.roughDzFromOm
        if (rz != null) this.defProposedZEdit = rz
        this.show(
          `Spans X ${sx.toFixed(4)} / Y ${sy.toFixed(4)} mm — review and Apply`,
          'success'
        )
      } catch (e: any) {
        this.show(e?.message ?? 'M5017 failed', 'error')
      } finally {
        this.p4ProbeBusy = false
      }
    },
    async onCaptureFace(slot: 'l1' | 'r1' | 'l2' | 'r2') {
      if (this.calMode === 'probe') {
        await this.probeAndCaptureFace(slot)
      } else {
        this.captureProbeFace(slot)
      }
    },
    async probeAndCaptureFace(slot: 'l1' | 'r1' | 'l2' | 'r2') {
      if (!this.canProbeCaptureFace || this.calMode !== 'probe') return
      const axis = this.selectedAxis as AxisLetter
      if (axis !== 'X' && axis !== 'Y') return
      if (this.touchProbeId == null) return
      const sizeMm = slot === 'l1' || slot === 'r1' ? this.refDim1 : this.refDim2
      const dir = slot === 'r1' || slot === 'r2' ? 1 : -1
      const clearance = 15
      this.p2CaptureBusy = slot
      try {
        // Raise→outside→dive→G6512 find→return to center (M5018 default)
        await this.sendCode(
          `M5018 ${axis}${dir} O${clearance} S${sizeMm} D${this.p4DiveMm}`
        )
        this.captureProbeFace(slot)
      } catch (e: any) {
        this.show(e?.message ?? 'Probe + capture failed', 'error')
      } finally {
        this.p2CaptureBusy = null
      }
    },
    lastProbeResult(): number | null {
      const v = readFirmwareGlobal(this.$store.state.machine.model.global, 'nxtLastProbeResult')
      return typeof v === 'number' ? v : null
    },
    captureProbeFace(slot: 'l1' | 'r1' | 'l2' | 'r2') {
      const v = this.lastProbeResult()
      if (v == null) {
        this.show('No nxtLastProbeResult yet', 'warning')
        return
      }
      if (slot === 'l1') this.p2Face1Left = v
      else if (slot === 'r1') this.p2Face1Right = v
      else if (slot === 'l2') this.p2Face2Left = v
      else this.p2Face2Right = v
      this.show(`Captured ${slot.toUpperCase()} = ${v}`, 'success')
    },
    addBacklashSample(dir: 'pos' | 'neg') {
      const v = this.lastProbeResult()
      if (v == null) {
        this.show('No nxtLastProbeResult yet', 'warning')
        return
      }
      if (dir === 'pos') {
        this.blSamplesPos.push(v)
        this.blMeanPos = meanOf(this.blSamplesPos)
      } else {
        this.blSamplesNeg.push(v)
        this.blMeanNeg = meanOf(this.blSamplesNeg)
      }
    },
    mergePendingIntoDraft(draft: NxtUserConfigDraft): void {
      if (this.pendingSteps.X != null) draft.nxtCustomXSteps = this.pendingSteps.X
      if (this.pendingSteps.Y != null) draft.nxtCustomYSteps = this.pendingSteps.Y
      if (this.pendingSteps.Z != null) draft.nxtCustomZSteps = this.pendingSteps.Z
      if (this.pendingSteps.A != null) draft.nxtCustomASteps = this.pendingSteps.A
      if (this.pendingBacklash.X != null) draft.nxtCustomXBacklash = this.pendingBacklash.X
      if (this.pendingBacklash.Y != null) draft.nxtCustomYBacklash = this.pendingBacklash.Y
      if (this.pendingBacklash.Z != null) draft.nxtCustomZBacklash = this.pendingBacklash.Z
      if (this.pendingBacklash.A != null) draft.nxtCustomABacklash = this.pendingBacklash.A
      if (this.pendingDeflection != null) draft.nxtProbeDeflection = this.pendingDeflection
    },
    async saveCalibration() {
      if (!this.canSaveCalibration) {
        this.show(this.$t('plugins.nxt.panels.calibration.saveBlockedDeflection').toString(), 'error')
        this.openPhase = '1'
        return
      }
      this.saving = true
      try {
        const draft = snapshotConfigFromOm(this.$store.state.machine.model.global)
        this.mergePendingIntoDraft(draft)
        if (
          this.touchProbeReady &&
          (draft.nxtProbeDeflection == null || isFactoryZeroDeflection(draft.nxtProbeDeflection))
        ) {
          this.show(this.$t('plugins.nxt.panels.calibration.saveBlockedDeflection').toString(), 'error')
          this.openPhase = '1'
          return
        }
        const result = await persistNxtUserConfig(draft, {
          sendCode: (c) => this.sendCode(c),
          isConnected: this.isConnected,
          deployCustomPack: this.isCustomPlatform
        })
        clearWizardProgressKeepConfirm(this as unknown as NxtCalSessionPanelFields)
        this.flushPersistCalSession()
        this.show(
          'Calibration saved to nxt-user-vars.g' +
            (result.customDeployed.length > 0 ? ' + custom overlays' : ''),
          'success'
        )
      } catch (e: any) {
        this.show(e?.message ?? 'Save failed', 'error')
      } finally {
        this.saving = false
      }
    }
  }
})
</script>
