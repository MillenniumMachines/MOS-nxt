<template>
  <v-card outlined class="mt-4">
    <v-card-title class="subtitle-1 py-3">
      <v-icon left class="mr-2">mdi-wrench-clock</v-icon>
      {{ $t('plugins.nxt.panels.maintenance.caption') }}
      <v-spacer />
      <v-btn
        v-if="isConnected && nxtReady"
        small
        outlined
        color="primary"
        :loading="saving"
        :disabled="uiFrozen || saving"
        @click="saveMaint"
      >
        {{ $t('plugins.nxt.panels.maintenance.save') }}
      </v-btn>
    </v-card-title>
    <v-divider />
    <v-card-text class="pa-3">
      <v-alert v-if="!maintenanceEnabled" type="info" dense outlined class="mb-3">
        {{ $t('plugins.nxt.panels.maintenance.disabledHint') }}
      </v-alert>

      <div class="subtitle-2 mb-2">{{ $t('plugins.nxt.panels.maintenance.axisTravel') }}</div>
      <v-simple-table dense>
        <template #default>
          <thead>
            <tr>
              <th class="text-left">{{ $t('plugins.nxt.panels.maintenance.colAxis') }}</th>
              <th class="text-left">{{ $t('plugins.nxt.panels.maintenance.colTravel') }}</th>
              <th class="text-left">{{ $t('plugins.nxt.panels.maintenance.colServiceAt') }}</th>
              <th class="text-left">{{ $t('plugins.nxt.panels.maintenance.colProgress') }}</th>
              <th class="text-left"></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in axisRows" :key="'ax' + row.index">
              <td>{{ row.letter }}</td>
              <td>{{ row.travelLabel }}</td>
              <td>
                <v-text-field
                  :value="row.serviceKm"
                  type="number"
                  min="0"
                  step="1"
                  dense
                  hide-details
                  class="nxt-maint-threshold"
                  :disabled="uiFrozen"
                  @change="setAxisThreshold(row.index, $event)"
                />
              </td>
              <td>
                <v-progress-linear
                  :value="row.pct"
                  :color="row.due ? 'warning' : 'primary'"
                  height="8"
                  rounded
                />
              </td>
              <td>
                <v-btn
                  x-small
                  outlined
                  :disabled="uiFrozen || row.travelRaw <= 0"
                  @click="confirmService(row)"
                >
                  <v-icon left x-small>mdi-check</v-icon>
                  {{ $t('plugins.nxt.panels.maintenance.serviced') }}
                </v-btn>
              </td>
            </tr>
          </tbody>
        </template>
      </v-simple-table>

      <template v-if="coolantEnabled">
        <v-divider class="my-4" />
        <div class="d-flex align-center mb-2">
          <v-icon left small>mdi-water-outline</v-icon>
          <span class="subtitle-2">{{ $t('plugins.nxt.panels.maintenance.coolantRuntime') }}</span>
          <v-spacer />
          <v-chip v-if="coolantDue" x-small label color="warning" text-color="white">
            {{ $t('plugins.nxt.panels.maintenance.serviceDue') }}
          </v-chip>
        </div>
        <v-row dense align="center">
          <v-col cols="12" sm="4">
            <div class="body-2">{{ coolantLabel }}</div>
          </v-col>
          <v-col cols="12" sm="4">
            <v-text-field
              :value="coolantServiceMins"
              type="number"
              min="0"
              step="1"
              dense
              hide-details
              :label="$t('plugins.nxt.panels.maintenance.coolantServiceMins')"
              :disabled="uiFrozen"
              @change="setCoolantThreshold($event)"
            />
          </v-col>
          <v-col cols="12" sm="4">
            <v-progress-linear :value="coolantPct" :color="coolantDue ? 'warning' : 'primary'" height="8" rounded />
          </v-col>
        </v-row>
        <v-btn
          x-small
          outlined
          class="mt-2"
          :disabled="uiFrozen || coolantRaw <= 0"
          @click="resetCoolantRuntime"
        >
          {{ $t('plugins.nxt.panels.maintenance.coolantServiced') }}
        </v-btn>
      </template>

      <v-divider class="my-4" />
      <div class="subtitle-2 mb-2">{{ $t('plugins.nxt.panels.maintenance.idleActions') }}</div>
      <v-switch
        :input-value="idleEnabled"
        :label="$t('plugins.nxt.panels.maintenance.idleEnable')"
        :disabled="uiFrozen"
        hide-details
        class="mt-0"
        @change="setIdleEnabled"
      />
      <v-row dense>
        <v-col cols="12" sm="4">
          <v-text-field
            :value="idleMinutes"
            type="number"
            min="1"
            step="1"
            dense
            hide-details
            :label="$t('plugins.nxt.panels.maintenance.idleAfterMins')"
            :disabled="uiFrozen || !idleEnabled"
            @change="setIdleMinutes"
          />
        </v-col>
        <v-col cols="12" sm="4">
          <v-text-field
            :value="idleFanPct"
            type="number"
            min="0"
            max="100"
            step="1"
            dense
            hide-details
            :label="$t('plugins.nxt.panels.maintenance.idleFanPct')"
            :disabled="uiFrozen || !idleEnabled"
            @change="setIdleFanPct"
          />
        </v-col>
        <v-col cols="12" sm="4">
          <v-text-field
            :value="idleDimBri"
            type="number"
            min="0"
            max="255"
            step="1"
            dense
            hide-details
            :label="$t('plugins.nxt.panels.maintenance.idleDimBri')"
            :disabled="uiFrozen || !idleEnabled"
            @change="setIdleDimBri"
          />
        </v-col>
      </v-row>
    </v-card-text>

    <v-dialog v-model="serviceDialog" max-width="400">
      <v-card>
        <v-card-title class="subtitle-1">
          {{ $t('plugins.nxt.panels.maintenance.confirmServiceTitle') }}
        </v-card-title>
        <v-card-text>
          {{ $t('plugins.nxt.panels.maintenance.confirmServiceBody', { axis: serviceAxis.letter }) }}
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn text @click="serviceDialog = false">{{ $t('plugins.nxt.panels.maintenance.cancel') }}</v-btn>
          <v-btn color="primary" text :disabled="uiFrozen" @click="doService">
            {{ $t('plugins.nxt.panels.maintenance.serviced') }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-card>
</template>

<script lang="ts">
// @ts-nocheck — Vue 2 + BaseComponent.extend(): tsc does not merge computeds onto `this`.
import BaseComponent from '../base/BaseComponent.vue'
import store from '@/store'
import { readFirmwareGlobal } from '../../utils/nxtToolChangerOm'
import { fmtDist, fmtDur } from '../../utils/nxtMaintenanceUi'

function machineModel(): Record<string, any> {
  const m = store.state.machine?.model
  return m != null && typeof m === 'object' ? (m as Record<string, any>) : {}
}

function mosGlobal(key: string): unknown {
  return readFirmwareGlobal(machineModel().global, key)
}

export default BaseComponent.extend({
  name: 'NxtMaintenancePanel',

  data() {
    return {
      saving: false,
      serviceDialog: false,
      serviceAxis: { index: 0, letter: '?' }
    }
  },

  computed: {
    maintenanceEnabled(): boolean {
      const v = mosGlobal('nxtFeatMaint')
      return v === true || v === 1
    },

    axisRows() {
      const axes = machineModel().move?.axes
      const travel = mosGlobal('nxtAxisTravel')
      const serviceAt = mosGlobal('nxtAxisServiceAt')
      if (!Array.isArray(axes)) {
        return []
      }
      const rows = []
      for (let i = 0; i < axes.length; i++) {
        const letter = axes[i]?.letter ? axes[i].letter : '#' + i
        const travelRaw = Array.isArray(travel) && typeof travel[i] === 'number' ? travel[i] : 0
        const serviceMm = Array.isArray(serviceAt) && typeof serviceAt[i] === 'number' ? serviceAt[i] : 0
        const pct = serviceMm > 0 ? Math.min(100, (travelRaw / serviceMm) * 100) : 0
        const due = serviceMm > 0 && travelRaw >= serviceMm
        rows.push({
          index: i,
          letter,
          travelRaw,
          travelLabel: fmtDist(travelRaw),
          serviceAt: serviceMm,
          serviceKm: serviceMm > 0 ? Math.round(serviceMm / 1000) : 0,
          pct,
          due
        })
      }
      return rows
    },

    coolantEnabled(): boolean {
      const v = mosGlobal('nxtFeatureCoolantControl')
      return v === true || v === 1
    },

    coolantRaw(): number {
      const v = mosGlobal('nxtCoolantRuntime')
      return typeof v === 'number' ? v : 0
    },

    coolantLabel(): string {
      return fmtDur(this.coolantRaw)
    },

    coolantServiceAt(): number {
      const v = mosGlobal('nxtCoolantServiceAt')
      return typeof v === 'number' ? v : 0
    },

    coolantServiceMins(): number {
      return Math.round(this.coolantServiceAt / 60)
    },

    coolantPct(): number {
      return this.coolantServiceAt > 0 ? Math.min(100, (this.coolantRaw / this.coolantServiceAt) * 100) : 0
    },

    coolantDue(): boolean {
      return this.coolantServiceAt > 0 && this.coolantRaw >= this.coolantServiceAt
    },

    idleEnabled(): boolean {
      const v = mosGlobal('nxtFeatIdleActions')
      return v === true || v === 1
    },

    idleMinutes(): number {
      const v = mosGlobal('nxtIdleAfter')
      const sec = typeof v === 'number' ? v : 1800
      return Math.max(1, Math.round(sec / 60))
    },

    idleFanPct(): number {
      const v = mosGlobal('nxtIdleFanLow')
      const pwm = typeof v === 'number' ? v : 0.3
      return Math.round(pwm * 100)
    },

    idleDimBri(): number {
      const v = mosGlobal('nxtIdleDimBri')
      return typeof v === 'number' ? Math.round(v) : 40
    }
  },

  methods: {
    async saveMaint() {
      this.saving = true
      try {
        await this.sendCode('M98 P"nxt/nxt-save-maintenance.g"')
      } finally {
        this.saving = false
      }
    },

    async setAxisThreshold(index: number, raw: string | number) {
      let km = Number(raw)
      if (!Number.isFinite(km) || km < 0) {
        km = 0
      }
      const mm = Math.round(km * 1000)
      await this.sendCode('set global.nxtAxisServiceAt[' + index + '] = ' + mm)
      await this.saveMaint()
    },

    async setCoolantThreshold(raw: string | number) {
      let mins = Number(raw)
      if (!Number.isFinite(mins) || mins < 0) {
        mins = 0
      }
      const sec = Math.round(mins * 60)
      await this.sendCode('set global.nxtCoolantServiceAt = ' + sec)
      await this.saveMaint()
    },

    async setIdleEnabled(enabled: boolean) {
      await this.sendCode('set global.nxtFeatIdleActions = ' + (enabled ? 'true' : 'false'))
      await this.saveMaint()
    },

    async setIdleMinutes(raw: string | number) {
      let mins = Math.round(Number(raw))
      if (!Number.isFinite(mins) || mins < 1) {
        mins = 1
      }
      await this.sendCode('set global.nxtIdleAfter = ' + mins * 60)
      await this.saveMaint()
    },

    async setIdleFanPct(raw: string | number) {
      let pct = Number(raw)
      if (!Number.isFinite(pct) || pct < 0) {
        pct = 0
      }
      if (pct > 100) {
        pct = 100
      }
      await this.sendCode('set global.nxtIdleFanLow = ' + pct / 100)
      await this.saveMaint()
    },

    async setIdleDimBri(raw: string | number) {
      let bri = Math.round(Number(raw))
      if (!Number.isFinite(bri) || bri < 0) {
        bri = 0
      }
      if (bri > 255) {
        bri = 255
      }
      await this.sendCode('set global.nxtIdleDimBri = ' + bri)
      await this.saveMaint()
    },

    confirmService(row: { index: number; letter: string }) {
      this.serviceAxis = { index: row.index, letter: row.letter }
      this.serviceDialog = true
    },

    async doService() {
      await this.sendCode('set global.nxtAxisTravel[' + this.serviceAxis.index + '] = 0')
      await this.saveMaint()
      this.serviceDialog = false
    },

    async resetCoolantRuntime() {
      await this.sendCode('set global.nxtCoolantRuntime = 0')
      await this.saveMaint()
    }
  }
})
</script>

<style scoped>
.nxt-maint-threshold {
  max-width: 100px;
}
</style>
