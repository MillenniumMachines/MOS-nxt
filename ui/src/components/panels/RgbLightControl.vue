<template>
  <v-card v-if="showCard" :outlined="!compact" :flat="compact" :class="compact ? 'pa-0' : ''">
    <v-card-subtitle v-if="!compact" class="pb-0">
      <v-icon left small>mdi-lightbulb-on</v-icon>
      {{ $t('plugins.nxt.panels.rgbLight.caption') }}
    </v-card-subtitle>
    <v-card-text :class="compact ? 'pa-2' : 'pt-2'">
      <v-alert v-if="!featureEnabled" type="info" dense outlined class="mb-3">
        {{ $t('plugins.nxt.panels.rgbLight.enableInConfiguration') }}
      </v-alert>
      <template v-else>
        <v-row dense align="center">
          <v-col cols="12" :sm="compact ? 12 : 6">
            <v-switch
              :input-value="rgbState.on"
              :label="$t('plugins.nxt.panels.rgbLight.power')"
              :disabled="controlsDisabled"
              hide-details
              class="mt-0"
              @change="onPowerChange"
            />
          </v-col>
          <v-col cols="12" :sm="compact ? 12 : 6">
            <v-slider
              :value="rgbState.brightness"
              :label="$t('plugins.nxt.panels.rgbLight.brightness')"
              min="0"
              max="100"
              step="1"
              thumb-label
              :disabled="controlsDisabled || !rgbState.on"
              hide-details
              @input="onBrightnessChange"
            />
          </v-col>
        </v-row>
        <v-row dense>
          <v-col cols="12" md="6">
            <v-color-picker
              v-model="pickerColor"
              hide-inputs
              hide-canvas
              show-swatches
              swatches-max-height="120"
              :disabled="controlsDisabled || !rgbState.on"
              class="mx-auto"
              @input="onPickerInput"
            />
          </v-col>
          <v-col cols="12" md="6" class="d-flex flex-wrap align-start">
            <v-btn
              v-for="preset in presets"
              :key="preset.key"
              x-small
              outlined
              class="ma-1"
              :disabled="controlsDisabled"
              @click="applyPreset(preset)"
            >
              {{ preset.label }}
            </v-btn>
            <v-btn
              small
              color="primary"
              class="ma-1"
              :disabled="controlsDisabled"
              :loading="saving"
              @click="saveRgbSettings"
            >
              {{ $t('plugins.nxt.panels.rgbLight.save') }}
            </v-btn>
          </v-col>
        </v-row>
      </template>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
// @ts-nocheck — Vue 2 + BaseComponent.extend(): tsc does not merge computeds onto `this`.
import BaseComponent from '../base/BaseComponent.vue'
import store from '@/store'
import { PluginDataType, setPluginData } from '@/store'
import {
  buildM6524Command,
  clampByte,
  NXT_RGB_UI_DEFAULT,
  type NxtRgbUiState
} from '../../utils/nxtRgbControl'
import { isRgbLightHardwareConfigured, readOmLedsFromMachineModel } from '../../utils/nxtRgbAvailability'

type RgbPreset = { key: string; label: string; r: number; g: number; b: number }

const PLUGIN = 'nxt'
const RGB_STATE_KEY = 'nxtRgbUiState'

