<template>
  <v-card>
    <v-card-title class="d-flex align-center">
      <v-icon left>mdi-table</v-icon>
      Probe Results Table
      <v-spacer />
      <v-btn
        small
        text
        color="error"
        @click="clearAllResults"
        :disabled="!hasResults"
      >
        <v-icon small left>mdi-delete-sweep</v-icon>
        Clear All
      </v-btn>
    </v-card-title>

    <v-card-text>
      <v-alert v-if="!touchProbeEnabled" type="info" dense outlined class="mb-4">
        <v-icon small left>mdi-information</v-icon>
        Touch probe feature must be enabled to use probing functionality.
      </v-alert>

      <v-data-table
        :headers="headers"
        :items="resultsTableData"
        :items-per-page="10"
        :hide-default-footer="true"
        dense
        class="elevation-1"
        :single-select="true"
        v-model="selectedResults"
        show-select
        item-key="index"
      >
        <template v-slot:item.x="{ item }">
          {{ formatCoordinate(item.x) }}
        </template>
        <template v-slot:item.y="{ item }">
          {{ formatCoordinate(item.y) }}
        </template>
        <template v-slot:item.z="{ item }">
          {{ formatCoordinate(item.z) }}
        </template>
        <template v-slot:item.a="{ item }">
          {{ formatCoordinate(item.a) }}
        </template>
        <template v-slot:item.rotation="{ item }">
          {{ formatRotation(item.rotation) }}
        </template>
        <template v-slot:item.actions="{ item }">
          <v-btn
            x-small
            icon
            color="error"
            @click="clearResult(item.index)"
            :disabled="!item.hasData"
          >
            <v-icon x-small>mdi-delete</v-icon>
          </v-btn>
        </template>
      </v-data-table>

      <v-divider class="my-4" />

      <!-- Actions Panel -->
      <v-card outlined>
        <v-card-subtitle class="pb-2">
          <v-icon small left>mdi-cog</v-icon>
          Result Actions
        </v-card-subtitle>
        <v-card-text>
          <v-row dense>
            <!-- Push to WCS -->
            <v-col cols="12" md="6">
              <v-card outlined>
                <v-card-subtitle class="py-2">Push to WCS</v-card-subtitle>
                <v-card-text>
                  <v-select
                    v-model="selectedWcs"
                    :items="wcsOptions"
                    label="Target WCS"
                    dense
                    outlined
                    hide-details
                    class="mb-2"
                  />
                  <v-checkbox
                    v-model="pushAxes.x"
                    label="X Axis"
                    dense
                    hide-details
                    class="my-1"
                    :disabled="!selectedResultData.x"
                  />
                  <v-checkbox
                    v-model="pushAxes.y"
                    label="Y Axis"
                    dense
                    hide-details
                    class="my-1"
                    :disabled="!selectedResultData.y"
                  />
                  <v-checkbox
                    v-model="pushAxes.z"
                    label="Z Axis"
                    dense
                    hide-details
                    class="my-1"
                    :disabled="!selectedResultData.z"
                  />
                  <v-checkbox
                    v-if="hasAAxis"
                    v-model="pushAxes.a"
                    label="A Axis"
                    dense
                    hide-details
                    class="my-1"
                    :disabled="!selectedResultData.a"
                  />
                  <v-btn
                    small
                    block
                    color="primary"
                    @click="pushToWcs"
                    :disabled="!canPushToWcs"
                    class="mt-3"
                  >
                    <v-icon small left>mdi-application-export</v-icon>
                    Push to {{ wcsLabel }}
                  </v-btn>
                </v-card-text>
              </v-card>
            </v-col>

            <!-- Average Results -->
            <v-col cols="12" md="6">
              <v-card outlined>
                <v-card-subtitle class="py-2">Average Results</v-card-subtitle>
                <v-card-text>
                  <v-select
                    v-model="averageWithIndex"
                    :items="averageableResults"
                    label="Average With Result"
                    dense
                    outlined
                    hide-details
                    class="mb-2"
                  />
                  <v-alert type="info" dense text class="mt-2 mb-3">
                    <div class="text-caption">
                      Averages common axes between selected result and chosen result.
                      Result will be stored in the selected row.
                    </div>
                  </v-alert>
                  <v-btn
                    small
                    block
                    color="secondary"
                    @click="averageResults"
                    :disabled="!canAverage"
                  >
                    <v-icon small left>mdi-chart-bell-curve</v-icon>
                    Average Results
                  </v-btn>
                </v-card-text>
              </v-card>
            </v-col>
          </v-row>
        </v-card-text>
      </v-card>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import BaseComponent from '../base/BaseComponent.vue'

interface ProbeResult {
  index: number
  x: number
  y: number
  z: number
  a: number
  rotation: number
  hasData: boolean
}

