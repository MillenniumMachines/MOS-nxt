<template>
  <v-card>
    <v-card-title class="d-flex align-center">
      <v-icon class="mr-2">mdi-table</v-icon>
      Probe Results Table
      <v-spacer />
      <v-btn
        size="small"
        variant="text"
        color="error"
        @click="clearAllResults"
        :disabled="!hasResults"
      >
        <v-icon class="mr-2" size="small">mdi-delete-sweep</v-icon>
        Clear All
      </v-btn>
    </v-card-title>

    <v-card-text>
      <v-alert v-if="!touchProbeEnabled" type="info" density="compact" variant="outlined" class="mb-4">
        <v-icon class="mr-2" size="small">mdi-information</v-icon>
        Touch probe feature must be enabled to use probing functionality.
      </v-alert>

      <v-data-table
        :headers="headers"
        :items="resultsTableData"
        :items-per-page="10"
        :hide-default-footer="true"
        density="compact"
        class="elevation-1"
        select-strategy="single"
        v-model="selectedResults"
        show-select
        item-value="index"
      >
        <template v-slot:item.x="{ item }: { item: any }">
          {{ formatCoordinate(item.x, item.hasData) }}
        </template>
        <template v-slot:item.y="{ item }: { item: any }">
          {{ formatCoordinate(item.y, item.hasData) }}
        </template>
        <template v-slot:item.z="{ item }: { item: any }">
          {{ formatCoordinate(item.z, item.hasData) }}
        </template>
        <template v-slot:item.a="{ item }: { item: any }">
          {{ formatCoordinate(item.a, item.hasData) }}
        </template>
        <template v-slot:item.rotation="{ item }: { item: any }">
          {{ formatRotation(item.rotation, item.hasData) }}
        </template>
        <template v-slot:item.actions="{ item }: { item: any }">
          <v-btn
            size="x-small"
            icon
            color="error"
            @click="clearResult(item.index)"
            :disabled="!item.hasData"
          >
            <v-icon size="x-small">mdi-delete</v-icon>
          </v-btn>
        </template>
      </v-data-table>

      <v-divider class="my-4" />

      <!-- Actions Panel -->
      <v-card variant="outlined">
        <v-card-subtitle class="pb-2">
          <v-icon class="mr-2" size="small">mdi-cog</v-icon>
          Result Actions
        </v-card-subtitle>
        <v-card-text>
          <v-row density="compact">
            <!-- Push to WCS -->
            <v-col cols="12" md="6">
              <v-card variant="outlined">
                <v-card-subtitle class="py-2">Push to WCS</v-card-subtitle>
                <v-card-text>
                  <v-select
                    v-model="selectedWcs"
                    :items="wcsOptions"
                    item-title="text"
                    item-value="value"
                    label="Target WCS"
                    density="compact"
                    variant="outlined"
                    hide-details
                    class="mb-2"
                  />
                  <v-checkbox
                    v-model="pushAxes.x"
                    label="X Axis"
                    density="compact"
                    hide-details
                    class="my-1"
                    :disabled="!selectedResultData.hasData"
                  />
                  <v-checkbox
                    v-model="pushAxes.y"
                    label="Y Axis"
                    density="compact"
                    hide-details
                    class="my-1"
                    :disabled="!selectedResultData.hasData"
                  />
                  <v-checkbox
                    v-model="pushAxes.z"
                    label="Z Axis"
                    density="compact"
                    hide-details
                    class="my-1"
                    :disabled="!selectedResultData.hasData"
                  />
                  <v-checkbox
                    v-if="hasAAxis"
                    v-model="pushAxes.a"
                    label="A Axis"
                    density="compact"
                    hide-details
                    class="my-1"
                    :disabled="!selectedResultData.hasData"
                  />
                  <v-btn
                    size="small"
                    block
                    color="primary"
                    @click="pushToWcs"
                    :disabled="!canPushToWcs"
                    class="mt-3"
                  >
                    <v-icon class="mr-2" size="small">mdi-application-export</v-icon>
                    Push to {{ wcsLabel }}
                  </v-btn>
                </v-card-text>
              </v-card>
            </v-col>

            <!-- Average Results -->
            <v-col cols="12" md="6">
              <v-card variant="outlined">
                <v-card-subtitle class="py-2">Average Results</v-card-subtitle>
                <v-card-text>
                  <v-select
                    v-model="averageWithIndex"
                    :items="averageableResults"
                    label="Average With Result"
                    density="compact"
                    variant="outlined"
                    hide-details
                    class="mb-2"
                  />
                  <v-alert type="info" density="compact" variant="text" class="mt-2 mb-3">
                    <div class="text-caption">
                      Averages common axes between selected result and chosen result.
                      Result will be stored in the selected row.
                    </div>
                  </v-alert>
                  <v-btn
                    size="small"
                    block
                    color="secondary"
                    @click="averageResults"
                    :disabled="!canAverage"
                  >
                    <v-icon class="mr-2" size="small">mdi-chart-bell-curve</v-icon>
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
import { defineNxtComponent } from '../base/BaseComponent.vue'

