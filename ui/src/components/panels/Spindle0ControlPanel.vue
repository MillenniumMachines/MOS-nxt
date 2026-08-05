<template>
  <v-card v-if="spindleConfigured" variant="outlined" class="fill-height">
    <v-card-title class="py-2 font-weight-bold">
      <v-icon class="mr-2">mdi-rotate-right</v-icon>
      {{ $t('plugins.nxt.panels.spindleControl.caption') }}
    </v-card-title>
    <v-card-text class="pt-0">
      <v-table density="compact">
        <thead>
          <tr>
            <th>{{ $t('panel.spindle.spindle') }}</th>
            <th>{{ $t('panel.spindle.active') }}</th>
            <th v-if="canReverse">{{ $t('panel.spindle.direction') }}</th>
            <th>{{ $t('panel.spindle.currentRPM') }}</th>
            <th>{{ $t('panel.spindle.setRPM') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr
            :class="{
              'nxt-spindle0-active': (spindle.current ?? 0) > 0 && (spindle.active ?? 0) > 0
            }"
          >
            <td>{{ spindleLabel }}</td>
            <td>
              <v-btn v-if="spindleRunning" size="small" block :disabled="uiFrozen" @click="spindleOff">
                {{ $t('panel.spindle.on') }}
              </v-btn>
              <v-btn v-else size="small" block :disabled="uiFrozen" @click="spindleOn">
                {{ $t('panel.spindle.off') }}
              </v-btn>
            </td>
            <td v-if="canReverse">
              <v-btn-toggle v-model="direction" mandatory density="compact" :disabled="uiFrozen">
                <v-btn size="small">{{ $t('panel.spindle.forward') }}</v-btn>
                <v-btn size="small">{{ $t('panel.spindle.reverse') }}</v-btn>
              </v-btn-toggle>
            </td>
            <td>{{ spindle.current }}</td>
            <td>
              <v-combobox
                density="compact"
                hide-details
                :items="rpmPresets"
                :model-value="spindle.active"
                :disabled="uiFrozen"
                @update:model-value="setActiveRpm"
              />
            </td>
          </tr>
        </tbody>
      </v-table>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
// @ts-nocheck — Vue 2 + BaseComponent.extend(): tsc does not merge computeds onto `this`.
import { defineNxtComponent } from '../base/BaseComponent.vue'
import { Spindle, SpindleState } from '@duet3d/objectmodel'
import store from '../../compat/dwcStore'

const SPINDLE_INDEX = 0

export default defineNxtComponent({
  name: 'NxtSpindle0ControlPanel',

  data() {
    return {
      direction: 0
    }
  },

  computed: {
    spindle(): Spindle | null {
      const spindles = store.state.machine.model.spindles
      if (!spindles || spindles.length <= SPINDLE_INDEX) {
        return null
      }
      return spindles[SPINDLE_INDEX]
    },

    spindleConfigured(): boolean {
      return this.spindle != null && this.spindle.state !== SpindleState.unconfigured
    },

    spindleRunning(): boolean {
      const s = this.spindle
      if (!s) {
        return false
      }
      return s.state === SpindleState.forward || s.state === SpindleState.reverse
    },

    canReverse(): boolean {
      return this.spindle?.canReverse === true
    },

    spindleLabel(): string {
      const t = (this as any).$t('panel.spindle.spindle').toString()
      return `${t} ${SPINDLE_INDEX}`
    },

    rpmPresets(): number[] {
      const spindle = this.spindle
      if (!spindle || spindle.min === null || spindle.max === null) {
        return []
      }
      const values = store.state.machine.settings.spindleRPM.filter(
        (rpm: number) => rpm >= spindle.min! && rpm <= spindle.max!
      )
      if (!values.includes(0)) {
        values.push(0)
      }
      values.sort((a: number, b: number) => a - b)
      return values
    }
  },

  watch: {
    spindle: {
      deep: true,
      immediate: true,
      handler() {
        this.syncDirectionFromSpindle()
      }
    }
  },

  methods: {
    syncDirectionFromSpindle() {
      const s = this.spindle
      if (!s) {
        return
      }
      if (s.state === SpindleState.reverse) {
        this.direction = 1
      } else if (s.state === SpindleState.forward) {
        this.direction = 0
      }
    },

    async setActiveRpm(value: number) {
      const cmd = `${this.direction ? 'M4' : 'M3'} P${SPINDLE_INDEX} S${value}`
      await this.sendCode(cmd)
    },

    async spindleOn() {
      const s = this.spindle
      if (!s) {
        return
      }
      const cmd = `${this.direction ? 'M4' : 'M3'} P${SPINDLE_INDEX} S${s.active}`
      await this.sendCode(cmd)
    },

    async spindleOff() {
      await this.sendCode(`M5 P${SPINDLE_INDEX}`)
    }
  }
})
</script>

<style scoped>
.nxt-spindle0-active {
  background-color: rgba(0, 187, 0, 0.15);
}
</style>