export default BaseComponent.extend({
  name: 'NxtRgbLightControl',

  props: {
    compact: {
      type: Boolean,
      default: false
    }
  },

  data() {
    return {
      pickerColor: '#ffffff',
      sending: false,
      saving: false
    }
  },

  computed: {
    rgbHardwareConfigured(): boolean {
      return isRgbLightHardwareConfigured({
        leds: readOmLedsFromMachineModel(store.state.machine.model),
        boardShortName: this.boardShortNameForRgb
      })
    },

    boardShortNameForRgb(): string | null {
      const g = this.configDraftBoardShortName
      if (g != null && String(g).trim().length > 0) {
        return String(g).trim()
      }
      const boards = store.state.machine.model.boards
      if (Array.isArray(boards) && boards[0]?.shortName) {
        return String(boards[0].shortName)
      }
      return null
    },

    configDraftBoardShortName(): string | null {
      const override = this.globals.nxtBoardShortNameOverride
      if (override != null && String(override).trim().length > 0) {
        return String(override).trim()
      }
      return null
    },

    showCard(): boolean {
      return this.rgbHardwareConfigured
    },

    featureEnabled(): boolean {
      return this.globals.nxtFeatureRgbLight === true || this.globals.nxtFeatureRgbLight === 1
    },

    controlsDisabled(): boolean {
      return !this.isConnected || !this.nxtReady || this.uiFrozen || this.sending || this.saving
    },

    rgbState(): NxtRgbUiState {
      const plugins = store.state.settings?.plugins
      const raw = plugins?.[PLUGIN]?.[RGB_STATE_KEY]
      if (raw != null && typeof raw === 'object') {
        return {
          r: clampByte(Number((raw as NxtRgbUiState).r)),
          g: clampByte(Number((raw as NxtRgbUiState).g)),
          b: clampByte(Number((raw as NxtRgbUiState).b)),
          brightness: Number((raw as NxtRgbUiState).brightness) || 0,
          on: (raw as NxtRgbUiState).on !== false
        }
      }
      return { ...NXT_RGB_UI_DEFAULT }
    },

    presets(): RgbPreset[] {
      const t = (key: string, fallback: string) => {
        const v = (this as any).$t(key).toString()
        return v === key ? fallback : v
      }
      return [
        { key: 'white', label: t('plugins.nxt.panels.rgbLight.presetWhite', 'White'), r: 255, g: 255, b: 255 },
        { key: 'warm', label: t('plugins.nxt.panels.rgbLight.presetWarm', 'Warm'), r: 255, g: 180, b: 80 },
        { key: 'red', label: t('plugins.nxt.panels.rgbLight.presetRed', 'Red'), r: 255, g: 0, b: 0 },
        { key: 'off', label: t('plugins.nxt.panels.rgbLight.presetOff', 'Off'), r: 0, g: 0, b: 0 }
      ]
    }
  },

  watch: {
    rgbState: {
      immediate: true,
      handler(state: NxtRgbUiState) {
        this.pickerColor = this.rgbToHex(state.r, state.g, state.b)
      }
    }
  },

  methods: {
    rgbToHex(r: number, g: number, b: number): string {
      const h = (n: number) => clampByte(n).toString(16).padStart(2, '0')
      return `#${h(r)}${h(g)}${h(b)}`
    },

    hexToRgb(hex: string): { r: number; g: number; b: number } | null {
      const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex)
      if (!m) {
        return null
      }
      return {
        r: parseInt(m[1], 16),
        g: parseInt(m[2], 16),
        b: parseInt(m[3], 16)
      }
    },

    commitRgbState(next: NxtRgbUiState) {
      setPluginData(PLUGIN, PluginDataType.globalSetting, RGB_STATE_KEY, { ...next })
    },

    async applyState(next: NxtRgbUiState) {
      this.commitRgbState(next)
      if (!this.featureEnabled || this.controlsDisabled) {
        return
      }
      this.sending = true
      try {
        await this.sendCode(buildM6524Command(next))
      } catch (e) {
        console.error('nxt RGB: failed to send M6524', e)
      } finally {
        this.sending = false
      }
    },

    onPowerChange(on: boolean) {
      this.applyState({ ...this.rgbState, on })
    },

    onBrightnessChange(brightness: number) {
      this.applyState({ ...this.rgbState, brightness, on: true })
    },

    onPickerInput(hex: string) {
      const rgb = this.hexToRgb(hex)
      if (rgb == null) {
        return
      }
      this.applyState({ ...this.rgbState, ...rgb, on: true })
    },

    applyPreset(preset: RgbPreset) {
      if (preset.key === 'off') {
        this.applyState({ ...this.rgbState, r: 0, g: 0, b: 0, on: false })
        return
      }
      this.applyState({
        ...this.rgbState,
        r: preset.r,
        g: preset.g,
        b: preset.b,
        on: true
      })
    },

    async saveRgbSettings() {
      if (!this.featureEnabled || this.controlsDisabled) {
        return
      }
      this.saving = true
      try {
        await this.sendCode('M98 P"nxt/nxt-save-rgb.g"')
      } catch (e) {
        console.error('nxt RGB: failed to save settings', e)
      } finally {
        this.saving = false
      }
    }
  }
})
</script>

<style scoped>
.v-color-picker {
  max-width: 100%;
}
</style>
