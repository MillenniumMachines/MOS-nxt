<template>
  <v-card>
    <v-card-title class="d-flex align-center">
      <v-icon class="mr-2">mdi-crosshairs-gps</v-icon>
      {{ $t('plugins.nxt.panels.probingCycles.title') }}
    </v-card-title>

    <v-card-text>
      <v-alert v-if="!touchProbeEnabled" type="warning" density="compact" variant="outlined" class="mb-4">
        <v-icon class="mr-2" size="small">mdi-alert</v-icon>
        {{ $t('plugins.nxt.panels.probingCycles.touchProbeWarning') }}
      </v-alert>

      <v-alert
        v-else-if="probeToolId == null"
        type="warning"
        density="compact"
        variant="outlined"
        class="mb-4"
      >
        {{ $t('plugins.nxt.panels.probingCycles.probeToolIdUnset') }}
      </v-alert>

      <v-alert
        v-else-if="!touchProbeSelected"
        type="info"
        density="compact"
        variant="outlined"
        class="mb-4"
      >
        <div class="d-flex flex-column flex-sm-row align-sm-center justify-space-between ga-3">
          <div>
            <v-icon class="mr-2" size="small">mdi-information</v-icon>
            {{ $t('plugins.nxt.panels.probingCycles.selectProbeTool', [probeToolLabel]) }}
          </div>
          <v-btn
            color="primary"
            :loading="enableProbeBusy"
            :disabled="uiFrozen || !isConnected || enableProbeBusy"
            @click="enableProbe"
          >
            {{ $t('plugins.nxt.panels.probingCycles.enableProbe') }}
          </v-btn>
        </div>
      </v-alert>

      <v-row density="compact" class="mb-3">
        <v-col cols="12" sm="6">
          <v-select
            v-model="targetWcs"
            :items="wcsOptions"
            item-title="text"
            item-value="value"
            :label="$t('plugins.nxt.panels.probingCycles.targetWcs')"
            variant="outlined"
            density="compact"
            hide-details
          >
            <template v-slot:prepend-inner>
              <v-icon size="small">mdi-axis-arrow</v-icon>
            </template>
          </v-select>
        </v-col>
        <v-col cols="12" sm="6">
          <v-select
            v-model="rotationPolicy"
            :items="rotationPolicyOptions"
            item-title="text"
            item-value="value"
            :label="$t('plugins.nxt.panels.probingCycles.rotationPolicy')"
            variant="outlined"
            density="compact"
            hide-details
          />
        </v-col>
        <v-col cols="12">
          <v-switch
            v-model="guidedJogMode"
            :label="$t('plugins.nxt.panels.probingCycles.guidedJogMode')"
            :disabled="!touchProbeEnabled"
            hide-details
            density="compact"
            class="mt-0"
          />
        </v-col>
        <v-col cols="12">
          <v-select
            v-model="selectedCycle"
            :items="probingCycles"
            item-title="text"
            item-value="value"
            :label="$t('plugins.nxt.panels.probing.caption')"
            variant="outlined"
            density="compact"
            hide-details
          >
            <template v-slot:prepend-inner>
              <v-icon size="small">mdi-target</v-icon>
            </template>
          </v-select>
        </v-col>
      </v-row>

      <!-- Cycle-specific parameter forms -->
      <v-card variant="outlined" v-if="selectedCycle">
        <v-card-subtitle class="pb-2">
          <v-icon class="mr-2" size="small">{{ cycleConfig.icon }}</v-icon>
          {{ cycleConfig.name }}
        </v-card-subtitle>
        <v-card-text>
          <v-alert type="info" density="compact" variant="text" class="mb-3">
            <div class="text-caption">{{ cycleConfig.description }}</div>
          </v-alert>

          <v-form ref="cycleForm" v-model="formValid">
            <v-row density="compact">
              <!-- Common Parameters -->
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('D')">
                <v-text-field
                  v-model.number="params.diameter"
                  label="Diameter (D)"
                  suffix="mm"
                  type="number"
                  variant="outlined"
                  density="compact"
                  :rules="[v => !!v || 'Required', v => v > 0 || 'Must be positive']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('W')">
                <v-text-field
                  v-model.number="params.width"
                  label="Width (W)"
                  suffix="mm"
                  type="number"
                  variant="outlined"
                  density="compact"
                  :rules="[v => !!v || 'Required', v => v > 0 || 'Must be positive']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('H')">
                <v-text-field
                  v-model.number="params.height"
                  label="Height (H)"
                  suffix="mm"
                  type="number"
                  variant="outlined"
                  density="compact"
                  :rules="[v => !!v || 'Required', v => v > 0 || 'Must be positive']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('L')">
                <v-text-field
                  v-model.number="params.depth"
                  :label="$t('plugins.nxt.panels.probingCycles.depthLabel')"
                  :hint="$t('plugins.nxt.panels.probingCycles.depthHint')"
                  persistent-hint
                  suffix="mm"
                  type="number"
                  variant="outlined"
                  density="compact"
                  :rules="[v => !!v || 'Required', v => v > 0 || 'Must be positive']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('S')">
                <v-text-field
                  v-model.number="params.spacing"
                  label="Spacing (S)"
                  suffix="mm"
                  type="number"
                  variant="outlined"
                  density="compact"
                  :rules="[v => !!v || 'Required', v => v > 0 || 'Must be positive']"
                />
              </v-col>
              <v-col cols="12" v-if="cycleConfig.params.includes('SURF')">
                <div class="text-subtitle-2 mb-1">
                  {{ $t('plugins.nxt.panels.probingCycles.faceLabel') }}
                </div>
                <div class="text-caption text-medium-emphasis mb-2">
                  {{ $t('plugins.nxt.panels.probingCycles.faceHint') }}
                </div>
                <div class="nxt-face-pad mb-2">
                  <v-btn
                    class="nxt-face-pad__back"
                    size="small"
                    :variant="params.face === 3 ? 'flat' : 'outlined'"
                    :color="params.face === 3 ? 'primary' : undefined"
                    @click="selectFace(3)"
                  >
                    {{ $t('plugins.nxt.panels.probingCycles.faceBack') }}
                  </v-btn>
                  <v-btn
                    class="nxt-face-pad__left"
                    size="small"
                    :variant="params.face === 0 ? 'flat' : 'outlined'"
                    :color="params.face === 0 ? 'primary' : undefined"
                    @click="selectFace(0)"
                  >
                    {{ $t('plugins.nxt.panels.probingCycles.faceLeft') }}
                  </v-btn>
                  <v-btn
                    class="nxt-face-pad__top"
                    size="small"
                    :variant="params.face === 4 ? 'flat' : 'outlined'"
                    :color="params.face === 4 ? 'primary' : undefined"
                    @click="selectFace(4)"
                  >
                    {{ $t('plugins.nxt.panels.probingCycles.faceTop') }}
                  </v-btn>
                  <v-btn
                    class="nxt-face-pad__right"
                    size="small"
                    :variant="params.face === 1 ? 'flat' : 'outlined'"
                    :color="params.face === 1 ? 'primary' : undefined"
                    @click="selectFace(1)"
                  >
                    {{ $t('plugins.nxt.panels.probingCycles.faceRight') }}
                  </v-btn>
                  <v-btn
                    class="nxt-face-pad__front"
                    size="small"
                    :variant="params.face === 2 ? 'flat' : 'outlined'"
                    :color="params.face === 2 ? 'primary' : undefined"
                    @click="selectFace(2)"
                  >
                    {{ $t('plugins.nxt.panels.probingCycles.faceFront') }}
                  </v-btn>
                </div>
                <v-input
                  :model-value="params.face"
                  :rules="[(v: number | null) => v != null || $t('plugins.nxt.panels.probingCycles.faceRequired').toString()]"
                  hide-details="auto"
                />
              </v-col>
              <v-col
                cols="12"
                sm="6"
                md="4"
                v-if="cycleConfig.params.includes('SURF')"
              >
                <v-text-field
                  v-model.number="params.surfaceTravel"
                  :label="$t('plugins.nxt.panels.probingCycles.surfaceTravel')"
                  suffix="mm"
                  type="number"
                  variant="outlined"
                  density="compact"
                  :hint="$t('plugins.nxt.panels.probingCycles.surfaceTravelHint')"
                  persistent-hint
                  :rules="[
                    (v: number | null) => (v != null && !Number.isNaN(Number(v))) || 'Required',
                    (v: number | null) => (Number(v) > 0) || 'Must be positive'
                  ]"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('N')">
                <v-select
                  v-model="params.axis"
                  :items="axisOptions"
                  item-title="text"
                  item-value="value"
                  label="Axis (N)"
                  variant="outlined"
                  density="compact"
                  :rules="[v => v != null || 'Required']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('CORNER')">
                <v-select
                  v-model="params.corner"
                  :items="cornerOptions"
                  item-title="text"
                  item-value="value"
                  :label="$t('plugins.nxt.panels.probingCycles.cornerLabel')"
                  variant="outlined"
                  density="compact"
                  :rules="[(v: number | null) => v != null || 'Required']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('DIR')">
                <v-select
                  v-model="params.direction"
                  :items="directionOptions"
                  item-title="text"
                  item-value="value"
                  label="Approach side (D)"
                  variant="outlined"
                  density="compact"
                  :rules="[v => v != null || 'Required']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('FACE_H')">
                <v-text-field
                  v-model.number="params.faceLengthX"
                  :label="$t('plugins.nxt.panels.probingCycles.faceLengthX')"
                  :hint="$t('plugins.nxt.panels.probingCycles.faceLengthXHint')"
                  suffix="mm"
                  type="number"
                  variant="outlined"
                  density="compact"
                  persistent-hint
                  :rules="[
                    (v: number | null) => (v != null && !Number.isNaN(Number(v))) || 'Required',
                    (v: number | null) => (Number(v) > 0) || 'Must be positive'
                  ]"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('FACE_I')">
                <v-text-field
                  v-model.number="params.faceLengthY"
                  :label="$t('plugins.nxt.panels.probingCycles.faceLengthY')"
                  :hint="$t('plugins.nxt.panels.probingCycles.faceLengthYHint')"
                  suffix="mm"
                  type="number"
                  variant="outlined"
                  density="compact"
                  persistent-hint
                  :rules="[
                    (v: number | null) => (v != null && !Number.isNaN(Number(v))) || 'Required',
                    (v: number | null) => (Number(v) > 0) || 'Must be positive'
                  ]"
                />
              </v-col>
              <v-col
                cols="12"
                sm="6"
                md="4"
                v-if="cycleConfig.params.includes('FACE_S') && params.face != null && params.face !== 4"
              >
                <v-text-field
                  v-model.number="params.faceLengthS"
                  :label="$t('plugins.nxt.panels.probingCycles.faceLengthS')"
                  :hint="$t('plugins.nxt.panels.probingCycles.faceLengthSHint')"
                  suffix="mm"
                  type="number"
                  variant="outlined"
                  density="compact"
                  persistent-hint
                  :rules="[
                    (v: number | null) => (v != null && !Number.isNaN(Number(v))) || 'Required',
                    (v: number | null) => (Number(v) > 0) || 'Must be positive'
                  ]"
                />
              </v-col>
              <v-col
                cols="12"
                v-if="cycleConfig.params.includes('FACE_S') && params.face === 4"
              >
                <div class="text-caption text-medium-emphasis">
                  {{ $t('plugins.nxt.panels.probingCycles.faceLengthZDeferred') }}
                </div>
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('C')">
                <v-text-field
                  v-model.number="params.clearance"
                  :label="$t('plugins.nxt.panels.probingCycles.approachClearance')"
                  :hint="$t('plugins.nxt.panels.probingCycles.approachClearanceHint')"
                  suffix="mm"
                  type="number"
                  variant="outlined"
                  density="compact"
                  persistent-hint
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('E')">
                <v-text-field
                  v-model.number="params.cornerOffset"
                  :label="$t('plugins.nxt.panels.probingCycles.cornerOffset')"
                  :hint="$t('plugins.nxt.panels.probingCycles.cornerOffsetHint')"
                  suffix="mm"
                  type="number"
                  variant="outlined"
                  density="compact"
                  persistent-hint
                  :rules="[
                    (v: number | null) => (v != null && !Number.isNaN(Number(v))) || 'Required',
                    (v: number | null) => (Number(v) > 0) || 'Must be positive'
                  ]"
                />
              </v-col>

              <!-- Optional Parameters -->
              <v-col cols="12">
                <v-expansion-panels flat>
                  <v-expansion-panel>
                    <v-expansion-panel-title class="px-0">
                      <span class="text-caption">
                        <v-icon class="mr-2" size="small">mdi-tune</v-icon>
                        {{ $t('plugins.nxt.panels.probingCycles.optionalParams') }}
                      </span>
                    </v-expansion-panel-title>
                    <v-expansion-panel-text>
                      <v-row density="compact">
                        <v-col cols="12" sm="6" md="4" v-if="selectedCycle !== 'G6510'">
                          <v-text-field
                            v-model.number="params.overtravel"
                            label="Overtravel (O)"
                            suffix="mm"
                            type="number"
                            variant="outlined"
                            density="compact"
                            hide-details
                          />
                        </v-col>
                        <v-col cols="12" sm="6" md="4">
                          <v-text-field
                            v-model.number="params.retries"
                            label="Retries (R)"
                            type="number"
                            variant="outlined"
                            density="compact"
                            hide-details
                          />
                        </v-col>
                      </v-row>
                    </v-expansion-panel-text>
                  </v-expansion-panel>
                </v-expansion-panels>
              </v-col>
            </v-row>
          </v-form>

          <v-divider class="my-3" />

          <v-btn
            block
            size="large"
            color="primary"
            @click="executeCycle"
            :disabled="!canExecute"
            :loading="executing"
          >
            <v-icon class="mr-2">mdi-play</v-icon>
            {{ $t('plugins.nxt.panels.probingCycles.execute', [cycleConfig.gcode]) }}
          </v-btn>
        </v-card-text>
      </v-card>

      <v-alert v-else type="info" variant="outlined" class="mt-3">
        <v-icon class="mr-2">mdi-arrow-up</v-icon>
        {{ $t('plugins.nxt.panels.probingCycles.selectCycle') }}
      </v-alert>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import store from '../../compat/dwcStore'
