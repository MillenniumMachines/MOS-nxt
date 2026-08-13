<template>
  <div>
    <v-alert v-if="!arborAvailable" type="warning" variant="outlined" class="mb-4">
      <v-icon class="mr-2">mdi-alert</v-icon>
      {{ $t('plugins.nxt.panels.vfd.notInstalled') }}
    </v-alert>

    <template v-else>
      <v-alert type="info" variant="outlined" class="mb-4">
        <v-icon class="mr-2">mdi-information-outline</v-icon>
        {{ $t('plugins.nxt.panels.vfd.intro') }}
      </v-alert>

      <v-row>
        <v-col cols="12" md="6">
          <v-select
            v-model="form.typeIndex"
            :items="modelItems"
            item-title="text"
            item-value="value"
            :label="$t('plugins.nxt.panels.vfd.model')"
            density="compact"
            variant="outlined"
            hide-details="auto"
            :disabled="uiFrozen || !isConnected"
          />
        </v-col>
        <v-col cols="12" md="6">
          <v-select
            v-model="form.spindleId"
            :items="spindleSelectItems"
            item-title="text"
            item-value="value"
            :label="$t('plugins.nxt.panels.vfd.spindle')"
            density="compact"
            variant="outlined"
            hide-details="auto"
            :disabled="uiFrozen || !isConnected || spindleSelectItems.length === 0"
          />
        </v-col>
        <v-col cols="12" sm="4">
          <v-select
            v-model="form.channel"
            :items="channelItems"
            item-title="text"
            item-value="value"
            :label="$t('plugins.nxt.panels.vfd.uart')"
            density="compact"
            variant="outlined"
            hide-details="auto"
            :disabled="uiFrozen || !isConnected"
          />
        </v-col>
        <v-col cols="12" sm="4">
          <v-select
            v-model="form.baud"
            :items="baudItems"
            :label="$t('plugins.nxt.panels.vfd.baud')"
            density="compact"
            variant="outlined"
            hide-details="auto"
            :disabled="uiFrozen || !isConnected"
          />
        </v-col>
        <v-col cols="12" sm="4">
          <v-text-field
            v-model.number="form.address"
            type="number"
            :label="$t('plugins.nxt.panels.vfd.address')"
            density="compact"
            variant="outlined"
            hide-details="auto"
            :disabled="uiFrozen || !isConnected"
          />
        </v-col>
        <v-col cols="6" sm="4">
          <v-text-field
            v-model.number="form.motorW"
            type="number"
            step="0.1"
            :label="$t('plugins.nxt.panels.vfd.motorKw')"
            density="compact"
            variant="outlined"
            hide-details="auto"
            :disabled="uiFrozen || !isConnected"
          />
        </v-col>
        <v-col cols="6" sm="4">
          <v-select
            v-model="form.motorPoles"
            :items="[2, 4]"
            :label="$t('plugins.nxt.panels.vfd.poles')"
            density="compact"
            variant="outlined"
            hide-details="auto"
            :disabled="uiFrozen || !isConnected"
          />
        </v-col>
        <v-col cols="6" sm="4">
          <v-text-field
            v-model.number="form.motorV"
            type="number"
            :label="$t('plugins.nxt.panels.vfd.motorV')"
            density="compact"
            variant="outlined"
            hide-details="auto"
            :disabled="uiFrozen || !isConnected"
          />
        </v-col>
        <v-col cols="6" sm="4">
          <v-text-field
            v-model.number="form.motorF"
            type="number"
            :label="$t('plugins.nxt.panels.vfd.motorF')"
            density="compact"
            variant="outlined"
            hide-details="auto"
            :disabled="uiFrozen || !isConnected"
          />
        </v-col>
        <v-col cols="6" sm="4">
          <v-text-field
            v-model.number="form.motorI"
            type="number"
            step="0.1"
            :label="$t('plugins.nxt.panels.vfd.motorI')"
            density="compact"
            variant="outlined"
            hide-details="auto"
            :disabled="uiFrozen || !isConnected"
          />
        </v-col>
        <v-col cols="6" sm="4">
          <v-text-field
            v-model.number="form.motorR"
            type="number"
            :label="$t('plugins.nxt.panels.vfd.motorR')"
            density="compact"
            variant="outlined"
            hide-details="auto"
            :disabled="uiFrozen || !isConnected"
          />
        </v-col>
        <v-col cols="6" sm="4">
          <v-text-field
            v-model.number="form.accelSec"
            type="number"
            step="0.1"
            min="0.1"
            label="Accel (s)"
            density="compact"
            variant="outlined"
            hide-details="auto"
            :disabled="uiFrozen || !isConnected"
          />
        </v-col>
        <v-col cols="6" sm="4">
          <v-text-field
            v-model.number="form.decelSec"
            type="number"
            step="0.1"
            min="0.1"
            label="Decel (s)"
            density="compact"
            variant="outlined"
            hide-details="auto"
            :disabled="uiFrozen || !isConnected"
          />
        </v-col>
      </v-row>

      <div class="d-flex flex-wrap align-center mt-2 mb-2">
        <v-chip class="mr-2 mb-2" size="small" :color="commColor" variant="tonal">
          {{ $t('plugins.nxt.panels.vfd.commReady') }}: {{ commLabel }}
        </v-chip>
        <v-chip v-if="statusSummary" class="mr-2 mb-2" size="small" variant="outlined">
          {{ statusSummary }}
        </v-chip>
      </div>

      <div class="d-flex flex-wrap align-center">
        <v-btn
          color="primary"
          class="mr-2 mb-2"
          :disabled="uiFrozen || !isConnected || !canApply"
          :loading="applying"
          @click="applyVfd"
        >
          <v-icon start size="small">mdi-serial-port</v-icon>
          {{ $t('plugins.nxt.panels.vfd.apply') }}
        </v-btn>
        <v-btn
          color="secondary"
          variant="outlined"
          class="mb-2"
          :disabled="!isConnected"
          @click="openArborCtlPlugin"
        >
          <v-icon start size="small">mdi-open-in-new</v-icon>
          {{ $t('plugins.nxt.panels.vfd.openAdvanced') }}
        </v-btn>
      </div>

      <v-alert v-if="applyError" type="error" density="compact" variant="outlined" class="mt-2">
        {{ applyError }}
      </v-alert>
      <v-alert v-if="applyOk" type="success" density="compact" variant="outlined" class="mt-2">
        {{ $t('plugins.nxt.panels.vfd.applyOk') }}
      </v-alert>
    </template>
  </div>
