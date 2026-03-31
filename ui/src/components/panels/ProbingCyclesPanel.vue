<template>
  <v-card>
    <v-card-title class="d-flex align-center">
      <v-icon left>mdi-crosshairs-gps</v-icon>
      Probing Cycles
    </v-card-title>

    <v-card-text>
      <v-alert v-if="!touchProbeEnabled" type="warning" dense outlined class="mb-4">
        <v-icon small left>mdi-alert</v-icon>
        Touch probe feature must be enabled to use probing cycles.
      </v-alert>

      <v-alert v-else-if="!touchProbeSelected" type="info" dense outlined class="mb-4">
        <v-icon small left>mdi-information</v-icon>
        Touch probe (T{{ probeToolId }}) must be selected to run probing cycles.
      </v-alert>

      <v-row dense class="mb-3">
        <v-col cols="12" sm="6">
          <v-select
            v-model="selectedResultIndex"
            :items="resultIndexOptions"
            label="Store Result In"
            outlined
            dense
            hide-details
            :hint="`Result will be stored in probe results table at index ${selectedResultIndex}`"
          >
            <template v-slot:prepend-inner>
              <v-icon small>mdi-table-row</v-icon>
            </template>
          </v-select>
        </v-col>
        <v-col cols="12" sm="6">
          <v-select
            v-model="selectedCycle"
            :items="probingCycles"
            label="Probing Cycle"
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
              <v-col cols="12" sm="6" md="4" v-if="cycleConfig.params.includes('Z')">
                <v-text-field
                  v-model.number="params.zTarget"
                  label="Z Target (Z)"
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

              <!-- Optional Parameters -->
              <v-col cols="12">
                <v-expansion-panels flat>
                  <v-expansion-panel>
                    <v-expansion-panel-header class="px-0">
                      <span class="text-caption">
                        <v-icon small left>mdi-tune</v-icon>
                        Optional Parameters
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
            Execute {{ cycleConfig.gcode }}
          </v-btn>
        </v-card-text>
      </v-card>

      <v-alert v-else type="info" outlined class="mt-3">
        <v-icon left>mdi-arrow-up</v-icon>
        Select a probing cycle to configure and execute
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
  axis: number | null
  overtravel: number | null
  clearance: number | null
  feedRate: number | null
  retries: number | null
}

export default BaseComponent.extend({
  data() {
    return {
      selectedResultIndex: 0,
      selectedCycle: null as string | null,
      formValid: false,
      executing: false,
      params: {
        diameter: null,
        width: null,
        height: null,
        depth: null,
        spacing: null,
        zTarget: null,
        axis: null,
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
          params: ['N', 'D', 'L']
        },
        G6505: {
          gcode: 'G6505',
          name: 'Pocket (X/Y)',
          description: 'Probes a pocket in either X or Y to find the center point on that axis.',
          icon: 'mdi-arrow-expand-horizontal',
          params: ['N', 'D', 'L']
        },
        G6506: {
          gcode: 'G6506',
          name: 'Rotation Probe',
          description: 'Probes 2 points along a surface in X or Y to find the rotation angle.',
          icon: 'mdi-angle-acute',
          params: ['N', 'D', 'S']
        },
        G6508: {
          gcode: 'G6508',
          name: 'Outside Corner',
          description: 'Probes an assumed-90-degree outside corner to find the intersection point.',
          icon: 'mdi-arrow-top-left',
          params: ['N', 'L']
        },
        G6509: {
          gcode: 'G6509',
          name: 'Inside Corner',
          description: 'Probes an assumed-90-degree inside corner to find the intersection point.',
          icon: 'mdi-arrow-bottom-right',
          params: ['N', 'D', 'L']
        },
        G6510: {
          gcode: 'G6510',
          name: 'Single Surface',
          description: 'Probes one surface in X, Y, or Z to find the surface location.',
          icon: 'mdi-arrow-right',
          params: ['Z']
        },
        G6520: {
          gcode: 'G6520',
          name: 'Vise Corner',
          description: 'Z probe for vise top, then outside corner probe for X/Y position (3 probes total).',
          icon: 'mdi-desk',
          params: ['N']
        }
      } as Record<string, CycleConfig>,
      axisOptions: [
        { text: 'X Axis (0)', value: 0 },
        { text: 'Y Axis (1)', value: 1 }
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
    resultIndexOptions(): any[] {
      const options = []
      const maxResults = this.globals.nxtProbeResults?.length || 10
      for (let i = 0; i < maxResults; i++) {
        options.push({ text: `Result ${i}`, value: i })
      }
      return options
    },
    cycleConfig(): CycleConfig | null {
      if (!this.selectedCycle) return null
      return this.cycleConfigs[this.selectedCycle] || null
    },
    canExecute(): boolean {
      return this.touchProbeEnabled && 
             this.touchProbeSelected && 
             this.formValid && 
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
        axis: null,
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
        this.$makeNotification('success', 'Probing Complete', 
          `${this.selectedCycle} completed successfully`)
      } catch (error) {
        this.$makeNotification('error', 'Probing Failed', 
          `${this.selectedCycle} failed: ${error}`)
      } finally {
        this.executing = false
      }
    },
    buildGcode(): string {
      if (!this.selectedCycle) return ''

      let gcode = `${this.selectedCycle} P${this.selectedResultIndex}`

      // Add required parameters based on cycle
      if (this.params.diameter != null) gcode += ` D${this.params.diameter}`
      if (this.params.width != null) gcode += ` W${this.params.width}`
      if (this.params.height != null) gcode += ` H${this.params.height}`
      if (this.params.depth != null) gcode += ` L${this.params.depth}`
      if (this.params.spacing != null) gcode += ` S${this.params.spacing}`
      if (this.params.zTarget != null) gcode += ` Z${this.params.zTarget}`
      if (this.params.axis != null) gcode += ` N${this.params.axis}`

      // Add optional parameters if specified
      if (this.params.overtravel != null) gcode += ` O${this.params.overtravel}`
      if (this.params.clearance != null) gcode += ` C${this.params.clearance}`
      if (this.params.feedRate != null) gcode += ` F${this.params.feedRate}`
      if (this.params.retries != null) gcode += ` R${this.params.retries}`

      return gcode
    }
  }
})
</script>