import { defineNxtComponent } from '../base/BaseComponent.vue'
import {
  enableNxtProbeTool,
  isNxtFeatureTouchProbe,
  isNxtProbeToolLoaded,
  resolveNxtProbeToolId
} from '../../utils/nxtEnableProbe'
import { formatToolLabelFromTools } from '../../utils/nxtLoadedToolStatus'
import {
  readNxtUiState,
  writeNxtUiSelectedWcs
} from '../../utils/nxtProbeResultsUi'

interface CycleConfig {
  gcode: string
  name: string
  description: string
  icon: string
  params: string[]
}

interface CycleParams {
  diameter: number | null
  width: number | null
  height: number | null
  depth: number | null
  spacing: number | null
  zTarget: number | null
  /** Max travel (mm) toward the selected G6510 face from the jog pose */
  surfaceTravel: number | null
  axis: number | null
  /** Operator-relative G6510 face: 0 Left, 1 Right, 2 Front, 3 Back, 4 Top */
  face: number | null
  /** Corner index 0–3 for G6508 / G6509 / G6520 (firmware N) */
  corner: number | null
  direction: number | null
  overtravel: number | null
  clearance: number | null
  /** Along-face inset from corner before Z dive (E); corner cycles */
  cornerOffset: number | null
  /** X-normal face length (H) for corner cycles */
  faceLengthX: number | null
  /** Y-normal face length (I) for corner cycles */
  faceLengthY: number | null
  /** Face length (S) for G6510 X/Y multi-point */
  faceLengthS: number | null
  retries: number | null
}

