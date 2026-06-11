<template>
  <v-container fluid class="nxt-tool-management nxt-tc pa-2">
    <v-card outlined>
      <v-card-title class="subtitle-1 d-flex flex-wrap align-center py-3">
        <v-icon left class="mr-2">mdi-bookshelf</v-icon>
        <span>{{ $t('plugins.nxt.panels.toolManagement.caption') }}</span>
        <v-spacer />
        <v-btn
          v-if="isConnected && nxtReady"
          class="mr-2"
          small
          outlined
          color="primary"
          :loading="persistingTools"
          :disabled="uiFrozen || persistingTools"
          @click="saveToolLibraryToBoard"
        >
          {{ $t('plugins.nxt.panels.toolManagement.saveToBoard') }}
        </v-btn>
        <v-btn
          v-if="isConnected && nxtReady"
          small
          outlined
          :disabled="uiFrozen || persistingTools"
          @click="reloadToolLibraryFromSd"
        >
          {{ $t('plugins.nxt.panels.toolManagement.reloadFromSd') }}
        </v-btn>
        <div v-if="!isConnected || !nxtReady" class="d-flex align-center">
          <v-icon small class="mr-2" color="warning">{{ !isConnected ? 'mdi-lan-disconnect' : 'mdi-alert-circle-outline' }}</v-icon>
          <span class="text-caption">{{
            !isConnected ? $t('plugins.nxt.messages.disconnectedShort') : $t('plugins.nxt.messages.notReadyShort')
          }}</span>
        </div>
      </v-card-title>
      <v-divider />
      <v-card-text class="pa-3">
        <p class="body-2 grey--text text--darken-1 mb-3">
          {{ $t('plugins.nxt.panels.toolManagement.libraryIntro') }}
        </p>
        <p class="body-2 grey--text text--darken-1 mb-3">
          {{ $t('plugins.nxt.panels.toolManagement.persistenceHint') }}
        </p>
        <v-simple-table dense class="nxt-tc-tool-lib-table">
          <template #default>
            <thead>
              <tr>
                <th class="text-left">{{ $t('plugins.nxt.panels.toolManagement.colToolNumber') }}</th>
                <th class="text-left">{{ $t('plugins.nxt.panels.toolManagement.colDescription') }}</th>
                <th class="text-left">{{ $t('plugins.nxt.panels.toolManagement.colRadius') }}</th>
                <th class="text-left">{{ $t('plugins.nxt.panels.toolManagement.colFlutes') }}</th>
                <th class="text-left">{{ $t('plugins.nxt.panels.toolManagement.colFluteLength') }}</th>
                <th class="text-left">{{ $t('plugins.nxt.panels.toolManagement.colStatus') }}</th>
                <th class="text-left">{{ $t('plugins.nxt.panels.toolManagement.colLife') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in toolLibraryRows"
                :key="'tl' + row.index"
                :class="{ 'nxt-tc-row-spindle': row.inSpindle }"
              >
                <td class="text-no-wrap">T{{ row.index }}</td>
                <td>{{ row.description }}</td>
                <td>{{ row.radiusLabel }}</td>
                <td>{{ row.flutesLabel }}</td>
                <td>{{ row.fluteLengthLabel }}</td>
                <td>
                  <v-chip
                    v-if="row.statusKind === 'spindle'"
                    x-small
                    color="success"
                    text-color="white"
                    label
                  >
                    {{ $t('plugins.nxt.panels.toolManagement.statusInSpindle') }}
                  </v-chip>
                  <v-chip
                    v-else-if="row.statusKind === 'probe'"
                    x-small
                    color="deep-purple"
                    text-color="white"
                    label
                  >
                    {{ $t('plugins.nxt.panels.toolManagement.statusProbe') }}
                  </v-chip>
                  <v-chip v-else x-small outlined label>
                    {{ $t('plugins.nxt.panels.toolManagement.statusManual') }}
                  </v-chip>
                </td>
                <td class="grey--text">—</td>
              </tr>
            </tbody>
          </template>
        </v-simple-table>
        <p v-if="toolLibraryRows.length === 0" class="body-2 grey--text mb-0">
          {{ $t('plugins.nxt.panels.toolManagement.noTools') }}
        </p>
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script lang="ts">
// @ts-nocheck — Vue 2 + BaseComponent.extend(): tsc does not merge computeds onto `this`.
import BaseComponent from '../base/BaseComponent.vue'
import store from '@/store'
import {
  readFirmwareGlobal,
  NxtToolChangerOmKeys,
  augmentRrfToolForNxtUi
} from '../../utils/nxtToolChangerOm'
import {
  isNxtToolSlotConfiguredInLibrary,
  isToolRecord,
  buildNxtUserToolsGContent
} from '../../utils/nxtUserToolsFile'
import { uploadDwcFile, NXT_USER_TOOLS_DWC_PATH } from '../../utils/nxtFileUpload'

function machineModel(): Record<string, any> {
  const m = store.state.machine?.model
  return m != null && typeof m === 'object' ? (m as Record<string, any>) : {}
}

export default BaseComponent.extend({
  name: 'NxtToolManagementPanel',

  data() {
    return {
      persistingTools: false
    }
  },

  computed: {
    firmwareGlobals() {
      const g = machineModel().global
      return g != null && typeof g === 'object' ? g : {}
    },

    rrfState() {
      const st = machineModel().state
      return st != null && typeof st === 'object' ? st : {}
    },

    currentToolIndex() {
      const t = this.rrfState.currentTool
      return typeof t === 'number' && t >= 0 ? t : -1
    },

    probeToolIndexForLibrary() {
      const g = this.firmwareGlobals
      const probeTool = readFirmwareGlobal(g, 'nxtProbeToolID')
      if (typeof probeTool === 'number' && probeTool >= 0) {
        return probeTool
      }
      const id = readFirmwareGlobal(g, NxtToolChangerOmKeys.legacyProbeToolIdKey)
      return typeof id === 'number' && id >= 0 ? id : -1
    },

    toolLibraryRows() {
      const tools = machineModel().tools
      if (!Array.isArray(tools)) {
        return []
      }
      const ct = this.currentToolIndex
      const probeIdx = this.probeToolIndexForLibrary
      const rows = []
      for (let i = 0; i < tools.length; i++) {
        const t = tools[i]
        if (t == null) {
          continue
        }
        const inSpindle = i === ct
        const isProbeSlot = probeIdx >= 0 && i === probeIdx
        if (!inSpindle && !isProbeSlot && !isNxtToolSlotConfiguredInLibrary(t)) {
          continue
        }
        const isProbe = isProbeSlot || this.probeNameMatch(t)
        const augmented = augmentRrfToolForNxtUi(t, this.firmwareGlobals, i)
        const radiusLabel =
          augmented.nxtRadiusMm != null ? String(augmented.nxtRadiusMm) : '—'
        const flutesLabel =
          augmented.nxtFluteCount != null ? String(augmented.nxtFluteCount) : '—'
        const fluteLengthLabel =
          augmented.nxtFluteLengthMm != null ? String(augmented.nxtFluteLengthMm) : '—'
        const description =
          typeof augmented.name === 'string' && augmented.name.length > 0 ? augmented.name : '—'
        let statusKind = 'manual'
        if (inSpindle) {
          statusKind = 'spindle'
        } else if (isProbe) {
          statusKind = 'probe'
        }
        rows.push({
          index: i,
          description,
          radiusLabel,
          flutesLabel,
          fluteLengthLabel,
          inSpindle,
          statusKind
        })
      }
      if (
        ct >= 0 &&
        ct < tools.length &&
        !rows.some((r) => r.index === ct) &&
        isToolRecord(tools[ct])
      ) {
        const t = tools[ct]
        const augmented = augmentRrfToolForNxtUi(t, this.firmwareGlobals, ct)
        rows.push({
          index: ct,
          description:
            typeof augmented.name === 'string' && augmented.name.length > 0 ? augmented.name : '—',
          radiusLabel:
            augmented.nxtRadiusMm != null ? String(augmented.nxtRadiusMm) : '—',
          flutesLabel:
            augmented.nxtFluteCount != null ? String(augmented.nxtFluteCount) : '—',
          fluteLengthLabel:
            augmented.nxtFluteLengthMm != null ? String(augmented.nxtFluteLengthMm) : '—',
          inSpindle: true,
          statusKind: 'spindle'
        })
      }
      rows.sort((a, b) => a.index - b.index)
      return rows
    }
  },

  methods: {
    probeNameMatch(toolObj) {
      if (!toolObj || !toolObj.name) {
        return false
      }
      return String(toolObj.name).toLowerCase().includes('touch probe')
    },

    async saveToolLibraryToBoard() {
      if (!this.isConnected || !this.nxtReady) {
        return
      }
      this.persistingTools = true
      try {
        const m = machineModel()
        const tools = Array.isArray(m.tools) ? m.tools : []
        const axes =
          m.move != null &&
          typeof m.move === 'object' &&
          Array.isArray((m.move as { axes?: unknown }).axes)
            ? (m.move as { axes: Array<{ letter: string }> }).axes
            : []
        const body = buildNxtUserToolsGContent({
          generatedAt: new Date().toISOString(),
          tools,
          firmwareGlobals: m.global,
          axes,
          probeToolIndex: this.probeToolIndexForLibrary,
          currentToolIndex: this.currentToolIndex
        })
        await uploadDwcFile(NXT_USER_TOOLS_DWC_PATH, body)
        await this.$store.dispatch('machine/showMessage', {
          type: 'success',
          message: this.$t('plugins.nxt.panels.toolManagement.saveToBoardSuccess', {
            path: NXT_USER_TOOLS_DWC_PATH
          })
        })
      } catch (e) {
        const msg =
          e && typeof e.message === 'string'
            ? e.message
            : this.$t('plugins.nxt.panels.toolManagement.saveToBoardFailed')
        console.error('nxt: saveToolLibraryToBoard', e)
        await this.$store.dispatch('machine/showMessage', {
          type: 'error',
          message: msg
        })
      } finally {
        this.persistingTools = false
      }
    },

    async reloadToolLibraryFromSd() {
      if (!this.isConnected || !this.nxtReady) {
        return
      }
      try {
        await this.sendCode('M98 P"nxt-user-tools.g"')
        await this.$store.dispatch('machine/showMessage', {
          type: 'success',
          message: this.$t('plugins.nxt.panels.toolManagement.reloadFromSdSuccess')
        })
      } catch (e) {
        const msg =
          e && typeof e.message === 'string'
            ? e.message
            : this.$t('plugins.nxt.panels.toolManagement.reloadFromSdFailed')
        console.error('nxt: reloadToolLibraryFromSd', e)
        await this.$store.dispatch('machine/showMessage', {
          type: 'error',
          message: msg
        })
      }
    }
  }
})
</script>

<style scoped>
.nxt-tc-tool-lib-table .nxt-tc-row-spindle {
  background-color: rgba(76, 175, 80, 0.12);
}
</style>