interface ProbeResult {
  index: number
  x: number
  y: number
  z: number
  a: number
  rotation: number
  hasData: boolean
}

export default defineNxtComponent({
  data() {
    return {
      // Vuetify 3's v-data-table binds selection to an array of `item-value` values
      // (the row's `index` field), not full row objects like Vuetify 2's v-data-table did
      selectedResults: [] as number[],
      selectedWcs: 1,
      pushAxes: {
        x: true,
        y: true,
        z: true,
        a: false
      },
      averageWithIndex: null as number | null,
      headers: [
        { title: '#', key: 'index', sortable: false, width: '60px' },
        { title: 'X (mm)', key: 'x', sortable: false },
        { title: 'Y (mm)', key: 'y', sortable: false },
        { title: 'Z (mm)', key: 'z', sortable: false },
        { title: 'A', key: 'a', sortable: false },
        { title: 'Rot (°)', key: 'rotation', sortable: false },
        { title: '', key: 'actions', sortable: false, width: '60px' }
      ],
      wcsOptions: [
        { text: 'WCS1 (G54)', value: 1 },
        { text: 'WCS2 (G55)', value: 2 },
        { text: 'WCS3 (G56)', value: 3 },
        { text: 'WCS4 (G57)', value: 4 },
        { text: 'WCS5 (G58)', value: 5 },
        { text: 'WCS6 (G59)', value: 6 },
        { text: 'WCS7 (G59.1)', value: 7 },
        { text: 'WCS8 (G59.2)', value: 8 },
        { text: 'WCS9 (G59.3)', value: 9 }
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
          x: hasData && result.length > 0 ? (result[0] ?? 0) : 0,
          y: hasData && result.length > 1 ? (result[1] ?? 0) : 0,
          z: hasData && result.length > 2 ? (result[2] ?? 0) : 0,
          a: hasData && this.hasAAxis && result.length > 3 ? (result[3] ?? 0) : 0,
          // θ is always the last slot (#move.axes), not a fixed index 4
          rotation: hasData && result.length > 3 ? (result[result.length - 1] ?? 0) : 0,
          hasData
        })
      }
      return results
    },
    hasResults(): boolean {
      return this.resultsTableData.some((r: ProbeResult) => r.hasData)
    },
    selectedResultIndex(): number | null {
      return this.selectedResults.length > 0 ? this.selectedResults[0] : null
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
      const wcs = this.wcsOptions.find((w: { text: string; value: number }) => w.value === this.selectedWcs)
      return wcs ? wcs.text : 'WCS'
    },
    canPushToWcs(): boolean {
      return this.selectedResultIndex !== null && 
             this.selectedResultData.hasData &&
             (this.pushAxes.x || this.pushAxes.y || this.pushAxes.z || this.pushAxes.a)
    },
    averageableResults(): any[] {
      return this.resultsTableData
        .filter((r: ProbeResult) => r.hasData && r.index !== this.selectedResultIndex)
        .map((r: ProbeResult) => ({
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
    formatCoordinate(value: number, hasData: boolean): string {
      if (!hasData) return '-'
      return value.toFixed(3)
    },
    formatRotation(value: number, hasData: boolean): string {
      if (!hasData) return '-'
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
.v-data-table :deep(tbody tr.v-data-table__selected) {
  background: rgba(var(--v-primary-base), 0.08) !important;
}
</style>
