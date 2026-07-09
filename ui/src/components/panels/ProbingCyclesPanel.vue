<template>
  <v-card>
    <v-card-title class="d-flex align-center">
      <v-icon left>mdi-crosshairs-gps</v-icon>
      {{ $t('plugins.nxt.panels.probingCycles.title') }}
    </v-card-title>

    <v-card-text>
      <v-alert v-if="!touchProbeEnabled" type="warning" dense outlined class="mb-4">
        <v-icon small left>mdi-alert</v-icon>
        {{ $t('plugins.nxt.panels.probingCycles.touchProbeWarning') }}
      </v-alert>

      <v-alert v-else-if="!touchProbeSelected" type="info" dense outlined class="mb-4">
        <v-icon small left>mdi-information</v-icon>
        {{ $t('plugins.nxt.panels.probingCycles.selectProbeTool', [probeToolId]) }}
      </v-alert>

      <v-row dense class="mb-3">
        <v-col cols="12" sm="6">
          <v-select
            v-model="targetWcs"
            :items="wcsOptions"
            :label="$t('plugins.nxt.panels.probingCycles.targetWcs')"
            :hint="$t('plugins.nxt.panels.probingCycles.wcsHint')"
            outlined
            dense
            persistent-hint
          >
            <template v-slot:prepend-inner>
              <v-icon small>mdi-axis-arrow</v-icon>
            </template>
          </v-select>
        </v-col>
        <v-col cols="12" sm="6">
          <v-select
            v-model="rotationPolicy"
            :items="rotationPolicyOptions"
            :label="$t('plugins.nxt.panels.probingCycles.rotationPolicy')"
            outlined
            dense
            hide-details
          />
        </v-col>
        <v-col cols="12">
          <v-switch
            v-model="guidedJogMode"
            :label="$t('plugins.nxt.panels.probingCycles.guidedJogMode')"
            :hint="$t('plugins.nxt.panels.probingCycles.guidedJogHint')"
            :disabled="!touchProbeEnabled"
            persistent-hint
            hide-details="auto"
            class="mt-0"
          />
        </v-col>
        <v-col cols="12">
          <v-select
            v-model="selectedCycle"
            :items="probingCycles"
            :label="$t('plugins.nxt.panels.probing.caption')"
            outlined
            dense
            hide-details
          >
            <template v-slot:prepend-inner>
              <v-icon small>mdi-target</v-icon>
            </template>
          </v-select>
        </v-col>
      </v-row>

      <!-- Cycle-specific parameter forms -->
      <v-card outlined v-if="selectedCycle">
        <v-card-subtitle class="pb-2">
          <v-icon small left>{{ cycleConfig.icon }}</v-icon>
          {{ cycleConfig.name }}
        </v-card-subtitle>
        <v-card-text>
          <v-alert type="info" dense text class="mb-3">
            <div class="text-caption">{{ cycleConfig.description }}</div>
          </v-alert>

          <v-form ref="cycleForm" v-model="formValid">
            <v-row dense>
              <!-- Common Parameters -->
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('D')">
                <v-text-field
                  v-model.number="params.diameter"
                  label="Diameter (D)"
                  suffix="mm"
                  type="number"
                  outlined
                  dense
                  :rules="[v => !!v || 'Required', v => v > 0 || 'Must be positive']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('W')">
                <v-text-field
                  v-model.number="params.width"
                  label="Width (W)"
                  suffix="mm"
                  type="number"
                  outlined
                  dense
                  :rules="[v => !!v || 'Required', v => v > 0 || 'Must be positive']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('H')">
                <v-text-field
                  v-model.number="params.height"
                  label="Height (H)"
                  suffix="mm"
                  type="number"
                  outlined
                  dense
                  :rules="[v => !!v || 'Required', v => v > 0 || 'Must be positive']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('L')">
                <v-text-field
                  v-model.number="params.depth"
                  label="Depth (L)"
                  suffix="mm"
                  type="number"
                  outlined
                  dense
                  :rules="[v => !!v || 'Required', v => v > 0 || 'Must be positive']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('S')">
                <v-text-field
                  v-model.number="params.spacing"
                  label="Spacing (S)"
                  suffix="mm"
                  type="number"
                  outlined
                  dense
                  :rules="[v => !!v || 'Required', v => v > 0 || 'Must be positive']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('SURF')">
                <v-select
                  v-model="params.axis"
                  :items="surfaceAxisOptions"
                  label="Probe axis"
                  outlined
                  dense
                  :rules="[v => v != null || 'Required']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('SURF')">
                <v-text-field
                  v-model.number="params.surfaceTarget"
                  label="Target (machine)"
                  suffix="mm"
                  type="number"
                  outlined
                  dense
                  :rules="[v => v != null || 'Required']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('N')">
                <v-select
                  v-model="params.axis"
                  :items="axisOptions"
                  label="Axis (N)"
                  outlined
                  dense
                  :rules="[v => v != null || 'Required']"
                />
              </v-col>
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('DIR')">
                <v-select
                  v-model="params.direction"
                  :items="directionOptions"
                  label="Approach side (D)"
                  outlined
                  dense
                  :rules="[v => v != null || 'Required']"
                />
              </v-col>

              <!-- Optional Parameters -->
              <v-col cols="12">
                <v-expansion-panels flat>
                  <v-expansion-panel>
                    <v-expansion-panel-header class="px-0">
                      <span class="text-caption">
                        <v-icon small left>mdi-tune</v-icon>
                        {{ $t('plugins.nxt.panels.probingCycles.optionalParams') }}
                      </span>
                    </v-expansion-panel-header>
                    <v-expansion-panel-content>
                      <v-row dense>
                        <v-col cols="12" sm="6" md="4">
                          <v-text-field
                            v-model.number="params.overtravel"
                            label="Overtravel (O)"
                            suffix="mm"
                            type="number"
                            outlined
                            dense
                            hint="Default: 2.0mm"
                            persistent-hint
                          />
                        </v-col>
                        <v-col cols="12" sm="6" md="4">
                          <v-text-field
                            v-model.number="params.clearance"
                            label="Clearance (C)"
                            suffix="mm"
                            type="number"
                            outlined
                            dense
                            hint="Default: 5.0mm"
                            persistent-hint
                          />
                        </v-col>
                        <v-col cols="12" sm="6" md="4">
                          <v-text-field
                            v-model.number="params.feedRate"
                            label="Feed Rate (F)"
                            suffix="mm/min"
                            type="number"
                            outlined
                            dense
                            hint="Default: probe speed"
                            persistent-hint
                          />
                        </v-col>
                        <v-col cols="12" sm="6" md="4">
                          <v-text-field
                            v-model.number="params.retries"
                            label="Retries (R)"
                            type="number"
                            outlined
                            dense
                            hint="Default: probe setting"
                            persistent-hint
                          />
                        </v-col>
                      </v-row>
                    </v-expansion-panel-content>
                  </v-expansion-panel>
                </v-expansion-panels>
              </v-col>
            </v-row>
          </v-form>

          <v-divider class="my-3" />

          <v-btn
            block
            large
            color="primary"
            @click="executeCycle"
            :disabled="!canExecute"
            :loading="executing"
          >
            <v-icon left>mdi-play</v-icon>
            {{ $t('plugins.nxt.panels.probingCycles.execute', [cycleConfig.gcode]) }}
          </v-btn>
        </v-card-text>
      </v-card>

      <v-alert v-else type="info" outlined class="mt-3">
        <v-icon left>mdi-arrow-up</v-icon>
        {{ $t('plugins.nxt.panels.probingCycles.selectCycle') }}
      </v-alert>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import BaseComponent from '../base/BaseComponent.vue'

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
  surfaceTarget: number | null
  axis: number | null
  direction: number | null
  overtravel: number | null
  clearance: number | null
  feedRate: number | null
  retries: number | null
}

