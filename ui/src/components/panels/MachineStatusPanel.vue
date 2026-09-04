<template>
  <v-card>
    <v-card-title>
      <v-icon class="mr-2">mdi-information-outline</v-icon>
      {{ $t('plugins.nxt.panels.status.caption') }}
      <v-spacer />
      <div v-if="!isConnected || !nxtReady" class="d-flex align-center">
        <v-icon size="small" class="mr-2" color="warning">{{ !isConnected ? 'mdi-lan-disconnect' : 'mdi-alert-circle-outline' }}</v-icon>
        <span class="text-caption">{{
          !isConnected ? $t('plugins.nxt.messages.disconnectedShort') : $t('plugins.nxt.messages.notReadyShort')
        }}</span>
      </div>
    </v-card-title>

    <v-card-text>
      <v-row>
        <!-- nxt System Status -->
        <v-col cols="12" md="6">
          <v-card variant="outlined">
            <v-card-subtitle>nxt System</v-card-subtitle>
            <v-card-text>
              <v-list density="compact">
                <v-list-item>
                  <v-list-item-title>nxt loaded (firmware)</v-list-item-title>
                  <v-list-item-subtitle class="text-caption">
                    <code>global.nxtLoaded</code> true after successful boot
                  </v-list-item-subtitle>
                  <v-list-item-action>
                    <v-icon :color="nxtBackendReady ? 'success' : 'error'">
                      {{ nxtBackendReady ? 'mdi-check' : 'mdi-close' }}
                    </v-icon>
                  </v-list-item-action>
                </v-list-item>

                <v-list-item v-if="nxtErrorText">
                  <v-list-item-title class="text-error">
                    Last Error: {{ nxtErrorText }}
                  </v-list-item-title>
                </v-list-item>

                <v-list-item>
                  <v-list-item-title>Probe tool loaded (T{{ probeToolIdText }})</v-list-item-title>
                  <v-list-item-subtitle class="text-caption">
                    Current tool must match <code>global.nxtProbeToolID</code> to run probing cycles
                  </v-list-item-subtitle>
                  <v-list-item-action>
                    <v-icon :color="touchProbeToolLoaded ? 'success' : 'warning'">
                      {{ touchProbeToolLoaded ? 'mdi-check-circle' : 'mdi-close-circle-outline' }}
                    </v-icon>
                  </v-list-item-action>
                </v-list-item>
              </v-list>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- Machine Position -->
        <v-col cols="12" md="6">
          <v-card variant="outlined">
            <v-card-subtitle>Axis Positions</v-card-subtitle>
            <v-card-text>
              <v-list density="compact">
                <v-list-item
                  v-for="(axis, letter) in visibleAxesByLetter"
                  :key="letter"
                >
                  <v-list-item-title>
                    {{ letter }}: {{ formatPosition(axis.machinePosition) }}
                  </v-list-item-title>
                  <v-list-item-subtitle v-if="axis.userPosition !== axis.machinePosition">
                    Work: {{ formatPosition(axis.userPosition) }}
                  </v-list-item-subtitle>
                  <v-list-item-action>
                    <v-icon
                      :color="axis.homed ? 'success' : 'warning'"
                      size="small"
                    >
                      {{ axis.homed ? 'mdi-home' : 'mdi-home-outline' }}
                    </v-icon>
                  </v-list-item-action>
                </v-list-item>
              </v-list>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- Motor / VFD relay (gpOut P5 on Scylla PD_5) -->
        <v-col v-if="relayConfigured" cols="12" md="6">
          <v-card variant="outlined">
            <v-card-subtitle>{{ $t('plugins.nxt.panels.status.relayPower') }}</v-card-subtitle>
            <v-card-text>
              <v-list density="compact">
                <v-list-item>
                  <v-list-item-title>
                    {{ relayArmed
                      ? $t('plugins.nxt.panels.status.relayArmed')
                      : $t('plugins.nxt.panels.status.relayDisarmed') }}
                  </v-list-item-title>
                  <v-list-item-action>
                    <v-icon :color="relayArmed ? 'success' : 'error'">
                      {{ relayArmed ? 'mdi-power-plug' : 'mdi-power-plug-off' }}
                    </v-icon>
                  </v-list-item-action>
                </v-list-item>
              </v-list>
              <v-alert
                v-if="estopPressed"
                type="warning"
                density="compact"
                variant="tonal"
                class="mb-3"
              >
                {{ $t('plugins.nxt.panels.status.relayEstopPressed') }}
              </v-alert>
              <v-alert
                v-else-if="!relayArmed"
                type="info"
                density="compact"
                variant="tonal"
                class="mb-3"
              >
                {{ $t('plugins.nxt.panels.status.relayArmHint') }}
              </v-alert>
              <div class="d-flex flex-wrap ga-2">
                <v-btn
                  color="success"
                  variant="flat"
                  size="small"
                  :disabled="!isConnected || uiFrozen || relayArmed || estopPressed || relayBusy"
                  :loading="relayBusy"
                  @click="openArmConfirm"
                >
                  {{ $t('plugins.nxt.panels.status.relayArm') }}
                </v-btn>
                <v-btn
                  color="error"
                  variant="outlined"
                  size="small"
                  :disabled="!isConnected || uiFrozen || !relayArmed || relayBusy"
                  :loading="relayBusy"
                  @click="openDisarmConfirm"
                >
                  {{ $t('plugins.nxt.panels.status.relayDisarm') }}
                </v-btn>
              </div>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- Feature Status -->
        <v-col cols="12">
          <v-card variant="outlined">
            <v-card-subtitle>nxt Features</v-card-subtitle>
            <v-card-text>
              <v-row>
                <v-col cols="6" sm="4">
                  <div class="feature-status">
                    <v-icon
                      :color="globals.nxtFeatureTouchProbe ? 'success' : 'grey'"
                      class="mr-2"
                    >
                      mdi-target
                    </v-icon>
                    Touch Probe
                  </div>
                </v-col>

                <v-col cols="6" sm="4">
                  <div class="feature-status">
                    <v-icon
                      :color="globals.nxtFeatureToolSetter ? 'success' : 'grey'"
                      class="mr-2"
                    >
                      mdi-wrench
                    </v-icon>
                    Tool Setter
                  </div>
                </v-col>

                <v-col cols="6" sm="4">
                  <div class="feature-status">
                    <v-icon
                      :color="globals.nxtFeatureCoolantControl ? 'success' : 'grey'"
                      class="mr-2"
                    >
                      mdi-water
                    </v-icon>
                    Coolant Control
                  </div>
                </v-col>
                <v-col cols="6" sm="4">
                  <div class="feature-status">
                    <v-icon
                      :color="globals.nxtFeatureMachinePower ? 'success' : 'grey'"
                      class="mr-2"
                    >
                      mdi-power
                    </v-icon>
                    {{ $t('plugins.nxt.panels.status.featureMachinePower') }}
                  </div>
                </v-col>
                <v-col cols="6" sm="4" v-if="rgbHardwareConfigured">
                  <div class="feature-status">
                    <v-icon
                      :color="rgbFeatureEnabled ? 'success' : 'grey'"
                      class="mr-2"
                    >
                      mdi-lightbulb-on
                    </v-icon>
                    RGB Work Light
                  </div>
                </v-col>
              </v-row>
            </v-card-text>
          </v-card>
        </v-col>

        <v-col cols="12">
          <nxt-rgb-light-control />
        </v-col>
      </v-row>
    </v-card-text>

    <!-- Vue confirm — does not use M291/M80.9 (avoids M292 input races) -->
    <v-dialog v-model="relayConfirmOpen" max-width="480" persistent>
      <v-card>
        <v-card-title>
          {{
            relayConfirmMode === 'arm'
              ? $t('plugins.nxt.panels.status.relayConfirmArmTitle')
              : $t('plugins.nxt.panels.status.relayConfirmDisarmTitle')
          }}
        </v-card-title>
        <v-card-text>
          {{
            relayConfirmMode === 'arm'
              ? $t('plugins.nxt.panels.status.relayConfirmArmBody')
              : $t('plugins.nxt.panels.status.relayConfirmDisarmBody')
          }}
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" :disabled="relayBusy" @click="relayConfirmOpen = false">
            {{ $t('plugins.nxt.panels.status.relayConfirmCancel') }}
          </v-btn>
          <v-btn
            :color="relayConfirmMode === 'arm' ? 'success' : 'error'"
            variant="flat"
            :loading="relayBusy"
            :disabled="relayBusy"
            @click="confirmRelayAction"
          >
            {{
              relayConfirmMode === 'arm'
                ? $t('plugins.nxt.panels.status.relayConfirmArmOk')
                : $t('plugins.nxt.panels.status.relayConfirmDisarmOk')
            }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-card>
</template>

<script lang="ts">
import { defineNxtComponent } from '../base/BaseComponent.vue'
import { readFirmwareGlobal } from '../../utils/nxtToolChangerOm'
import {
  isRgbFeatureEnabled,
  isRgbLightHardwareConfigured,
  readOmLedsFromMachineModel
} from '../../utils/nxtRgbAvailability'
import store from '../../compat/dwcStore'
import RgbLightControl from './RgbLightControl.vue'

/**
 * nxt Machine Status Panel
 *
 * Machine power: Vue confirm then M42/M80 — not M80.9 (M291/M292 unreliable on SBC).
 */
export default defineNxtComponent({
  name: 'NxtMachineStatusPanel',

  components: {
    NxtRgbLightControl: RgbLightControl
  },

  data() {
    return {
      /** One-shot Vue arm dialog after nxt loads with contactor off. */
      relayArmPromptSent: false,
      relayConfirmOpen: false,
      relayConfirmMode: 'arm' as 'arm' | 'disarm',
      relayBusy: false
    }
  },

  watch: {
    nxtReady: {
      immediate: true,
      handler: 'onNxtReadyForRelayPrompt'
    },
    relayConfigured: 'onRelayConfiguredForPrompt'
  },

  computed: {
    nxtErrorText(): string {
      const e = this.globals.nxtError
      if (e == null || e === '') {
        return ''
      }
      if (typeof e === 'string') {
        return e
      }
      if (typeof e === 'number' || typeof e === 'boolean') {
        return String(e)
      }
      try {
        return JSON.stringify(e)
      } catch {
        return String(e)
      }
    },

    probeToolId(): number | null {
      const id = this.globals.nxtProbeToolID
      if (typeof id === 'number' && Number.isFinite(id)) {
        return id
      }
      return null
    },

    probeToolIdText(): string {
      return this.probeToolId === null ? 'unset' : String(this.probeToolId)
    },

    touchProbeToolLoaded(): boolean {
      if (!this.globals.nxtFeatureTouchProbe || this.probeToolId === null) {
        return false
      }
      return this.currentTool?.number === this.probeToolId
    },

    rgbHardwareConfigured(): boolean {
      const g = store.state.machine.model.global
      const boards = store.state.machine.model.boards
      const override = readFirmwareGlobal(g, 'nxtBoardShortNameOverride')
      const boardShortName =
        override != null && String(override).trim().length > 0
          ? String(override).trim()
          : Array.isArray(boards) && boards[0]?.shortName
            ? String(boards[0].shortName)
            : null
      return isRgbLightHardwareConfigured({
        leds: readOmLedsFromMachineModel(store.state.machine.model),
        boardShortName,
        rgbPin: readFirmwareGlobal(g, 'nxtRGBPin'),
        rgbReady: readFirmwareGlobal(g, 'nxtRGBReady')
      })
    },

    rgbFeatureEnabled(): boolean {
      return isRgbFeatureEnabled(store.state.machine.model.global)
    },

    relayGpOutId(): number | null {
      const id = readFirmwareGlobal(this.$store.state.machine.model.global, 'nxtRelayID')
      if (typeof id === 'number' && Number.isFinite(id) && id >= 0) {
        return id
      }
      return null
    },

    relayConfigured(): boolean {
      const feat = readFirmwareGlobal(this.$store.state.machine.model.global, 'nxtFeatureMachinePower')
      if (feat !== true && feat !== 1) {
        return false
      }
      if (this.relayGpOutId != null) {
        return true
      }
      const atx = this.$store.state.machine.model.state?.atxPowerPort
      return atx !== null && atx !== undefined
    },

    relayArmed(): boolean {
      const id = this.relayGpOutId
      if (id != null) {
        const model = this.$store.state.machine.model
        const fromState = (model.state as { gpOut?: Array<{ pwm?: number } | null> } | undefined)?.gpOut
        const fromSensors = (model.sensors as { gpOut?: Array<{ pwm?: number } | null> } | undefined)
          ?.gpOut
        const gpOut = Array.isArray(fromState) ? fromState : fromSensors
        if (Array.isArray(gpOut) && id < gpOut.length && gpOut[id] != null) {
          const pwm = gpOut[id]?.pwm
          if (typeof pwm === 'number' && pwm > 0) {
            return true
          }
        }
      }
      return this.$store.state.machine.model.state?.atxPower === true
    },

    estopPressed(): boolean {
      const gpIn = this.$store.state.machine.model.sensors?.gpIn as
        | Array<{ value?: number } | null>
        | undefined
      if (!Array.isArray(gpIn) || gpIn.length === 0) {
        return false
      }
      return gpIn[0]?.value === 1
    }
  },

  methods: {
    formatPosition(position: number | null | undefined): string {
      if (position === null || position === undefined) {
        return 'N/A'
      }
      return position.toFixed(3)
    },

    onNxtReadyForRelayPrompt(ready: boolean): void {
      if (ready) {
        void this.maybePromptRelayArm()
      }
    },

    onRelayConfiguredForPrompt(configured: boolean): void {
      if (configured) {
        void this.maybePromptRelayArm()
      }
    },

    openArmConfirm(): void {
      if (!this.relayConfigured || this.relayArmed || this.estopPressed) {
        return
      }
      this.relayConfirmMode = 'arm'
      this.relayConfirmOpen = true
    },

    openDisarmConfirm(): void {
      if (!this.relayConfigured || !this.relayArmed) {
        return
      }
      this.relayConfirmMode = 'disarm'
      this.relayConfirmOpen = true
    },

    async confirmRelayAction(): Promise<void> {
      if (this.relayBusy) {
        return
      }
      this.relayBusy = true
      try {
        if (this.relayConfirmMode === 'arm') {
          if (this.estopPressed) {
            await this.$store.dispatch('machine/showMessage', {
              type: 'warning',
              title: 'nxt',
              message: String(this.$t('plugins.nxt.panels.status.relayEstopPressed'))
            })
            return
          }
          await this.sendArmCode()
        } else {
          await this.sendDisarmCode()
        }
        this.relayConfirmOpen = false
      } catch (e: unknown) {
        console.error('nxt: relay confirm failed', e)
        await this.$store.dispatch('machine/showMessage', {
          type: 'error',
          title: 'nxt',
          message:
            this.relayConfirmMode === 'arm'
              ? String(this.$t('plugins.nxt.panels.status.relayArmFailed'))
              : String(this.$t('plugins.nxt.panels.status.relayDisarmFailed'))
        })
      } finally {
        this.relayBusy = false
      }
    },

    async sendArmCode(): Promise<void> {
      const id = this.relayGpOutId
      if (id != null) {
        await this.sendCode(`M42 P${id} S1`)
      } else {
        await this.sendCode('M80')
      }
    },

    async sendDisarmCode(): Promise<void> {
      const id = this.relayGpOutId
      if (id != null) {
        await this.sendCode(`M42 P${id} S0`)
      } else {
        await this.sendCode('M81')
      }
    },

    /**
     * After boot, open Vue arm confirm once if Machine Power is on and contactor is off.
     * Does not call M80.9 (keeps nxt.g free; avoids M291/M292).
     */
    async maybePromptRelayArm(): Promise<void> {
      if (this.relayArmPromptSent) {
        return
      }
      if (!this.isConnected || !this.nxtReady || this.uiFrozen) {
        return
      }
      if (!this.relayConfigured || this.relayArmed || this.estopPressed) {
        return
      }
      if (this.relayConfirmOpen) {
        return
      }
      this.relayArmPromptSent = true
      this.openArmConfirm()
    }
  }
})
</script>

<style scoped>
.feature-status {
  display: flex;
  align-items: center;
  font-size: 0.875rem;
  padding: 4px 0;
}

.v-card {
  height: 100%;
}

.v-list-item-title {
  font-size: 0.875rem !important;
}

.v-list-item-subtitle {
  font-size: 0.75rem !important;
}
</style>
