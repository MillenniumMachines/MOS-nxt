<template>
  <v-card
    v-if="showCard"
    :variant="compact ? 'flat' : 'outlined'"
    :class="compact ? 'pa-0' : 'mt-2'"
  >
    <v-card-subtitle v-if="!compact" class="pb-0">
      <v-icon class="mr-2" size="small">mdi-lightbulb-on</v-icon>
      {{ $t('plugins.nxt.panels.rgbLight.caption') }}
    </v-card-subtitle>
    <v-card-text :class="compact ? 'pa-2' : 'pt-2'">
      <v-alert
        v-if="!rgbHardwareConfigured"
        type="warning"
        density="compact"
        variant="outlined"
        class="mb-3"
      >
        {{ $t('plugins.nxt.panels.rgbLight.hardwareMissing') }}
      </v-alert>
      <v-alert v-if="!featureEnabled" type="info" density="compact" variant="outlined" class="mb-3">
        {{ $t('plugins.nxt.panels.rgbLight.enableInConfiguration') }}
      </v-alert>
      <template v-if="featureEnabled">
        <!-- Live light -->
        <v-row density="compact" align="center">
          <v-col cols="12" :sm="compact ? 12 : 6">
            <v-switch
              :model-value="rgbState.on"
              :label="$t('plugins.nxt.panels.rgbLight.power')"
              :disabled="controlsDisabled"
              hide-details
              class="mt-0"
              @update:model-value="onPowerChange"
            />
          </v-col>
          <v-col cols="12" :sm="compact ? 12 : 6">
            <v-slider
              :model-value="rgbState.brightness"
              :label="$t('plugins.nxt.panels.rgbLight.brightness')"
              min="0"
              max="100"
              step="1"
              thumb-label
              :disabled="controlsDisabled || !rgbState.on"
              hide-details
              @update:model-value="onBrightnessChange"
            />
          </v-col>
        </v-row>

        <v-row density="compact">
          <v-col cols="12" :md="compact ? 12 : 5">
            <v-color-picker
              v-model="pickerColor"
              :hide-inputs="compact"
              :hide-canvas="compact"
              show-swatches
              swatches-max-height="120"
              :disabled="controlsDisabled || !rgbState.on"
              class="mx-auto nxt-rgb-picker"
              @update:model-value="onPickerInput"
            />
          </v-col>
          <v-col cols="12" :md="compact ? 12 : 7">
            <template v-if="!compact">
              <v-row density="compact" class="mb-2">
                <v-col cols="12" sm="4">
                  <v-text-field
                    v-model="hexDraft"
                    :label="$t('plugins.nxt.panels.rgbLight.hex')"
                    density="compact"
                    variant="outlined"
                    hide-details
                    :disabled="controlsDisabled || !rgbState.on"
                    @change="onHexCommit"
                    @keyup.enter="onHexCommit"
                  />
                </v-col>
                <v-col cols="4" sm="2">
                  <v-text-field
                    v-model.number="channelDraft.r"
                    :label="$t('plugins.nxt.panels.rgbLight.channelR')"
                    type="number"
                    min="0"
                    max="255"
                    step="1"
                    density="compact"
                    variant="outlined"
                    hide-details
                    :disabled="controlsDisabled || !rgbState.on"
                    @change="onChannelCommit"
                  />
                </v-col>
                <v-col cols="4" sm="2">
                  <v-text-field
                    v-model.number="channelDraft.g"
                    :label="$t('plugins.nxt.panels.rgbLight.channelG')"
                    type="number"
                    min="0"
                    max="255"
                    step="1"
                    density="compact"
                    variant="outlined"
                    hide-details
                    :disabled="controlsDisabled || !rgbState.on"
                    @change="onChannelCommit"
                  />
                </v-col>
                <v-col cols="4" sm="2">
                  <v-text-field
                    v-model.number="channelDraft.b"
                    :label="$t('plugins.nxt.panels.rgbLight.channelB')"
                    type="number"
                    min="0"
                    max="255"
                    step="1"
                    density="compact"
                    variant="outlined"
                    hide-details
                    :disabled="controlsDisabled || !rgbState.on"
                    @change="onChannelCommit"
                  />
                </v-col>
              </v-row>
            </template>
            <div class="d-flex flex-wrap align-start">
              <v-btn
                v-for="preset in presets"
                :key="preset.key"
                size="x-small"
                variant="outlined"
                class="ma-1"
                :disabled="controlsDisabled"
                @click="applyPreset(preset)"
              >
                {{ preset.label }}
              </v-btn>
            </div>
          </v-col>
        </v-row>

        <!-- Status colors (Status tab only) -->
        <template v-if="!compact">
          <v-divider class="my-4" />
          <div class="text-subtitle-2 mb-1">{{ $t('plugins.nxt.panels.rgbLight.statusColors') }}</div>
          <p class="text-caption text-grey mb-3">{{ $t('plugins.nxt.panels.rgbLight.statusColorsHint') }}</p>

          <v-row
            v-for="row in statusRows"
            :key="row.id"
            density="compact"
            align="center"
            class="mb-1"
          >
            <v-col cols="12" sm="3" class="d-flex align-center">
              <span
                class="nxt-rgb-swatch mr-2"
                :style="{ backgroundColor: rgbToHex(row.color.r, row.color.g, row.color.b) }"
              />
              <span class="text-body-2">{{ row.label }}</span>
            </v-col>
            <v-col cols="6" sm="2">
              <v-text-field
                :model-value="row.hex"
                :label="$t('plugins.nxt.panels.rgbLight.hex')"
                density="compact"
                variant="outlined"
                hide-details
                :disabled="controlsDisabled"
                @update:model-value="onStatusHexDraft(row.id, $event)"
                @change="commitStatusHex(row.id)"
              />
            </v-col>
            <v-col cols="2" sm="1">
              <v-text-field
                :model-value="row.color.r"
                :label="$t('plugins.nxt.panels.rgbLight.channelR')"
                type="number"
                min="0"
                max="255"
                density="compact"
                variant="outlined"
                hide-details
                :disabled="controlsDisabled"
                @update:model-value="onStatusChannel(row.id, 'r', $event)"
              />
            </v-col>
            <v-col cols="2" sm="1">
              <v-text-field
                :model-value="row.color.g"
                :label="$t('plugins.nxt.panels.rgbLight.channelG')"
                type="number"
                min="0"
                max="255"
                density="compact"
                variant="outlined"
                hide-details
                :disabled="controlsDisabled"
                @update:model-value="onStatusChannel(row.id, 'g', $event)"
              />
            </v-col>
            <v-col cols="2" sm="1">
              <v-text-field
                :model-value="row.color.b"
                :label="$t('plugins.nxt.panels.rgbLight.channelB')"
                type="number"
                min="0"
                max="255"
                density="compact"
                variant="outlined"
                hide-details
                :disabled="controlsDisabled"
                @update:model-value="onStatusChannel(row.id, 'b', $event)"
              />
            </v-col>
            <v-col cols="12" sm="4" class="d-flex flex-wrap">
              <v-btn
                size="x-small"
                variant="tonal"
                class="ma-1"
                :disabled="controlsDisabled"
                :loading="testingId === row.id"
                @click="testStatus(row.id)"
              >
                {{ $t('plugins.nxt.panels.rgbLight.test') }}
              </v-btn>
              <v-btn
                size="x-small"
                variant="outlined"
                class="ma-1"
                :disabled="controlsDisabled"
                @click="applyStatusToMachine(row.id)"
              >
                {{ $t('plugins.nxt.panels.rgbLight.apply') }}
              </v-btn>
            </v-col>
          </v-row>

          <div class="d-flex flex-wrap align-center mt-3 ga-1">
            <v-btn
              size="small"
              variant="outlined"
              :disabled="controlsDisabled"
              @click="clearRgbTest"
            >
              {{ $t('plugins.nxt.panels.rgbLight.clearTest') }}
            </v-btn>
            <v-btn
              size="small"
              variant="outlined"
              :disabled="controlsDisabled"
              @click="resetStatusDefaults"
            >
              {{ $t('plugins.nxt.panels.rgbLight.resetDefaults') }}
            </v-btn>
            <v-btn
              size="small"
              color="primary"
              :disabled="controlsDisabled"
              :loading="saving"
              @click="saveRgbSettings"
            >
              {{ $t('plugins.nxt.panels.rgbLight.save') }}
            </v-btn>
            <v-chip v-if="activeTest" size="small" color="warning" class="ml-2" label>
              {{ $t('plugins.nxt.panels.rgbLight.testActive', [activeTest]) }}
            </v-chip>
          </div>
        </template>

        <template v-else>
          <v-btn
            size="small"
            color="primary"
            class="ma-1"
            :disabled="controlsDisabled"
            :loading="saving"
            @click="saveRgbSettings"
          >
            {{ $t('plugins.nxt.panels.rgbLight.save') }}
          </v-btn>
        </template>
      </template>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
