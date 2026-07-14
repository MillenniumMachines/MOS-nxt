<template>
  <v-container fluid class="nxt-tool-management nxt-tc pa-2">
    <v-card variant="outlined">
      <v-card-title class="subtitle-1 d-flex flex-wrap align-center py-3">
        <v-icon class="mr-2">mdi-bookshelf</v-icon>
        <span>{{ $t('plugins.nxt.panels.toolManagement.caption') }}</span>
        <v-spacer />
        <v-btn
          v-if="isConnected && nxtReady"
          class="mr-2"
          size="small"
          variant="outlined"
          :color="locked ? 'warning' : 'default'"
          :disabled="uiFrozen"
          @click="toggleLock"
        >
          <v-icon class="mr-1" size="small">{{ locked ? 'mdi-lock' : 'mdi-lock-open-variant' }}</v-icon>
          {{
            locked
              ? $t('plugins.nxt.panels.toolManagement.unlockTable')
              : $t('plugins.nxt.panels.toolManagement.lockTable')
          }}
        </v-btn>
        <v-btn
          v-if="isConnected && nxtReady && !locked"
          class="mr-2"
          size="small"
          variant="outlined"
          color="primary"
          :disabled="uiFrozen"
          @click="openAdd"
        >
          {{ $t('plugins.nxt.panels.toolManagement.addTool') }}
        </v-btn>
        <v-btn
          v-if="isConnected && nxtReady && !locked"
          class="mr-2"
          size="small"
          variant="outlined"
          :disabled="uiFrozen"
          @click="openImport"
        >
          {{ $t('plugins.nxt.panels.toolManagement.importFusion') }}
        </v-btn>
        <v-btn
          v-if="isConnected && nxtReady"
          class="mr-2"
          size="small"
          variant="outlined"
          color="primary"
          :loading="persistingTools"
          :disabled="uiFrozen || persistingTools"
          @click="saveToolLibraryToBoard"
        >
          {{ $t('plugins.nxt.panels.toolManagement.saveToBoard') }}
        </v-btn>
        <v-btn
          v-if="isConnected && nxtReady"
          size="small"
          variant="outlined"
          :loading="reloadingTools"
          :disabled="uiFrozen || reloadingTools"
          @click="reloadToolLibraryFromSd"
        >
          {{ $t('plugins.nxt.panels.toolManagement.reloadFromSd') }}
        </v-btn>
        <div v-if="!isConnected || !nxtReady" class="d-flex align-center">
          <v-icon size="small" class="mr-2" color="warning">{{ !isConnected ? 'mdi-lan-disconnect' : 'mdi-alert-circle-outline' }}</v-icon>
          <span class="text-caption">{{
            !isConnected ? $t('plugins.nxt.messages.disconnectedShort') : $t('plugins.nxt.messages.notReadyShort')
          }}</span>
        </div>
      </v-card-title>
      <v-divider />
      <v-card-text class="pa-3">
        <p class="text-body-2 text-grey-darken-1 mb-3">
          {{ $t('plugins.nxt.panels.toolManagement.libraryIntro') }}
        </p>
        <p class="text-body-2 text-grey-darken-1 mb-3">
          {{ $t('plugins.nxt.panels.toolManagement.persistenceHint') }}
        </p>
        <p v-if="locked" class="text-body-2 text-warning mb-3">
          {{ $t('plugins.nxt.panels.toolManagement.lockedHint') }}
        </p>
        <p class="text-body-2 mb-3">
          {{ $t('plugins.nxt.panels.toolManagement.activeToolLabel') }}:
          <strong>{{ activeToolLabel }}</strong>
          <v-btn
            v-if="currentToolIndex >= 0 && isConnected && nxtReady"
            size="x-small"
            variant="text"
            class="ml-2"
            :disabled="uiFrozen"
            @click="clearActive"
          >
            {{ $t('plugins.nxt.panels.toolManagement.clearActive') }}
          </v-btn>
        </p>
        <v-table density="compact" class="nxt-tc-tool-lib-table">
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
                <th class="text-left">{{ $t('plugins.nxt.panels.toolManagement.colActions') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in toolLibraryRows"
                :key="'tl' + row.index"
                :class="{ 'nxt-tc-row-spindle': row.inSpindle }"
              >
                <td class="text-no-wrap">
                  T{{ row.index }}
                  <v-chip
                    v-if="row.isReservedSlot"
                    size="x-small"
                    color="deep-purple"
                    text-color="white"
                    label
                    class="ml-1"
                  >
                    {{ $t('plugins.nxt.panels.toolManagement.reservedBadge') }}
                  </v-chip>
                </td>
                <td>{{ row.description }}</td>
                <td>{{ row.radiusLabel }}</td>
                <td>{{ row.flutesLabel }}</td>
                <td>{{ row.fluteLengthLabel }}</td>
                <td>
                  <v-chip
                    v-if="row.statusKind === 'spindle'"
                    size="x-small"
                    color="success"
                    text-color="white"
                    label
                  >
                    {{ $t('plugins.nxt.panels.toolManagement.statusInSpindle') }}
                  </v-chip>
                  <v-chip
                    v-else-if="row.statusKind === 'probe'"
                    size="x-small"
                    color="deep-purple"
                    text-color="white"
                    label
                  >
                    {{ $t('plugins.nxt.panels.toolManagement.statusProbe') }}
                  </v-chip>
                  <v-chip v-else size="x-small" variant="outlined" label>
                    {{ $t('plugins.nxt.panels.toolManagement.statusManual') }}
                  </v-chip>
                </td>
                <td>
                  <span>{{ row.lifeLabel }}</span>
                  <v-btn
                    v-if="row.lifeSeconds > 0 && !row.isReservedSlot && isConnected && nxtReady"
                    icon
                    size="x-small"
                    variant="text"
                    :disabled="uiFrozen"
                    :title="$t('plugins.nxt.panels.toolManagement.resetLife')"
                    @click="confirmResetLife(row)"
                  >
                    <v-icon size="small">mdi-restore</v-icon>
                  </v-btn>
                </td>
                <td class="text-no-wrap">
                  <v-btn
                    v-if="isConnected && nxtReady && !row.isReservedSlot"
                    size="x-small"
                    variant="text"
                    :disabled="uiFrozen"
                    @click="setActive(row)"
                  >
                    {{ $t('plugins.nxt.panels.toolManagement.setActive') }}
                  </v-btn>
                  <v-btn
                    v-if="isConnected && nxtReady && !locked && !row.isReservedSlot"
                    size="x-small"
                    variant="text"
                    :disabled="uiFrozen"
                    @click="openEdit(row)"
                  >
                    {{ $t('plugins.nxt.panels.toolManagement.editTool') }}
                  </v-btn>
                  <v-btn
                    v-if="isConnected && nxtReady && !locked && !row.isReservedSlot && row.configured"
                    size="x-small"
                    variant="text"
                    color="error"
                    :disabled="uiFrozen"
                    @click="confirmRemove(row)"
                  >
                    {{ $t('plugins.nxt.panels.toolManagement.deleteTool') }}
                  </v-btn>
                </td>
              </tr>
            </tbody>
          </template>
        </v-table>
        <p v-if="toolLibraryRows.length === 0" class="text-body-2 text-grey mb-0">
          {{ $t('plugins.nxt.panels.toolManagement.noTools') }}
        </p>
      </v-card-text>
    </v-card>

    <v-dialog v-model="editDialog" max-width="480">
      <v-card>
        <v-card-title>
          {{
            editing.isAdd
              ? $t('plugins.nxt.panels.toolManagement.addTool')
              : $t('plugins.nxt.panels.toolManagement.editTool')
          }}
        </v-card-title>
        <v-card-text>
          <v-text-field
            v-model.number="editing.index"
            type="number"
            :label="$t('plugins.nxt.panels.toolManagement.colToolNumber')"
            :disabled="!editing.isAdd"
            :error-messages="indexError"
            density="compact"
            variant="outlined"
          />
          <v-text-field
            v-model="editing.name"
            :label="$t('plugins.nxt.panels.toolManagement.colDescription')"
            :error-messages="nameError"
            density="compact"
            variant="outlined"
          />
          <v-text-field
            v-model.number="editing.radius"
            type="number"
            step="0.001"
            :label="$t('plugins.nxt.panels.toolManagement.colRadius')"
            density="compact"
            variant="outlined"
          />
          <v-text-field
            v-model.number="editing.flutes"
            type="number"
            :label="$t('plugins.nxt.panels.toolManagement.colFlutes')"
            density="compact"
            variant="outlined"
            clearable
          />
          <v-text-field
            v-model.number="editing.fluteLen"
            type="number"
            step="0.001"
            :label="$t('plugins.nxt.panels.toolManagement.colFluteLength')"
            density="compact"
            variant="outlined"
            clearable
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="editDialog = false">{{ $t('plugins.nxt.panels.toolManagement.cancel') }}</v-btn>
          <v-btn color="primary" :loading="savingTool" :disabled="!canSave" @click="saveTool">
            {{ $t('plugins.nxt.panels.toolManagement.save') }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="removeDialog" max-width="420">
      <v-card>
        <v-card-title>{{ $t('plugins.nxt.panels.toolManagement.deleteTool') }}</v-card-title>
        <v-card-text>
          {{ $t('plugins.nxt.panels.toolManagement.deleteConfirm', { tool: removingLabel }) }}
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="removeDialog = false">{{ $t('plugins.nxt.panels.toolManagement.cancel') }}</v-btn>
          <v-btn color="error" :loading="removingBusy" @click="doRemove">
            {{ $t('plugins.nxt.panels.toolManagement.deleteTool') }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="resetLifeDialog" max-width="420">
      <v-card>
        <v-card-title>{{ $t('plugins.nxt.panels.toolManagement.resetLife') }}</v-card-title>
        <v-card-text>
          {{ $t('plugins.nxt.panels.toolManagement.resetLifeConfirm', { tool: resetLifeLabel }) }}
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="resetLifeDialog = false">{{ $t('plugins.nxt.panels.toolManagement.cancel') }}</v-btn>
          <v-btn color="primary" :loading="resettingLife" @click="doResetLife">
            {{ $t('plugins.nxt.panels.toolManagement.resetLife') }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="importDialog" max-width="720">
      <v-card>
        <v-card-title>{{ $t('plugins.nxt.panels.toolManagement.importFusion') }}</v-card-title>
        <v-card-text>
          <p class="text-body-2 text-grey-darken-1">
            {{ $t('plugins.nxt.panels.toolManagement.importFusionHint') }}
          </p>
          <v-file-input
            accept=".tools,.json,application/zip,application/json"
            show-size
            truncate-length="40"
            :label="$t('plugins.nxt.panels.toolManagement.importFile')"
            :disabled="importing"
            @update:model-value="onImportFile"
          />
          <v-checkbox
            v-model="replaceImport"
            :label="$t('plugins.nxt.panels.toolManagement.importReplace')"
            hide-details
            class="mt-0"
          />
          <v-alert v-if="importError" type="error" density="compact" variant="outlined" class="mt-3">
            {{ importError }}
          </v-alert>
          <v-alert
            v-if="importRows.length > 0 || importWarnings.length > 0"
            type="info"
            density="compact"
            variant="outlined"
            class="mt-3"
          >
            {{
              $t('plugins.nxt.panels.toolManagement.importSummary', {
                kept: importRows.length,
                skipped: importWarnings.filter((w: string) => String(w).startsWith('Skipped')).length,
                max: maxUserIndex
              })
            }}
          </v-alert>
          <v-alert
            v-for="(w, wi) in importWarnings"
            :key="'iw' + wi"
            type="warning"
            density="compact"
            variant="outlined"
            class="mt-2"
          >
            {{ w }}
          </v-alert>
          <v-table v-if="importRows.length > 0" density="compact" class="mt-3">
            <thead>
              <tr>
                <th>T#</th>
                <th>{{ $t('plugins.nxt.panels.toolManagement.colDescription') }}</th>
                <th>{{ $t('plugins.nxt.panels.toolManagement.colRadius') }}</th>
                <th>{{ $t('plugins.nxt.panels.toolManagement.colFlutes') }}</th>
                <th>{{ $t('plugins.nxt.panels.toolManagement.colFluteLength') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in importRows" :key="'imp' + row.index">
                <td>T{{ row.index }}</td>
                <td>{{ row.name }}</td>
                <td>{{ row.radius }}</td>
                <td>{{ row.flutes != null ? row.flutes : '—' }}</td>
                <td>{{ row.fluteLengthMm != null ? row.fluteLengthMm : '—' }}</td>
              </tr>
            </tbody>
          </v-table>
          <v-progress-linear
            v-if="importing"
            class="mt-3"
            :model-value="importProgressPercent"
            height="8"
            rounded
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" :disabled="importing" @click="importDialog = false">
            {{ $t('plugins.nxt.panels.toolManagement.cancel') }}
          </v-btn>
          <v-btn
            color="primary"
            :loading="importing"
            :disabled="importRows.length === 0"
            @click="confirmImport"
          >
            {{ $t('plugins.nxt.panels.toolManagement.importConfirm') }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script lang="ts">
// @ts-nocheck — Vue 2 + BaseComponent.extend(): tsc does not merge computeds onto `this`.
import { defineNxtComponent } from '../base/BaseComponent.vue'
import store from '../../compat/dwcStore'
import {
  readFirmwareGlobal,
  NxtToolChangerOmKeys,
  augmentRrfToolForNxtUi,
  readMosTTRow,
  readOmVectorCell
} from '../../utils/nxtToolChangerOm'
import {
  isNxtToolSlotConfiguredInLibrary,
  isToolRecord,
  buildNxtUserToolsGContent,
  buildM4000Command,
  buildToolImportScratchContent,
  sendM4000,
  NXT_TOOL_IMPORT_SCRATCH_PATH
} from '../../utils/nxtUserToolsFile'
import { uploadDwcFile, NXT_USER_TOOLS_DWC_PATH } from '../../utils/nxtFileUpload'
import {
  buildFusionImportPreview,
  maxUserToolIndex,
  parseFusionToolsFile
} from '../../utils/fusionToolsImport'

function machineModel(): Record<string, any> {
  const m = store.state.machine?.model
  return m != null && typeof m === 'object' ? (m as Record<string, any>) : {}
}

function formatNum(n: unknown): string {
  if (typeof n !== 'number' || !Number.isFinite(n)) {
    return '—'
  }
  return String(Math.round(n * 1000) / 1000)
}

function formatLife(seconds: unknown): string {
  if (typeof seconds !== 'number' || !Number.isFinite(seconds) || seconds <= 0) {
    return '—'
  }
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = Math.floor(seconds % 60)
  if (h > 0) {
    return `${h}h ${m}m`
  }
  if (m > 0) {
    return `${m}m`
  }
  return `${s}s`
}

export default defineNxtComponent({
  name: 'NxtToolManagementPanel',

  data() {
    return {
      persistingTools: false,
      reloadingTools: false,
      editDialog: false,
      savingTool: false,
      removeDialog: false,
      removingBusy: false,
      removing: { index: -1, name: '' },
      resetLifeDialog: false,
      resettingLife: false,
      resetLifeTool: { index: -1, name: '' },
      importDialog: false,
      importError: '',
      importWarnings: [],
      importRows: [],
      importing: false,
      importProgress: 0,
      importTotal: 0,
      replaceImport: true,
      editing: {
        isAdd: true,
        index: 0,
        name: '',
        radius: 0,
        flutes: null,
        fluteLen: null
      }
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

    limitsTools() {
      const lim = machineModel().limits
      return lim != null && typeof lim.tools === 'number' ? lim.tools : null
    },

    reservedFrom() {
      // Legacy OM key cleared at boot; probe slot is nxtProbeToolID only.
      return this.probeToolIndexForLibrary >= 0 ? this.probeToolIndexForLibrary : null
    },

    maxUserIndex() {
      return maxUserToolIndex(this.limitsTools, this.reservedFrom)
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

    locked() {
      const v = readFirmwareGlobal(this.firmwareGlobals, 'nxtTTLocked')
      return v === true || v === 1
    },

    toolLifeVector() {
      return readFirmwareGlobal(this.firmwareGlobals, 'nxtToolLife')
    },

    activeToolLabel() {
      const ct = this.currentToolIndex
      if (ct < 0) {
        return this.$t('plugins.nxt.panels.toolManagement.activeNone').toString()
      }
      const tools = machineModel().tools
      let name = ''
      if (Array.isArray(tools) && tools[ct] && typeof tools[ct].name === 'string') {
        name = tools[ct].name
      }
      return name.length > 0 ? `T${ct} — ${name}` : `T${ct}`
    },

    indexError() {
      if (!this.editing.isAdd) {
        return ''
      }
      const e = this.editing.index
      if (typeof e !== 'number' || Number.isNaN(e)) {
        return this.$t('plugins.nxt.panels.toolManagement.indexRequired').toString()
      }
      if (e < 0 || e > this.maxUserIndex) {
        return this.$t('plugins.nxt.panels.toolManagement.indexOutOfRange', {
          max: this.maxUserIndex
        }).toString()
      }
      if (e === this.probeToolIndexForLibrary) {
        return this.$t('plugins.nxt.panels.toolManagement.indexProbeReserved').toString()
      }
      return ''
    },

    nameError() {
      return this.editing.name && String(this.editing.name).trim().length > 0
        ? ''
        : this.$t('plugins.nxt.panels.toolManagement.nameRequired').toString()
    },

    canSave() {
      return !this.indexError && !this.nameError && !this.savingTool
    },

    removingLabel() {
      return this.removing.name || `T${this.removing.index}`
    },

    resetLifeLabel() {
      return this.resetLifeTool.name || `T${this.resetLifeTool.index}`
    },

    importProgressPercent() {
      if (this.importTotal < 1) {
        return 0
      }
      return Math.round((this.importProgress / this.importTotal) * 100)
    },

    toolLibraryRows() {
      const tools = machineModel().tools
      if (!Array.isArray(tools)) {
        return []
      }
      const ct = this.currentToolIndex
      const probeIdx = this.probeToolIndexForLibrary
      const lifeVec = this.toolLifeVector
      const rows = []
      for (let i = 0; i < tools.length; i++) {
        const t = tools[i]
        const isReservedSlot = probeIdx >= 0 && i === probeIdx
        if (t == null && !isReservedSlot) {
          continue
        }
        const inSpindle = i === ct
        if (!inSpindle && !isReservedSlot && !isNxtToolSlotConfiguredInLibrary(t)) {
          continue
        }
        // Show every configured RRF slot (including above maxUserIndex). Import/add
        // still clamp to 0..maxUserIndex; hiding here made T17/T18 look "discarded"
        // when reservedFrom was tight or tools loaded before boot normalized the probe slot.
        const isProbe = isReservedSlot || this.probeNameMatch(t)
        const augmented = t != null ? augmentRrfToolForNxtUi(t, this.firmwareGlobals, i) : null
        const row = readMosTTRow(this.firmwareGlobals, i)
        const radiusRaw =
          augmented?.nxtRadiusMm ??
          (row != null && typeof readOmVectorCell(row, 0) === 'number'
            ? readOmVectorCell(row, 0)
            : null)
        const flutesRaw =
          augmented?.nxtFluteCount ??
          (row != null && readOmVectorCell(row, 2) >= 0 ? readOmVectorCell(row, 2) : null)
        const fluteLenRaw =
          augmented?.nxtFluteLengthMm ??
          (row != null && readOmVectorCell(row, 3) >= 0 ? readOmVectorCell(row, 3) : null)
        const description =
          augmented && typeof augmented.name === 'string' && augmented.name.length > 0
            ? augmented.name
            : isReservedSlot
              ? this.$t('plugins.nxt.panels.toolManagement.statusProbe').toString()
              : '—'
        let statusKind = 'manual'
        if (inSpindle) {
          statusKind = 'spindle'
        } else if (isProbe) {
          statusKind = 'probe'
        }
        const lifeSeconds =
          Array.isArray(lifeVec) && typeof lifeVec[i] === 'number' ? lifeVec[i] : 0
        rows.push({
          index: i,
          description,
          radiusLabel: formatNum(radiusRaw),
          flutesLabel: flutesRaw != null ? String(flutesRaw) : '—',
          fluteLengthLabel: formatNum(fluteLenRaw),
          rawRadius: typeof radiusRaw === 'number' ? radiusRaw : 0,
          rawFlutes: typeof flutesRaw === 'number' ? flutesRaw : null,
          rawFluteLen: typeof fluteLenRaw === 'number' ? fluteLenRaw : null,
          rawName:
            augmented && typeof augmented.name === 'string' ? augmented.name : `T${i}`,
          inSpindle,
          statusKind,
          isReservedSlot,
          configured: isNxtToolSlotConfiguredInLibrary(t),
          lifeSeconds,
          lifeLabel: formatLife(lifeSeconds)
        })
      }
      if (
        probeIdx >= 0 &&
        !rows.some((r) => r.index === probeIdx)
      ) {
        rows.push({
          index: probeIdx,
          description: this.$t('plugins.nxt.panels.toolManagement.statusProbe').toString(),
          radiusLabel: '—',
          flutesLabel: '—',
          fluteLengthLabel: '—',
          rawRadius: 0,
          rawFlutes: null,
          rawFluteLen: null,
          rawName: 'Touch Probe',
          inSpindle: probeIdx === ct,
          statusKind: probeIdx === ct ? 'spindle' : 'probe',
          isReservedSlot: true,
          configured: false,
          lifeSeconds: 0,
          lifeLabel: '—'
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

    openAdd() {
      this.editing = {
        isAdd: true,
        index: 0,
        name: '',
        radius: 0,
        flutes: null,
        fluteLen: null
      }
      this.editDialog = true
    },

    openEdit(row) {
      this.editing = {
        isAdd: false,
        index: row.index,
        name: row.rawName,
        radius: row.rawRadius,
        flutes: row.rawFlutes,
        fluteLen: row.rawFluteLen
      }
      this.editDialog = true
    },

    async saveTool() {
      if (!this.canSave || !this.isConnected || !this.nxtReady) {
        return
      }
      this.savingTool = true
      try {
        await sendM4000(this.sendCode.bind(this), {
          toolIndex: this.editing.index,
          radius: this.editing.radius,
          name: String(this.editing.name).trim(),
          flutes: this.editing.flutes,
          fluteLengthMm: this.editing.fluteLen,
          probeToolIndex: this.probeToolIndexForLibrary >= 0 ? this.probeToolIndexForLibrary : null,
          includeTc: false
        })
        this.editDialog = false
      } catch (e) {
        console.error('nxt: saveTool', e)
      } finally {
        this.savingTool = false
      }
    },

    confirmRemove(row) {
      this.removing = { index: row.index, name: row.rawName }
      this.removeDialog = true
    },

    async doRemove() {
      if (!this.isConnected || !this.nxtReady) {
        return
      }
      this.removingBusy = true
      try {
        await this.sendCode(`M4001 P${this.removing.index}`)
        this.removeDialog = false
      } catch (e) {
        console.error('nxt: doRemove', e)
      } finally {
        this.removingBusy = false
      }
    },

    confirmResetLife(row) {
      this.resetLifeTool = { index: row.index, name: row.rawName }
      this.resetLifeDialog = true
    },

    async doResetLife() {
      if (!this.isConnected || !this.nxtReady) {
        return
      }
      this.resettingLife = true
      try {
        await this.sendCode('M98 P"nxt-tool-life-ensure.g"')
        await this.sendCode(`set global.nxtToolLife[${this.resetLifeTool.index}] = 0`)

        this.resetLifeDialog = false
      } catch (e) {
        console.error('nxt: doResetLife', e)
      } finally {
        this.resettingLife = false
      }
    },

    async setActive(row) {
      await this.sendCode(`T${row.index}`)
    },

    async clearActive() {
      await this.sendCode('T-1')
    },

    async toggleLock() {
      if (!this.isConnected || !this.nxtReady) {
        return
      }
      const next = !this.locked
      await this.sendCode(`set global.nxtTTLocked = ${next ? 'true' : 'false'}`)
      await this.sendCode('M98 P"nxt-user-tools-sync.g"')
    },

    openImport() {
      this.importError = ''
      this.importRows = []
      this.importWarnings = []
      this.importProgress = 0
      this.importTotal = 0
      this.importDialog = true
    },

    async onImportFile(value) {
      this.importError = ''
      this.importRows = []
      this.importWarnings = []
      const file = Array.isArray(value) ? value[0] : value
      if (!file) {
        return
      }
      try {
        const records = await parseFusionToolsFile(file)
        const preview = buildFusionImportPreview(records, {
          limitsTools: this.limitsTools ?? 50,
          probeIndex: this.probeToolIndexForLibrary >= 0 ? this.probeToolIndexForLibrary : 49
        })
        this.importRows = preview.rows
        this.importWarnings = preview.warnings
        if (preview.rows.length === 0 && preview.warnings.length === 0) {
          this.importError = this.$t('plugins.nxt.panels.toolManagement.importEmpty').toString()
        }
      } catch (e) {
        this.importError =
          e && typeof e.message === 'string'
            ? e.message
            : this.$t('plugins.nxt.panels.toolManagement.importFailed').toString()
      }
    },

    async confirmImport() {
      if (!this.isConnected || !this.nxtReady || this.importRows.length === 0) {
        return
      }
      this.importing = true
      this.importTotal = this.importRows.length
      this.importProgress = 0
      try {
        // One upload + one M98 — per-tool sendCode floods DSF and often yields
        // "Invalid password" / disconnect on SBC (session churn + per-M4000 SD sync).
        const m4000Lines = this.importRows.map(
          (row: {
            index: number
            radius: number
            name: string
            flutes: number | null
            fluteLengthMm: number | null
          }) =>
            buildM4000Command({
              toolIndex: row.index,
              radius: row.radius,
              name: row.name,
              flutes: row.flutes,
              fluteLengthMm: row.fluteLengthMm,
              probeToolIndex: this.probeToolIndexForLibrary >= 0 ? this.probeToolIndexForLibrary : null,
              includeTc: false
            })
        )
        const body = buildToolImportScratchContent({
          replace: this.replaceImport,
          m4000Lines
        })
        await uploadDwcFile(NXT_TOOL_IMPORT_SCRATCH_PATH, body)
        this.importProgress = Math.max(1, Math.floor(this.importTotal / 2))
        await this.sendCode('M98 P"nxt-tool-import-scratch.g"')
        this.importProgress = this.importTotal
        this.importDialog = false
        await this.$store.dispatch('machine/showMessage', {
          type: 'success',
          message: this.$t('plugins.nxt.panels.toolManagement.importSuccess', {
            count: this.importRows.length
          })
        })
      } catch (e) {
        const msg =
          e && typeof e.message === 'string'
            ? e.message
            : this.$t('plugins.nxt.panels.toolManagement.importFailed')
        console.error('nxt: confirmImport', e)
        await this.$store.dispatch('machine/showMessage', { type: 'error', message: msg })
      } finally {
        this.importing = false
      }
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
      this.reloadingTools = true
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
      } finally {
        this.reloadingTools = false
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
