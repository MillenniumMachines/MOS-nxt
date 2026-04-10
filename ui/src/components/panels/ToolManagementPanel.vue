<template>
  <v-container fluid class="nxt-tool-management mos-atc pa-2">
    <v-card outlined>
      <v-card-title class="subtitle-1 d-flex flex-wrap align-center py-3">
        <v-icon left class="mr-2">mdi-bookshelf</v-icon>
        <span>{{ $t('plugins.next.panels.toolManagement.caption') }}</span>
        <v-spacer />
        <div v-if="!isConnected || !nxtReady" class="d-flex align-center mr-2">
          <v-icon small class="mr-2" color="warning">{{ !isConnected ? 'mdi-lan-disconnect' : 'mdi-alert-circle-outline' }}</v-icon>
          <span class="text-caption">{{
            !isConnected ? $t('plugins.next.messages.disconnectedShort') : $t('plugins.next.messages.notReadyShort')
          }}</span>
        </div>
        <v-chip
          small
          class="ml-2"
          :color="atcModeChipColor"
          :outlined="atcModeChipOutlined"
          label
        >
          {{ atcModeChipLabel }}
        </v-chip>
      </v-card-title>
      <v-divider />
      <v-tabs v-model="mainTab" show-arrows background-color="transparent">
        <v-tab>Tool Library</v-tab>
        <v-tab>Magazine</v-tab>
        <v-tab :disabled="!jobRunning">
          Current Job
        </v-tab>
        <v-tab>ATC Control</v-tab>
      </v-tabs>
      <v-divider />
      <v-tabs-items v-model="mainTab">
        <!-- Tool Library -->
        <v-tab-item class="pa-3">
          <p class="body-2 grey--text text--darken-1 mb-3">
            Tool numbers match the <code>P</code> index used with <code>M4000</code> (e.g. MillenniumOS). Status uses ATC mapping and the current spindle tool from the object model.
          </p>
          <v-simple-table dense class="mos-atc-tool-lib-table">
            <template #default>
              <thead>
                <tr>
                  <th class="text-left">Tool number</th>
                  <th class="text-left">Description</th>
                  <th class="text-left">Radius</th>
                  <th class="text-left">Status</th>
                  <th class="text-left">Life</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in toolLibraryRows"
                  :key="'tl' + row.index"
                  :class="{ 'mos-atc-row-spindle': row.inSpindle }"
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
                      In Spindle
                    </v-chip>
                    <v-chip
                      v-else-if="row.statusKind === 'probe'"
                      x-small
                      color="deep-purple"
                      text-color="white"
                      label
                    >
                      Probe
                    </v-chip>
                    <v-chip
                      v-else-if="row.statusKind === 'bay'"
                      x-small
                      color="primary"
                      text-color="white"
                      label
                    >
                      Bay {{ row.bayOneBased }}
                    </v-chip>
                    <v-chip v-else x-small outlined label>
                      Unassigned
                    </v-chip>
                  </td>
                  <td class="grey--text">—</td>
                </tr>
              </tbody>
            </template>
          </v-simple-table>
          <p v-if="toolLibraryRows.length === 0" class="body-2 grey--text mb-0">
            No tools defined in the RRF object model yet.
          </p>
        </v-tab-item>

        <!-- Magazine -->
        <v-tab-item class="pa-3">
          <v-alert v-if="!layoutOk" type="warning" dense outlined class="mb-3">
            Install <code>0:/sys/mos-atc.g</code> and <code>0:/sys/M870.g</code>–<code>M879.g</code> (incl. <code>M878.g</code>/<code>M879.g</code> for library persistence), or configure layout in <strong>ATC Control</strong>.
          </v-alert>
          <v-alert v-else-if="!atcEnabledFlag" type="info" dense outlined class="mb-3">
            ATC is disabled (<code>global.atcEnabled</code>). Bay cards are read-only; Present and Clear are hidden.
          </v-alert>
          <div
            v-if="layoutOk"
            class="body-2 mb-3 d-flex flex-wrap align-center mos-atc-summary-bar"
          >
            <span class="mr-4"><strong>Bays:</strong> {{ pocketCount }}</span>
            <span class="mr-4"><strong>Loaded:</strong> {{ magazineLoadedCount }}</span>
            <span><strong>Empty:</strong> {{ magazineEmptyCount }}</span>
          </div>
          <v-row v-if="layoutOk" dense>
            <v-col
              v-for="bay in bayCardRows"
              :key="'bay' + bay.flat"
              cols="12"
              sm="6"
              md="4"
              lg="3"
            >
              <v-card
                outlined
                class="mos-atc-bay-card pa-3 fill-height d-flex flex-column"
                :class="{
                  'mos-atc-bay-card--empty': bay.empty,
                  'mos-atc-bay-card--spindle': bay.inSpindle
                }"
                :style="bay.empty ? { opacity: 0.55 } : {}"
              >
                <div class="d-flex align-center mb-2">
                  <span class="title text-h6 mb-0">Bay {{ bay.bayOneBased }}</span>
                  <v-spacer />
                  <v-progress-circular
                    v-if="presentingPocket === bay.flat"
                    indeterminate
                    size="22"
                    width="2"
                    color="primary"
                  />
                </div>
                <div class="caption grey--text text--darken-1 mb-1 font-mono">
                  {{ bay.locationLabel }}
                </div>
                <div class="body-2 mb-1">
                  <strong>{{ bay.toolName }}</strong>
                </div>
                <div class="body-2 grey--text text--darken-1 mb-1">
                  Tool #{{ bay.empty ? '—' : bay.rrfTool }} · R {{ bay.radiusLabel }}
                </div>
                <div class="mb-2">
                  <v-chip x-small :color="bay.statusChipColor" text-color="white" label>
                    {{ bay.statusLabel }}
                  </v-chip>
                </div>
                <v-spacer />
                <div v-if="magazineActionsEnabled" class="d-flex flex-wrap mt-2" style="gap: 8px">
                  <v-btn
                    small
                    color="primary"
                    outlined
                    :disabled="presentBayDisabled"
                    @click="presentBay(bay.flat)"
                  >
                    Present bay
                  </v-btn>
                  <v-btn
                    small
                    color="secondary"
                    text
                    :disabled="clearBayDisabled(bay)"
                    @click="clearBay(bay.bayOneBased)"
                  >
                    Clear
                  </v-btn>
                </div>
              </v-card>
            </v-col>
          </v-row>
        </v-tab-item>

        <!-- Current Job -->
        <v-tab-item class="pa-3">
          <p class="body-2 grey--text text--darken-1 mb-3">
            Sequence and overflow data come from firmware globals (<code>atcJobSeq*</code>), filled when your job/post pipeline parses tool order. Status uses <code>state.currentTool</code> and <code>atcJobSeqComplete[]</code>.
          </p>
          <v-simple-table dense class="mos-atc-job-table">
            <template #default>
              <thead>
                <tr>
                  <th class="text-left">Seq</th>
                  <th class="text-left">Tool #</th>
                  <th class="text-left">Name</th>
                  <th class="text-left">Bay</th>
                  <th class="text-left">Status</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in currentJobRows"
                  :key="'job' + row.seq"
                  :class="{
                    'mos-atc-job-row-active': row.isActive,
                    'mos-atc-job-row-overflow': row.overflow
                  }"
                >
                  <td>{{ row.seq }}</td>
                  <td>{{ row.toolIndex }}</td>
                  <td>{{ row.toolName }}</td>
                  <td>{{ row.bayLabel }}</td>
                  <td>
                    <v-chip
                      x-small
                      :color="row.statusColor"
                      text-color="white"
                      label
                    >
                      {{ row.statusLabel }}
                    </v-chip>
                  </td>
                </tr>
              </tbody>
            </template>
          </v-simple-table>
          <p v-if="currentJobRows.length === 0" class="body-2 grey--text mb-3">
            No job sequence rows (<code>atcJobSeqLength</code> is 0). Start a job after your parser populates the sequence.
          </p>
          <v-chip
            v-if="jobOverflowWarningFlag"
            small
            color="amber darken-2"
            text-color="white"
            class="mt-2"
            label
          >
            Overflow: more unique tools than bays — manual tool-change pauses required
          </v-chip>
        </v-tab-item>

        <!-- ATC Control -->
        <v-tab-item class="pa-2">
          <v-dialog v-model="unloadAllDialog" max-width="520">
            <v-card>
              <v-card-title class="subtitle-1">
                Unload all tools?
              </v-card-title>
              <v-card-text class="body-2">
                Sends <code>M4010</code> to return tools to bays and clear STC state. If a previous unload was aborted, use <strong>Recovery after abort</strong> instead.
              </v-card-text>
              <v-card-actions>
                <v-spacer />
                <v-btn text @click="unloadAllDialog = false">
                  Cancel
                </v-btn>
                <v-btn color="primary" @click="confirmUnloadAll">
                  Confirm unload
                </v-btn>
              </v-card-actions>
            </v-card>
          </v-dialog>

          <v-card outlined class="pa-3 mb-3">
            <v-card-title class="subtitle-1 px-0 pt-0">
              STC status
            </v-card-title>
            <v-card-text class="px-0 pb-0">
              <v-simple-table dense>
                <template #default>
                  <tbody>
                    <tr v-for="r in atcStatusTableRows" :key="r.key">
                      <td class="font-weight-medium" style="width:40%">
                        {{ r.label }}
                      </td>
                      <td>{{ r.value }}</td>
                    </tr>
                  </tbody>
                </template>
              </v-simple-table>
            </v-card-text>
          </v-card>

          <v-card outlined class="pa-3 mb-3">
            <v-card-title class="subtitle-1 px-0 pt-0">
              Operations
            </v-card-title>
            <v-card-text class="px-0 pb-0">
              <div class="d-flex flex-wrap mb-3" style="gap: 8px">
                <v-btn
                  color="primary"
                  outlined
                  :disabled="unloadAllDisabled"
                  @click="unloadAllDialog = true"
                >
                  Unload all
                </v-btn>
                <v-btn
                  color="secondary"
                  outlined
                  :disabled="recoveryAfterAbortDisabled"
                  @click="runRecoveryAfterAbort"
                >
                  Recovery after abort
                </v-btn>
                <v-btn
                  color="default"
                  outlined
                  @click="runStatusDump"
                >
                  Status dump
                </v-btn>
                <v-btn
                  color="default"
                  outlined
                  :disabled="bayTestDisabled"
                  @click="runBayTest"
                >
                  Bay test
                </v-btn>
              </div>
              <p class="caption grey--text text--darken-1 mb-2">
                Bay test sends <code>M4014</code> (commissioning). Machine must be homed and no job running.
              </p>
              <v-row dense align="center">
                <v-col cols="12" sm="6" md="4">
                  <v-text-field
                    v-model.number="manualPresentBay"
                    label="Bay number (1-based)"
                    type="number"
                    min="1"
                    :max="Math.max(1, pocketCount)"
                    hide-details
                    outlined
                    dense
                    :disabled="!layoutOk || jobRunning || !atcEnabledFlag"
                  />
                </v-col>
                <v-col cols="12" sm="auto">
                  <v-btn
                    color="primary"
                    :disabled="manualPresentDisabled"
                    @click="runManualPresentBay"
                  >
                    Present bay
                  </v-btn>
                </v-col>
              </v-row>
              <p class="caption grey--text text--darken-1 mt-1 mb-0">
                Sends <code>M4013 B…</code> (ATC axis only, not X/Y).
              </p>
            </v-card-text>
          </v-card>

          <v-card outlined class="pa-3 mb-3">
            <v-card-title class="subtitle-1 px-0 pt-0">
              M870–M876 + M878–M879 (M878/M879 = save/load library)
            </v-card-title>
            <v-card-text class="px-0 pb-0">
              <div class="d-flex flex-wrap mb-3" style="gap: 8px">
                <v-btn color="default" outlined @click="sendCode(`M${MOS_ATC_M.init}`)">
                  Run M870 init
                </v-btn>
                <v-btn color="warning" outlined :disabled="!layoutOk" @click="runSeedIdentity">
                  Seed identity (M874)
                </v-btn>
              </div>

              <v-row dense align="center" class="mb-2">
                <v-col cols="12" sm="5" md="4">
                  <v-text-field
                    v-model.number="resolvePocketInput"
                    label="Pocket index (P)"
                    type="number"
                    min="0"
                    :max="Math.max(0, pocketCount - 1)"
                    hide-details
                    outlined
                    dense
                  />
                </v-col>
                <v-col cols="12" sm="auto">
                  <v-btn color="primary" :disabled="resolvePocketDisabled" @click="runResolvePocket">
                    Resolve pocket (M872)
                  </v-btn>
                </v-col>
                <v-col cols="12" sm="auto" class="body-2 grey--text text--darken-1">
                  atcResolvedTool: {{ resolvedToolValue >= 0 ? `T${resolvedToolValue}` : '—' }}
                </v-col>
              </v-row>

              <v-row dense align="center" class="mb-2">
                <v-col cols="12" sm="5" md="4">
                  <v-text-field
                    v-model.number="resolveToolInput"
                    label="Tool index (R)"
                    type="number"
                    min="0"
                    :max="Math.max(0, toolTableLength - 1)"
                    hide-details
                    outlined
                    dense
                  />
                </v-col>
                <v-col cols="12" sm="auto">
                  <v-btn color="primary" :disabled="resolveToolDisabled" @click="runResolveTool">
                    Resolve tool (M873)
                  </v-btn>
                </v-col>
                <v-col cols="12" sm="auto" class="body-2 grey--text text--darken-1">
                  atcResolvedPocket: {{ resolvedPocketValue >= 0 ? `#${resolvedPocketValue + 1}` : '—' }}
                </v-col>
              </v-row>

              <v-row dense align="center">
                <v-col cols="12" sm="5" md="4">
                  <v-text-field
                    v-model.number="selectDemoPocketInput"
                    label="Pocket index for demo (P)"
                    type="number"
                    min="0"
                    :max="Math.max(0, pocketCount - 1)"
                    hide-details
                    outlined
                    dense
                  />
                </v-col>
                <v-col cols="12" sm="auto">
                  <v-btn
                    color="secondary"
                    outlined
                    :disabled="selectDemoDisabled"
                    @click="runSelectFromPocketDemo"
                  >
                    Select from pocket (M875)
                  </v-btn>
                </v-col>
              </v-row>
            </v-card-text>
          </v-card>

          <v-card v-if="statusDumpText" outlined class="mb-3">
            <v-card-title
              class="subtitle-2 py-2 d-flex align-center"
              style="cursor: pointer"
              @click="statusDumpExpanded = !statusDumpExpanded"
            >
              Status dump output
              <v-spacer />
              <span class="caption">{{ statusDumpExpanded ? 'Hide' : 'Show' }}</span>
            </v-card-title>
            <v-expand-transition>
              <div v-show="statusDumpExpanded">
                <v-divider />
                <v-card-text>
                  <pre class="mos-atc-dump body-2 mb-0">{{ statusDumpText }}</pre>
                </v-card-text>
              </div>
            </v-expand-transition>
          </v-card>

          <v-row>
            <v-col cols="12" md="6">
              <v-card outlined class="pa-3 mb-3">
                <v-card-title class="subtitle-1 px-0 pt-0">Layout</v-card-title>
                <v-card-text class="px-0 pb-0">
                  <p class="body-2 grey--text text--darken-1 mb-3">
                    Set the number of ATC magazines and pockets per magazine on the firmware (RRF 3.6+).
                    Flat pocket index = magazine × slots per magazine + slot (zero-based).
                  </p>
                  <v-alert v-if="!layoutOk" type="warning" dense outlined class="mb-3">
                    Install <code>0:/sys/mos-atc.g</code> and <code>0:/sys/M870.g</code>–<code>M879.g</code> (ATC M-codes; <code>mos-atc.g</code> loads saved bay map via <code>M879</code> when <code>mos-atc-library.g</code> exists).
                    The panel can also run <code>M870</code> automatically to allocate vectors, so you typically only need to click “Apply layout”.
                  </v-alert>
                  <v-row dense>
                    <v-col cols="6">
                      <v-text-field
                        v-model.number="formMagazines"
                        label="ATC magazines"
                        type="number"
                        min="1"
                        max="32"
                        hide-details
                        outlined
                        dense
                      />
                    </v-col>
                    <v-col cols="6">
                      <v-text-field
                        v-model.number="formSlots"
                        label="Slots per ATC"
                        type="number"
                        min="1"
                        max="128"
                        hide-details
                        outlined
                        dense
                      />
                    </v-col>
                  </v-row>
                  <v-btn color="primary" class="mt-3" :disabled="!canApplyLayout" @click="applyLayout">
                    Apply layout on board
                  </v-btn>
                </v-card-text>
              </v-card>

              <v-card outlined class="pa-3 mb-3">
                <v-card-title class="subtitle-1 px-0 pt-0">Active ATC &amp; mapping</v-card-title>
                <v-card-text class="px-0 pb-0">
                  <v-select
                    v-model="selectedMagazine"
                    :items="magazineItems"
                    label="ATC (magazine)"
                    item-text="title"
                    item-value="value"
                    hide-details
                    outlined
                    dense
                    class="mb-3"
                    :disabled="!layoutOk"
                  />
                  <v-simple-table dense style="border:1px solid rgba(128,128,128,.35);border-radius:4px">
                    <template #default>
                      <thead>
                        <tr>
                          <th class="text-left">Slot</th>
                          <th class="text-left">Location</th>
                          <th class="text-left">RRF tool</th>
                          <th class="text-right" />
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-for="row in tableRows" :key="row.flat">
                          <td>{{ row.localSlot + 1 }}</td>
                          <td>
                            <span style="font-family:monospace">M{{ row.magazine + 1 }}-S{{ row.localSlot + 1 }}</span>
                            <span class="caption grey--text"> · #{{ row.flat + 1 }}</span>
                          </td>
                          <td>
                            <v-select
                              :value="row.rrfTool"
                              :items="toolSelectItems"
                              item-text="title"
                              item-value="value"
                              hide-details
                              outlined
                              dense
                              :disabled="!layoutOk"
                              @input="onSlotToolInput(row, $event)"
                            />
                          </td>
                          <td class="text-right">
                            <v-btn small text :disabled="!layoutOk || row.rrfTool < 0" @click="assignTool(row.flat, -1)">
                              Clear
                            </v-btn>
                          </td>
                        </tr>
                      </tbody>
                    </template>
                  </v-simple-table>
                </v-card-text>
              </v-card>
            </v-col>

            <v-col cols="12" md="6">
              <v-card outlined class="pa-3 mb-3">
                <v-card-title class="subtitle-1 px-0 pt-0">Visualization</v-card-title>
                <v-card-text class="px-0 pb-0">
                  <v-radio-group v-model="highlightMode" row hide-details class="mt-0 mb-2">
                    <v-radio label="Highlight by location #" value="location" />
                    <v-radio label="Highlight tool T#" value="tool" />
                  </v-radio-group>
                  <v-text-field
                    v-if="highlightMode === 'location'"
                    v-model.number="highlightLocation"
                    label="Location number (1-based flat pocket)"
                    type="number"
                    min="1"
                    hide-details
                    outlined
                    dense
                    class="mb-3"
                  />
                  <v-select
                    v-else
                    v-model="highlightTool"
                    :items="toolSelectItems"
                    item-text="title"
                    item-value="value"
                    label="Tool to highlight"
                    hide-details
                    outlined
                    dense
                    class="mb-3"
                  />
                  <div class="pa-2" style="border:1px solid rgba(128,128,128,.35);border-radius:4px">
                    <svg :viewBox="svgViewBox" width="100%" style="max-height: 320px;">
                      <g
                        v-for="(mag, mi) in magazineViz"
                        :key="'m' + mi"
                        :transform="'translate(0 ' + (mi * (slotH + magPad)) + ')'"
                      >
                        <text x="0" y="-6" fill="currentColor" style="font-size:12px;font-weight:600">{{ mag.label }}</text>
                        <g v-for="cell in mag.cells" :key="'c' + cell.flat">
                          <rect
                            :x="cell.x"
                            y="0"
                            :width="slotW - 4"
                            :height="slotH"
                            :rx="4"
                            :fill="cell.highlight ? '#29b6f6' : (cell.filled ? '#455a64' : '#37474f')"
                            :stroke="cell.highlight ? '#0277bd' : '#78909c'"
                            stroke-width="1"
                          />
                          <text
                            :x="cell.x + (slotW - 4) / 2"
                            :y="slotH / 2 + 5"
                            text-anchor="middle"
                            fill="#eceff1"
                            style="font-size:11px;font-family:monospace"
                          >
                            {{ cell.label }}
                          </text>
                        </g>
                      </g>
                    </svg>
                  </div>
                </v-card-text>
              </v-card>

              <v-card outlined class="pa-3">
                <v-card-title class="subtitle-1 px-0 pt-0">Firmware snapshot</v-card-title>
                <v-card-text class="px-0 pb-0 body-2" style="font-family:monospace">
                  <div>Magazines: {{ magCount }} · Slots/mag: {{ slotsPer }} · Total pockets: {{ pocketCount }}</div>
                  <div class="caption grey--text mt-1">Uses object model <code>global.*</code> (RRF 3.6+).</div>
                </v-card-text>
              </v-card>
            </v-col>
          </v-row>
        </v-tab-item>
      </v-tabs-items>
    </v-card>
  </v-container>