// @ts-nocheck — Vue 2 + BaseComponent.extend(): tsc does not merge computeds onto `this`.
import { defineNxtComponent } from '../base/BaseComponent.vue'
import store from '../../compat/dwcStore'
import { PluginDataType, setPluginData } from '../../compat/dwcStore'
import { readFirmwareGlobal } from '../../utils/nxtToolChangerOm'
import {
  buildRgbManualM150Command,
  clampByte,
  forceRgbRepaintCommand,
  formatRgbTestCommand,
  formatRgbwSetCommand,
  hexToRgb,
  NXT_RGB_STATUS_DEFAULTS,
  NXT_RGB_STATUS_DEFS,
  NXT_RGB_UI_DEFAULT,
  parseRgbwVector,
  rgbToHex,
  type NxtRgbStatusId,
  type NxtRgbUiState,
  type NxtRgbw
} from '../../utils/nxtRgbControl'
import {
  isRgbFeatureEnabled,
  isRgbLightHardwareConfigured,
  readOmLedsFromMachineModel
} from '../../utils/nxtRgbAvailability'

type RgbPreset = { key: string; label: string; r: number; g: number; b: number }

const PLUGIN = 'nxt'
const RGB_STATE_KEY = 'nxtRgbUiState'

function emptyStatusMap(): Record<NxtRgbStatusId, NxtRgbw> {
  const out = {} as Record<NxtRgbStatusId, NxtRgbw>
  for (const def of NXT_RGB_STATUS_DEFS) {
    out[def.id] = { ...NXT_RGB_STATUS_DEFAULTS[def.id] }
  }
  return out
}