</template>

<script lang="ts">
import { defineNxtComponent } from '../base/BaseComponent.vue'
import { readFirmwareGlobal } from '../../utils/nxtToolChangerOm'
import { uploadDwcFile } from '../../utils/nxtFileUpload'
import {
  isArborCtlFirmwareLive,
  isArborCtlPluginInstalled
} from '../../utils/nxtInstalledPlugins'
import {
  ARBORCTL_USER_VARS_PATH,
  ARBOR_UART_CHANNELS,
  FALLBACK_ARBOR_MODELS,
  arborInternalName,
  arborTypeName,
  buildArborCtlConfigCode,
  buildArborCtlUserVarsFile,
  clampArborUartChannel,
  isArborUartChannel
} from '../../utils/arborctlApply'

const BAUD_LIST = [4800, 9600, 19200, 38400, 57600]

export default defineNxtComponent({
  name: 'NxtVfdPanel',

  data() {
    return {
      applying: false,
      applyError: '' as string,
      applyOk: false,
      form: {
        channel: 2,
        baud: 9600,
        address: 1,
        typeIndex: 1,
        spindleId: 0,
        motorW: 1.5,
        motorPoles: 4,
        motorV: 220,
        motorF: 400,
        motorI: 4.0,
        motorR: 24000,
        accelSec: 2.5,
        decelSec: 2.5
      }
    }
  },

  computed: {
    arborAvailable(): boolean {
      const model = this.$store.state.machine.model as {
        plugins?: Map<string, unknown> | Record<string, { started?: boolean }>
        global?: unknown
      }
      const settingsPlugins = (this.$store.state as { settings?: { plugins?: Record<string, { started?: boolean }> } })
        .settings?.plugins
      if (
        isArborCtlPluginInstalled({
          modelPlugins: model?.plugins ?? null,
          settingsPlugins: settingsPlugins ?? null
        })
      ) {
        return true
      }
      return isArborCtlFirmwareLive(model?.global)
    },

    modelItems(): Array<{ text: string; value: number }> {
      const g = this.$store.state.machine.model.global
      const m = readFirmwareGlobal(g, 'arborAvailableModels')
      if (Array.isArray(m)) {
        return m.map((text: unknown, i: number) => ({ text: String(text), value: i }))
      }
      return FALLBACK_ARBOR_MODELS.map((text, i) => ({ text, value: i }))
    },

    channelItems(): Array<{ text: string; value: number }> {
      return ARBOR_UART_CHANNELS
    },

    baudItems(): number[] {
      return BAUD_LIST
    },

    spindleSelectItems(): Array<{ text: string; value: number }> {
      const model = this.$store.state.machine.model as {
        spindles?: Array<{ state?: string } | null>
        limits?: { spindles?: number }
      }
      const spindles = model?.spindles
      const maxS = model?.limits?.spindles ?? 8
      const items: Array<{ text: string; value: number }> = []
      for (let i = 0; i < maxS; i++) {
        const s = spindles && spindles[i]
        if (s && s.state !== 'unconfigured') {
          items.push({ text: `Spindle ${i}`, value: i })
        }
      }
      return items
    },

    hzLimits(): { t: number; e: number } {
      const model = this.$store.state.machine.model as {
        spindles?: Array<{ min?: number; max?: number } | null>
      }
      const s = model?.spindles?.[this.form.spindleId]
      const poles = Number(this.form.motorPoles) || 4
      const mf = Number(this.form.motorF) || 400
      if (!s) {
        return { t: 0, e: mf }
      }
      const minRpm = s.min != null ? Number(s.min) : 0
      const maxRpm = s.max != null ? Number(s.max) : 0
      const t = Math.min(mf, Math.ceil((minRpm / 120) * poles))
      const e = Math.min(mf, Math.ceil((maxRpm / 120) * poles))
      return { t, e }
    },

    canApply(): boolean {
      if (this.spindleSelectItems.length === 0) return false
      const hz = this.hzLimits
      return (
        this.form.address >= 1 &&
        this.form.address <= 247 &&
        this.form.motorW > 0 &&
        this.form.motorPoles > 0 &&
        this.form.motorV > 0 &&
        this.form.motorF > 0 &&
        this.form.motorI > 0 &&
        this.form.motorR > 0 &&
        this.form.accelSec > 0 &&
        this.form.decelSec > 0 &&
        Number.isFinite(hz.t) &&
        Number.isFinite(hz.e) &&
        hz.e >= hz.t &&
        isArborUartChannel(this.form.channel)
      )
    },

    commReady(): boolean | null {
      const g = this.$store.state.machine.model.global
      const comm = readFirmwareGlobal(g, 'arborVFDCommReady')
      const sid = this.form.spindleId
      if (!Array.isArray(comm) || comm[sid] == null) return null
      return comm[sid] === true
    },

    commLabel(): string {
      if (this.commReady === true) return 'OK'
      if (this.commReady === false) return 'Off'
      return '—'
    },

    commColor(): string {
      if (this.commReady === true) return 'success'
      if (this.commReady === false) return 'warning'
      return 'grey'
    },

    statusSummary(): string {
      const g = this.$store.state.machine.model.global
      const st = readFirmwareGlobal(g, 'arborVFDStatus')
      const sid = this.form.spindleId
      if (!Array.isArray(st) || st[sid] == null || !Array.isArray(st[sid])) return ''
      const row = st[sid] as unknown[]
      const rpm = row[3]
      const hz = row[2]
      const parts: string[] = []
      if (typeof hz === 'number' && Number.isFinite(hz)) parts.push(`${hz.toFixed(1)} Hz`)
      if (typeof rpm === 'number' && Number.isFinite(rpm)) parts.push(`${Math.round(rpm)} RPM`)
      return parts.join(' · ')
    }
  },

  mounted() {
    this.loadFromMachine()
  },

  methods: {
    loadFromMachine(): void {
      const g = this.$store.state.machine.model.global
      const cfg = readFirmwareGlobal(g, 'arborVFDConfig')
      const motor = readFirmwareGlobal(g, 'arborMotorSpec')
      if (Array.isArray(cfg)) {
        for (let i = 0; i < cfg.length; i++) {
          if (cfg[i] != null && Array.isArray(cfg[i])) {
            const c = cfg[i] as number[]
            this.form.typeIndex = c[0]
            this.form.channel = clampArborUartChannel(c[1])
            this.form.address = c[2]
            this.form.spindleId = i
            break
          }
        }
      }
      const sid = this.form.spindleId
      if (Array.isArray(motor) && motor[sid] != null && Array.isArray(motor[sid])) {
        const m = motor[sid] as number[]
        this.form.motorW = m[0]
        this.form.motorPoles = m[1]
        this.form.motorV = m[2]
        this.form.motorF = m[3]
        this.form.motorI = m[4]
        this.form.motorR = m[5]
      }
      const ramp = readFirmwareGlobal(g, 'arborWizardRamp')
      if (Array.isArray(ramp) && ramp[sid] != null && Array.isArray(ramp[sid]) && ramp[sid].length >= 2) {
        const r = ramp[sid] as number[]
        if (typeof r[0] === 'number' && Number.isFinite(r[0]) && r[0] > 0) {
          this.form.accelSec = r[0]
        }
        if (typeof r[1] === 'number' && Number.isFinite(r[1]) && r[1] > 0) {
          this.form.decelSec = r[1]
        }
      }
      if (this.spindleSelectItems.length > 0) {
        const ok = this.spindleSelectItems.some(
          (it: { value: number }) => it.value === this.form.spindleId
        )
        if (!ok) {
          this.form.spindleId = this.spindleSelectItems[0].value
        }
      }
    },

    async applyVfd(): Promise<void> {
      this.applyError = ''
      this.applyOk = false
      this.applying = true
      try {
        const g = this.$store.state.machine.model.global
        const models = readFirmwareGlobal(g, 'arborAvailableModels') as string[] | null
        const internals = readFirmwareGlobal(g, 'arborModelInternalNames') as string[] | null
        const typeName = arborTypeName(this.form.typeIndex, models)
        const internal = arborInternalName(this.form.typeIndex, internals)
        const hz = this.hzLimits
        const content = buildArborCtlUserVarsFile(this.form, hz, typeName)
        await uploadDwcFile(ARBORCTL_USER_VARS_PATH, content)
        await this.sendCode(`M98 P"${ARBORCTL_USER_VARS_PATH}"`)
        await this.sendCode(buildArborCtlConfigCode(this.form, hz, internal))
        this.applyOk = true
      } catch (e) {
        this.applyError = e instanceof Error ? e.message : String(e)
        console.error('[nxt VFD] Apply failed', e)
      } finally {
        this.applying = false
      }
    },

    openArborCtlPlugin(): void {
      try {
        void this.$router.push('/Plugins/ArborCTL')
      } catch (e) {
        console.error('[nxt VFD] navigate to ArborCTL failed', e)
      }
    }
  }
})
</script>
