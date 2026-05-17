<template>
  <v-card>
    <v-card-title>
      <v-icon left>mdi-cog</v-icon>
      {{ $t('plugins.next.panels.configuration.caption') }}
      <v-spacer />
      <div v-if="!isConnected || !nxtReady" class="d-flex align-center">
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
                  :value="globals.nxtPlatformProfile"
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
                  :value="globals.nxtBoardShortNameOverride != null ? String(globals.nxtBoardShortNameOverride) : undefined"
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
                  @change="onScyllaMotorVoltageChange"
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
            <div class="d-flex flex-wrap mt-2" style="gap: 8px">
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
                  :value="globals.nxtSpindleID"
                  :items="availableSpindles"
                  item-text="name"
                  item-value="id"
                  label="Spindle"
                  :disabled="uiFrozen"
                  @input="updateVariable('nxtSpindleID', $event)"
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
                          :disabled="uiFrozen || globals.nxtSpindleID === null"
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
                  :value="globals.nxtSpindleAccelSec"
                  label="Acceleration Time (s)"
                  type="number"
                  step="0.1"
                  :disabled="uiFrozen"
                  @input="updateVariable('nxtSpindleAccelSec', $event)"
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
                          :disabled="uiFrozen || globals.nxtSpindleID === null"
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
                  :value="globals.nxtSpindleDecelSec"
                  label="Deceleration Time (s)"
                  type="number"
                  step="0.1"
                  :disabled="uiFrozen"
                  @input="updateVariable('nxtSpindleDecelSec', $event)"
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
                          :disabled="uiFrozen || globals.nxtSpindleID === null || globals.nxtSpindleAccelSec === null || globals.nxtSpindleAccelSec === undefined"
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
                  v-model="globals.nxtTouchProbeID"
                  :items="availableProbes"
                  item-text="name"
                  item-value="id"
                  label="Touch Probe Sensor *"
                  :disabled="uiFrozen"
                  @change="updateVariable('nxtTouchProbeID', globals.nxtTouchProbeID)"
                  hint="Required - Select configured probe"
                  persistent-hint
                  :error="globals.nxtTouchProbeID === null"
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
                      v-if="globals.nxtTouchProbeID !== null"
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
                  v-model.number="globals.nxtProbeTipRadius"
                  label="Probe Tip Radius (mm) *"
                  type="number"
                  step="0.001"
                  :disabled="uiFrozen"
                  @blur="updateVariable('nxtProbeTipRadius', globals.nxtProbeTipRadius)"
                  hint="Required - For horizontal compensation"
                  persistent-hint
                  :error="globals.nxtProbeTipRadius === null || globals.nxtProbeTipRadius === 0"
                />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field
                  v-model.number="globals.nxtProbeDeflection"
                  label="Probe Deflection (mm) *"
                  type="number"
                  step="0.001"
                  :disabled="uiFrozen"
                  @blur="updateVariable('nxtProbeDeflection', globals.nxtProbeDeflection)"
                  hint="Required - Measured deflection value (0 if not measured)"
                  persistent-hint
                  :error="globals.nxtProbeDeflection === null"
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
            <v-row>
              <v-col cols="12" md="4">
                <v-text-field
                  v-model.number="globals.nxtProbeInnerSampleCount"
                  label="Inner samples (nxt-vars.g)"
                  type="number"
                  min="1"
                  step="1"
                  :disabled="uiFrozen"
                  @blur="updateVariable('nxtProbeInnerSampleCount', globals.nxtProbeInnerSampleCount)"
                  hint="Used when pair tolerance is 0; G6512 forces 3 touches when tolerance > 0"
                  persistent-hint
                />
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field
                  v-model.number="globals.nxtProbeMaxSampleSpreadMm"
                  label="Max consecutive-pair deviation (mm)"
                  type="number"
                  step="0.0001"
                  :disabled="uiFrozen"
                  @blur="updateVariable('nxtProbeMaxSampleSpreadMm', globals.nxtProbeMaxSampleSpreadMm)"
                  hint="0 = disabled. Default 0.0075 from nxt-vars.g; both pairs among 3 touches must pass"
                  persistent-hint
                />
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field
                  v-model.number="globals.nxtProbeSampleOuterRetries"
                  label="Outer retries after failed pair tolerance"
                  type="number"
                  min="0"
                  step="1"
                  :disabled="uiFrozen"
                  @blur="updateVariable('nxtProbeSampleOuterRetries', globals.nxtProbeSampleOuterRetries)"
                  hint="Extra full sample blocks; 1 = one retry. See nxt-vars.g"
                  persistent-hint
                />
              </v-col>
            </v-row>

            <!-- Feature Toggle -->
            <v-row class="mt-4">
              <v-col cols="12">
                <v-divider class="mb-4" />
                <v-switch
                  :input-value="globals.nxtFeatureTouchProbe"
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
                  v-model="globals.nxtToolSetterID"
                  :items="availableProbes"
                  item-text="name"
                  item-value="id"
                  label="Tool Setter Sensor *"
                  :disabled="uiFrozen"
                  @change="updateVariable('nxtToolSetterID', globals.nxtToolSetterID)"
                  hint="Required - Select configured probe"
                  persistent-hint
                  :error="globals.nxtToolSetterID === null"
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
                      v-if="globals.nxtToolSetterID !== null"
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
                  :error="!globals.nxtToolSetterPos || !Array.isArray(globals.nxtToolSetterPos) || globals.nxtToolSetterPos.length !== 3"
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
                  :input-value="globals.nxtFeatureToolSetter"
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
                  v-model="globals.nxtCoolantAirID"
                  :items="boardKitGpOutputs"
                  item-text="name"
                  item-value="id"
                  label="Air Blast Output"
                  :disabled="uiFrozen"
                  @change="updateVariable('nxtCoolantAirID', globals.nxtCoolantAirID)"
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
                  v-model="globals.nxtCoolantMistID"
                  :items="boardKitGpOutputs"
                  item-text="name"
                  item-value="id"
                  label="Mist Coolant Output"
                  :disabled="uiFrozen"
                  @change="updateVariable('nxtCoolantMistID', globals.nxtCoolantMistID)"
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
                  v-model="globals.nxtCoolantFloodID"
                  :items="boardKitGpOutputs"
                  item-text="name"
                  item-value="id"
                  label="Flood Coolant Output"
                  :disabled="uiFrozen"
                  @change="updateVariable('nxtCoolantFloodID', globals.nxtCoolantFloodID)"
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
                  :input-value="globals.nxtFeatureCoolantControl"
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
            :disabled="uiFrozen || !nxtReady"
            :loading="saving"
          >
            <v-icon left>mdi-content-save</v-icon>
            Save Configuration
          </v-btn>
          <v-btn
            color="secondary"
            class="ml-2"
            @click="loadConfiguration"
            :disabled="uiFrozen"
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
  NXT_SCYLLA_MOTOR_VOLTAGE_ITEMS,
  type NxtPlatformId,
  type GpOutItem
} from '../../utils/nxtBoardManifest'
import {
  NXT_USER_VARS_DWC_PATH,
  NXT_USER_PINMAP_DWC_PATH,
  uploadDwcFile
} from '../../utils/nxtFileUpload'

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

      NXT_SCYLLA_MOTOR_VOLTAGE_ITEMS
    }
  },

  computed: {
    formatToolSetterPos(): string {
      if (!this.globals.nxtToolSetterPos || !Array.isArray(this.globals.nxtToolSetterPos)) {
        return 'Not configured'
      }
      return `[${this.globals.nxtToolSetterPos.map((v: number) => v.toFixed(3)).join(', ')}]`
    },

    /**
     * Get minimum RPM for the selected spindle
     */
    selectedSpindleMinRpm(): number {
      if (this.globals.nxtSpindleID === null) return 1000

      const spindles = this.$store.state.machine.model.spindles || []
      const spindle = spindles[this.globals.nxtSpindleID]

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
      if (this.globals.nxtSpindleID === null) return 10000

      const spindles = this.$store.state.machine.model.spindles || []
      const spindle = spindles[this.globals.nxtSpindleID]

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
      const g = this.globals
      return (
        g.nxtTouchProbeID !== null &&
        g.nxtProbeTipRadius !== null && g.nxtProbeTipRadius !== 0 &&
        g.nxtProbeDeflection !== null
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
      if (this.globals.nxtTouchProbeID === null) missing.push('Probe Sensor')
      if (this.globals.nxtProbeTipRadius === null || this.globals.nxtProbeTipRadius === 0) missing.push('Tip Radius')
      if (this.globals.nxtProbeDeflection === null) missing.push('Deflection')
      return `Required: ${missing.join(', ')}`
    },

    /**
     * Check if tool setter requirements are met
     */
    toolSetterRequirementsMet(): boolean {
      const g = this.globals
      return (
        g.nxtToolSetterID !== null &&
        g.nxtToolSetterPos !== null &&
        Array.isArray(g.nxtToolSetterPos) &&
        g.nxtToolSetterPos.length === 3
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
      if (this.globals.nxtToolSetterID === null) missing.push('Tool Setter Sensor')
      if (!this.globals.nxtToolSetterPos || !Array.isArray(this.globals.nxtToolSetterPos) || this.globals.nxtToolSetterPos.length !== 3) {
        missing.push('Position')
      }
      return `Required: ${missing.join(', ')}`
    },

    /**
     * Check if coolant control requirements are met
     */
    coolantControlRequirementsMet(): boolean {
      const g = this.globals
      // At least one coolant output must be configured
      return (
        g.nxtCoolantAirID !== null ||
        g.nxtCoolantMistID !== null ||
        g.nxtCoolantFloodID !== null
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
      const g = this.globals as Record<string, unknown>
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
      const g = this.globals as Record<string, unknown>
      const v = g.nxtScyllaMotorVoltage
      if (v === 24 || v === 48) {
        return v as number
      }
      const legacy = migrateLegacyBoardKitKey(g.nxtBoardKitKey as any)
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
      const p = this.globals.nxtPlatformProfile
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
      const sel = this.globals.nxtBoardShortNameOverride
      if (om === '—' || om.length === 0 || sel == null || String(sel).length === 0) {
        return false
      }
      return String(sel).trim() !== om
    },

    nxtPlatformSelectItems() {
      return NXT_PLATFORM_OPTIONS
    },

    boardBootstrapModeUi(): string {
      const m = this.globals.nxtBoardBootstrapMode
      return m === 'auto' ? 'auto' : 'off'
    },

    boardBootstrapModeItems() {
      return [
        { value: 'off', title: 'Off (SD sentinel only)' },
        { value: 'auto', title: 'Auto (documented — use sentinel + nxt-user-board.g)' }
      ]
    },

    kitEntryPathForUi(): string {
      const platRaw = this.globals.nxtPlatformProfile as NxtPlatformId | null | undefined
      const plat = platRaw === 'v1.6_v2' ? 'v1.6_v2' : platRaw === 'v1.5' ? 'v1.5' : null
      if (!plat) {
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
    console.log('NeXT: Configuration panel mounted')
  },

  methods: {
    async onPlatformProfileChange(value: NxtPlatformId | null) {
      await this.updateVariable('nxtPlatformProfile', value)
    },

    async onBoardProfileShortNameChange(value: string | null) {
      const v = value != null && String(value).trim().length > 0 ? String(value).trim() : null
      await this.updateVariable('nxtBoardShortNameOverride', v)
      await this.updateVariable('nxtBoardKitKey', null)
      if (v !== 'scylla1_0_h723') {
        await this.updateVariable('nxtScyllaMotorVoltage', null)
      }
    },

    async onScyllaMotorVoltageChange(value: number | null) {
      const v = value === 24 || value === 48 ? value : null
      await this.updateVariable('nxtScyllaMotorVoltage', v)
      await this.updateVariable('nxtBoardKitKey', null)
    },

    async onBoardBootstrapModeChange(value: string) {
      await this.updateVariable('nxtBoardBootstrapMode', value === 'auto' ? 'auto' : 'off')
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

    formatPersistedBool(value: unknown): string {
      return value === true || value === 1 ? 'true' : 'false'
    },

    formatPersistedVector(value: unknown): string {
      if (value == null) {
        return 'null'
      }
      if (Array.isArray(value)) {
        return `{${value.join(', ')}}`
      }
      if (value instanceof Map) {
        const parts: unknown[] = []
        for (let i = 0; i < 16; i++) {
          if (!value.has(i) && !value.has(String(i))) {
            break
          }
          parts.push(value.get(i) ?? value.get(String(i)))
        }
        return parts.length ? `{${parts.join(', ')}}` : 'null'
      }
      if (typeof value === 'object') {
        const o = value as Record<string, unknown>
        const keys = Object.keys(o)
          .filter((k) => /^\d+$/.test(k))
          .sort((a, b) => Number(a) - Number(b))
        if (keys.length) {
          return `{${keys.map((k) => o[k]).join(', ')}}`
        }
      }
      return 'null'
    },

    /**
     * Save configuration to /sys/nxt-user-vars.g (full file replace via DWC upload)
     */
    async saveConfiguration() {
      this.saving = true
      try {
        const g = this.globals

        // Use set global.* only — nxt.g reloads this file without M999 (see nxt.g comments).
        const lines = [
          '; NeXT User Configuration',
          '; Auto-generated - Do not edit manually',
          '; Last updated: ' + new Date().toISOString(),
          '',
          '; Feature Flags',
          `set global.nxtFeatureTouchProbe = ${this.formatPersistedBool(g.nxtFeatureTouchProbe)}`,
          `set global.nxtFeatureToolSetter = ${this.formatPersistedBool(g.nxtFeatureToolSetter)}`,
          `set global.nxtFeatureCoolantControl = ${this.formatPersistedBool(g.nxtFeatureCoolantControl)}`,
          '',
          '; Probe tool index and static datum (touch probe / toolsetter calibration)',
          `set global.nxtProbeToolID = ${g.nxtProbeToolID !== null && g.nxtProbeToolID !== undefined ? g.nxtProbeToolID : 'null'}`,
          `set global.nxtDeltaMachine = ${g.nxtDeltaMachine !== null && g.nxtDeltaMachine !== undefined ? g.nxtDeltaMachine : 'null'}`,
          '',
          '; Spindle Configuration',
          `set global.nxtSpindleID = ${g.nxtSpindleID !== null && g.nxtSpindleID !== undefined ? g.nxtSpindleID : 'null'}`,
          `set global.nxtSpindleAccelSec = ${g.nxtSpindleAccelSec !== null && g.nxtSpindleAccelSec !== undefined ? g.nxtSpindleAccelSec : 'null'}`,
          `set global.nxtSpindleDecelSec = ${g.nxtSpindleDecelSec !== null && g.nxtSpindleDecelSec !== undefined ? g.nxtSpindleDecelSec : 'null'}`,
          '',
          '; Touch Probe Configuration',
          `set global.nxtTouchProbeID = ${g.nxtTouchProbeID !== null && g.nxtTouchProbeID !== undefined ? g.nxtTouchProbeID : 'null'}`,
          `set global.nxtProbeTipRadius = ${g.nxtProbeTipRadius !== null && g.nxtProbeTipRadius !== undefined ? g.nxtProbeTipRadius : 'null'}`,
          `set global.nxtProbeDeflection = ${g.nxtProbeDeflection !== null && g.nxtProbeDeflection !== undefined ? g.nxtProbeDeflection : 'null'}`,
          `set global.nxtProbeInnerSampleCount = ${g.nxtProbeInnerSampleCount !== null && g.nxtProbeInnerSampleCount !== undefined ? g.nxtProbeInnerSampleCount : 3}`,
          `set global.nxtProbeMaxSampleSpreadMm = ${g.nxtProbeMaxSampleSpreadMm !== null && g.nxtProbeMaxSampleSpreadMm !== undefined ? g.nxtProbeMaxSampleSpreadMm : 0.0075}`,
          `set global.nxtProbeSampleOuterRetries = ${g.nxtProbeSampleOuterRetries !== null && g.nxtProbeSampleOuterRetries !== undefined ? g.nxtProbeSampleOuterRetries : 1}`,
          '',
          '; Tool Setter Configuration',
          `set global.nxtToolSetterID = ${g.nxtToolSetterID !== null && g.nxtToolSetterID !== undefined ? g.nxtToolSetterID : 'null'}`,
          `set global.nxtToolSetterPos = ${this.formatPersistedVector(g.nxtToolSetterPos)}`,
          '',
          '; Coolant Configuration',
          `set global.nxtCoolantAirID = ${g.nxtCoolantAirID !== null && g.nxtCoolantAirID !== undefined ? g.nxtCoolantAirID : 'null'}`,
          `set global.nxtCoolantMistID = ${g.nxtCoolantMistID !== null && g.nxtCoolantMistID !== undefined ? g.nxtCoolantMistID : 'null'}`,
          `set global.nxtCoolantFloodID = ${g.nxtCoolantFloodID !== null && g.nxtCoolantFloodID !== undefined ? g.nxtCoolantFloodID : 'null'}`,
          '',
          '; Board / platform (Configuration panel)',
          `set global.nxtPlatformProfile = ${
            g.nxtPlatformProfile != null && g.nxtPlatformProfile !== ''
              ? '"' + String(g.nxtPlatformProfile).replace(/"/g, '') + '"'
              : 'null'
          }`,
          `set global.nxtBoardShortNameOverride = ${
            g.nxtBoardShortNameOverride != null && g.nxtBoardShortNameOverride !== ''
              ? '"' + String(g.nxtBoardShortNameOverride).replace(/"/g, '') + '"'
              : 'null'
          }`,
          'set global.nxtBoardKitKey = null',
          `set global.nxtScyllaMotorVoltage = ${
            g.nxtScyllaMotorVoltage !== null && g.nxtScyllaMotorVoltage !== undefined
              ? g.nxtScyllaMotorVoltage
              : 'null'
          }`,
          `set global.nxtBoardBootstrapMode = "${
            g.nxtBoardBootstrapMode === 'auto' ? 'auto' : 'off'
          }"`
        ]

        await uploadDwcFile(NXT_USER_VARS_DWC_PATH, lines.join('\n'))

        this.showStatus(`Configuration saved to ${NXT_USER_VARS_DWC_PATH}`, 'success')
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
      if (this.globals.nxtSpindleID === null || this.spindleTesting) return

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
      if (this.globals.nxtSpindleID === null || this.measuringAccel) return

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
      if (this.globals.nxtSpindleID === null || this.measuringDecel) return

      this.measuringDecel = true

      try {
        const maxRpm = this.selectedSpindleMaxRpm
        const accelTime = this.globals.nxtSpindleAccelSec || 0

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
      if (this.globals.nxtTouchProbeID === null) return

      try {
        // Check probe state from sensors
        const probes = this.$store.state.machine.model.sensors?.probes || []
        const probe = probes[this.globals.nxtTouchProbeID]

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
      if (this.globals.nxtToolSetterID === null) return

      try {
        // Check probe state from sensors
        const probes = this.$store.state.machine.model.sensors?.probes || []
        const probe = probes[this.globals.nxtToolSetterID]

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
        this.globals.nxtToolSetterPos = pos
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
        this.globals.nxtToolSetterPos = pos
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
      if (val && this.globals.nxtToolSetterPos && Array.isArray(this.globals.nxtToolSetterPos)) {
        // Initialize edit values from current position
        this.toolSetterPosEdit.x = this.globals.nxtToolSetterPos[0] || 0
        this.toolSetterPosEdit.y = this.globals.nxtToolSetterPos[1] || 0
        this.toolSetterPosEdit.z = this.globals.nxtToolSetterPos[2] || 0
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