export default BaseComponent.extend({
  data() {
    const wcsGcode = ['G54', 'G55', 'G56', 'G57', 'G58', 'G59', 'G59.1', 'G59.2', 'G59.3']
    return {
      targetWcs: 1,
      rotationPolicy: 0 as number,
      wcsGcodeLabels: wcsGcode,
      selectedCycle: null as string | null,
      guidedJogMode: false,
      jogCapableCycles: ['G6500', 'G6501', 'G6502', 'G6503', 'G6504', 'G6505', 'G6508', 'G6510', 'G6520'],
      formValid: false,
      executing: false,
      params: {
        diameter: null,
        width: null,
        height: null,
        depth: null,
        spacing: null,
        zTarget: null,
        surfaceTarget: null,
        axis: null,
        direction: null,
        overtravel: null,
        clearance: null,
        feedRate: null,
        retries: null
      } as CycleParams,
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
          description: 'Probes a circular bore by probing in 4 directions (±X, ±Y) to find the center.',
          icon: 'mdi-circle-outline',
          params: ['D', 'L']
        },
        G6501: {
          gcode: 'G6501',
          name: 'Boss Probe',
          description: 'Probes a circular boss from outside in 4 directions (±X, ±Y) to find the center.',
          icon: 'mdi-circle',
          params: ['D', 'L']
        },
        G6502: {
          gcode: 'G6502',
          name: 'Rectangle Pocket',
          description: 'Probes all 4 edges of a rectangular pocket in X and Y to find the center.',
          icon: 'mdi-rectangle-outline',
          params: ['W', 'H', 'L']
        },
        G6503: {
          gcode: 'G6503',
          name: 'Rectangle Block',
          description: 'Probes all 4 edges of a rectangular block from outside to find the center.',
          icon: 'mdi-rectangle',
          params: ['W', 'H', 'L']
        },
        G6504: {
          gcode: 'G6504',
          name: 'Web (X/Y)',
          description: 'Probes a web (block) in either X or Y to find the center point on that axis.',
          icon: 'mdi-arrow-left-right',
          params: ['N', 'W', 'L']
        },
        G6505: {
          gcode: 'G6505',
          name: 'Pocket (X/Y)',
          description: 'Probes a pocket in either X or Y to find the center point on that axis.',
          icon: 'mdi-arrow-expand-horizontal',
          params: ['N', 'W', 'L']
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
          description: 'Probes an assumed-90-degree outside corner to find the intersection point.',
          icon: 'mdi-arrow-top-left',
          params: ['L']
        },
        G6509: {
          gcode: 'G6509',
          name: 'Inside Corner',
          description: 'Probes an assumed-90-degree inside corner to find the intersection point.',
          icon: 'mdi-arrow-bottom-right',
          params: ['L']
        },
        G6510: {
          gcode: 'G6510',
          name: 'Single Surface',
          description: 'Probes one surface in X, Y, or Z to find the surface location.',
          icon: 'mdi-arrow-right',
          params: ['SURF']
        },
        G6520: {
          gcode: 'G6520',
          name: 'Vise Corner',
          description: 'Z probe for vise top, then outside corner probe for X/Y position (3 probes total).',
          icon: 'mdi-desk',
          params: ['L']
        }
      } as Record<string, CycleConfig>,
      axisOptions: [
        { text: 'X Axis (0)', value: 0 },
        { text: 'Y Axis (1)', value: 1 }
      ],
      surfaceAxisOptions: [
        { text: 'X', value: 0 },
        { text: 'Y', value: 1 },
        { text: 'Z', value: 2 }
      ],
      directionOptions: [
        { text: 'Negative / first side (0)', value: 0 },
        { text: 'Positive / second side (1)', value: 1 }
      ]
    }
  },
  computed: {
    touchProbeEnabled(): boolean {
      return this.globals.nxtFeatureTouchProbe === true
    },
    probeToolId(): number {
      return this.globals.nxtProbeToolID
    },
    touchProbeSelected(): boolean {
      return this.$store.state.machine.model?.state?.currentTool === this.probeToolId
    },
    wcsOptions(): { text: string; value: number }[] {
      const labels = this.wcsGcodeLabels as string[]
      return labels.map((g, i) => ({
        text: `WCS ${i + 1} (${g})`,
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
      // Reset parameters when cycle changes
      this.params = {
        diameter: null,
        width: null,
        height: null,
        depth: null,
        spacing: null,
        zTarget: null,
        surfaceTarget: null,
        axis: null,
        direction: null,
        overtravel: null,
        clearance: null,
        feedRate: null,
        retries: null
      }
    }
  },
  methods: {
    async executeCycle() {
      if (!this.canExecute || !this.selectedCycle) return

      this.executing = true

      try {
        const gcode = this.buildGcode()
        await this.sendCode(gcode)
        this.$store.dispatch('machine/showMessage', {
          type: 'success',
          message: `${this.selectedCycle} completed successfully`
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
        if (this.params.axis === 0 && this.params.surfaceTarget != null) gcode += ` X${this.params.surfaceTarget}`
        else if (this.params.axis === 1 && this.params.surfaceTarget != null) gcode += ` Y${this.params.surfaceTarget}`
        else if (this.params.axis === 2 && this.params.surfaceTarget != null) gcode += ` Z${this.params.surfaceTarget}`
      } else if (this.params.axis != null) {
        gcode += ` N${this.params.axis}`
      }

      if (this.selectedCycle === 'G6506') {
        if (this.params.direction != null) gcode += ` D${this.params.direction}`
      } else if (this.params.diameter != null) {
        gcode += ` D${this.params.diameter}`
      }

      if (this.params.width != null) gcode += ` W${this.params.width}`
      if (this.params.height != null) gcode += ` H${this.params.height}`
      if (this.params.depth != null) gcode += ` L${this.params.depth}`
      if (this.params.spacing != null) gcode += ` S${this.params.spacing}`

      if (this.params.overtravel != null) gcode += ` O${this.params.overtravel}`
      if (this.params.clearance != null) gcode += ` C${this.params.clearance}`
      if (this.params.feedRate != null) gcode += ` F${this.params.feedRate}`
      if (this.params.retries != null) gcode += ` R${this.params.retries}`

      return gcode
    }
  }
})
</script>