const DEFAULT_SURFACE_TRAVEL_MM = 5
const DEFAULT_CORNER_OFFSET_MM = 5
const DEFAULT_CLEARANCE_MM = 5

function emptyCycleParams(): CycleParams {
  return {
    diameter: null,
    width: null,
    height: null,
    depth: null,
    spacing: null,
    zTarget: null,
    surfaceTravel: DEFAULT_SURFACE_TRAVEL_MM,
    axis: null,
    face: 4,
    corner: 0,
    direction: null,
    overtravel: null,
    clearance: DEFAULT_CLEARANCE_MM,
    cornerOffset: DEFAULT_CORNER_OFFSET_MM,
    faceLengthX: null,
    faceLengthY: null,
    faceLengthS: null,
    retries: null
  }
}

export default defineNxtComponent({
  emits: ['can-execute'],
  data() {
    return {
      rotationPolicy: 0 as number,
      selectedCycle: null as string | null,
      guidedJogMode: false,
      jogCapableCycles: ['G6500', 'G6501', 'G6502', 'G6503', 'G6504', 'G6505', 'G6508', 'G6510', 'G6520'],
      formValid: false,
      executing: false,
      enableProbeBusy: false,
      params: emptyCycleParams(),
      probingCycles: [
        { text: 'G6500 - Bore', value: 'G6500' },
        { text: 'G6501 - Boss', value: 'G6501' },
        { text: 'G6502 - Rectangle Pocket', value: 'G6502' },
        { text: 'G6503 - Rectangle Block', value: 'G6503' },
        { text: 'G6504 - Web (X/Y)', value: 'G6504' },
        { text: 'G6505 - Pocket (X/Y)', value: 'G6505' },
        { text: 'G6506 - Rotation', value: 'G6506' },
        { text: 'G6508 - Outside Corner', value: 'G6508' },
        { text: 'G6509 - Inside Corner', value: 'G6509' },
        { text: 'G6510 - Single Surface', value: 'G6510' },
        { text: 'G6520 - Vise Corner', value: 'G6520' }
      ],
      cycleConfigs: {
        G6500: {
          gcode: 'G6500',
          name: 'Bore Probe',
          description:
            'Jog over the approximate bore center. Three inside approaches spaced 120° find the bore center.',
          icon: 'mdi-circle-outline',
          params: ['D', 'L']
        },
        G6501: {
          gcode: 'G6501',
          name: 'Boss Probe',
          description:
            'Jog over the approximate boss center. Three outside approaches spaced 120° find the boss center. Use approach clearance so the probe stays clear of the OD before dropping Z.',
          icon: 'mdi-circle',
          params: ['D', 'L', 'C']
        },
        G6502: {
          gcode: 'G6502',
          name: 'Rectangle Pocket',
          description: 'Probes all 4 edges of a rectangular pocket in X and Y to find the center.',
          icon: 'mdi-rectangle-outline',
          params: ['W', 'H', 'L', 'C']
        },
        G6503: {
          gcode: 'G6503',
          name: 'Rectangle Block',
          description:
            'Probes outside faces of a rectangular block to find the center. Jog over the approximate center first.',
          icon: 'mdi-rectangle',
          params: ['W', 'H', 'L', 'C']
        },
        G6504: {
          gcode: 'G6504',
          name: 'Web (X/Y)',
          description: 'Probes a web (block) in either X or Y to find the center point on that axis.',
          icon: 'mdi-arrow-left-right',
          params: ['N', 'W', 'L', 'C']
        },
        G6505: {
          gcode: 'G6505',
          name: 'Pocket (X/Y)',
          description: 'Probes a pocket in either X or Y to find the center point on that axis.',
          icon: 'mdi-arrow-expand-horizontal',
          params: ['N', 'W', 'L', 'C']
        },
        G6506: {
          gcode: 'G6506',
          name: 'Rotation Probe',
          description: 'Probes 2 points along a surface in X or Y to find the rotation angle.',
          icon: 'mdi-angle-acute',
          params: ['N', 'DIR', 'S', 'L']
        },
        G6508: {
          gcode: 'G6508',
          name: 'Outside Corner',
          description:
            'Probes an outside 90° corner with 1 or 3 points per face (from face lengths). Select the corner, enter face lengths, jog near it in air, then Execute.',
          icon: 'mdi-arrow-top-left',
          params: ['CORNER', 'L', 'C', 'E', 'FACE_H', 'FACE_I']
        },
        G6509: {
          gcode: 'G6509',
          name: 'Inside Corner',
          description:
            'Probes an inside 90° pocket corner with 1 or 3 points per face. Select the corner, enter face lengths, jog inside near it, then Execute.',
          icon: 'mdi-arrow-bottom-right',
          params: ['CORNER', 'L', 'C', 'E', 'FACE_H', 'FACE_I']
        },
        G6510: {
          gcode: 'G6510',
          name: 'Single Surface',
          description:
            'Jog in air next to the face (or above Top), relative to the operator at the front of the mill. Travel is from the current pose toward that face. XY faces can use face length for multi-point; Top is one contact (multi-Z later).',
          icon: 'mdi-arrow-right',
          params: ['SURF', 'FACE_S']
        },
        G6520: {
          gcode: 'G6520',
          name: 'Vise Corner',
          description:
            'Probes vise top Z (one hit), then the outside corner X/Y with 1 or 3 points per face. Enter face lengths, jog near the corner, then Execute.',
          icon: 'mdi-desk',
          params: ['CORNER', 'L', 'C', 'E', 'FACE_H', 'FACE_I']
        }
      } as Record<string, CycleConfig>,
      axisOptions: [
        { text: 'X Axis (0)', value: 0 },
        { text: 'Y Axis (1)', value: 1 }
      ],
      cornerOptions: [
        { text: 'Front Left (0)', value: 0 },
        { text: 'Front Right (1)', value: 1 },
        { text: 'Back Right (2)', value: 2 },
        { text: 'Back Left (3)', value: 3 }
      ],
      directionOptions: [
        { text: 'Negative / first side (0)', value: 0 },
        { text: 'Positive / second side (1)', value: 1 }
      ]
    }
  },
  computed: {
    targetWcs: {
      get(): number {
        const w = readNxtUiState(store.state.settings?.plugins)?.selectedWcs
        return typeof w === 'number' && w >= 1 && w <= 9 ? w : 1
      },
      set(v: number) {
        writeNxtUiSelectedWcs(v, store.state.settings?.plugins)
      }
    },
    touchProbeEnabled(): boolean {
      return isNxtFeatureTouchProbe(this.$store.state.machine.model.global)
    },
    probeToolId(): number {
      return resolveNxtProbeToolId(this.$store.state.machine.model.global)
    },
    /** M4000 S human name with T# for Enable Probe copy (`T{n} — {name}`). */
    probeToolLabel(): string {
      const id = this.probeToolId
      const label = formatToolLabelFromTools(this.$store.state.machine.model.tools, id)
      return label.length > 0 ? label : `T${id}`
    },
    touchProbeSelected(): boolean {
      const cur = this.$store.state.machine.model?.state?.currentTool
      const idx = typeof cur === 'number' ? cur : null
      const toolNumRaw = this.currentTool?.number
      const toolNum = typeof toolNumRaw === 'number' ? toolNumRaw : null
      return isNxtProbeToolLoaded(idx, this.probeToolId, toolNum)
    },
    wcsOptions(): { text: string; value: number }[] {
      // 1–9 = G54–G59.3 (M6520 W / probe U). WCS1 = G54, WCS2 = G55, …
      const gCodes = ['G54', 'G55', 'G56', 'G57', 'G58', 'G59', 'G59.1', 'G59.2', 'G59.3']
      return Array.from({ length: 9 }, (_, i) => ({
        text: `WCS${i + 1} (${gCodes[i]})`,
        value: i + 1
      }))
    },
    rotationPolicyOptions(): { text: string; value: number }[] {
      return [
        { text: this.$t('plugins.nxt.panels.probingCycles.rotPrompt').toString(), value: 0 },
        { text: this.$t('plugins.nxt.panels.probingCycles.rotApply').toString(), value: 1 },
        { text: this.$t('plugins.nxt.panels.probingCycles.rotNever').toString(), value: 2 }
      ]
    },
    cycleConfig(): CycleConfig | null {
      if (!this.selectedCycle) return null
      return this.cycleConfigs[this.selectedCycle] || null
    },
    canExecute(): boolean {
      const jogOk = this.guidedJogMode &&
        this.selectedCycle != null &&
        this.jogCapableCycles.includes(this.selectedCycle)
      return this.touchProbeEnabled &&
             this.touchProbeSelected &&
             (jogOk || this.formValid) &&
             !this.executing &&
             this.selectedCycle !== null
    }
  },
  watch: {
    selectedCycle() {
      this.params = emptyCycleParams()
    },
    canExecute: {
      immediate: true,
      handler: 'emitCanExecute'
    }
  },
  methods: {
    emitCanExecute(ok: boolean): void {
      this.$emit('can-execute', ok)
    },
    selectFace(n: number): void {
      this.params.face = n
    },
    surfaceFaceName(n: number | null): string {
      if (n === 0) return this.$t('plugins.nxt.panels.probingCycles.faceLeft').toString()
      if (n === 1) return this.$t('plugins.nxt.panels.probingCycles.faceRight').toString()
      if (n === 2) return this.$t('plugins.nxt.panels.probingCycles.faceFront').toString()
      if (n === 3) return this.$t('plugins.nxt.panels.probingCycles.faceBack').toString()
      if (n === 4) return this.$t('plugins.nxt.panels.probingCycles.faceTop').toString()
      return this.$t('plugins.nxt.panels.probingCycles.faceLabel').toString()
    },
    async enableProbe() {
      const id = this.probeToolId
      if (id == null) {
        this.$store.dispatch('machine/showMessage', {
          type: 'error',
          message: this.$t('plugins.nxt.panels.probingCycles.probeToolIdUnset').toString()
        })
        return
      }
      this.enableProbeBusy = true
      try {
        await enableNxtProbeTool(
          (c: string) => this.sendCode(c),
          id
        )
        this.$store.dispatch('machine/showMessage', {
          type: 'success',
          message: this.$t('plugins.nxt.panels.probingCycles.enableProbeDone', [
            this.probeToolLabel
          ]).toString()
        })
      } catch (error) {
        this.$store.dispatch('machine/showMessage', {
          type: 'error',
          message: `${this.$t('plugins.nxt.panels.probingCycles.enableProbe').toString()} failed: ${error}`
        })
      } finally {
        this.enableProbeBusy = false
      }
    },
    async executeCycle() {
      if (!this.canExecute || !this.selectedCycle) return

      this.executing = true

      try {
        const gcode = this.buildGcode()
        await this.sendCode(gcode)
        // U → table slot U-1; ProbeResultsPanel watches nxtUiState.selectedResultIndex
        writeNxtUiSelectedWcs(
          this.targetWcs,
          this.$store.state.settings?.plugins
        )
        let wcsNote = ''
        if (!this.guidedJogMode) {
          if (this.selectedCycle === 'G6510') {
            const faceName = this.surfaceFaceName(this.params.face)
            if (this.params.face === 4) {
              wcsNote = ` — WCS${this.targetWcs} applied (${faceName}; returned to start Z)`
            } else {
              wcsNote = ` — WCS${this.targetWcs} applied (${faceName})`
            }
          } else {
            wcsNote = ` — WCS${this.targetWcs} applied (parked at feature)`
          }
        }
        this.$store.dispatch('machine/showMessage', {
          type: 'success',
          message: `${this.selectedCycle} completed successfully${wcsNote}`
        })
      } catch (error) {
        this.$store.dispatch('machine/showMessage', {
          type: 'error',
          message: `${this.selectedCycle} failed: ${error}`
        })
      } finally {
        this.executing = false
      }
    },
    buildGcode(): string {
      if (!this.selectedCycle) return ''

      if (this.guidedJogMode && this.jogCapableCycles.includes(this.selectedCycle)) {
        const wcs = this.targetWcs - 1
        return `M5012\n${this.selectedCycle}-jog W${wcs}`
      }

      let gcode = `${this.selectedCycle} U${this.targetWcs}`
      gcode += ` Q${this.rotationPolicy}`

      if (this.selectedCycle === 'G6510') {
        if (this.params.face == null) {
          throw new Error(
            this.$t('plugins.nxt.panels.probingCycles.faceRequired').toString()
          )
        }
        const travel = this.params.surfaceTravel
        if (travel == null || !(travel > 0)) {
          throw new Error(
            this.$t('plugins.nxt.panels.probingCycles.surfaceTravelRequired').toString()
          )
        }
        gcode += ` N${this.params.face}`
        gcode += ` O${travel}`
      } else if (
        this.selectedCycle === 'G6508' ||
        this.selectedCycle === 'G6509' ||
        this.selectedCycle === 'G6520'
      ) {
        if (this.params.corner == null) {
          throw new Error(this.$t('plugins.nxt.panels.probingCycles.cornerRequired').toString())
        }
        gcode += ` N${this.params.corner}`
      } else if (this.params.axis != null) {
        gcode += ` N${this.params.axis}`
      }

      if (this.selectedCycle === 'G6506') {
        if (this.params.direction != null) gcode += ` D${this.params.direction}`
      } else if (this.params.diameter != null) {
        gcode += ` D${this.params.diameter}`
      }

      if (this.params.width != null) gcode += ` W${this.params.width}`
      if (
        this.params.height != null &&
        this.selectedCycle !== 'G6508' &&
        this.selectedCycle !== 'G6509' &&
        this.selectedCycle !== 'G6520'
      ) {
        gcode += ` H${this.params.height}`
      }
      if (
        this.selectedCycle === 'G6508' ||
        this.selectedCycle === 'G6509' ||
        this.selectedCycle === 'G6520'
      ) {
        if (this.params.faceLengthX == null || !(this.params.faceLengthX > 0)) {
          throw new Error('X-face length (H) is required')
        }
        if (this.params.faceLengthY == null || !(this.params.faceLengthY > 0)) {
          throw new Error('Y-face length (I) is required')
        }
        gcode += ` H${this.params.faceLengthX}`
        gcode += ` I${this.params.faceLengthY}`
      }
      if (this.selectedCycle === 'G6510' && this.params.face != null && this.params.face !== 4) {
        if (this.params.faceLengthS == null || !(this.params.faceLengthS > 0)) {
          throw new Error('Face length (S) is required for X/Y surface probes')
        }
        gcode += ` S${this.params.faceLengthS}`
      }
      if (this.params.depth != null) gcode += ` L${this.params.depth}`
      if (this.selectedCycle !== 'G6510' && this.params.spacing != null) {
        gcode += ` S${this.params.spacing}`
      }

      if (this.selectedCycle !== 'G6510' && this.params.overtravel != null) {
        gcode += ` O${this.params.overtravel}`
      }
      if (this.params.clearance != null) gcode += ` C${this.params.clearance}`
      if (this.params.cornerOffset != null) gcode += ` E${this.params.cornerOffset}`
      if (this.params.retries != null) gcode += ` R${this.params.retries}`

      return gcode
    }
  }
})
</script>

<style scoped>
.nxt-face-pad {
  display: grid;
  grid-template-columns: repeat(3, minmax(4.5rem, 1fr));
  gap: 0.5rem;
  max-width: 20rem;
}
.nxt-face-pad__back {
  grid-column: 2;
  grid-row: 1;
}
.nxt-face-pad__left {
  grid-column: 1;
  grid-row: 2;
}
.nxt-face-pad__top {
  grid-column: 2;
  grid-row: 2;
}
.nxt-face-pad__right {
  grid-column: 3;
  grid-row: 2;
}
.nxt-face-pad__front {
  grid-column: 2;
  grid-row: 3;
}
</style>
