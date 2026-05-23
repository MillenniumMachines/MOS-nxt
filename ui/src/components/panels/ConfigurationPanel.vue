<template>
  <v-card>
    <v-card-title>
      <v-icon left>mdi-cog</v-icon>
      {{ $t('plugins.next.panels.configuration.caption') }}
      <v-spacer />
      <div v-if="!isConnected || !configurationUiAllowed" class="d-flex align-center">
        <v-icon small class="mr-2" color="warning">{{ !isConnected ? 'mdi-lan-disconnect' : 'mdi-alert-circle-outline' }}</v-icon>
        <span class="text-caption">{{
          !isConnected ? $t('plugins.next.messages.disconnectedShort') : $t('plugins.next.messages.notReadyShort')
        }}</span>
      </div>
    </v-card-title>

    <v-card-text>
      <v-alert type="info" outlined dense class="mb-4">
        <v-icon left small>mdi-information</v-icon>
        Changes are saved immediately to the object model. Use "Save Configuration" to persist to nxt-user-vars.g
      </v-alert>

      <!-- Configuration Sections -->
      <v-expansion-panels v-model="openPanels" multiple class="mb-4">
        <!-- Board & kit -->
        <v-expansion-panel>
          <v-expansion-panel-header>
            <div>
              <v-icon left>mdi-circuit-board</v-icon>
              <strong>{{ $t('plugins.next.panels.configuration.boardSection') }}</strong>
              <v-spacer />
              <v-icon
                v-if="boardProfileMismatch || scyllaVoltageMissing"
                small
                color="warning"
                class="mr-2"
              >mdi-alert</v-icon>
            </div>
          </v-expansion-panel-header>
          <v-expansion-panel-content>
            <v-alert type="info" dense outlined class="mb-3">
              <span class="text-caption">{{ $t('plugins.next.panels.configuration.boardBootstrapHint') }}</span>
            </v-alert>
            <v-alert type="info" dense outlined class="mb-3">
              <span class="text-caption">{{ $t('plugins.next.panels.configuration.boardLoadOrderHint') }}</span>
            </v-alert>
            <p class="text-caption grey--text mb-2">{{ $t('plugins.next.panels.configuration.boardDetected') }}</p>
            <v-chip
              v-for="(b, i) in machineBoardsList"
              :key="'brd-' + i"
              small
              class="mr-2 mb-2"
              outlined
            >
              [{{ i }}] {{ b.shortName || '—' }} — {{ b.name || '' }}
            </v-chip>
            <p v-if="machineBoardsList.length === 0" class="text-caption grey--text">—</p>
            <v-row class="mt-2">
              <v-col cols="12" md="6">
                <v-text-field
                  :value="primaryBoardShortName"
                  :label="$t('plugins.next.panels.configuration.boardPrimaryShortName')"
                  readonly
                  dense
                  outlined
                  hide-details
                />
              </v-col>
              <v-col cols="12" md="6">
                <v-select
                  :value="configDraft.nxtPlatformProfile"
                  :items="nxtPlatformSelectItems"
                  item-text="title"
                  item-value="value"
                  :label="$t('plugins.next.panels.configuration.boardPlatform')"
                  clearable
                  :disabled="uiFrozen"
                  hide-details
                  @change="onPlatformProfileChange"
                />
              </v-col>
            </v-row>
            <v-row>
              <v-col cols="12" md="6">
                <v-select
                  :value="configDraft.nxtBoardShortNameOverride != null ? String(configDraft.nxtBoardShortNameOverride) : undefined"
                  :items="boardProfileSelectItems"
                  item-text="title"
                  item-value="value"
                  :label="$t('plugins.next.panels.configuration.boardProfile')"
                  clearable
                  :placeholder="primaryBoardShortName && primaryBoardShortName !== '—' ? `Auto (${primaryBoardShortName})` : 'Auto (object model)'"
                  :disabled="uiFrozen || boardProfileSelectItems.length === 0"
                  hide-details
                  @change="onBoardProfileShortNameChange"
                />
                <p v-if="boardProfileSelectItems.length === 0" class="text-caption grey--text mt-1">
                  {{ $t('plugins.next.panels.configuration.boardNoKitsPlatform') }}
                </p>
              </v-col>
              <v-col cols="12" md="6">
                <v-select
                  v-if="boardNeedsMotorVoltage"
                  :value="scyllaMotorVoltageUiValue"
                  :items="NXT_SCYLLA_MOTOR_VOLTAGE_ITEMS"
                  item-text="title"
                  item-value="value"
                  :label="$t('plugins.next.panels.configuration.boardMotorVoltage')"
                  :disabled="uiFrozen"
                  hide-details
                  @change="onBoardMotorVoltageChange"
                />
              </v-col>
            </v-row>
            <v-row>
              <v-col cols="12" md="6">
                <v-select
                  :value="boardBootstrapModeUi"
                  :items="boardBootstrapModeItems"
                  item-text="title"
                  item-value="value"
                  :label="$t('plugins.next.panels.configuration.boardBootstrapMode')"
                  :disabled="uiFrozen"
                  hide-details
                  @change="onBoardBootstrapModeChange"
                />
              </v-col>
            </v-row>
            <v-alert v-if="boardProfileMismatch" type="warning" dense outlined class="mt-3">
              {{ $t('plugins.next.panels.configuration.boardMismatch') }}
            </v-alert>
            <v-alert v-if="scyllaVoltageMissing" type="warning" dense outlined class="mt-3">
              {{ $t('plugins.next.panels.configuration.boardVoltageMissing') }}
            </v-alert>
            <v-alert
              v-for="(msg, i) in boardBootstrapWarnings"
              :key="'boot-warn-' + i"
              type="warning"
              dense
              outlined
              class="mt-3"
            >
              {{ msg }}
            </v-alert>
            <v-alert
              v-for="(msg, i) in boardPackWarnings"
              :key="'pack-warn-' + i"
              type="warning"
              dense
              outlined
              class="mt-3"
            >
              {{ msg }}
            </v-alert>
            <v-alert
              v-for="(msg, i) in sdConfigWarnings"
              :key="'sd-warn-' + i"
              type="warning"
              dense
              outlined
              class="mt-3"
            >
              {{ msg }}
            </v-alert>
            <v-textarea
              :value="kitEntryPathForUi"
              :label="$t('plugins.next.panels.configuration.boardKitEntry')"
              readonly
              outlined
              dense
              rows="2"
              class="mt-3"
              hide-details
            />
            <div
              v-if="
                selectedPlatformStructure.sysDeployFiles.length ||
                selectedPlatformStructure.boardEntryPaths.length ||
                selectedPlatformStructure.machineEntryPath
              "
              class="mt-3"
            >
              <p class="text-caption font-weight-medium mb-1">{{ $t('plugins.next.panels.configuration.boardPlatformTree') }}</p>
              <ul class="text-caption grey--text text--darken-1 pl-4 mb-2">
                <li v-if="selectedPlatformStructure.machineEntryPath">
                  Boot machine: {{ selectedPlatformStructure.machineEntryPath }}
                </li>
                <li v-for="f in selectedPlatformStructure.sysDeployFiles" :key="'sd-' + f">
                  Deploy homing: 0:/sys/{{ f }}
                </li>
                <li v-for="p in selectedPlatformStructure.boardEntryPaths" :key="'ent-' + p">
                  Boot board: {{ p }}
                </li>
              </ul>
              <p class="text-caption grey--text mb-2">{{ $t('plugins.next.panels.configuration.boardHomingDocHint') }}</p>
            </div>
            <div class="d-flex flex-wrap mt-2" style="gap: 8px">
              <v-btn
                small
                outlined
                :disabled="!isConnected"
                :loading="boardStateChecking"
                @click="runBoardStateChecks"
              >
                <v-icon small left>mdi-folder-search</v-icon>
                {{ $t('plugins.next.panels.configuration.boardCheckSd') }}
              </v-btn>
              <v-btn
                small
                outlined
                color="primary"
                :disabled="!isConnected || uiFrozen || !canDeployPlatformSysFiles"
                :loading="sysDeploying"
                @click="applyPlatformSysFiles"
              >
                <v-icon small left>mdi-file-upload</v-icon>
                {{ $t('plugins.next.panels.configuration.boardApplySysFiles') }}
              </v-btn>
              <v-btn small outlined color="primary" :disabled="!isConnected" @click="copyBoardConfigHint">
                <v-icon small left>mdi-content-copy</v-icon>
                {{ $t('plugins.next.panels.configuration.boardCopySnippet') }}
              </v-btn>
              <v-btn
                small
                outlined
                :disabled="!isConnected || uiFrozen || pinmapSaving"
                :loading="pinmapSaving"
                @click="savePinmapStub"
              >
                {{ $t('plugins.next.panels.configuration.boardSavePinmap') }}
              </v-btn>
            </div>
            <p class="text-caption grey--text mt-2 mb-0">{{ $t('plugins.next.panels.configuration.boardPinmapHint') }}</p>
          </v-expansion-panel-content>
        </v-expansion-panel>

        <!-- Spindle Configuration -->
        <v-expansion-panel>
          <v-expansion-panel-header>
            <div>
              <v-icon left>mdi-fan</v-icon>
              <strong>Spindle Configuration</strong>
            </div>
          </v-expansion-panel-header>
          <v-expansion-panel-content>
            <v-row>
              <v-col cols="12">
                <v-select
                  :value="configDraft.nxtSpindleID"
                  :items="availableSpindles"
                  item-text="name"
                  item-value="id"
                  label="Spindle"
                  :disabled="uiFrozen"
                  @input="onConfigDraftSelect('nxtSpindleID', $event)"
                  hint="Select configured spindle"
                  persistent-hint
                  clearable
                >
                  <template v-slot:item="{ item }">
                    <v-list-item-content>
                      <v-list-item-title>{{ item.name }}</v-list-item-title>
                      <v-list-item-subtitle>ID: {{ item.id }}</v-list-item-subtitle>
                    </v-list-item-content>
                  </template>
                  <template v-slot:append-outer>
                    <v-tooltip top>
                      <template v-slot:activator="{ on }">
                        <v-btn
                          icon
                          small
                          @mousedown="startSpindleTest"
                          @mouseup="stopSpindleTest"
                          @mouseleave="stopSpindleTest"
                          @touchstart="startSpindleTest"
                          @touchend="stopSpindleTest"
                          :disabled="uiFrozen || configDraft.nxtSpindleID === null"
                          :color="spindleTesting ? 'primary' : ''"
                          v-on="on"
                        >
                          <v-icon small>{{ spindleTesting ? 'mdi-fan' : 'mdi-test-tube' }}</v-icon>
                        </v-btn>
                      </template>
                      <span>{{ spindleTesting ? 'Release to Stop' : 'Hold to Test Spindle' }}</span>
                    </v-tooltip>
                  </template>
                </v-select>
              </v-col>
            </v-row>
            <v-row>
              <v-col cols="12" md="6">
                <v-text-field
                  :value="configDraft.nxtSpindleAccelSec"
                  label="Acceleration Time (s)"
                  type="number"
                  step="0.1"
                  :disabled="uiFrozen"
                  @input="onConfigDraftNumber('nxtSpindleAccelSec', $event)"
                  hint="Time for spindle to reach speed"
                  persistent-hint
                >
                  <template v-slot:append-outer>
                    <v-tooltip top>
                      <template v-slot:activator="{ on }">
                        <v-btn
                          icon
                          small
                          @mousedown="startAccelerationMeasurement"
                          @mouseup="stopAccelerationMeasurement"
                          @mouseleave="stopAccelerationMeasurement"
                          @touchstart="startAccelerationMeasurement"
                          @touchend="stopAccelerationMeasurement"
                          :disabled="uiFrozen || configDraft.nxtSpindleID === null"
                          :color="measuringAccel ? 'primary' : ''"
                          v-on="on"
                        >
                          <v-icon small :class="{ 'rotating-icon': measuringAccel }">
                            {{ measuringAccel ? 'mdi-fan' : 'mdi-timer-play' }}
                          </v-icon>
                        </v-btn>
                      </template>
                      <span>{{ measuringAccel ? 'Release when at full speed' : 'Hold to measure acceleration' }}</span>
                    </v-tooltip>
                  </template>
                </v-text-field>
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field
                  :value="configDraft.nxtSpindleDecelSec"
                  label="Deceleration Time (s)"
                  type="number"
                  step="0.1"
                  :disabled="uiFrozen"
                  @input="onConfigDraftNumber('nxtSpindleDecelSec', $event)"
                  hint="Time for spindle to stop"
                  persistent-hint
                >
                  <template v-slot:append-outer>
                    <v-tooltip top>
                      <template v-slot:activator="{ on }">
                        <v-btn
                          icon
                          small
                          @mousedown="startDecelerationMeasurement"
                          @mouseup="stopDecelerationMeasurement"
                          @mouseleave="stopDecelerationMeasurement"
                          @touchstart="startDecelerationMeasurement"
                          @touchend="stopDecelerationMeasurement"
                          :disabled="uiFrozen || configDraft.nxtSpindleID === null || configDraft.nxtSpindleAccelSec === null || configDraft.nxtSpindleAccelSec === undefined"
                          :color="measuringDecel ? 'primary' : ''"
                          v-on="on"
                        >
                          <v-icon small :class="{ 'rotating-icon': measuringDecel }">
                            {{ measuringDecel ? 'mdi-fan' : 'mdi-timer-stop' }}
                          </v-icon>
                        </v-btn>
                      </template>
                      <span>{{ measuringDecel ? 'Release when fully stopped' : 'Hold to measure deceleration (requires acceleration time)' }}</span>
                    </v-tooltip>
                  </template>
                </v-text-field>
              </v-col>
            </v-row>
          </v-expansion-panel-content>
        </v-expansion-panel>

        <!-- Touch Probe Configuration -->
        <v-expansion-panel>
          <v-expansion-panel-header>
            <div>
              <v-icon left>mdi-target</v-icon>
              <strong>Touch Probe Configuration</strong>
              <v-spacer />
              <v-icon v-if="touchProbeRequirementsMet" small color="success" class="mr-2">mdi-check-circle</v-icon>
              <v-icon v-else small color="warning" class="mr-2">mdi-alert-circle</v-icon>
            </div>
          </v-expansion-panel-header>
          <v-expansion-panel-content>
            <v-alert v-if="!touchProbeRequirementsMet" type="warning" dense outlined class="mb-4">
              <div class="text-caption">{{ touchProbeRequirementsMessage }}</div>
            </v-alert>

            <v-row>
              <v-col cols="12">
                <v-select
                  :value="configDraft.nxtTouchProbeID"
                  :items="availableProbes"
                  item-text="name"
                  item-value="id"
                  label="Touch Probe Sensor *"
                  :disabled="uiFrozen"
                  @input="onConfigDraftSelect('nxtTouchProbeID', $event)"
                  hint="Required - Select configured probe"
                  persistent-hint
                  :error="configDraft.nxtTouchProbeID === null"
                  clearable
                >
                  <template v-slot:item="{ item }">
                    <v-list-item-content>
                      <v-list-item-title>{{ item.name }}</v-list-item-title>
                      <v-list-item-subtitle>ID: {{ item.id }} | Type: {{ item.type }}</v-list-item-subtitle>
                    </v-list-item-content>
                  </template>
                  <template v-slot:append-outer>
                    <v-chip
                      v-if="configDraft.nxtTouchProbeID !== null"
                      small
                      :color="touchProbeTriggered ? 'success' : 'grey'"
                      @click="testTouchProbe"
                    >
                      <v-icon small left>{{ touchProbeTriggered ? 'mdi-check-circle' : 'mdi-circle-outline' }}</v-icon>
                      {{ touchProbeTriggered ? 'Triggered' : 'Test' }}
                    </v-chip>
                  </template>
                </v-select>
              </v-col>
            </v-row>
            <v-row>
              <v-col cols="12" md="6">
                <v-text-field
                  :value="configDraft.nxtProbeTipRadius"
                  label="Probe Tip Radius (mm) *"
                  type="number"
                  step="0.001"
                  :disabled="uiFrozen"
                  @input="onConfigDraftNumber('nxtProbeTipRadius', $event)"
                  hint="Required - For horizontal compensation"
                  persistent-hint
                  :error="configDraft.nxtProbeTipRadius === null || configDraft.nxtProbeTipRadius === 0"
                />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field
                  :value="configDraft.nxtProbeDeflection"
                  label="Probe Deflection (mm) *"
                  type="number"
                  step="0.001"
                  :disabled="uiFrozen"
                  @input="onConfigDraftNumber('nxtProbeDeflection', $event)"
                  hint="Required - Measured deflection value (0 if not measured)"
                  persistent-hint
                  :error="configDraft.nxtProbeDeflection === null"
                >
                  <template v-slot:append-outer>
                    <v-tooltip top>
                      <template v-slot:activator="{ on }">
                        <v-btn
                          icon
                          small
                          @click="navigateToCalibration"
                          :disabled="uiFrozen"
                          v-on="on"
                        >
                          <v-icon small>mdi-ruler</v-icon>
                        </v-btn>
                      </template>
                      <span>Go to Calibration</span>
                    </v-tooltip>
                  </template>
                </v-text-field>
              </v-col>
            </v-row>
            <v-alert type="info" dense outlined class="mb-2">
              <span class="text-caption">
                Probe repeatability (G6512 sample count, pair tolerance, retries) uses defaults from
                <code>nxt-vars.g</code>. Copy <code>nxt-user-overrides.g.example</code> to
                <code>0:/sys/nxt-user-overrides.g</code> to override (loaded last in <code>nxt.g</code>).
              </span>
            </v-alert>

            <!-- Feature Toggle -->
            <v-row class="mt-4">
              <v-col cols="12">
                <v-divider class="mb-4" />
                <v-switch
                  :input-value="configDraft.nxtFeatureTouchProbe"
                  label="Enable Touch Probe Feature"
                  :disabled="uiFrozen || !touchProbeRequirementsMet"
                  @change="updateFeature('nxtFeatureTouchProbe', $event)"
                  :hint="touchProbeRequirementsMessage"
                  persistent-hint
                  class="mt-0"
                >
                  <template v-slot:prepend>
                    <v-icon :color="touchProbeRequirementsMet ? 'success' : 'warning'">
                      {{ touchProbeRequirementsMet ? 'mdi-check-circle' : 'mdi-alert-circle' }}
                    </v-icon>
                  </template>
                </v-switch>
              </v-col>
            </v-row>
          </v-expansion-panel-content>
        </v-expansion-panel>

        <!-- Tool Setter Configuration -->
        <v-expansion-panel>
          <v-expansion-panel-header>
            <div>
              <v-icon left>mdi-wrench</v-icon>
              <strong>Tool Setter Configuration</strong>
              <v-spacer />
              <v-icon v-if="toolSetterRequirementsMet" small color="success" class="mr-2">mdi-check-circle</v-icon>
              <v-icon v-else small color="warning" class="mr-2">mdi-alert-circle</v-icon>
            </div>
          </v-expansion-panel-header>
          <v-expansion-panel-content>
            <v-alert v-if="!toolSetterRequirementsMet" type="warning" dense outlined class="mb-4">
              <div class="text-caption">{{ toolSetterRequirementsMessage }}</div>
            </v-alert>

            <v-row>
              <v-col cols="12">
                <v-select
                  :value="configDraft.nxtToolSetterID"
                  :items="availableProbes"
                  item-text="name"
                  item-value="id"
                  label="Tool Setter Sensor *"
                  :disabled="uiFrozen"
                  @input="onConfigDraftSelect('nxtToolSetterID', $event)"
                  hint="Required - Select configured probe"
                  persistent-hint
                  :error="configDraft.nxtToolSetterID === null"
                  clearable
                >
                  <template v-slot:item="{ item }">
                    <v-list-item-content>
                      <v-list-item-title>{{ item.name }}</v-list-item-title>
                      <v-list-item-subtitle>ID: {{ item.id }} | Type: {{ item.type }}</v-list-item-subtitle>
                    </v-list-item-content>
                  </template>
                  <template v-slot:append-outer>
                    <v-chip
                      v-if="configDraft.nxtToolSetterID !== null"
                      small
                      :color="toolSetterTriggered ? 'success' : 'grey'"
                      @click="testToolSetter"
                    >
                      <v-icon small left>{{ toolSetterTriggered ? 'mdi-check-circle' : 'mdi-circle-outline' }}</v-icon>
                      {{ toolSetterTriggered ? 'Triggered' : 'Test' }}
                    </v-chip>
                  </template>
                </v-select>
              </v-col>
            </v-row>
            <v-row>
              <v-col cols="12">
                <v-text-field
                  :value="formatToolSetterPos"
                  label="Tool Setter Position [X, Y, Z] *"
                  readonly
                  hint="Required - Position in machine coordinates"
                  persistent-hint
                  :error="!configDraft.nxtToolSetterPos || !Array.isArray(configDraft.nxtToolSetterPos) || configDraft.nxtToolSetterPos.length !== 3"
                >
                  <template v-slot:append>
                    <v-tooltip top>
                      <template v-slot:activator="{ on }">
                        <v-btn
                          icon
                          small
                          @click="setCurrentPositionAsToolSetter"
                          :disabled="uiFrozen || !allAxesHomed"
                          v-on="on"
                        >
                          <v-icon small>mdi-crosshairs-gps</v-icon>
                        </v-btn>
                      </template>
                      <span>Set Current Position</span>
                    </v-tooltip>
                    <v-btn
                      icon
                      small
                      @click="showToolSetterPosDialog = true"
                      :disabled="uiFrozen"
                    >
                      <v-icon small>mdi-pencil</v-icon>
                    </v-btn>
                  </template>
                </v-text-field>
              </v-col>
            </v-row>

            <!-- Feature Toggle -->
            <v-row class="mt-4">
              <v-col cols="12">
                <v-divider class="mb-4" />
                <v-switch
                  :input-value="configDraft.nxtFeatureToolSetter"
                  label="Enable Tool Setter Feature"
                  :disabled="uiFrozen || !toolSetterRequirementsMet"
                  @change="updateFeature('nxtFeatureToolSetter', $event)"
                  :hint="toolSetterRequirementsMessage"
                  persistent-hint
                  class="mt-0"
                >
                  <template v-slot:prepend>
                    <v-icon :color="toolSetterRequirementsMet ? 'success' : 'warning'">
                      {{ toolSetterRequirementsMet ? 'mdi-check-circle' : 'mdi-alert-circle' }}
                    </v-icon>
                  </template>
                </v-switch>
              </v-col>
            </v-row>
          </v-expansion-panel-content>
        </v-expansion-panel>

        <!-- Coolant Control Configuration -->
        <v-expansion-panel>
          <v-expansion-panel-header>
            <div>
              <v-icon left>mdi-water</v-icon>
              <strong>Coolant Control Configuration</strong>
              <v-spacer />
              <v-icon v-if="coolantControlRequirementsMet" small color="success" class="mr-2">mdi-check-circle</v-icon>
              <v-icon v-else small color="warning" class="mr-2">mdi-alert-circle</v-icon>
            </div>
          </v-expansion-panel-header>
          <v-expansion-panel-content>
            <v-alert v-if="!coolantControlRequirementsMet" type="warning" dense outlined class="mb-4">
              <div class="text-caption">{{ coolantControlRequirementsMessage }}</div>
            </v-alert>

            <v-row>
              <v-col cols="12" md="4">
                <v-select
                  :value="configDraft.nxtCoolantAirID"
                  :items="boardKitGpOutputs"
                  item-text="name"
                  item-value="id"
                  label="Air Blast Output"
                  :disabled="uiFrozen"
                  @input="onConfigDraftSelect('nxtCoolantAirID', $event)"
                  hint="Select GP Output port"
                  persistent-hint
                  clearable
                >
                  <template v-slot:item="{ item }">
                    <v-list-item-content>
                      <v-list-item-title>{{ item.name }}</v-list-item-title>
                    </v-list-item-content>
                  </template>
                </v-select>
              </v-col>
              <v-col cols="12" md="4">
                <v-select
                  :value="configDraft.nxtCoolantMistID"
                  :items="boardKitGpOutputs"
                  item-text="name"
                  item-value="id"
                  label="Mist Coolant Output"
                  :disabled="uiFrozen"
                  @input="onConfigDraftSelect('nxtCoolantMistID', $event)"
                  hint="Select GP Output port"
                  persistent-hint
                  clearable
                >
                  <template v-slot:item="{ item }">
                    <v-list-item-content>
                      <v-list-item-title>{{ item.name }}</v-list-item-title>
                    </v-list-item-content>
                  </template>
                </v-select>
              </v-col>
              <v-col cols="12" md="4">
                <v-select
                  :value="configDraft.nxtCoolantFloodID"
                  :items="boardKitGpOutputs"
                  item-text="name"
                  item-value="id"
                  label="Flood Coolant Output"
                  :disabled="uiFrozen"
                  @input="onConfigDraftSelect('nxtCoolantFloodID', $event)"
                  hint="Select GP Output port"
                  persistent-hint
                  clearable
                >
                  <template v-slot:item="{ item }">
                    <v-list-item-content>
                      <v-list-item-title>{{ item.name }}</v-list-item-title>
                    </v-list-item-content>
                  </template>
                </v-select>
              </v-col>
            </v-row>

            <!-- Feature Toggle -->
            <v-row class="mt-4">
              <v-col cols="12">
                <v-divider class="mb-4" />
                <v-switch
                  :input-value="configDraft.nxtFeatureCoolantControl"
                  label="Enable Coolant Control Feature"
                  :disabled="uiFrozen || !coolantControlRequirementsMet"
                  @change="updateFeature('nxtFeatureCoolantControl', $event)"
                  :hint="coolantControlRequirementsMessage"
                  persistent-hint
                  class="mt-0"
                >
                  <template v-slot:prepend>
                    <v-icon :color="coolantControlRequirementsMet ? 'success' : 'warning'">
                      {{ coolantControlRequirementsMet ? 'mdi-check-circle' : 'mdi-alert-circle' }}
                    </v-icon>
                  </template>
                </v-switch>
              </v-col>
            </v-row>
          </v-expansion-panel-content>
        </v-expansion-panel>

        <!-- NeXT globals snapshot (read-only) -->
        <v-expansion-panel>
          <v-expansion-panel-header>
            <div>
              <v-icon left>mdi-database-eye</v-icon>
              <strong>{{ $t('plugins.next.panels.configuration.globalsSnapshotTitle') }}</strong>
            </div>
          </v-expansion-panel-header>
          <v-expansion-panel-content>
            <p class="body-2 grey--text text--darken-1 mb-3">
              {{ $t('plugins.next.panels.configuration.globalsSnapshotIntro') }}
            </p>
            <div class="d-flex flex-wrap mb-2" style="gap: 8px">
              <v-btn small outlined color="primary" :disabled="!isConnected" @click="copyNxtGlobalsSnapshot">
                <v-icon small left>mdi-content-copy</v-icon>
                {{ $t('plugins.next.panels.configuration.globalsSnapshotCopy') }}
              </v-btn>
            </div>
            <v-simple-table dense class="nxt-globals-snapshot-table">
              <template #default>
                <thead>
                  <tr>
                    <th class="text-left text-no-wrap">{{ $t('plugins.next.panels.configuration.globalsColKey') }}</th>
                    <th class="text-left">{{ $t('plugins.next.panels.configuration.globalsColDescription') }}</th>
                    <th class="text-left">{{ $t('plugins.next.panels.configuration.globalsColValue') }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="row in nxtGlobalsSnapshotRows"
                    :key="row.key"
                    :class="{ 'grey lighten-4': row.missing }"
                  >
                    <td class="text-no-wrap font-mono">{{ row.key }}</td>
                    <td class="body-2">{{ row.description }}</td>
                    <td class="font-mono body-2 nxt-globals-snapshot-value">{{ row.valueText }}</td>
                  </tr>
                </tbody>
              </template>
            </v-simple-table>
          </v-expansion-panel-content>
        </v-expansion-panel>
      </v-expansion-panels>

      <!-- Action Buttons -->
      <v-row class="mt-4">
        <v-col cols="12">
          <v-btn
            color="success"
            @click="saveConfiguration"
            :disabled="uiFrozen || !configurationUiAllowed"
            :loading="saving"
          >
            <v-icon left>mdi-content-save</v-icon>
            Save Configuration
          </v-btn>
          <v-btn
            color="secondary"
            class="ml-2"
            @click="loadConfiguration"
            :disabled="uiFrozen || !configurationUiAllowed"
            :loading="loading"
          >
            <v-icon left>mdi-refresh</v-icon>
            Reload
          </v-btn>
        </v-col>
      </v-row>

      <!-- Status Messages -->
      <v-alert
        v-if="statusMessage"
        :type="statusType"
        dismissible
        class="mt-4"
        @input="statusMessage = ''"
      >
        {{ statusMessage }}
      </v-alert>
    </v-card-text>

    <!-- Tool Setter Position Dialog -->
    <v-dialog v-model="showToolSetterPosDialog" max-width="500">
      <v-card>
        <v-card-title>Edit Tool Setter Position</v-card-title>
        <v-card-text>
          <v-row>
            <v-col cols="4">
              <v-text-field
                v-model.number="toolSetterPosEdit.x"
                label="X"
                type="number"
                step="0.001"
              />
            </v-col>
            <v-col cols="4">
              <v-text-field
                v-model.number="toolSetterPosEdit.y"
                label="Y"
                type="number"
                step="0.001"
              />
            </v-col>
            <v-col cols="4">
              <v-text-field
                v-model.number="toolSetterPosEdit.z"
                label="Z"
                type="number"
                step="0.001"
              />
            </v-col>
          </v-row>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn text @click="showToolSetterPosDialog = false">Cancel</v-btn>
          <v-btn color="primary" @click="saveToolSetterPos">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
    </v-card>
  </template>
<script lang="ts">
import BaseComponent from '../base/BaseComponent.vue'
import { snapshotNxtGlobals } from '../../utils/nxtGlobalsManifest'
import {
  NXT_PLATFORM_OPTIONS,
  boardProfileSelectItems as getBundledBoardProfileSelectItems,
  nxtBoardPackRelPath,
  bundledBoardMeta,
  migrateLegacyBoardKitKey,
  gpOutItemsForBoard,
  platformStructureSummary,
  NXT_SCYLLA_MOTOR_VOLTAGE_ITEMS,
  type NxtPlatformId,
  type GpOutItem
} from '../../utils/nxtBoardManifest'
import { deployPlatformSysFiles } from '../../utils/nxtBoardSysDeploy'
import { nxtPlatformFromManifest } from '../../utils/nxtConfigManifestData'
import {
  NXT_USER_VARS_DWC_PATH,
  NXT_USER_PINMAP_DWC_PATH,
  uploadDwcFile
} from '../../utils/nxtFileUpload'
import { syncBoardBootstrapSentinels } from '../../utils/nxtBoardBootstrapSync'
import { scanNxtConfigOnSd, formatSdScanWarnings } from '../../utils/nxtConfigSdScan'
import { reconcileBoardState } from '../../utils/nxtBoardStateReconcile'
import {
  buildInitialConfigDraft,
  buildNxtUserVarsGcode,
  emptyConfigDraft,
  nxtConfigPendingInOm,
  nxtUserVarsPresentInOm,
  snapshotConfigFromOm,
  type NxtUserConfigDraft
} from '../../utils/nxtUserVarsPersistence'
import { readFirmwareGlobal } from '../../utils/nxtToolChangerOm'

/**
 * NeXT Configuration Panel
 *
 * Replaces G8000 wizard with direct UI-based configuration editing.
 * Allows configuration of all NeXT settings including features, spindle,
 * touch probe, tool setter, and coolant control.
 */
export default BaseComponent.extend({
  name: 'NxtConfigurationPanel',

  data() {
    return {
      openPanels: [0], // Open features panel by default
      showToolSetterPosDialog: false,
      saving: false,
      loading: false,
      statusMessage: '',
      statusType: 'success' as 'success' | 'error' | 'warning' | 'info',

      // Measurement states
      measuringAccel: false,
      measuringDecel: false,
      accelStartTime: 0,
      decelStartTime: 0,
      accelDialog: false,
      decelDialog: false,

      // Probe test states
      touchProbeTriggered: false,
      toolSetterTriggered: false,

      // Spindle test state
      spindleTesting: false,

      // Tool setter position editing
      toolSetterPosEdit: {
        x: 0,
        y: 0,
        z: 0
      },

      pinmapSaving: false,
      sysDeploying: false,
      boardStateChecking: false,
      boardBootstrapWarnings: [] as string[],
      boardPackWarnings: [] as string[],
      sdConfigWarnings: [] as string[],

      configDraft: emptyConfigDraft() as NxtUserConfigDraft,

      NXT_SCYLLA_MOTOR_VOLTAGE_ITEMS
    }
  },

  computed: {
    configurationUiAllowed(): boolean {
      if (!this.isConnected) {
        return false
      }
      const globalVal = this.$store.state.machine.model.global
      return (
        this.nxtBackendReady ||
        nxtConfigPendingInOm(globalVal) ||
        nxtUserVarsPresentInOm(globalVal) ||
        readFirmwareGlobal(globalVal, 'nxtVarsLoaded') === true ||
        readFirmwareGlobal(globalVal, 'nxtVarsLoaded') === 1
      )
    },

    formatToolSetterPos(): string {
      const pos = this.configDraft.nxtToolSetterPos
      if (!pos || !Array.isArray(pos) || pos.length < 3) {
        return 'Not configured'
      }
      return `[${pos.map((v: number) => Number(v).toFixed(3)).join(', ')}]`
    },

    /**
     * Get minimum RPM for the selected spindle
     */
    selectedSpindleMinRpm(): number {
      if (this.configDraft.nxtSpindleID === null) return 1000

      const spindles = this.$store.state.machine.model.spindles || []
      const spindle = spindles[this.configDraft.nxtSpindleID]

      if (spindle && spindle.min !== undefined) {
        return spindle.min
      }

      // Default to 1000 RPM if not specified
      return 1000
    },

    /**
     * Get maximum RPM for the selected spindle
     */
    selectedSpindleMaxRpm(): number {
      if (this.configDraft.nxtSpindleID === null) return 10000

      const spindles = this.$store.state.machine.model.spindles || []
      const spindle = spindles[this.configDraft.nxtSpindleID]

      if (spindle && spindle.max !== undefined) {
        return spindle.max
      }

      // Default to 10000 RPM if not specified
      return 10000
    },

    /**
     * Check if touch probe requirements are met
     */
    touchProbeRequirementsMet(): boolean {
      const d = this.configDraft
      return (
        d.nxtTouchProbeID !== null &&
        d.nxtProbeTipRadius !== null && d.nxtProbeTipRadius !== 0 &&
        d.nxtProbeDeflection !== null
      )
    },

    /**
     * Get touch probe requirements message
     */
    touchProbeRequirementsMessage(): string {
      if (this.touchProbeRequirementsMet) {
        return 'All requirements met - feature can be enabled'
      }
      const missing = []
      if (this.configDraft.nxtTouchProbeID === null) missing.push('Probe Sensor')
      if (this.configDraft.nxtProbeTipRadius === null || this.configDraft.nxtProbeTipRadius === 0) missing.push('Tip Radius')
      if (this.configDraft.nxtProbeDeflection === null) missing.push('Deflection')
      return `Required: ${missing.join(', ')}`
    },

    /**
     * Check if tool setter requirements are met
     */
    toolSetterRequirementsMet(): boolean {
      const pos = this.configDraft.nxtToolSetterPos
      return (
        this.configDraft.nxtToolSetterID !== null &&
        pos !== null &&
        Array.isArray(pos) &&
        pos.length === 3
      )
    },

    /**
     * Get tool setter requirements message
     */
    toolSetterRequirementsMessage(): string {
      if (this.toolSetterRequirementsMet) {
        return 'All requirements met - feature can be enabled'
      }
      const missing = []
      if (this.configDraft.nxtToolSetterID === null) missing.push('Tool Setter Sensor')
      const pos = this.configDraft.nxtToolSetterPos
      if (!pos || !Array.isArray(pos) || pos.length !== 3) {
        missing.push('Position')
      }
      return `Required: ${missing.join(', ')}`
    },

    /**
     * Check if coolant control requirements are met
     */
    coolantControlRequirementsMet(): boolean {
      const d = this.configDraft
      return (
        d.nxtCoolantAirID !== null ||
        d.nxtCoolantMistID !== null ||
        d.nxtCoolantFloodID !== null
      )
    },

    /**
     * Get coolant control requirements message
     */
    coolantControlRequirementsMessage(): string {
      if (this.coolantControlRequirementsMet) {
        return 'At least one output configured - feature can be enabled'
      }
      return 'Required: At least one coolant output (Air, Mist, or Flood)'
    },

    machineBoardsList(): Array<{ shortName?: string; name?: string }> {
      const boards = this.$store.state.machine.model.boards
      if (!Array.isArray(boards)) {
        return []
      }
      return boards.map((b: { shortName?: string; name?: string }) => ({
        shortName: b?.shortName,
        name: b?.name
      }))
    },

    primaryBoardShortName(): string {
      const b = this.machineBoardsList[0]
      return b?.shortName != null && String(b.shortName).length > 0 ? String(b.shortName) : '—'
    },

    resolvedBoardShortNameForPack(): string | null {
      const g = this.configDraft as Record<string, unknown>
      const o = g.nxtBoardShortNameOverride
      if (o != null && String(o).trim().length > 0) {
        return String(o).trim()
      }
      const legacy = migrateLegacyBoardKitKey(g.nxtBoardKitKey as any)
      if (legacy) {
        return legacy.shortName
      }
      const om = this.machineBoardsList[0]?.shortName
      return om != null && String(om).length > 0 ? String(om) : null
    },

    resolvedMotorVoltageForPack(): number | null {
      const v = this.configDraft.nxtBoardMotorVoltage
      if (v === 24 || v === 48) {
        return v
      }
      const legacy = migrateLegacyBoardKitKey(this.configDraft.nxtBoardKitKey as any)
      if (
        legacy &&
        legacy.shortName === 'scylla1_0_h723' &&
        legacy.motorVoltage != null
      ) {
        return legacy.motorVoltage
      }
      return null
    },

    scyllaMotorVoltageUiValue(): number | undefined {
      const v = this.resolvedMotorVoltageForPack
      return v === 24 || v === 48 ? v : undefined
    },

    boardProfileSelectItems(): Array<{ value: string; title: string }> {
      const p = this.configDraft.nxtPlatformProfile
      return getBundledBoardProfileSelectItems(p as NxtPlatformId | null | undefined)
    },

    boardNeedsMotorVoltage(): boolean {
      const sn = this.resolvedBoardShortNameForPack
      return bundledBoardMeta(sn)?.variant === 'motor-24v-48v'
    },

    scyllaVoltageMissing(): boolean {
      if (!this.boardNeedsMotorVoltage) {
        return false
      }
      const v = this.resolvedMotorVoltageForPack
      return v !== 24 && v !== 48
    },

    boardProfileMismatch(): boolean {
      const om = this.primaryBoardShortName
      const sel = this.configDraft.nxtBoardShortNameOverride
      if (om === '—' || om.length === 0 || sel == null || String(sel).length === 0) {
        return false
      }
      return String(sel).trim() !== om
    },

    nxtPlatformSelectItems() {
      return NXT_PLATFORM_OPTIONS
    },

    selectedPlatformStructure(): { sysDeployFiles: string[]; boardEntryPaths: string[] } {
      return platformStructureSummary(this.configDraft.nxtPlatformProfile)
    },

    canDeployPlatformSysFiles(): boolean {
      const id = this.configDraft.nxtPlatformProfile
      if (id == null || id === '') {
        return false
      }
      const p = nxtPlatformFromManifest(id)
      return Boolean(p?.hasCommonDeploy && p.sysDeployFiles.length > 0)
    },

    boardBootstrapModeUi(): string {
      return this.configDraft.nxtBoardBootstrapMode === 'auto' ? 'auto' : 'off'
    },

    boardBootstrapModeItems() {
      return [
        { value: 'off', title: 'Off (no pack load at boot)' },
        { value: 'auto', title: 'Auto (Save creates nxt-board-bootstrap.requested)' }
      ]
    },

    kitEntryPathForUi(): string {
      const plat = this.configDraft.nxtPlatformProfile
      if (!plat || !nxtPlatformFromManifest(plat)) {
        return ''
      }
      const sn = this.resolvedBoardShortNameForPack
      if (!sn) {
        return ''
      }
      let volt: number | null = null
      if (bundledBoardMeta(sn)?.variant === 'motor-24v-48v') {
        volt = this.resolvedMotorVoltageForPack
      }
      const rel = nxtBoardPackRelPath(plat, sn, volt)
      if (!rel) {
        return ''
      }
      return `M98 P"${rel}"`
    },

    boardConfigGHint(): string {
      const kitLine = this.kitEntryPathForUi
      return (
        '; NeXT: call early in config.g. If using board pack auto-load, create 0:/sys/nxt-board-bootstrap.requested.\n' +
        '; Pack loads after nxt-user-vars.g (motor voltage must be set for Scylla). Avoid duplicating drives/limits if the pack loads them.\n' +
        'M98 P"nxt.g"\n\n' +
        (kitLine ? `; Or load one pack entry only:\n${kitLine}\n` : '')
      )
    },

    boardKitGpOutputs(): GpOutItem[] {
      const lim = this.$store.state.machine.model.limits as { gpOutPorts?: number } | undefined
      const n = lim?.gpOutPorts
      const maxPorts = typeof n === 'number' && n > 0 ? n : 8
      return gpOutItemsForBoard(this.resolvedBoardShortNameForPack, maxPorts)
    },

    nxtGlobalsSnapshotRows() {
      return snapshotNxtGlobals(this.$store.state.machine.model.global)
    }
  },

  mounted() {
    this.initializeConfigurationDraft()
    if (this.isConnected) {
      this.runBoardStateChecks()
    }
  },

  methods: {
    syncConfigDraftFromOm() {
      this.configDraft = snapshotConfigFromOm(this.$store.state.machine.model.global)
    },

    initializeConfigurationDraft() {
      const globalVal = this.$store.state.machine.model.global
      if (nxtUserVarsPresentInOm(globalVal)) {
        this.syncConfigDraftFromOm()
      } else {
        this.configDraft = buildInitialConfigDraft(globalVal, {
          spindles: this.availableSpindles,
          probes: this.availableProbes
        })
      }
    },

    async onConfigDraftSelect(key: keyof NxtUserConfigDraft, value: unknown) {
      const v = value === undefined || value === '' ? null : value
      ;(this.configDraft as Record<string, unknown>)[key] = v
      await this.updateVariable(String(key), v)
    },

    async onConfigDraftNumber(key: keyof NxtUserConfigDraft, raw: string | number | null) {
      let v: number | null =
        raw === '' || raw === null || raw === undefined ? null : typeof raw === 'number' ? raw : Number(raw)
      if (v !== null && !Number.isFinite(v)) {
        return
      }
      ;(this.configDraft as Record<string, unknown>)[key] = v
      await this.updateVariable(String(key), v)
    },

    async loadConfiguration() {
      this.loading = true
      try {
        if (!this.configurationUiAllowed) {
          return
        }
        const globalVal = this.$store.state.machine.model.global
        if (nxtUserVarsPresentInOm(globalVal)) {
          await this.sendCode('M98 P"nxt-user-vars.g"')
          await this.$nextTick()
          this.syncConfigDraftFromOm()
          await this.runBoardStateChecks()
          this.showStatus('Configuration reloaded from nxt-user-vars.g', 'success')
        } else {
          this.configDraft = buildInitialConfigDraft(globalVal, {
            spindles: this.availableSpindles,
            probes: this.availableProbes
          })
          await this.runBoardStateChecks()
          this.showStatus(
            'No nxt-user-vars.g — form filled from MOS globals or empty defaults. Save to create the file.',
            'info'
          )
        }
      } catch (e) {
        console.error('NeXT: loadConfiguration', e)
        this.showStatus('Failed to reload configuration', 'error')
      } finally {
        this.loading = false
      }
    },

    prepareBoardPackFieldsForSave() {
      const plat = this.configDraft.nxtPlatformProfile
      const sn = this.resolvedBoardShortNameForPack
      const volt = this.resolvedMotorVoltageForPack
      this.configDraft.nxtBoardPackExpectedEntry = nxtBoardPackRelPath(plat, sn, volt)
    },

    async runBoardStateChecks() {
      if (!this.isConnected) {
        this.boardBootstrapWarnings = []
        this.boardPackWarnings = []
        this.sdConfigWarnings = []
        return
      }
      this.boardStateChecking = true
      try {
        const globalVal = this.$store.state.machine.model.global
        const reconcile = await reconcileBoardState(this.configDraft, globalVal)
        this.boardBootstrapWarnings = reconcile.bootstrapWarnings
        this.boardPackWarnings = reconcile.packEntryWarnings
        const scan = await scanNxtConfigOnSd(
          this.configDraft.nxtPlatformProfile,
          this.resolvedBoardShortNameForPack,
          this.resolvedMotorVoltageForPack
        )
        this.sdConfigWarnings = formatSdScanWarnings(scan)
      } catch (e) {
        console.error('NeXT: runBoardStateChecks', e)
      } finally {
        this.boardStateChecking = false
      }
    },

    async onPlatformProfileChange(value: NxtPlatformId | null) {
      const previous = this.configDraft.nxtPlatformProfile
      this.configDraft.nxtPlatformProfile = value
      await this.updateVariable('nxtPlatformProfile', value)
      if (value != null && value !== '' && value !== previous) {
        const plat = nxtPlatformFromManifest(value)
        if (plat?.hasCommonDeploy && plat.sysDeployFiles.length > 0) {
          const msg = (this as any).$t('plugins.next.panels.configuration.boardDeployOnPlatformChange', {
            platform: value,
            files: plat.sysDeployFiles.map((f) => `0:/sys/${f}`).join(', ')
          })
          if (typeof msg === 'string' && window.confirm(msg)) {
            await this.runDeployPlatformSysFiles(value)
          }
        }
      }
    },

    async applyPlatformSysFiles() {
      const id = this.configDraft.nxtPlatformProfile
      if (id == null || id === '') {
        return
      }
      const plat = nxtPlatformFromManifest(id)
      if (!plat?.hasCommonDeploy) {
        return
      }
      const msg = (this as any).$t('plugins.next.panels.configuration.boardDeployConfirm', {
        platform: id,
        files: plat.sysDeployFiles.map((f) => `0:/sys/${f}`).join(', ')
      })
      if (typeof msg === 'string' && !window.confirm(msg)) {
        return
      }
      await this.runDeployPlatformSysFiles(id)
    },

    async runDeployPlatformSysFiles(platformId: string) {
      this.sysDeploying = true
      try {
        const written = await deployPlatformSysFiles(platformId)
        this.configDraft.nxtBoardSysDeployPlatform = platformId
        await this.updateVariable('nxtBoardSysDeployPlatform', platformId)
        const msg = (this as any).$t('plugins.next.panels.configuration.boardDeploySuccess', {
          count: written.length
        })
        this.showStatus(typeof msg === 'string' ? msg : `Deployed ${written.length} file(s) to 0:/sys/`, 'success')
      } catch (e: any) {
        console.error('NeXT: deployPlatformSysFiles', e)
        const errMsg = e && typeof e.message === 'string' ? e.message : 'Deploy failed'
        this.showStatus(errMsg, 'error')
      } finally {
        this.sysDeploying = false
      }
    },

    async onBoardProfileShortNameChange(value: string | null) {
      const v = value != null && String(value).trim().length > 0 ? String(value).trim() : null
      this.configDraft.nxtBoardShortNameOverride = v
      this.configDraft.nxtBoardKitKey = null
      await this.updateVariable('nxtBoardShortNameOverride', v)
      await this.updateVariable('nxtBoardKitKey', null)
      if (!bundledBoardMeta(v)?.variant || bundledBoardMeta(v)?.variant !== 'motor-24v-48v') {
        this.configDraft.nxtBoardMotorVoltage = null
        await this.updateVariable('nxtBoardMotorVoltage', null)
      }
    },

    async onBoardMotorVoltageChange(value: number | null) {
      const v = value === 24 || value === 48 ? value : null
      this.configDraft.nxtBoardMotorVoltage = v
      this.configDraft.nxtBoardKitKey = null
      await this.updateVariable('nxtBoardMotorVoltage', v)
      await this.updateVariable('nxtBoardKitKey', null)
    },

    async onBoardBootstrapModeChange(value: string) {
      const mode = value === 'auto' ? 'auto' : 'off'
      this.configDraft.nxtBoardBootstrapMode = mode
      await this.updateVariable('nxtBoardBootstrapMode', mode)
    },

    copyBoardConfigHint() {
      const text = this.boardConfigGHint
      const done = () => {
        const msg = (this as any).$t('plugins.next.panels.configuration.boardSnippetCopied')
        this.showStatus(typeof msg === 'string' ? msg : 'Copied', 'success')
      }
      const fail = () => this.showStatus('Copy failed', 'error')
      try {
        if (navigator.clipboard && typeof navigator.clipboard.writeText === 'function') {
          navigator.clipboard.writeText(text).then(done).catch(fail)
        } else {
          fail()
        }
      } catch {
        fail()
      }
    },

    async savePinmapStub() {
      this.pinmapSaving = true
      try {
        const lines = [
          '; nxt-user-pinmap.g - stub generated from NeXT Configuration UI',
          '; Add M950 or other pin overrides below; load after nxt.g if needed.',
          '; ' + new Date().toISOString(),
          ''
        ]
        await uploadDwcFile(NXT_USER_PINMAP_DWC_PATH, lines.join('\n'))
        const msg = (this as any).$t('plugins.next.panels.configuration.boardPinmapSaved')
        this.showStatus(typeof msg === 'string' ? msg : 'Saved', 'success')
      } catch (e: any) {
        console.error('NeXT: savePinmapStub', e)
        const msg = e && typeof e.message === 'string' ? e.message : 'Failed to write pinmap file'
        this.showStatus(msg, 'error')
      } finally {
        this.pinmapSaving = false
      }
    },

    copyNxtGlobalsSnapshot() {
      const rows = this.nxtGlobalsSnapshotRows as Array<{ key: string; valueText: string }>
      const lines = rows.map((r) => `${r.key}\t${r.valueText}`)
      const text = ['key\tvalue', ...lines].join('\n')
      const done = () => {
        const msg = (this as any).$t('plugins.next.panels.configuration.globalsSnapshotCopied')
        this.showStatus(typeof msg === 'string' ? msg : 'Copied to clipboard', 'success')
      }
      const fail = () => {
        this.showStatus(
          (this as any).$t('plugins.next.panels.configuration.globalsSnapshotCopyFailed'),
          'error'
        )
      }
      try {
        if (navigator.clipboard && typeof navigator.clipboard.writeText === 'function') {
          navigator.clipboard.writeText(text).then(done).catch(fail)
        } else {
          fail()
        }
      } catch {
        fail()
      }
    },

    /**
     * Update a feature flag with validation
     */
    async updateFeature(key: string, value: boolean) {
      try {
        // Validate requirements before enabling
        if (value) {
          if (key === 'nxtFeatureTouchProbe' && !this.touchProbeRequirementsMet) {
            this.showStatus('Cannot enable Touch Probe: ' + this.touchProbeRequirementsMessage, 'error')
            return
          }
          if (key === 'nxtFeatureToolSetter' && !this.toolSetterRequirementsMet) {
            this.showStatus('Cannot enable Tool Setter: ' + this.toolSetterRequirementsMessage, 'error')
            return
          }
          if (key === 'nxtFeatureCoolantControl' && !this.coolantControlRequirementsMet) {
            this.showStatus('Cannot enable Coolant Control: ' + this.coolantControlRequirementsMessage, 'error')
            return
          }
        }

        await this.sendCode(`set global.${key} = ${value}`)
        ;(this.configDraft as Record<string, unknown>)[key] = value
        this.showStatus(`${key} ${value ? 'enabled' : 'disabled'}`, 'success')
      } catch (error) {
        console.error('NeXT: Failed to update feature', key, error)
        this.showStatus(`Failed to update ${key}`, 'error')
      }
    },

    /**
     * Update a variable value
     */
    async updateVariable(key: string, value: any) {
      try {
        // Handle null values
        if (value === null || value === undefined || value === '') {
          await this.sendCode(`set global.${key} = null`)
        } else if (typeof value === 'number') {
          await this.sendCode(`set global.${key} = ${value}`)
        } else {
          await this.sendCode(`set global.${key} = "${value}"`)
        }
        console.log(`NeXT: Updated ${key} to ${value}`)
      } catch (error) {
        console.error('NeXT: Failed to update variable', key, error)
        this.showStatus(`Failed to update ${key}`, 'error')
      }
    },

    /**
     * Save configuration to /sys/nxt-user-vars.g (full file replace via DWC upload)
     */
    async saveConfiguration() {
      this.saving = true
      try {
        this.prepareBoardPackFieldsForSave()
        const bootMode = this.configDraft.nxtBoardBootstrapMode === 'auto' ? 'auto' : 'off'
        const content = buildNxtUserVarsGcode(this.configDraft)
        await uploadDwcFile(NXT_USER_VARS_DWC_PATH, content)
        if (this.isConnected) {
          await syncBoardBootstrapSentinels(bootMode)
          await this.runBoardStateChecks()
        }

        this.showStatus(
          `Configuration saved to ${NXT_USER_VARS_DWC_PATH} and bootstrap files synced (${bootMode}). Reload or reboot to apply.`,
          'success'
        )
      } catch (error: any) {
        console.error('NeXT: Failed to save configuration', error)
        const msg =
          error && typeof error.message === 'string'
            ? error.message
            : 'Failed to save configuration'
        this.showStatus(msg, 'error')
      } finally {
        this.saving = false
      }
    },

    /**
     * Start spindle test (on button press)
     */
    async startSpindleTest() {
      if (this.configDraft.nxtSpindleID === null || this.spindleTesting) return

      this.spindleTesting = true

      try {
        const rpm = this.selectedSpindleMinRpm
        this.showStatus(`Starting spindle at ${rpm} RPM (minimum speed). Release button to stop.`, 'info')
        await this.sendCode(`M3 S${rpm}`)
      } catch (error) {
        console.error('NeXT: Spindle test start failed', error)
        this.showStatus('Failed to start spindle', 'error')
        this.spindleTesting = false
      }
    },

    /**
     * Stop spindle test (on button release)
     */
    async stopSpindleTest() {
      if (!this.spindleTesting) return

      this.spindleTesting = false

      try {
        await this.sendCode('M5')
        this.showStatus('Spindle stopped', 'success')
      } catch (error) {
        console.error('NeXT: Spindle stop failed', error)
        this.showStatus('Failed to stop spindle', 'error')
      }
    },

    /**
     * Start measuring spindle acceleration (on button press)
     * User holds button until spindle reaches full speed
     */
    async startAccelerationMeasurement() {
      if (this.configDraft.nxtSpindleID === null || this.measuringAccel) return

      this.measuringAccel = true

      try {
        const maxRpm = this.selectedSpindleMaxRpm
        this.accelStartTime = Date.now()

        this.showStatus(`Starting spindle at ${maxRpm} RPM. Hold button until at full speed, then release.`, 'info')
        await this.sendCode(`M3 S${maxRpm}`)
      } catch (error) {
        console.error('NeXT: Acceleration measurement start failed', error)
        this.showStatus('Failed to start acceleration measurement', 'error')
        this.measuringAccel = false
      }
    },

    /**
     * Stop measuring spindle acceleration (on button release)
     */
    async stopAccelerationMeasurement() {
      if (!this.measuringAccel) return

      this.measuringAccel = false

      try {
        const elapsed = (Date.now() - this.accelStartTime) / 1000
        const measuredTime = parseFloat(elapsed.toFixed(2))

        // Stop spindle
        await this.sendCode('M5')

        // Save measured time
        await this.updateVariable('nxtSpindleAccelSec', measuredTime)
        this.configDraft.nxtSpindleAccelSec = measuredTime

        this.showStatus(`Acceleration time measured: ${measuredTime}s`, 'success')
      } catch (error) {
        console.error('NeXT: Acceleration measurement failed', error)
        this.showStatus('Acceleration measurement failed', 'error')
      }
    },

    /**
     * Start measuring spindle deceleration (on button press)
     * Uses measured acceleration time to spin up, then user holds until stopped
     */
    async startDecelerationMeasurement() {
      if (this.configDraft.nxtSpindleID === null || this.measuringDecel) return

      this.measuringDecel = true

      try {
        const maxRpm = this.selectedSpindleMaxRpm
        const accelTime = this.configDraft.nxtSpindleAccelSec || 0

        // Start spindle
        this.showStatus(`Starting spindle at ${maxRpm} RPM. Waiting ${accelTime}s for spin-up...`, 'info')
        await this.sendCode(`M3 S${maxRpm}`)

        // Wait for acceleration time
        await new Promise(resolve => setTimeout(resolve, accelTime * 1000))

        // Stop spindle and start timing
        this.showStatus('Stopping spindle. Hold button until fully stopped, then release.', 'info')
        this.decelStartTime = Date.now()
        await this.sendCode('M5')
      } catch (error) {
        console.error('NeXT: Deceleration measurement start failed', error)
        this.showStatus('Failed to start deceleration measurement', 'error')
        this.measuringDecel = false
      }
    },

    /**
     * Stop measuring spindle deceleration (on button release)
     */
    async stopDecelerationMeasurement() {
      if (!this.measuringDecel) return

      this.measuringDecel = false

      try {
        const elapsed = (Date.now() - this.decelStartTime) / 1000
        const measuredTime = parseFloat(elapsed.toFixed(2))

        // Save measured time
        await this.updateVariable('nxtSpindleDecelSec', measuredTime)
        this.configDraft.nxtSpindleDecelSec = measuredTime

        this.showStatus(`Deceleration time measured: ${measuredTime}s`, 'success')
      } catch (error) {
        console.error('NeXT: Deceleration measurement failed', error)
        this.showStatus('Deceleration measurement failed', 'error')
      }
    },

    /**
     * Test touch probe by checking if it's triggered
     */
    async testTouchProbe() {
      if (this.configDraft.nxtTouchProbeID === null) return

      try {
        const probes = this.$store.state.machine.model.sensors?.probes || []
        const probe = probes[this.configDraft.nxtTouchProbeID]

        if (probe) {
          this.touchProbeTriggered = probe.triggered || false

          // Reset after 15 seconds
          setTimeout(() => {
            this.touchProbeTriggered = false
          }, 15000)
        }
      } catch (error) {
        console.error('NeXT: Touch probe test failed', error)
      }
    },

    /**
     * Test tool setter by checking if it's triggered
     */
    async testToolSetter() {
      if (this.configDraft.nxtToolSetterID === null) return

      try {
        const probes = this.$store.state.machine.model.sensors?.probes || []
        const probe = probes[this.configDraft.nxtToolSetterID]

        if (probe) {
          this.toolSetterTriggered = probe.triggered || false

          // Reset after 15 seconds
          setTimeout(() => {
            this.toolSetterTriggered = false
          }, 15000)
        }
      } catch (error) {
        console.error('NeXT: Tool setter test failed', error)
      }
    },

    /**
     * Navigate to calibration page (placeholder for future implementation)
     */
    navigateToCalibration() {
      this.showStatus('Calibration page will be implemented in a future update.', 'info')
      // TODO: Navigate to calibration page when implemented
      // this.$router.push('/NeXT/calibration')
    },

    /**
     * Set tool setter position to current machine position
     */
    async setCurrentPositionAsToolSetter() {
      try {
        const axes = this.visibleAxesByLetter
        const pos = [
          axes.X?.machinePosition || 0,
          axes.Y?.machinePosition || 0,
          axes.Z?.machinePosition || 0
        ]

        await this.sendCode(`set global.nxtToolSetterPos = {${pos.join(', ')}}`)
        this.configDraft.nxtToolSetterPos = pos
        this.showStatus('Tool setter position set to current position', 'success')
      } catch (error) {
        console.error('NeXT: Failed to set tool setter position', error)
        this.showStatus('Failed to set tool setter position', 'error')
      }
    },

    /**
     * Save tool setter position
     */
    async saveToolSetterPos() {
      try {
        const pos = [
          this.toolSetterPosEdit.x,
          this.toolSetterPosEdit.y,
          this.toolSetterPosEdit.z
        ]
        await this.sendCode(`set global.nxtToolSetterPos = {${pos.join(', ')}}`)
        this.configDraft.nxtToolSetterPos = pos
        this.showToolSetterPosDialog = false
        this.showStatus('Tool setter position updated', 'success')
      } catch (error) {
        console.error('NeXT: Failed to update tool setter position', error)
        this.showStatus('Failed to update tool setter position', 'error')
      }
    },

    /**
     * Show status message
     */
    showStatus(message: string, type: 'success' | 'error' | 'warning' | 'info') {
      this.statusMessage = message
      this.statusType = type
    }
  },

  watch: {
    showToolSetterPosDialog(val: boolean) {
      const pos = this.configDraft.nxtToolSetterPos
      if (val && pos && Array.isArray(pos)) {
        this.toolSetterPosEdit.x = pos[0] || 0
        this.toolSetterPosEdit.y = pos[1] || 0
        this.toolSetterPosEdit.z = pos[2] || 0
      }
    },
    isConnected(connected: boolean) {
      if (connected) {
        this.runBoardStateChecks()
      }
    }
  }
})
</script>

<style scoped>
.v-expansion-panel-content >>> .v-expansion-panel-content__wrap {
  padding-top: 16px;
}
.nxt-globals-snapshot-table .nxt-globals-snapshot-value {
  white-space: pre-wrap;
  word-break: break-word;
  max-width: 36rem;
}
.font-mono {
  font-family: monospace;
}
</style>