export default BaseComponent.extend({
  data() {
    return {
      selectedResults: [] as ProbeResult[],
      selectedWcs: 1,
      pushAxes: {
        x: true,
        y: true,
        z: true,
        a: false
      },
      averageWithIndex: null as number | null,
      headers: [
        { text: '#', value: 'index', sortable: false, width: '60px' },
        { text: 'X (mm)', value: 'x', sortable: false },
        { text: 'Y (mm)', value: 'y', sortable: false },
        { text: 'Z (mm)', value: 'z', sortable: false },
        { text: 'A', value: 'a', sortable: false },
        { text: 'Rot (°)', value: 'rotation', sortable: false },
        { text: '', value: 'actions', sortable: false, width: '60px' }
      ],
      wcsOptions: [
        { text: 'G54 (WCS 1)', value: 1 },
        { text: 'G55 (WCS 2)', value: 2 },
        { text: 'G56 (WCS 3)', value: 3 },
        { text: 'G57 (WCS 4)', value: 4 },
        { text: 'G58 (WCS 5)', value: 5 },
        { text: 'G59 (WCS 6)', value: 6 }
      ]
    }
  },
  computed: {
    touchProbeEnabled(): boolean {
      return this.globals.nxtFeatureTouchProbe === true
    },
    probeResults(): any[] {
      return this.globals.nxtProbeResults || []
    },
    resultsTableData(): ProbeResult[] {
      const results: ProbeResult[] = []
      for (let i = 0; i < this.probeResults.length; i++) {
        const result = this.probeResults[i]
        const hasData = result != null && Array.isArray(result)
        
        results.push({
          index: i,
          x: hasData && result[0] ? result[0] : 0,
          y: hasData && result[1] ? result[1] : 0,
          z: hasData && result[2] ? result[2] : 0,
          a: hasData && result[3] ? result[3] : 0,
          rotation: hasData && result.length > 4 && result[4] ? result[4] : 0,
          hasData
        })
      }
      return results
    },
    hasResults(): boolean {
      return this.resultsTableData.some(r => r.hasData)
    },
    selectedResultIndex(): number | null {
      return this.selectedResults.length > 0 ? this.selectedResults[0].index : null
    },
    selectedResultData(): ProbeResult {
      if (this.selectedResultIndex === null) {
        return { index: -1, x: 0, y: 0, z: 0, a: 0, rotation: 0, hasData: false }
      }
      return this.resultsTableData[this.selectedResultIndex]
    },
    hasAAxis(): boolean {
      return this.$store.state.machine.model?.move?.axes?.length > 3
    },
    wcsLabel(): string {
      const wcs = this.wcsOptions.find(w => w.value === this.selectedWcs)
      return wcs ? wcs.text : 'WCS'
    },
    canPushToWcs(): boolean {
      return this.selectedResultIndex !== null && 
             this.selectedResultData.hasData &&
             (this.pushAxes.x || this.pushAxes.y || this.pushAxes.z || this.pushAxes.a)
    },
    averageableResults(): any[] {
      return this.resultsTableData
        .filter(r => r.hasData && r.index !== this.selectedResultIndex)
        .map(r => ({
          text: `Result ${r.index}`,
          value: r.index
        }))
    },
    canAverage(): boolean {
      return this.selectedResultIndex !== null &&
             this.averageWithIndex !== null &&
             this.selectedResultData.hasData
    }
  },
  methods: {
    formatCoordinate(value: number): string {
      if (!value || value === 0) return '-'
      return value.toFixed(3)
    },
    formatRotation(value: number): string {
      if (!value || value === 0) return '-'
      return value.toFixed(2)
    },
    async clearResult(index: number) {
      try {
        await this.sendCode(`M6521 P${index}`)
        this.$store.dispatch('machine/showMessage', {
          type: 'success',
          message: `Cleared probe result at index ${index}`
        })
      } catch (error) {
        this.$store.dispatch('machine/showMessage', {
          type: 'error',
          message: `Failed to clear result: ${error}`
        })
      }
    },
    async clearAllResults() {
      try {
        await this.sendCode('M6521')
        this.selectedResults = []
        this.averageWithIndex = null
        this.$store.dispatch('machine/showMessage', {
          type: 'success',
          message: 'Cleared all probe results'
        })
      } catch (error) {
        this.$store.dispatch('machine/showMessage', {
          type: 'error',
          message: `Failed to clear results: ${error}`
        })
      }
    },
    async pushToWcs() {
      if (!this.canPushToWcs) return

      const index = this.selectedResultIndex
      const wcs = this.selectedWcs
      
      // Build axis flags
      const axisFlags = []
      if (this.pushAxes.x && this.selectedResultData.x) axisFlags.push('X')
      if (this.pushAxes.y && this.selectedResultData.y) axisFlags.push('Y')
      if (this.pushAxes.z && this.selectedResultData.z) axisFlags.push('Z')
      if (this.pushAxes.a && this.selectedResultData.a) axisFlags.push('A')

      if (axisFlags.length === 0) {
        this.$store.dispatch('machine/showMessage', {
          type: 'warning',
          message: 'Select at least one axis to push'
        })
        return
      }

      const gcode = `M6520 P${index} W${wcs} ${axisFlags.join(' ')}`

      try {
        await this.sendCode(gcode)
        this.$store.dispatch('machine/showMessage', {
          type: 'success',
          message: `Pushed result ${index} to ${this.wcsLabel}`
        })
      } catch (error) {
        this.$store.dispatch('machine/showMessage', {
          type: 'error',
          message: `Failed to push to WCS: ${error}`
        })
      }
    },
    async averageResults() {
      if (!this.canAverage) return

      const index1 = this.selectedResultIndex
      const index2 = this.averageWithIndex

      try {
        await this.sendCode(`M6522 P${index1} Q${index2}`)
        this.$store.dispatch('machine/showMessage', {
          type: 'success',
          message: `Averaged results ${index1} and ${index2}, stored in ${index1}`
        })
        this.averageWithIndex = null
      } catch (error) {
        this.$store.dispatch('machine/showMessage', {
          type: 'error',
          message: `Failed to average results: ${error}`
        })
      }
    }
  }
})
</script>

<style scoped>
.v-data-table >>> tbody tr.v-data-table__selected {
  background: rgba(var(--v-primary-base), 0.08) !important;
}
</style>
