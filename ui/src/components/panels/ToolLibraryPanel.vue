<template>
  <v-card>
    <v-card-title>
      <v-icon left>mdi-bookshelf</v-icon>
      {{ $t('plugins.next.panels.toolLibrary.caption') }}
      <v-spacer />
      <div v-if="!isConnected" class="d-flex align-center">
        <v-icon small class="mr-2" color="warning">mdi-lan-disconnect</v-icon>
        <span class="text-caption">{{ $t('plugins.next.messages.disconnectedShort') }}</span>
      </div>
    </v-card-title>

    <v-card-text>
      <v-alert type="info" dense outlined class="mb-4">
        <v-icon left small>mdi-information-outline</v-icon>
        {{ $t('plugins.next.panels.toolLibrary.intro') }}
      </v-alert>

      <v-alert v-if="!layoutOk && pocketCount === 0" type="warning" dense outlined class="mb-3">
        {{ $t('plugins.next.panels.toolLibrary.noLayout') }}
      </v-alert>

      <v-row v-else-if="layoutOk" dense class="mb-2">
        <v-col cols="12" sm="auto">
          <span class="body-2">
            <strong>{{ $t('plugins.next.panels.toolLibrary.bays') }}</strong>
            {{ pocketCount }}
          </span>
        </v-col>
        <v-col cols="12" sm="auto">
          <span class="body-2">
            <strong>{{ $t('plugins.next.panels.toolLibrary.magazines') }}</strong>
            {{ magCount }} × {{ slotsPer }}
          </span>
        </v-col>
      </v-row>

      <div class="d-flex flex-wrap align-center mb-3" style="gap: 8px">
        <v-btn
          color="primary"
          small
          :disabled="selectToolDisabled"
          @click="sendSelectTool"
        >
          <v-icon left small>mdi-cursor-default-click</v-icon>
          {{ $t('plugins.next.panels.toolLibrary.selectTool') }}
        </v-btn>
        <v-btn
          color="secondary"
          outlined
          small
          :disabled="resolveToolDisabled"
          @click="sendResolveTool"
        >
          {{ $t('plugins.next.panels.toolLibrary.resolveMapping') }}
        </v-btn>
        <span v-if="selectedToolIndex >= 0" class="body-2 grey--text">
          {{ $t('plugins.next.panels.toolLibrary.selected', { n: selectedToolIndex }) }}
        </span>
      </div>

      <v-simple-table dense class="nxt-tool-lib-table">
        <template #default>
          <thead>
            <tr>
              <th class="text-left">{{ $t('plugins.next.panels.toolLibrary.colTool') }}</th>
              <th class="text-left">{{ $t('plugins.next.panels.toolLibrary.colDescription') }}</th>
              <th class="text-left">{{ $t('plugins.next.panels.toolLibrary.colRadius') }}</th>
              <th class="text-left">{{ $t('plugins.next.panels.toolLibrary.colStatus') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in toolLibraryRows"
              :key="'tl-' + row.index"
              :class="rowClasses(row)"
              @click="onRowClick(row)"
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
                  {{ $t('plugins.next.panels.toolLibrary.statusSpindle') }}
                </v-chip>
                <v-chip
                  v-else-if="row.statusKind === 'probe'"
                  x-small
                  color="deep-purple"
                  text-color="white"
                  label
                >
                  {{ $t('plugins.next.panels.toolLibrary.statusProbe') }}
                </v-chip>
                <v-chip
                  v-else-if="row.statusKind === 'bay'"
                  x-small
                  color="primary"
                  text-color="white"
                  label
                >
                  {{ $t('plugins.next.panels.toolLibrary.statusBay', { b: row.bayOneBased }) }}
                </v-chip>
                <v-chip v-else x-small outlined label>
                  {{ $t('plugins.next.panels.toolLibrary.statusUnassigned') }}
                </v-chip>
              </td>
            </tr>
          </tbody>
        </template>
      </v-simple-table>

      <p v-if="toolLibraryRows.length === 0" class="body-2 grey--text mb-0">
        {{ $t('plugins.next.panels.toolLibrary.noTools') }}
      </p>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import BaseComponent from '../base/BaseComponent.vue'
import store from '@/store'
import {
  readFirmwareGlobal,
  readMosTTRadius,
  normalizeAtcVector,
  ATC_TOOL_LIBRARY_M
} from '../../utils/atcToolLibrary'

type StatusKind = 'spindle' | 'probe' | 'bay' | 'unassigned'

interface ToolLibRow {
  index: number
  description: string
  radiusLabel: string
  statusKind: StatusKind
  bayOneBased: number
}

export default BaseComponent.extend({
  name: 'NxtToolLibraryPanel',

  data() {
    return {
      selectedToolIndex: -1 as number
    }
  },

  computed: {
    model(): Record<string, any> {
      const m = store.state.machine.model
      return m != null ? m : {}
    },

    firmwareGlobals(): Map<string, unknown> | Record<string, unknown> | null {
      const g = this.model.global
      return g != null && typeof g === 'object' ? g : null
    },

    rrfState(): Record<string, any> {
      return this.model.state != null ? this.model.state : {}
    },

    machineBusy(): boolean {
      const st = this.rrfState.status
      return st === 'busy' || st === 'processing' || st === 'paused' || st === 'resuming'
    },

    currentToolIndex(): number {
      const t = this.rrfState.currentTool
      return typeof t === 'number' && t >= 0 ? t : -1
    },

    magCount(): number {
      const n = readFirmwareGlobal(this.firmwareGlobals, 'atcMagazineCount')
      return typeof n === 'number' && n >= 1 ? n : 0
    },

    slotsPer(): number {
      const n = readFirmwareGlobal(this.firmwareGlobals, 'atcSlotsPerMagazine')
      return typeof n === 'number' && n >= 1 ? n : 0
    },

    pocketCount(): number {
      const n = readFirmwareGlobal(this.firmwareGlobals, 'atcPocketCount')
      if (typeof n === 'number' && n >= 1) {
        return n
      }
      if (this.magCount > 0 && this.slotsPer > 0) {
        return this.magCount * this.slotsPer
      }
      return 0
    },

    toolTableLength(): number {
      const lim = this.model.limits && this.model.limits.tools
      if (typeof lim === 'number' && lim >= 1) {
        return lim
      }
      const tools = this.model.tools
      if (Array.isArray(tools) && tools.length >= 1) {
        return tools.length
      }
      const raw = readFirmwareGlobal(this.firmwareGlobals, 'atcToolToPocket')
      if (Array.isArray(raw) && raw.length >= 1) {
        return raw.length
      }
      return 50
    },

    toolToPocket(): number[] {
      const raw = readFirmwareGlobal(this.firmwareGlobals, 'atcToolToPocket')
      return normalizeAtcVector(raw, this.toolTableLength)
    },

    pocketToTool(): number[] {
      const raw = readFirmwareGlobal(this.firmwareGlobals, 'atcPocketToTool')
      return normalizeAtcVector(raw, this.pocketCount)
    },

    layoutOk(): boolean {
      return this.pocketCount > 0 && this.pocketToTool.length === this.pocketCount
    },

    mosProbeToolIndex(): number {
      const id = readFirmwareGlobal(this.firmwareGlobals, 'mosPTID')
      return typeof id === 'number' && id >= 0 ? id : -1
    },

    toolLibraryRows(): ToolLibRow[] {
      const tools = this.model.tools
      if (!Array.isArray(tools)) {
        return []
      }
      const ct = this.currentToolIndex
      const probeIdx = this.mosProbeToolIndex
      const t2p = this.toolToPocket
      const g = this.firmwareGlobals
      const rows: ToolLibRow[] = []
      for (let i = 0; i < tools.length; i++) {
        if (tools[i] == null) {
          continue
        }
        const inSpindle = i === ct
        const pocket = i < t2p.length ? t2p[i] : -1
        const inBay = typeof pocket === 'number' && pocket >= 0
        const isProbe = probeIdx >= 0 ? i === probeIdx : this.probeNameMatch(tools[i])
        const radius = readMosTTRadius(g, i)
        const radiusLabel = radius != null ? String(radius) : '—'
        const description =
          tools[i] != null && typeof tools[i].name === 'string' && tools[i].name.length > 0
            ? tools[i].name
            : '—'
        let statusKind: StatusKind = 'unassigned'
        let bayOneBased = 0
        if (inSpindle) {
          statusKind = 'spindle'
        } else if (isProbe) {
          statusKind = 'probe'
        } else if (inBay) {
          statusKind = 'bay'
          bayOneBased = pocket + 1
        }
        rows.push({
          index: i,
          description,
          radiusLabel,
          statusKind,
          bayOneBased
        })
      }
      return rows
    },

    selectToolDisabled(): boolean {
      if (this.uiFrozen || this.machineBusy || !this.isConnected) {
        return true
      }
      return this.selectedToolIndex < 0
    },

    resolveToolDisabled(): boolean {
      if (this.uiFrozen || this.machineBusy || !this.isConnected) {
        return true
      }
      const r = this.selectedToolIndex
      return !Number.isFinite(r) || r < 0 || r >= this.toolTableLength
    }
  },

  methods: {
    probeNameMatch(toolObj: { name?: string } | null): boolean {
      if (!toolObj || !toolObj.name) {
        return false
      }
      return String(toolObj.name).toLowerCase().includes('touch probe')
    },

    rowClasses(row: ToolLibRow): Record<string, boolean> {
      return {
        'nxt-tool-lib-row--selected': this.selectedToolIndex === row.index,
        'nxt-tool-lib-row--spindle': row.statusKind === 'spindle'
      }
    },

    onRowClick(row: ToolLibRow) {
      this.selectedToolIndex = row.index
    },

    sendSelectTool() {
      if (this.selectToolDisabled) {
        return
      }
      const n = Math.floor(this.selectedToolIndex)
      this.sendCode(`T${n}`)
    },

    sendResolveTool() {
      if (this.resolveToolDisabled) {
        return
      }
      const r = Math.floor(this.selectedToolIndex)
      this.sendCode(`M${ATC_TOOL_LIBRARY_M.resolveTool} R${r}`)
    }
  }
})
</script>

<style scoped>
.nxt-tool-lib-table tbody tr {
  cursor: pointer;
}
.nxt-tool-lib-row--selected {
  background-color: rgba(33, 150, 243, 0.12);
}
.nxt-tool-lib-row--spindle {
  background-color: rgba(76, 175, 80, 0.12);
}
</style>