export default defineNxtComponent({
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
      hexDraft: '#ffffff',
      channelDraft: { r: 255, g: 255, b: 255 },
      statusColors: emptyStatusMap() as Record<NxtRgbStatusId, NxtRgbw>,
      statusHexDraft: {} as Record<NxtRgbStatusId, string>,
      sending: false,
      saving: false,
      testingId: null as NxtRgbStatusId | null,
      statusLoaded: false
    }
  },

  computed: {
    rgbHardwareConfigured(): boolean {
      const g = store.state.machine.model.global
      return isRgbLightHardwareConfigured({
        leds: readOmLedsFromMachineModel(store.state.machine.model),
        boardShortName: this.boardShortNameForRgb,
        rgbPin: readFirmwareGlobal(g, 'nxtRGBPin'),
        rgbReady: readFirmwareGlobal(g, 'nxtRGBReady')
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
      const override = readFirmwareGlobal(
        store.state.machine.model.global,
        'nxtBoardShortNameOverride'
      )
      if (override != null && String(override).trim().length > 0) {
        return String(override).trim()
      }
      return null
    },

    showCard(): boolean {
      // Status tab: always show the RGB subsection so status colors are editable.
      // Compact CNC strip: hardware present or feature already enabled.
      if (!this.compact) {
        return true
      }
      return this.rgbHardwareConfigured || this.featureEnabled
    },

    featureEnabled(): boolean {
      return isRgbFeatureEnabled(store.state.machine.model.global)
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
    },

    statusRows(): Array<{
      id: NxtRgbStatusId
      label: string
      color: NxtRgbw
      hex: string
    }> {
      return NXT_RGB_STATUS_DEFS.map((def: (typeof NXT_RGB_STATUS_DEFS)[number]) => {
        const color = this.statusColors[def.id] ?? NXT_RGB_STATUS_DEFAULTS[def.id]
        const hex =
          this.statusHexDraft[def.id] ?? rgbToHex(color.r, color.g, color.b)
        return {
          id: def.id,
          label: this.$t(`plugins.nxt.panels.rgbLight.${def.labelKey}`).toString(),
          color,
          hex
        }
      })
    },

    activeTest(): string {
      const v = readFirmwareGlobal(store.state.machine.model.global, 'nxtRGBTest')
      if (v == null || v === '') {
        return ''
      }
      return String(v)
    }
  },

  watch: {
    rgbState: {
      immediate: true,
      handler(state: NxtRgbUiState) {
        const hex = rgbToHex(state.r, state.g, state.b)
        this.pickerColor = hex
        this.hexDraft = hex
        this.channelDraft = { r: state.r, g: state.g, b: state.b }
      }
    },
    featureEnabled: {
      immediate: true,
      handler(on: boolean) {
        if (on && !this.compact) {
          this.loadStatusColorsFromOm()
        }
      }
    },
    isConnected: {
      handler(c: boolean) {
        if (c && this.featureEnabled && !this.compact) {
          this.loadStatusColorsFromOm()
        }
      }
    }
  },

  methods: {
    rgbToHex,

    loadStatusColorsFromOm() {
      const g = store.state.machine?.model?.global
      const next = emptyStatusMap()
      const hexDraft = {} as Record<NxtRgbStatusId, string>
      const rawCol = readFirmwareGlobal(g, 'nxtRGBCol')
      let cols: unknown[] | null = null
      if (Array.isArray(rawCol)) {
        cols = rawCol
      } else if (rawCol instanceof Map) {
        cols = Array.from(rawCol.values())
      }
      for (const def of NXT_RGB_STATUS_DEFS) {
        const fallback = NXT_RGB_STATUS_DEFAULTS[def.id]
        const slot = cols != null && def.colIndex < cols.length ? cols[def.colIndex] : null
        const c = parseRgbwVector(slot, fallback)
        next[def.id] = c
        hexDraft[def.id] = rgbToHex(c.r, c.g, c.b)
      }
      this.statusColors = next
      this.statusHexDraft = hexDraft
      this.statusLoaded = true
    },

    commitRgbState(next: NxtRgbUiState) {
      setPluginData(PLUGIN, PluginDataType.globalSetting, RGB_STATE_KEY, { ...next })
    },

    async applyState(next: NxtRgbUiState) {
      this.commitRgbState(next)
      if (!this.featureEnabled || !this.isConnected || !this.nxtReady || this.uiFrozen) {
        return
      }
      this.sending = true
      try {
        const g = store.state.machine.model.global
        const stripRaw = readFirmwareGlobal(g, 'nxtRGBStrip')
        const countRaw = readFirmwareGlobal(g, 'nxtRGBCount')
        const strip = typeof stripRaw === 'number' ? stripRaw : Number(stripRaw)
        const count = typeof countRaw === 'number' ? countRaw : Number(countRaw)
        // Direct M150 (U=green). Do not send M6524 … G… — RRF parses Gnnn as a G-code.
        await this.sendCode(
          buildRgbManualM150Command(next, {
            strip: Number.isFinite(strip) ? strip : 0,
            count: Number.isFinite(count) && count > 0 ? count : 1
          })
        )
      } catch (e) {
        console.error('nxt RGB: failed to send M150', e)
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
      const rgb = hexToRgb(typeof hex === 'string' ? hex : String(hex))
      if (rgb == null) {
        return
      }
      this.hexDraft = rgbToHex(rgb.r, rgb.g, rgb.b)
      this.channelDraft = { ...rgb }
      this.applyState({ ...this.rgbState, ...rgb, on: true })
    },

    onHexCommit() {
      const rgb = hexToRgb(this.hexDraft)
      if (rgb == null) {
        this.hexDraft = rgbToHex(this.rgbState.r, this.rgbState.g, this.rgbState.b)
        return
      }
      this.applyState({ ...this.rgbState, ...rgb, on: true })
    },

    onChannelCommit() {
      const r = clampByte(Number(this.channelDraft.r))
      const g = clampByte(Number(this.channelDraft.g))
      const b = clampByte(Number(this.channelDraft.b))
      this.channelDraft = { r, g, b }
      this.applyState({ ...this.rgbState, r, g, b, on: true })
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

    onStatusHexDraft(id: NxtRgbStatusId, v: string) {
      this.statusHexDraft = { ...this.statusHexDraft, [id]: v }
    },

    commitStatusHex(id: NxtRgbStatusId) {
      const rgb = hexToRgb(this.statusHexDraft[id] ?? '')
      if (rgb == null) {
        const c = this.statusColors[id]
        this.statusHexDraft = {
          ...this.statusHexDraft,
          [id]: rgbToHex(c.r, c.g, c.b)
        }
        return
      }
      this.patchStatusColor(id, { ...this.statusColors[id], ...rgb })
    },

    onStatusChannel(id: NxtRgbStatusId, ch: 'r' | 'g' | 'b', v: string | number) {
      const n = clampByte(Number(v))
      const prev = this.statusColors[id]
      this.patchStatusColor(id, { ...prev, [ch]: n })
    },

    patchStatusColor(id: NxtRgbStatusId, color: NxtRgbw) {
      this.statusColors = { ...this.statusColors, [id]: color }
      this.statusHexDraft = {
        ...this.statusHexDraft,
        [id]: rgbToHex(color.r, color.g, color.b)
      }
    },

    async applyStatusToMachine(id: NxtRgbStatusId) {
      if (this.controlsDisabled) {
        return
      }
      const def = NXT_RGB_STATUS_DEFS.find((d: (typeof NXT_RGB_STATUS_DEFS)[number]) => d.id === id)
      if (!def) {
        return
      }
      const c = this.statusColors[id]
      this.sending = true
      try {
        await this.sendCode(formatRgbwSetCommand(def.colIndex, c))
        await this.sendCode(forceRgbRepaintCommand())
      } catch (e) {
        console.error('nxt RGB: failed to apply status color', e)
      } finally {
        this.sending = false
      }
    },

    async pushAllStatusColors() {
      for (const def of NXT_RGB_STATUS_DEFS) {
        await this.sendCode(formatRgbwSetCommand(def.colIndex, this.statusColors[def.id]))
      }
      await this.sendCode(forceRgbRepaintCommand())
    },

    async testStatus(id: NxtRgbStatusId) {
      if (this.controlsDisabled) {
        return
      }
      this.testingId = id
      try {
        await this.applyStatusToMachine(id)
        await this.sendCode(formatRgbTestCommand(id))
        await this.sendCode(forceRgbRepaintCommand())
      } catch (e) {
        console.error('nxt RGB: test failed', e)
      } finally {
        this.testingId = null
      }
    },

    async clearRgbTest() {
      if (this.controlsDisabled) {
        return
      }
      this.sending = true
      try {
        await this.sendCode(formatRgbTestCommand(''))
        await this.sendCode(forceRgbRepaintCommand())
      } catch (e) {
        console.error('nxt RGB: clear test failed', e)
      } finally {
        this.sending = false
      }
    },

    async resetStatusDefaults() {
      if (this.controlsDisabled) {
        return
      }
      this.statusColors = emptyStatusMap()
      const hexDraft = {} as Record<NxtRgbStatusId, string>
      for (const def of NXT_RGB_STATUS_DEFS) {
        const c = NXT_RGB_STATUS_DEFAULTS[def.id]
        hexDraft[def.id] = rgbToHex(c.r, c.g, c.b)
      }
      this.statusHexDraft = hexDraft
      this.sending = true
      try {
        await this.pushAllStatusColors()
      } catch (e) {
        console.error('nxt RGB: reset defaults failed', e)
      } finally {
        this.sending = false
      }
    },

    async saveRgbSettings() {
      if (!this.featureEnabled || this.controlsDisabled) {
        return
      }
      this.saving = true
      try {
        if (!this.compact) {
          await this.pushAllStatusColors()
        }
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
.nxt-rgb-picker {
  max-width: 100%;
}
.nxt-rgb-swatch {
  display: inline-block;
  width: 18px;
  height: 18px;
  border-radius: 3px;
  border: 1px solid rgba(0, 0, 0, 0.35);
  flex-shrink: 0;
}
</style>
