<template>
  <v-container fluid class="nxt-tool-management nxt-tc pa-2">
    <v-card outlined>
      <v-card-title class="subtitle-1 d-flex flex-wrap align-center py-3">
        <v-icon left class="mr-2">mdi-bookshelf</v-icon>
        <span>{{ $t('plugins.next.panels.toolManagement.caption') }}</span>
        <v-spacer />
        <div v-if="!isConnected || !nxtReady" class="d-flex align-center">
          <v-icon small class="mr-2" color="warning">{{ !isConnected ? 'mdi-lan-disconnect' : 'mdi-alert-circle-outline' }}</v-icon>
          <span class="text-caption">{{
            !isConnected ? $t('plugins.next.messages.disconnectedShort') : $t('plugins.next.messages.notReadyShort')
          }}</span>
        </div>
      </v-card-title>
      <v-divider />
      <v-card-text class="pa-3">
        <p class="body-2 grey--text text--darken-1 mb-3">
          {{ $t('plugins.next.panels.toolManagement.libraryIntro') }}
        </p>
        <v-simple-table dense class="nxt-tc-tool-lib-table">
          <template #default>
            <thead>
              <tr>
                <th class="text-left">{{ $t('plugins.next.panels.toolManagement.colToolNumber') }}</th>
                <th class="text-left">{{ $t('plugins.next.panels.toolManagement.colDescription') }}</th>
                <th class="text-left">{{ $t('plugins.next.panels.toolManagement.colRadius') }}</th>
                <th class="text-left">{{ $t('plugins.next.panels.toolManagement.colStatus') }}</th>
                <th class="text-left">{{ $t('plugins.next.panels.toolManagement.colLife') }}</th>
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
                <td>
                  <v-chip
                    v-if="row.statusKind === 'spindle'"
                    x-small
                    color="success"
                    text-color="white"
                    label
                  >
                    {{ $t('plugins.next.panels.toolManagement.statusInSpindle') }}
                  </v-chip>
                  <v-chip
                    v-else-if="row.statusKind === 'probe'"
                    x-small
                    color="deep-purple"
                    text-color="white"
                    label
                  >
                    {{ $t('plugins.next.panels.toolManagement.statusProbe') }}
                  </v-chip>
                  <v-chip v-else x-small outlined label>
                    {{ $t('plugins.next.panels.toolManagement.statusManual') }}
                  </v-chip>
                </td>
                <td class="grey--text">—</td>
              </tr>
            </tbody>
          </template>
        </v-simple-table>
        <p v-if="toolLibraryRows.length === 0" class="body-2 grey--text mb-0">
          {{ $t('plugins.next.panels.toolManagement.noTools') }}
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
  resolveToolRadiusMm
} from '../../utils/nxtToolChangerOm'

function machineModel(): Record<string, any> {
  const m = store.state.machine?.model
  return m != null && typeof m === 'object' ? (m as Record<string, any>) : {}
}

/**
 * RRF may reserve indices with placeholder objects; list only tools that look configured,
 * plus the active spindle tool and configured probe index so they always appear.
 */
function isToolConfiguredInSystem(tool: any): boolean {
  if (tool == null || typeof tool !== 'object') {
    return false
  }
  const name = tool.name
  if (typeof name === 'string' && name.trim().length > 0) {
    return true
  }
  if (Array.isArray(tool.spindles) && tool.spindles.length > 0) {
    return true
  }
  if (typeof tool.spindle === 'number' && tool.spindle >= 0) {
    return true
  }
  if (Array.isArray(tool.extruders) && tool.extruders.length > 0) {
    return true
  }
  if (Array.isArray(tool.heaters) && tool.heaters.length > 0) {
    return true
  }
  if (Array.isArray(tool.drives) && tool.drives.length > 0) {
    return true
  }
  return false
}

export default BaseComponent.extend({
  name: 'NxtToolManagementPanel',

  computed: {
    firmwareGlobals() {
      const g = machineModel().global
      return g != null && typeof g === 'object' ? g : null
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
      const nxt = readFirmwareGlobal(g, 'nxtTouchProbeID')
      if (typeof nxt === 'number' && nxt >= 0) {
        return nxt
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
        if (!inSpindle && !isProbeSlot && !isToolConfiguredInSystem(t)) {
          continue
        }
        const isProbe = isProbeSlot || this.probeNameMatch(t)
        const radius = resolveToolRadiusMm(t, this.firmwareGlobals, i)
        const radiusLabel = radius != null ? String(radius) : '—'
        const description =
          t != null && typeof t.name === 'string' && t.name.length > 0 ? t.name : '—'
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
          inSpindle,
          statusKind
        })
      }
      if (ct >= 0 && ct < tools.length && !rows.some((r) => r.index === ct)) {
        const t = tools[ct]
        const radius = t != null ? resolveToolRadiusMm(t, this.firmwareGlobals, ct) : null
        rows.push({
          index: ct,
          description:
            t != null && typeof t.name === 'string' && t.name.length > 0 ? t.name : '—',
          radiusLabel: radius != null ? String(radius) : '—',
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
    }
  }
})
</script>

<style scoped>
.nxt-tc-tool-lib-table .nxt-tc-row-spindle {
  background-color: rgba(76, 175, 80, 0.12);
}
</style>