</template>

<script lang="ts">
import BaseComponent from '../base/BaseComponent.vue'
import { readFirmwareGlobal, readMosTTRadius, normalizeAtcVector, MOS_ATC_M } from '@/utils/atcToolLibrary'

const ATC_JOB_SEQ_MAX = 64

export default BaseComponent.extend({
  name: 'NxtToolManagementPanel',

  data() {
    return {
      MOS_ATC_M,
      mainTab: 0,
      formMagazines: 1,
      formSlots: 12,
      selectedMagazine: 0,
      highlightMode: 'location',
      highlightLocation: 1,
      highlightTool: 0,
      slotW: 44,
      slotH: 36,
      magPad: 28,
      autoInitDone: false,
      presentingPocket: null,
      presentSpinTimeoutId: null,
      prevMachineStatus: null,
      manualPresentBay: 1,
      unloadAllDialog: false,
      statusDumpText: '',
      statusDumpExpanded: true,
      resolvePocketInput: 0,
      resolveToolInput: 0,
      selectDemoPocketInput: 0
    }
  },

  computed: {
    model() {
      const m = this.$store.state.machine && this.$store.state.machine.model
      return m != null ? m : {}
    },

    /** Raw `model.global` (Map in stock DWC 3.6). */
    firmwareGlobals() {
      const g = this.model.global
      return g != null && typeof g === 'object' ? g : null
    },

    rrfState() {
      return this.model.state != null ? this.model.state : {}
    },

    /**
     * Job / motion busy: uses `state.status` from RRF OM (e.g. busy, processing, paused).
     * Adjust if your DWC fork uses different fields for “file job active”.
     */
    jobRunning() {
      const st = this.rrfState.status
      return st === 'busy' || st === 'processing' || st === 'paused' || st === 'resuming'
    },

    currentToolIndex() {
      const t = this.rrfState.currentTool
      return typeof t === 'number' && t >= 0 ? t : -1
    },

    atcModeChipLabel() {
      if (!this.jobRunning) {
        return 'Idle'
      }
      const m = readFirmwareGlobal(this.firmwareGlobals, 'atcToolChangeMode')
      if (m === 1) {
        return 'Semi-Automatic'
      }
      if (m === 2) {
        return 'Automatic'
      }
      return 'Manual'
    },

    atcModeChipColor() {
      if (!this.jobRunning) {
        return 'grey'
      }
      const m = readFirmwareGlobal(this.firmwareGlobals, 'atcToolChangeMode')
      if (m === 2) {
        return 'success'
      }
      if (m === 1) {
        return 'primary'
      }
      return 'orange darken-2'
    },

    atcModeChipOutlined() {
      return !this.jobRunning
    },

    atcEnabledFlag() {
      const v = readFirmwareGlobal(this.firmwareGlobals, 'atcEnabled')
      if (v === false) {
        return false
      }
      return true
    },

    magazineActionsEnabled() {
      return this.layoutOk && this.atcEnabledFlag
    },

    presentBayDisabled() {
      return this.jobRunning || !this.magazineActionsEnabled
    },

    unloadAllDisabled() {
      return this.jobRunning
    },

    recoveryAfterAbortDisabled() {
      return this.jobRunning
    },

    machineHomedForBayTest() {
      const axes = this.model.move && this.model.move.axes
      if (!Array.isArray(axes)) {
        return false
      }
      const need = { x: false, y: false, z: false }
      for (let i = 0; i < axes.length; i++) {
        const a = axes[i]
        if (!a || a.letter == null) {
          continue
        }
        const L = String(a.letter).toLowerCase()
        if (L in need && a.homed) {
          need[L] = true
        }
      }
      return need.x && need.y && need.z
    },

    bayTestDisabled() {
      return !this.machineHomedForBayTest || this.jobRunning
    },

    manualPresentDisabled() {
      if (!this.layoutOk || this.jobRunning || !this.atcEnabledFlag) {
        return true
      }
      const b = this.manualPresentBay
      if (!Number.isFinite(b) || b < 1 || b > this.pocketCount) {
        return true
      }
      return false
    },

    resolvePocketDisabled() {
      if (!this.layoutOk) {
        return true
      }
      const p = this.resolvePocketInput
      return !Number.isFinite(p) || p < 0 || p >= this.pocketCount
    },

    resolveToolDisabled() {
      const r = this.resolveToolInput
      return !Number.isFinite(r) || r < 0 || r >= this.toolTableLength
    },

    selectDemoDisabled() {
      if (!this.layoutOk || this.jobRunning) {
        return true
      }
      const p = this.selectDemoPocketInput
      return !Number.isFinite(p) || p < 0 || p >= this.pocketCount
    },

    atcBayModeLabel() {
      const m = readFirmwareGlobal(this.firmwareGlobals, 'atcBayMode')
      return m === 1 ? 'Persistent' : 'Guided'
    },

    atcToolChangeModeLabel() {
      const m = readFirmwareGlobal(this.firmwareGlobals, 'atcToolChangeMode')
      if (m === 2) {
        return 'Automatic'
      }
      if (m === 1) {
        return 'Semi-Automatic'
      }
      return 'Manual'
    },

    jobOverflowWarningFlag() {
      return readFirmwareGlobal(this.firmwareGlobals, 'atcJobOverflowWarning') === true
    },

    atcStatusTableRows() {
      const len = readFirmwareGlobal(this.firmwareGlobals, 'atcJobSeqLength')
      const lenStr = typeof len === 'number' ? String(len) : '0'
      return [
        { key: 'en', label: 'ATC enabled', value: this.atcEnabledFlag ? 'Yes' : 'No' },
        { key: 'bm', label: 'Bay mode', value: this.atcBayModeLabel },
        { key: 'cm', label: 'Tool-change mode', value: this.atcToolChangeModeLabel },
        { key: 'mag', label: 'Magazines × slots', value: `${this.magCount} × ${this.slotsPer}` },
        { key: 'poc', label: 'Total bays (pockets)', value: String(this.pocketCount) },
        {
          key: 'ct',
          label: 'Current tool (spindle)',
          value: this.currentToolIndex >= 0 ? `T${this.currentToolIndex}` : '—'
        },
        { key: 'jlen', label: 'Job sequence length', value: lenStr },
        {
          key: 'jow',
          label: 'Job overflow warning',
          value: this.jobOverflowWarningFlag ? 'Yes' : 'No'
        }
      ]
    },

    resolvedToolValue() {
      const t = readFirmwareGlobal(this.firmwareGlobals, 'atcResolvedTool')
      return typeof t === 'number' ? t : -1
    },

    resolvedPocketValue() {
      const p = readFirmwareGlobal(this.firmwareGlobals, 'atcResolvedPocket')
      return typeof p === 'number' ? p : -1
    },

    currentJobRows() {
      const lenRaw = readFirmwareGlobal(this.firmwareGlobals, 'atcJobSeqLength')
      const n =
        typeof lenRaw === 'number' && lenRaw >= 0
          ? Math.min(Math.floor(lenRaw), ATC_JOB_SEQ_MAX)
          : 0
      if (n < 1) {
        return []
      }
      const toolsVec = this.readGlobalIntVector('atcJobSeqTool', ATC_JOB_SEQ_MAX)
      const ovVec = this.readGlobalIntVector('atcJobSeqOverflow', ATC_JOB_SEQ_MAX)
      const bayVec = this.readGlobalIntVector('atcJobSeqBay', ATC_JOB_SEQ_MAX)
      const doneVec = this.readGlobalIntVector('atcJobSeqComplete', ATC_JOB_SEQ_MAX)
      const tools = Array.isArray(this.model.tools) ? this.model.tools : []
      const ct = this.currentToolIndex
      const t2p = this.toolToPocket
      const rows = []
      for (let i = 0; i < n; i++) {
        const toolIndex = i < toolsVec.length ? toolsVec[i] : -1
        if (typeof toolIndex !== 'number' || toolIndex < 0) {
          continue
        }
        const overflow = this.jobSeqFlag(ovVec, i)
        let bayLabel = '—'
        if (overflow) {
          bayLabel = 'Queued'
        } else {
          const sb = i < bayVec.length ? bayVec[i] : -1
          if (typeof sb === 'number' && sb >= 1) {
            bayLabel = `Bay ${sb}`
          } else if (toolIndex < t2p.length && t2p[toolIndex] >= 0) {
            bayLabel = `Bay ${t2p[toolIndex] + 1}`
          }
        }
        const isActive = toolIndex === ct
        const complete = this.jobSeqFlag(doneVec, i)
        let statusLabel = 'Pending'
        let statusColor = 'grey'
        if (isActive) {
          statusLabel = 'Active'
          statusColor = 'success'
        } else if (complete) {
          statusLabel = 'Complete'
          statusColor = 'blue-grey'
        }
        rows.push({
          seq: i + 1,
          toolIndex,
          toolName: this.toolDisplayName(tools[toolIndex], toolIndex),
          bayLabel,
          statusLabel,
          statusColor,
          isActive,
          overflow
        })
      }
      return rows
    },

    magCount() {
      const n = readFirmwareGlobal(this.firmwareGlobals, 'atcMagazineCount')
      return typeof n === 'number' && n >= 1 ? n : 0
    },

    slotsPer() {
      const n = readFirmwareGlobal(this.firmwareGlobals, 'atcSlotsPerMagazine')
      return typeof n === 'number' && n >= 1 ? n : 0
    },

    pocketCount() {
      const n = readFirmwareGlobal(this.firmwareGlobals, 'atcPocketCount')
      if (typeof n === 'number' && n >= 1) {
        return n
      }
      if (this.magCount > 0 && this.slotsPer > 0) {
        return this.magCount * this.slotsPer
      }
      return 0
    },

    layoutOk() {
      return this.pocketCount > 0 && this.pocketToTool.length === this.pocketCount
    },

    pocketToTool() {
      const raw = readFirmwareGlobal(this.firmwareGlobals, 'atcPocketToTool')
      return this.normalizeVector(raw, this.pocketCount)
    },

    toolTableLength() {
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

    toolToPocket() {
      const raw = readFirmwareGlobal(this.firmwareGlobals, 'atcToolToPocket')
      return this.normalizeVector(raw, this.toolTableLength)
    },

    mosProbeToolIndex() {
      const id = readFirmwareGlobal(this.firmwareGlobals, 'mosPTID')
      return typeof id === 'number' && id >= 0 ? id : -1
    },

    toolLibraryRows() {
      const tools = this.model.tools
      if (!Array.isArray(tools)) {
        return []
      }
      const ct = this.currentToolIndex
      const probeIdx = this.mosProbeToolIndex
      const t2p = this.toolToPocket
      const rows = []
      for (let i = 0; i < tools.length; i++) {
        if (tools[i] == null) {
          continue
        }
        const inSpindle = i === ct
        const pocket = i < t2p.length ? t2p[i] : -1
        const inBay = typeof pocket === 'number' && pocket >= 0
        const isProbe = probeIdx >= 0 ? i === probeIdx : this.probeNameMatch(tools[i])
        const radius = readMosTTRadius(this.firmwareGlobals, i)
        const radiusLabel = radius != null ? String(radius) : '—'
        const description =
          tools[i] != null && typeof tools[i].name === 'string' && tools[i].name.length > 0
            ? tools[i].name
            : '—'
        let statusKind = 'unassigned'
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
          inSpindle,
          statusKind,
          bayOneBased
        })
      }
      return rows
    },

    magazineLoadedCount() {
      let n = 0
      for (let i = 0; i < this.pocketToTool.length; i++) {
        const t = this.pocketToTool[i]
        if (typeof t === 'number' && t >= 0) {
          n++
        }
      }
      return n
    },

    magazineEmptyCount() {
      return Math.max(0, this.pocketCount - this.magazineLoadedCount)
    },

    bayCardRows() {
      if (!this.layoutOk || this.magCount < 1 || this.slotsPer < 1) {
        return []
      }
      const tools = Array.isArray(this.model.tools) ? this.model.tools : []
      const ct = this.currentToolIndex
      const g = this.firmwareGlobals
      const rows = []
      for (let flat = 0; flat < this.pocketCount; flat++) {
        const rawT = flat < this.pocketToTool.length ? this.pocketToTool[flat] : -1
        const rrfTool = typeof rawT === 'number' ? rawT : -1
        const empty = rrfTool < 0
        const mag = Math.floor(flat / this.slotsPer)
        const localSlot = flat % this.slotsPer
        const inSpindle = !empty && rrfTool === ct
        const toolName = empty ? 'Empty' : this.toolDisplayName(tools[rrfTool], rrfTool)
        const r = empty ? null : readMosTTRadius(g, rrfTool)
        const radiusLabel = r != null ? String(r) : '—'
        let statusLabel = 'Empty'
        let statusChipColor = 'grey'
        if (!empty) {
          if (inSpindle) {
            statusLabel = 'In spindle'
            statusChipColor = 'success'
          } else {
            statusLabel = 'In magazine'
            statusChipColor = 'blue-grey'
          }
        }
        rows.push({
          flat,
          bayOneBased: flat + 1,
          locationLabel: `M${mag + 1}-S${localSlot + 1} · #${flat + 1}`,
          rrfTool,
          empty,
          inSpindle,
          toolName,
          radiusLabel,
          statusLabel,
          statusChipColor
        })
      }
      return rows
    },

    magazineItems() {
      const items = []
      for (let i = 0; i < this.magCount; i++) {
        items.push({ title: `ATC ${i + 1}`, value: i })
      }
      return items
    },

    toolSelectItems() {
      const tools = this.model.tools
      const out = [{ title: '(empty pocket)', value: -1 }]
      if (!Array.isArray(tools)) {
        return out
      }
      for (let i = 0; i < tools.length; i++) {
        if (tools[i] != null) {
          const name = tools[i].name ? String(tools[i].name) : ''
          out.push({
            title: name ? `T${i} — ${name}` : `T${i}`,
            value: i
          })
        }
      }
      return out
    },

    tableRows() {
      if (!this.layoutOk || this.magCount < 1 || this.slotsPer < 1) {
        return []
      }
      const mag = Math.min(Math.max(0, this.selectedMagazine), this.magCount - 1)
      const rows = []
      const base = mag * this.slotsPer
      for (let s = 0; s < this.slotsPer; s++) {
        const flat = base + s
        const rrfTool = flat < this.pocketToTool.length ? this.pocketToTool[flat] : -1
        rows.push({
          magazine: mag,
          localSlot: s,
          flat,
          rrfTool: typeof rrfTool === 'number' ? rrfTool : -1
        })
      }
      return rows
    },

    canApplyLayout() {
      return (
        Number.isFinite(this.formMagazines) &&
        Number.isFinite(this.formSlots) &&
        this.formMagazines >= 1 &&
        this.formMagazines <= 32 &&
        this.formSlots >= 1 &&
        this.formSlots <= 128 &&
        this.formMagazines * this.formSlots <= 256
      )
    },

    highlightFlatZeroBased() {
      if (this.highlightMode === 'tool') {
        const t = this.highlightTool
        if (typeof t !== 'number' || t < 0 || !this.pocketToTool.length) {
          return -1
        }
        for (let i = 0; i < this.pocketToTool.length; i++) {
          if (this.pocketToTool[i] === t) {
            return i
          }
        }
        return -1
      }
      const loc = this.highlightLocation
      if (!Number.isFinite(loc) || loc < 1) {
        return -1
      }
      return loc - 1
    },

    svgViewBox() {
      const w = this.slotsPer * this.slotW + 8
      const h = this.magCount * (this.slotH + this.magPad) + 8
      return `0 0 ${w} ${Math.max(h, 48)}`
    },

    magazineViz() {
      const out = []
      if (!this.layoutOk || this.magCount < 1 || this.slotsPer < 1) {
        return out
      }
      const hi = this.highlightFlatZeroBased
      for (let m = 0; m < this.magCount; m++) {
        const cells = []
        for (let s = 0; s < this.slotsPer; s++) {
          const flat = m * this.slotsPer + s
          const tool = flat < this.pocketToTool.length ? this.pocketToTool[flat] : -1
          cells.push({
            flat,
            x: 4 + s * this.slotW,
            label: String(flat + 1),
            filled: typeof tool === 'number' && tool >= 0,
            highlight: flat === hi
          })
        }
        out.push({
          label: `ATC ${m + 1}`,
          cells
        })
      }
      return out
    }
  },

    watch: {
    jobRunning(isRun) {
      if (!isRun && this.mainTab === 2) {
        this.mainTab = 0
      }
    },

    model: {
      deep: true,
      handler() {
        const st = this.rrfState.status
        if (
          this.presentingPocket !== null &&
          st === 'idle' &&
          this.prevMachineStatus != null &&
          this.prevMachineStatus !== 'idle'
        ) {
          this.clearPresentSpinner()
        }
        this.prevMachineStatus = st
      }
    },

    firmwareGlobals: {
      deep: true,
      immediate: true,
      handler() {
        if (this.magCount >= 1) {
          this.formMagazines = this.magCount
        }
        if (this.slotsPer >= 1) {
          this.formSlots = this.slotsPer
        }
        if (this.selectedMagazine >= this.magCount) {
          this.selectedMagazine = Math.max(0, this.magCount - 1)
        }

        if (
          !this.autoInitDone &&
          this.magCount >= 1 &&
          this.slotsPer >= 1 &&
          this.pocketCount >= 1 &&
          this.pocketToTool.length !== this.pocketCount
        ) {
          this.autoInitDone = true
          this.sendCode(`M${MOS_ATC_M.init}`)
        }
      }
    }
  },

  mounted() {
    this.prevMachineStatus = this.rrfState.status
    if (this.magCount >= 1) {
      this.formMagazines = this.magCount
    }
    if (this.slotsPer >= 1) {
      this.formSlots = this.slotsPer
    }
  },

  beforeDestroy() {
    this.clearPresentSpinner()
    if (this.presentSpinTimeoutId != null) {
      clearTimeout(this.presentSpinTimeoutId)
      this.presentSpinTimeoutId = null
    }
  },

  methods: {
    readGlobalIntVector(key, maxLen) {
      const raw = readFirmwareGlobal(this.firmwareGlobals, key)
      const out = []
      if (Array.isArray(raw)) {
        for (let i = 0; i < maxLen; i++) {
          const v = raw[i]
          out.push(typeof v === 'number' ? v : -1)
        }
        return out
      }
      if (raw && typeof raw === 'object') {
        for (let i = 0; i < maxLen; i++) {
          const v = raw[i]
          out.push(typeof v === 'number' ? v : -1)
        }
        return out
      }
      for (let i = 0; i < maxLen; i++) {
        out.push(-1)
      }
      return out
    },

    jobSeqFlag(vec, i) {
      if (i < 0 || i >= vec.length) {
        return false
      }
      const v = vec[i]
      return v === 1
    },

    buildAtcStatusDump() {
      const lines = []
      lines.push('=== mos-atc STC status ===')
      for (let r = 0; r < this.atcStatusTableRows.length; r++) {
        const row = this.atcStatusTableRows[r]
        lines.push(`${row.label}: ${row.value}`)
      }
      lines.push('')
      lines.push('--- Bay map (flat pocket -> RRF tool, -1 empty) ---')
      for (let p = 0; p < this.pocketToTool.length; p++) {
        const t = this.pocketToTool[p]
        lines.push(`  pocket ${p} (Bay ${p + 1}): ${typeof t === 'number' && t >= 0 ? 'T' + t : 'empty'}`)
      }
      lines.push('=== end ===')
      return lines.join('\n')
    },

    runStatusDump() {
      this.statusDumpText = this.buildAtcStatusDump()
      this.statusDumpExpanded = true
      this.sendCode(`M${MOS_ATC_M.statusDump}`)
    },

    confirmUnloadAll() {
      this.unloadAllDialog = false
      this.sendCode(`M${MOS_ATC_M.unloadAll}`)
    },

    runRecoveryAfterAbort() {
      this.sendCode(`M${MOS_ATC_M.unloadAll} R1`)
    },

    runBayTest() {
      if (this.bayTestDisabled) {
        return
      }
      this.sendCode(`M${MOS_ATC_M.bayTest}`)
    },

    runManualPresentBay() {
      if (this.manualPresentDisabled) {
        return
      }
      const b = Math.floor(this.manualPresentBay)
      this.sendCode(`M${MOS_ATC_M.presentBay} B${b}`)
    },

    runResolvePocket() {
      if (this.resolvePocketDisabled) {
        return
      }
      const p = Math.floor(this.resolvePocketInput)
      this.sendCode(`M${MOS_ATC_M.resolvePocket} P${p}`)
    },

    runResolveTool() {
      if (this.resolveToolDisabled) {
        return
      }
      const r = Math.floor(this.resolveToolInput)
      this.sendCode(`M${MOS_ATC_M.resolveTool} R${r}`)
    },

    runSeedIdentity() {
      this.sendCode(`M${MOS_ATC_M.seedIdentity}`)
    },

    runSelectFromPocketDemo() {
      if (this.selectDemoDisabled) {
        return
      }
      const p = Math.floor(this.selectDemoPocketInput)
      this.sendCode(`M${MOS_ATC_M.selectFromPocketDemo} P${p}`)
    },

    probeNameMatch(toolObj) {
      if (!toolObj || !toolObj.name) {
        return false
      }
      return String(toolObj.name).toLowerCase().includes('touch probe')
    },

    toolDisplayName(toolObj, index) {
      if (toolObj && toolObj.name) {
        return String(toolObj.name)
      }
      return `T${index}`
    },

    clearBayDisabled(bay) {
      if (!this.magazineActionsEnabled || this.jobRunning) {
        return true
      }
      if (bay.empty) {
        return true
      }
      if (bay.inSpindle) {
        return true
      }
      return false
    },

    clearPresentSpinner() {
      this.presentingPocket = null
      if (this.presentSpinTimeoutId != null) {
        clearTimeout(this.presentSpinTimeoutId)
        this.presentSpinTimeoutId = null
      }
    },

    presentBay(flat) {
      if (this.presentBayDisabled) {
        return
      }
      this.presentingPocket = flat
      if (this.presentSpinTimeoutId != null) {
        clearTimeout(this.presentSpinTimeoutId)
      }
      this.presentSpinTimeoutId = setTimeout(() => {
        this.presentSpinTimeoutId = null
        this.presentingPocket = null
      }, 120000)
      const pending = this.sendCode(`M${MOS_ATC_M.presentBay} P${flat}`)
      if (pending != null && typeof pending.then === 'function') {
        pending.then(() => {
          setTimeout(() => {
            if (this.presentingPocket === flat) {
              this.clearPresentSpinner()
            }
          }, 400)
        })
      }
    },

    clearBay(bayOneBased) {
      if (!this.magazineActionsEnabled || this.jobRunning) {
        return
      }
      this.sendCode(`M${MOS_ATC_M.clearBay} B${bayOneBased} T-1`)
    },

    normalizeVector(raw: unknown, length: number): number[] {
      return normalizeAtcVector(raw, length)
    },

    applyLayout() {
      if (!this.canApplyLayout) {
        return
      }
      const ok = window.confirm(
        'Apply layout on the machine? This clears all pocket-to-tool mappings (M876).'
      )
      if (!ok) {
        return
      }
      const cmd = `M${MOS_ATC_M.setLayout} N${Math.floor(this.formMagazines)} S${Math.floor(this.formSlots)}`
      this.sendCode(cmd)
    },

    assignTool(flat, tool) {
      if (!this.layoutOk || flat < 0 || flat >= this.pocketCount) {
        return
      }
      const r = typeof tool === 'number' ? tool : -1
      const cmd = `M${MOS_ATC_M.mapPocket} P${flat} R${r}`
      this.sendCode(cmd)
    },

    onSlotToolInput(row, value) {
      this.assignTool(row.flat, value)
    }
  }
})
</script>

<style scoped>
.font-mono {
  font-family: monospace;
}
.mos-atc-tool-lib-table .mos-atc-row-spindle {
  background-color: rgba(76, 175, 80, 0.12);
}
.mos-atc-bay-card--spindle {
  border: 2px solid #4caf50 !important;
}
.mos-atc-job-table .mos-atc-job-row-active {
  background-color: rgba(76, 175, 80, 0.14);
  font-weight: 700;
}
.mos-atc-job-table .mos-atc-job-row-overflow {
  background-color: rgba(255, 193, 7, 0.18);
}
.mos-atc-dump {
  white-space: pre-wrap;
  font-family: monospace;
  max-height: 360px;
  overflow: auto;
}
</style>
