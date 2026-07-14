<template>
  <v-card>
    <v-card-title>
      <v-icon class="mr-2">mdi-cog</v-icon>
      {{ $t('plugins.nxt.panels.configuration.caption') }}
      <v-spacer />
      <div v-if="!isConnected || !configurationUiAllowed" class="d-flex align-center">
        <v-icon size="small" class="mr-2" color="warning">{{ !isConnected ? 'mdi-lan-disconnect' : 'mdi-alert-circle-outline' }}</v-icon>
        <span class="text-caption">{{
          !isConnected ? $t('plugins.nxt.messages.disconnectedShort') : $t('plugins.nxt.messages.notReadyShort')
        }}</span>
      </div>
    </v-card-title>

    <v-card-text>
      <v-alert type="info" variant="outlined" density="compact" class="mb-4">
        <v-icon class="mr-2" size="small">mdi-information</v-icon>
        Changes are saved immediately to the object model. Use "Save Configuration" to persist to nxt-user-vars.g
      </v-alert>

      <!-- Configuration Sections -->
      <v-expansion-panels v-model="openPanels" multiple class="mb-4">
        <!-- Board & kit -->
        <v-expansion-panel>
          <v-expansion-panel-title>
            <div>
              <v-icon class="mr-2">mdi-circuit-board</v-icon>
              <strong>{{ $t('plugins.nxt.panels.configuration.boardSection') }}</strong>
              <v-spacer />
              <v-icon
                v-if="boardProfileMismatch || scyllaVoltageMissing"
                size="small"
                color="warning"
                class="mr-2"
              >mdi-alert</v-icon>
            </div>
          </v-expansion-panel-title>
          <v-expansion-panel-text>
            <v-alert type="info" density="compact" variant="outlined" class="mb-3">
              <span class="text-caption">{{ $t('plugins.nxt.panels.configuration.boardBootstrapHint') }}</span>
            </v-alert>
            <v-alert type="info" density="compact" variant="outlined" class="mb-3">
              <span class="text-caption">{{ $t('plugins.nxt.panels.configuration.boardLoadOrderHint') }}</span>
            </v-alert>
            <p class="text-caption text-grey mb-2">{{ $t('plugins.nxt.panels.configuration.boardDetected') }}</p>
            <v-chip
              v-for="(b, i) in machineBoardsList"
              :key="'brd-' + i"
              size="small"
              class="mr-2 mb-2"
              variant="outlined"
            >
              [{{ i }}] {{ b.shortName || '—' }} — {{ b.name || '' }}
            </v-chip>
            <p v-if="machineBoardsList.length === 0" class="text-caption text-grey">—</p>
            <v-row class="mt-2">
              <v-col cols="12" md="6">
                <v-text-field
                  :model-value="primaryBoardShortName"
                  :label="$t('plugins.nxt.panels.configuration.boardPrimaryShortName')"
                  readonly
                  density="compact"
                  variant="outlined"
                  hide-details
                />
              </v-col>
              <v-col cols="12" md="6">
                <v-select
                  :model-value="configDraft.nxtPlatformProfile"
                  :items="nxtPlatformSelectItems"
                  item-title="title"
                  item-value="value"
                  :label="$t('plugins.nxt.panels.configuration.boardPlatform')"
                  clearable
                  :disabled="uiFrozen"
                  hide-details
                  @update:model-value="onPlatformProfileChange"
                />
              </v-col>
            </v-row>
            <v-row>
              <v-col cols="12" md="6">
                <v-select
                  :model-value="configDraft.nxtBoardShortNameOverride != null ? String(configDraft.nxtBoardShortNameOverride) : undefined"
                  :items="boardProfileSelectItems"
                  item-title="title"
                  item-value="value"
                  :label="$t('plugins.nxt.panels.configuration.boardProfile')"
                  clearable
                  :placeholder="primaryBoardShortName && primaryBoardShortName !== '—' ? `Auto (${primaryBoardShortName})` : 'Auto (object model)'"
                  :disabled="uiFrozen || boardProfileSelectItems.length === 0"
                  hide-details
                  @update:model-value="onBoardProfileShortNameChange"
                />
                <p v-if="boardProfileSelectItems.length === 0" class="text-caption text-grey mt-1">
                  {{ $t('plugins.nxt.panels.configuration.boardNoKitsPlatform') }}
                </p>
              </v-col>
              <v-col cols="12" md="6">
                <v-select
                  v-if="boardNeedsMotorVoltage"
                  :model-value="scyllaMotorVoltageUiValue"
                  :items="NXT_SCYLLA_MOTOR_VOLTAGE_ITEMS"
                  item-title="title"
                  item-value="value"
                  :label="$t('plugins.nxt.panels.configuration.boardMotorVoltage')"
                  :disabled="uiFrozen"
                  hide-details
                  @update:model-value="onBoardMotorVoltageChange"
                />
              </v-col>
            </v-row>
            <v-row>
              <v-col cols="12" md="6">
                <v-select
                  :model-value="boardBootstrapModeUi"
                  :items="boardBootstrapModeItems"
                  item-title="title"
                  item-value="value"
                  :label="$t('plugins.nxt.panels.configuration.boardBootstrapMode')"
                  :disabled="uiFrozen"
                  hide-details
                  @update:model-value="onBoardBootstrapModeChange"
                />
              </v-col>
            </v-row>
            <template v-if="isCustomPlatform">
              <v-divider class="my-3" />
              <p class="text-caption font-weight-medium mb-1">
                {{ $t('plugins.nxt.panels.configuration.customTravelSection') }}
              </p>
              <p class="text-caption text-grey mb-2">
                {{ $t('plugins.nxt.panels.configuration.customTravelHint') }}
              </p>
              <v-row>
                <v-col cols="6" md="4">
                  <v-text-field
                    :model-value="configDraft.nxtCustomXMin"
                    type="number"
                    step="0.001"
                    :label="$t('plugins.nxt.panels.configuration.customXMin')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomXMin', $event)"
                  />
                </v-col>
                <v-col cols="6" md="4">
                  <v-text-field
                    :model-value="configDraft.nxtCustomXMax"
                    type="number"
                    step="0.001"
                    :label="$t('plugins.nxt.panels.configuration.customXMax')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomXMax', $event)"
                  />
                </v-col>
                <v-col cols="6" md="4">
                  <v-text-field
                    :model-value="configDraft.nxtCustomYMin"
                    type="number"
                    step="0.001"
                    :label="$t('plugins.nxt.panels.configuration.customYMin')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomYMin', $event)"
                  />
                </v-col>
                <v-col cols="6" md="4">
                  <v-text-field
                    :model-value="configDraft.nxtCustomYMax"
                    type="number"
                    step="0.001"
                    :label="$t('plugins.nxt.panels.configuration.customYMax')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomYMax', $event)"
                  />
                </v-col>
                <v-col cols="6" md="4">
                  <v-text-field
                    :model-value="configDraft.nxtCustomZMin"
                    type="number"
                    step="0.001"
                    :label="$t('plugins.nxt.panels.configuration.customZMin')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomZMin', $event)"
                  />
                </v-col>
                <v-col cols="6" md="4">
                  <v-text-field
                    :model-value="configDraft.nxtCustomZMax"
                    type="number"
                    step="0.001"
                    :label="$t('plugins.nxt.panels.configuration.customZMax')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomZMax', $event)"
                  />
                </v-col>
                <v-col cols="6" md="4">
                  <v-text-field
                    :model-value="configDraft.nxtCustomAMin"
                    type="number"
                    step="0.001"
                    :label="$t('plugins.nxt.panels.configuration.customAMin')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomAMin', $event)"
                  />
                </v-col>
                <v-col cols="6" md="4">
                  <v-text-field
                    :model-value="configDraft.nxtCustomAMax"
                    type="number"
                    step="0.001"
                    :label="$t('plugins.nxt.panels.configuration.customAMax')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomAMax', $event)"
                  />
                </v-col>
              </v-row>

              <p class="text-caption font-weight-medium mb-1 mt-4">
                {{ $t('plugins.nxt.panels.configuration.customEndstopsSection') }}
              </p>
              <p class="text-caption text-grey mb-2">
                {{ $t('plugins.nxt.panels.configuration.customEndstopsHint') }}
              </p>
              <v-row v-for="axis in customAxisLetters" :key="'es-' + axis">
                <v-col cols="12" md="6">
                  <v-select
                    :model-value="customEndstopPinList(axis)"
                    :items="customEndstopPinItemsForAxis(axis)"
                    item-title="title"
                    item-value="value"
                    item-props
                    multiple
                    chips
                    closable-chips
                    :label="$t('plugins.nxt.panels.configuration.customEndstopPin', [axis])"
                    :disabled="uiFrozen"
                    clearable
                    hide-details
                    @update:model-value="onCustomEndstopPinList(axis, $event)"
                  >
                    <template #selection="{ item }">
                      <span>{{ endstopSelectItemTitle(item) }}</span>
                    </template>
                    <template #item="{ props: itemProps, item }">
                      <v-list-item
                        v-bind="itemProps"
                        :disabled="endstopSelectItemDisabled(item)"
                        :title="endstopSelectItemTitle(item)"
                      />
                    </template>
                  </v-select>
                </v-col>
                <v-col cols="12" md="6">
                  <v-select
                    :model-value="configDraft[customHomeAtKey(axis)]"
                    :items="customHomeAtItems"
                    item-title="title"
                    item-value="value"
                    :label="$t('plugins.nxt.panels.configuration.customHomeAt', [axis])"
                    :disabled="uiFrozen"
                    clearable
                    hide-details
                    @update:model-value="onConfigDraftSelect(customHomeAtKey(axis), $event)"
                  />
                </v-col>
              </v-row>

              <p class="text-caption font-weight-medium mb-1 mt-4">
                {{ $t('plugins.nxt.panels.configuration.customStepsSection') }}
              </p>
              <v-row>
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="configDraft.nxtCustomXSteps"
                    type="number"
                    step="0.001"
                    :label="$t('plugins.nxt.panels.configuration.customXSteps')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomXSteps', $event)"
                  />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="configDraft.nxtCustomYSteps"
                    type="number"
                    step="0.001"
                    :label="$t('plugins.nxt.panels.configuration.customYSteps')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomYSteps', $event)"
                  />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="configDraft.nxtCustomZSteps"
                    type="number"
                    step="0.001"
                    :label="$t('plugins.nxt.panels.configuration.customZSteps')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomZSteps', $event)"
                  />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="configDraft.nxtCustomASteps"
                    type="number"
                    step="0.001"
                    :label="$t('plugins.nxt.panels.configuration.customASteps')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomASteps', $event)"
                  />
                </v-col>
              </v-row>

              <p class="text-caption font-weight-medium mb-1 mt-4">
                {{ $t('plugins.nxt.panels.configuration.customDrivesSection') }}
              </p>
              <p class="text-caption text-grey mb-2">
                {{ $t('plugins.nxt.panels.configuration.customDrivesHint') }}
              </p>
              <v-row>
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="configDraft.nxtCustomXDrives"
                    :label="$t('plugins.nxt.panels.configuration.customXDrives')"
                    :disabled="uiFrozen"
                    hint="e.g. 0 or 0:1"
                    persistent-hint
                    @update:model-value="onConfigDraftString('nxtCustomXDrives', $event)"
                  />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="configDraft.nxtCustomYDrives"
                    :label="$t('plugins.nxt.panels.configuration.customYDrives')"
                    :disabled="uiFrozen"
                    hint="e.g. 1"
                    persistent-hint
                    @update:model-value="onConfigDraftString('nxtCustomYDrives', $event)"
                  />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="configDraft.nxtCustomZDrives"
                    :label="$t('plugins.nxt.panels.configuration.customZDrives')"
                    :disabled="uiFrozen"
                    hint="e.g. 2 or 2:3"
                    persistent-hint
                    @update:model-value="onConfigDraftString('nxtCustomZDrives', $event)"
                  />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="configDraft.nxtCustomADrives"
                    :label="$t('plugins.nxt.panels.configuration.customADrives')"
                    :disabled="uiFrozen"
                    hint="e.g. 3"
                    persistent-hint
                    @update:model-value="onConfigDraftString('nxtCustomADrives', $event)"
                  />
                </v-col>
              </v-row>

              <p class="text-caption font-weight-medium mb-1 mt-4">
                {{ $t('plugins.nxt.panels.configuration.customDriveDirsSection') }}
              </p>
              <v-row v-if="customMappedDriveIndices.length">
                <v-col
                  v-for="drive in customMappedDriveIndices"
                  :key="'dir-' + drive"
                  cols="12"
                  md="4"
                >
                  <v-select
                    :model-value="customDriveDirValue(drive)"
                    :items="customDriveDirItems"
                    item-title="title"
                    item-value="value"
                    :label="$t('plugins.nxt.panels.configuration.customDriveDir', [drive])"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onCustomDriveDirChange(drive, $event)"
                  />
                </v-col>
              </v-row>
              <p v-else class="text-caption text-grey">
                {{ $t('plugins.nxt.panels.configuration.customDriveDirsEmpty') }}
              </p>

              <p class="text-caption font-weight-medium mb-1 mt-4">
                {{ $t('plugins.nxt.panels.configuration.customCurrentsSection') }}
              </p>
              <v-row>
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="configDraft.nxtCustomXCurrent"
                    type="number"
                    step="1"
                    :label="$t('plugins.nxt.panels.configuration.customXCurrent')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomXCurrent', $event)"
                  />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="configDraft.nxtCustomYCurrent"
                    type="number"
                    step="1"
                    :label="$t('plugins.nxt.panels.configuration.customYCurrent')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomYCurrent', $event)"
                  />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="configDraft.nxtCustomZCurrent"
                    type="number"
                    step="1"
                    :label="$t('plugins.nxt.panels.configuration.customZCurrent')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomZCurrent', $event)"
                  />
                </v-col>
                <v-col cols="6" md="3">
                  <v-text-field
                    :model-value="configDraft.nxtCustomACurrent"
                    type="number"
                    step="1"
                    :label="$t('plugins.nxt.panels.configuration.customACurrent')"
                    :disabled="uiFrozen"
                    hide-details
                    @update:model-value="onConfigDraftNumber('nxtCustomACurrent', $event)"
                  />
                </v-col>
              </v-row>
            </template>
            <v-alert v-if="boardProfileMismatch" type="warning" density="compact" variant="outlined" class="mt-3">
              {{ $t('plugins.nxt.panels.configuration.boardMismatch') }}
            </v-alert>
            <v-alert v-if="scyllaVoltageMissing" type="warning" density="compact" variant="outlined" class="mt-3">
              {{ $t('plugins.nxt.panels.configuration.boardVoltageMissing') }}
            </v-alert>
            <v-alert
              v-for="(msg, i) in boardBootstrapWarnings"
              :key="'boot-warn-' + i"
              type="warning"
              density="compact"
              variant="outlined"
              class="mt-3"
            >
              {{ msg }}
            </v-alert>
            <v-alert
              v-for="(msg, i) in boardPackWarnings"
              :key="'pack-warn-' + i"
              type="warning"
              density="compact"
              variant="outlined"
              class="mt-3"
            >
              {{ msg }}
            </v-alert>
            <v-alert
              v-for="(msg, i) in sdConfigWarnings"
              :key="'sd-warn-' + i"
              type="warning"
              density="compact"
              variant="outlined"
              class="mt-3"
            >
              {{ msg }}
            </v-alert>
            <v-textarea
              :model-value="kitEntryPathForUi"
              :label="$t('plugins.nxt.panels.configuration.boardKitEntry')"
              readonly
              variant="outlined"
              density="compact"
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
              <p class="text-caption font-weight-medium mb-1">{{ $t('plugins.nxt.panels.configuration.boardPlatformTree') }}</p>
              <ul class="text-caption text-grey-darken-1 pl-4 mb-2">
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
              <p class="text-caption text-grey mb-2">{{ $t('plugins.nxt.panels.configuration.boardHomingDocHint') }}</p>
            </div>
            <div class="d-flex flex-wrap mt-2" style="gap: 8px">
              <v-btn
                size="small"
                variant="outlined"
                :disabled="!isConnected"
                :loading="boardStateChecking"
                @click="runBoardStateChecks"
              >
                <v-icon class="mr-2" size="small">mdi-folder-search</v-icon>
                {{ $t('plugins.nxt.panels.configuration.boardCheckSd') }}
              </v-btn>
              <v-btn
                size="small"
                variant="outlined"
                color="primary"
                :disabled="!isConnected || uiFrozen || !canDeployPlatformSysFiles"
                :loading="sysDeploying"
                @click="applyPlatformSysFiles"
              >
                <v-icon class="mr-2" size="small">mdi-file-upload</v-icon>
                {{ $t('plugins.nxt.panels.configuration.boardApplySysFiles') }}
              </v-btn>
              <v-btn size="small" variant="outlined" color="primary" :disabled="!isConnected" @click="copyBoardConfigHint">
                <v-icon class="mr-2" size="small">mdi-content-copy</v-icon>
                {{ $t('plugins.nxt.panels.configuration.boardCopySnippet') }}
              </v-btn>
              <v-btn
                size="small"
                variant="outlined"
                :disabled="!isConnected || uiFrozen || pinmapSaving"
                :loading="pinmapSaving"
                @click="savePinmapStub"
              >
                {{ $t('plugins.nxt.panels.configuration.boardSavePinmap') }}
              </v-btn>
            </div>
            <p class="text-caption text-grey mt-2 mb-0">{{ $t('plugins.nxt.panels.configuration.boardPinmapHint') }}</p>
          </v-expansion-panel-text>
        </v-expansion-panel>

        <!-- Spindle Configuration -->
        <v-expansion-panel>
          <v-expansion-panel-title>
            <div>
              <v-icon class="mr-2">mdi-fan</v-icon>
              <strong>Spindle Configuration</strong>
            </div>
          </v-expansion-panel-title>
          <v-expansion-panel-text>
            <v-row>
              <v-col cols="12">
                <v-select
                  :model-value="configDraft.nxtSpindleID"
                  :items="availableSpindles"
                  item-title="name"
                  item-value="id"
                  label="Spindle"
                  :disabled="uiFrozen"
                  @update:model-value="onConfigDraftSelect('nxtSpindleID', $event)"
                  hint="Select configured spindle"
                  persistent-hint
                  clearable
                >
                  <template #item="{ props: itemProps, item }">
                    <v-list-item
                      v-bind="itemProps"
                      :title="spindleSelectItemTitle(item)"
                      :subtitle="spindleSelectItemSubtitle(item)"
                    />
                  </template>
                  <template v-slot:append>
                    <v-tooltip location="top">
                      <template v-slot:activator="{ props }">
                        <v-btn
                          icon
                          size="small"
                          @mousedown="startSpindleTest"
                          @mouseup="stopSpindleTest"
                          @mouseleave="stopSpindleTest"
                          @touchstart="startSpindleTest"
                          @touchend="stopSpindleTest"
                          :disabled="uiFrozen || configDraft.nxtSpindleID === null"
                          :color="spindleTesting ? 'primary' : ''"
                          v-bind="props"
                        >
                          <v-icon size="small">{{ spindleTesting ? 'mdi-fan' : 'mdi-test-tube' }}</v-icon>
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
                  :model-value="configDraft.nxtSpindleAccelSec"
                  label="Acceleration Time (s)"
                  type="number"
                  step="0.1"
                  :disabled="uiFrozen"
                  @update:model-value="onConfigDraftNumber('nxtSpindleAccelSec', $event)"
                  hint="Time for spindle to reach speed"
                  persistent-hint
                >
                  <template v-slot:append>
                    <v-tooltip location="top">
                      <template v-slot:activator="{ props }">
                        <v-btn
                          icon
                          size="small"
                          @mousedown="startAccelerationMeasurement"
                          @mouseup="stopAccelerationMeasurement"
                          @mouseleave="stopAccelerationMeasurement"
                          @touchstart="startAccelerationMeasurement"
                          @touchend="stopAccelerationMeasurement"
                          :disabled="uiFrozen || configDraft.nxtSpindleID === null"
                          :color="measuringAccel ? 'primary' : ''"
                          v-bind="props"
                        >
                          <v-icon size="small" :class="{ 'rotating-icon': measuringAccel }">
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
                  :model-value="configDraft.nxtSpindleDecelSec"
                  label="Deceleration Time (s)"
                  type="number"
                  step="0.1"
                  :disabled="uiFrozen"
                  @update:model-value="onConfigDraftNumber('nxtSpindleDecelSec', $event)"
                  hint="Time for spindle to stop"
                  persistent-hint
                >
                  <template v-slot:append>
                    <v-tooltip location="top">
                      <template v-slot:activator="{ props }">
                        <v-btn
                          icon
                          size="small"
                          @mousedown="startDecelerationMeasurement"
                          @mouseup="stopDecelerationMeasurement"
                          @mouseleave="stopDecelerationMeasurement"
                          @touchstart="startDecelerationMeasurement"
                          @touchend="stopDecelerationMeasurement"
                          :disabled="uiFrozen || configDraft.nxtSpindleID === null || configDraft.nxtSpindleAccelSec === null || configDraft.nxtSpindleAccelSec === undefined"
                          :color="measuringDecel ? 'primary' : ''"
                          v-bind="props"
                        >
                          <v-icon size="small" :class="{ 'rotating-icon': measuringDecel }">
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
          </v-expansion-panel-text>
        </v-expansion-panel>

        <!-- Touch Probe Configuration -->
        <v-expansion-panel>
          <v-expansion-panel-title>
            <div>
              <v-icon class="mr-2">mdi-target</v-icon>
              <strong>Touch Probe Configuration</strong>
              <v-spacer />
              <v-icon v-if="touchProbeRequirementsMet" size="small" color="success" class="mr-2">mdi-check-circle</v-icon>
              <v-icon v-else size="small" color="warning" class="mr-2">mdi-alert-circle</v-icon>
            </div>
          </v-expansion-panel-title>
          <v-expansion-panel-text>
            <v-alert v-if="!touchProbeRequirementsMet" type="warning" density="compact" variant="outlined" class="mb-4">
              <div class="text-caption">{{ touchProbeRequirementsMessage }}</div>
            </v-alert>

            <v-row>
              <v-col cols="12" md="8">
                <v-select
                  :model-value="configDraft.nxtTouchProbeID"
                  :items="touchProbeSelectItems"
                  item-title="name"
                  item-value="id"
                  item-props
                  label="Touch Probe Sensor *"
                  :disabled="uiFrozen"
                  @update:model-value="onConfigDraftSelect('nxtTouchProbeID', $event)"
                  hint="Select the Probe pin (clear to unassign). Pins used by Toolsetter are disabled."
                  persistent-hint
                  :error="configDraft.nxtTouchProbeID === null"
                  clearable
                >
                  <template #selection="{ item }">
                    <span>{{ probeSelectItemTitle(item) }}</span>
                  </template>
                  <template #item="{ props: itemProps, item }">
                    <v-list-item
                      v-bind="itemProps"
                      :disabled="probeSelectItemDisabled(item)"
                      :title="probeSelectItemTitle(item)"
                      :subtitle="probeItemSubtitle(probeSelectItemRaw(item))"
                    />
                  </template>
                </v-select>
              </v-col>
              <v-col cols="12" md="4" class="d-flex align-center">
                <v-checkbox
                  :model-value="configDraft.nxtTouchProbeInvert"
                  label="Invert pin (active low)"
                  :disabled="uiFrozen || configDraft.nxtTouchProbeID === null"
                  hide-details
                  density="compact"
                  class="mt-0"
                  @update:model-value="onProbeInvertChange('nxtTouchProbeInvert', $event)"
                />
              </v-col>
            </v-row>
            <v-row class="mt-1">
              <v-col cols="12">
                <v-alert
                  :type="touchProbeLiveTriggered ? 'success' : 'info'"
                  density="compact"
                  variant="tonal"
                  class="mb-0"
                >
                  <div class="d-flex align-center flex-wrap" style="gap: 8px">
                    <v-icon size="small">{{ touchProbeLiveIcon }}</v-icon>
                    <strong>Input test:</strong>
                    <span>{{ touchProbeLiveLabel || 'Select a probe sensor' }}</span>
                    <v-spacer />
                    <span class="text-caption">{{ touchProbeLiveTooltip }}</span>
                  </div>
                </v-alert>
              </v-col>
            </v-row>
            <v-row>
              <v-col cols="12" md="4">
                <v-text-field
                  :model-value="configDraft.nxtProbeTipRadius"
                  label="Probe Tip Radius (mm) *"
                  type="number"
                  step="0.001"
                  :disabled="uiFrozen"
                  @update:model-value="onConfigDraftNumber('nxtProbeTipRadius', $event)"
                  hint="Required - For horizontal compensation"
                  persistent-hint
                  :error="configDraft.nxtProbeTipRadius === null || configDraft.nxtProbeTipRadius === 0"
                />
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field
                  :model-value="probeDeflectionX"
                  label="Deflection X (mm) *"
                  type="number"
                  step="0.001"
                  :disabled="uiFrozen"
                  @update:model-value="onProbeDeflectionComponent(0, $event)"
                  hint="X-axis touch-probe deflection"
                  persistent-hint
                  :error="!probeDeflectionConfigured"
                />
              </v-col>
              <v-col cols="12" md="4">
                <v-text-field
                  :model-value="probeDeflectionY"
                  label="Deflection Y (mm) *"
                  type="number"
                  step="0.001"
                  :disabled="uiFrozen"
                  @update:model-value="onProbeDeflectionComponent(1, $event)"
                  hint="Y-axis touch-probe deflection (0 if not measured)"
                  persistent-hint
                  :error="!probeDeflectionConfigured"
                >
                  <template v-slot:append>
                    <v-tooltip location="top">
                      <template v-slot:activator="{ props }">
                        <v-btn
                          icon
                          size="small"
                          @click="navigateToCalibration"
                          :disabled="uiFrozen"
                          v-bind="props"
                        >
                          <v-icon size="small">mdi-ruler</v-icon>
                        </v-btn>
                      </template>
                      <span>Go to Calibration</span>
                    </v-tooltip>
                  </template>
                </v-text-field>
              </v-col>
            </v-row>
            <v-alert type="info" density="compact" variant="outlined" class="mb-2">
              <span class="text-caption">
                Probe repeatability (G6512 sample count, pair tolerance, retries) uses defaults from
                <code>nxt-vars.g</code>. Copy <code>nxt-user-overrides.g.example</code> to
                <code>0:/sys/nxt-user-overrides.g</code> to override (loaded last in <code>nxt.g</code> before <code>nxtLoaded</code>).
              </span>
            </v-alert>

            <!-- Feature Toggle -->
            <v-row class="mt-4">
              <v-col cols="12">
                <v-divider class="mb-4" />
                <v-switch
                  :model-value="configDraft.nxtFeatureTouchProbe"
                  label="Enable Touch Probe Feature"
                  :disabled="uiFrozen || !touchProbeRequirementsMet"
                  @update:model-value="updateFeature('nxtFeatureTouchProbe', $event)"
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
          </v-expansion-panel-text>
        </v-expansion-panel>

        <!-- Tool Setter Configuration -->
        <v-expansion-panel>
          <v-expansion-panel-title>
            <div>
              <v-icon class="mr-2">mdi-wrench</v-icon>
              <strong>Tool Setter Configuration</strong>
              <v-spacer />
              <v-icon v-if="toolSetterRequirementsMet" size="small" color="success" class="mr-2">mdi-check-circle</v-icon>
              <v-icon v-else size="small" color="warning" class="mr-2">mdi-alert-circle</v-icon>
            </div>
          </v-expansion-panel-title>
          <v-expansion-panel-text>
            <v-alert v-if="!toolSetterRequirementsMet" type="warning" density="compact" variant="outlined" class="mb-4">
              <div class="text-caption">{{ toolSetterRequirementsMessage }}</div>
            </v-alert>

            <v-row>
              <v-col cols="12" md="8">
                <v-select
                  :model-value="configDraft.nxtToolSetterID"
                  :items="toolSetterSelectItems"
                  item-title="name"
                  item-value="id"
                  item-props
                  label="Tool Setter Sensor *"
                  :disabled="uiFrozen"
                  @update:model-value="onConfigDraftSelect('nxtToolSetterID', $event)"
                  hint="Select the Toolsetter pin (clear to unassign). Pins used by Touch Probe are disabled."
                  persistent-hint
                  :error="configDraft.nxtToolSetterID === null"
                  clearable
                >
                  <template #selection="{ item }">
                    <span>{{ probeSelectItemTitle(item) }}</span>
                  </template>
                  <template #item="{ props: itemProps, item }">
                    <v-list-item
                      v-bind="itemProps"
                      :disabled="probeSelectItemDisabled(item)"
                      :title="probeSelectItemTitle(item)"
                      :subtitle="probeItemSubtitle(probeSelectItemRaw(item))"
                    />
                  </template>
                </v-select>
              </v-col>
              <v-col cols="12" md="4" class="d-flex align-center">
                <v-checkbox
                  :model-value="configDraft.nxtToolSetterInvert"
                  label="Invert pin (active low)"
                  :disabled="uiFrozen || configDraft.nxtToolSetterID === null"
                  hide-details
                  density="compact"
                  class="mt-0"
                  @update:model-value="onProbeInvertChange('nxtToolSetterInvert', $event)"
                />
              </v-col>
            </v-row>
            <v-row class="mt-1">
              <v-col cols="12">
                <v-alert
                  :type="toolSetterLiveTriggered ? 'success' : 'info'"
                  density="compact"
                  variant="tonal"
                  class="mb-0"
                >
                  <div class="d-flex align-center flex-wrap" style="gap: 8px">
                    <v-icon size="small">{{ toolSetterLiveIcon }}</v-icon>
                    <strong>Input test:</strong>
                    <span>{{ toolSetterLiveLabel || 'Select a toolsetter sensor' }}</span>
                    <v-spacer />
                    <span class="text-caption">{{ toolSetterLiveTooltip }}</span>
                  </div>
                </v-alert>
              </v-col>
            </v-row>
            <v-row>
              <v-col cols="12">
                <v-text-field
                  :model-value="formatToolSetterPos"
                  label="Tool Setter Position [X, Y, Z] *"
                  readonly
                  hint="Required - Position in machine coordinates"
                  persistent-hint
                  :error="!configDraft.nxtToolSetterPos || !Array.isArray(configDraft.nxtToolSetterPos) || configDraft.nxtToolSetterPos.length !== 3"
                >
                  <template v-slot:append>
                    <v-tooltip location="top">
                      <template v-slot:activator="{ props }">
                        <v-btn
                          icon
                          size="small"
                          @click="setCurrentPositionAsToolSetter"
                          :disabled="uiFrozen || !allAxesHomed"
                          v-bind="props"
                        >
                          <v-icon size="small">mdi-crosshairs-gps</v-icon>
                        </v-btn>
                      </template>
                      <span>Set Current Position</span>
                    </v-tooltip>
                    <v-btn
                      icon
                      size="small"
                      @click="showToolSetterPosDialog = true"
                      :disabled="uiFrozen"
                    >
                      <v-icon size="small">mdi-pencil</v-icon>
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
                  :model-value="configDraft.nxtFeatureToolSetter"
                  label="Enable Tool Setter Feature"
                  :disabled="uiFrozen || !toolSetterRequirementsMet"
                  @update:model-value="updateFeature('nxtFeatureToolSetter', $event)"
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
          </v-expansion-panel-text>
        </v-expansion-panel>

        <!-- Coolant Control Configuration -->
        <v-expansion-panel>
          <v-expansion-panel-title>
            <div>
              <v-icon class="mr-2">mdi-water</v-icon>
              <strong>Coolant Control Configuration</strong>
              <v-spacer />
              <v-icon v-if="coolantControlRequirementsMet" size="small" color="success" class="mr-2">mdi-check-circle</v-icon>
              <v-icon v-else size="small" color="warning" class="mr-2">mdi-alert-circle</v-icon>
            </div>
          </v-expansion-panel-title>
          <v-expansion-panel-text>
            <v-alert v-if="!coolantControlRequirementsMet" type="warning" density="compact" variant="outlined" class="mb-4">
              <div class="text-caption">{{ coolantControlRequirementsMessage }}</div>
            </v-alert>
            <v-alert v-if="coolantRelayReserved" type="info" density="compact" variant="outlined" class="mb-4">
              <div class="text-caption">{{ $t('plugins.nxt.panels.configuration.coolantRelayReserved') }}</div>
            </v-alert>
            <p class="text-caption text-grey mb-2">
              {{ $t('plugins.nxt.panels.configuration.outputGpHint') }}
            </p>

            <v-row>
              <v-col cols="12" md="4">
                <v-select
                  :model-value="configDraft.nxtRelayID"
                  :items="gpOutItemsForRole('nxtRelayID')"
                  item-title="name"
                  item-value="id"
                  item-props
                  :label="$t('plugins.nxt.panels.configuration.outputRelay')"
                  :disabled="uiFrozen"
                  @update:model-value="onConfigDraftSelect('nxtRelayID', $event)"
                  :hint="$t('plugins.nxt.panels.configuration.outputGpHint')"
                  persistent-hint
                  clearable
                />
              </v-col>
              <v-col cols="12" md="4">
                <v-select
                  :model-value="configDraft.nxtAux1ID"
                  :items="gpOutItemsForRole('nxtAux1ID')"
                  item-title="name"
                  item-value="id"
                  item-props
                  :label="$t('plugins.nxt.panels.configuration.outputAux0')"
                  :disabled="uiFrozen"
                  @update:model-value="onConfigDraftSelect('nxtAux1ID', $event)"
                  clearable
                  hide-details
                />
              </v-col>
              <v-col cols="12" md="4">
                <v-select
                  :model-value="configDraft.nxtAux2ID"
                  :items="gpOutItemsForRole('nxtAux2ID')"
                  item-title="name"
                  item-value="id"
                  item-props
                  :label="$t('plugins.nxt.panels.configuration.outputAux1')"
                  :disabled="uiFrozen"
                  @update:model-value="onConfigDraftSelect('nxtAux2ID', $event)"
                  clearable
                  hide-details
                />
              </v-col>
              <v-col cols="12" md="4">
                <v-select
                  :model-value="configDraft.nxtAux3ID"
                  :items="gpOutItemsForRole('nxtAux3ID')"
                  item-title="name"
                  item-value="id"
                  item-props
                  :label="$t('plugins.nxt.panels.configuration.outputAux2')"
                  :disabled="uiFrozen"
                  @update:model-value="onConfigDraftSelect('nxtAux3ID', $event)"
                  clearable
                  hide-details
                />
              </v-col>
              <v-col cols="12" md="4">
                <v-select
                  :model-value="configDraft.nxtCoolantAirID"
                  :items="gpOutItemsForRole('nxtCoolantAirID')"
                  item-title="name"
                  item-value="id"
                  item-props
                  label="Air Blast Output"
                  :disabled="uiFrozen"
                  @update:model-value="onConfigDraftSelect('nxtCoolantAirID', $event)"
                  hint="Select named output (clear to unassign)"
                  persistent-hint
                  clearable
                />
              </v-col>
              <v-col cols="12" md="4">
                <v-select
                  :model-value="configDraft.nxtCoolantMistID"
                  :items="gpOutItemsForRole('nxtCoolantMistID')"
                  item-title="name"
                  item-value="id"
                  item-props
                  label="Mist Coolant Output"
                  :disabled="uiFrozen"
                  @update:model-value="onConfigDraftSelect('nxtCoolantMistID', $event)"
                  hint="Select Mist / named output (clear to unassign)"
                  persistent-hint
                  clearable
                />
              </v-col>
              <v-col cols="12" md="4">
                <v-select
                  :model-value="configDraft.nxtCoolantFloodID"
                  :items="gpOutItemsForRole('nxtCoolantFloodID')"
                  item-title="name"
                  item-value="id"
                  item-props
                  label="Flood / Coolant Output"
                  :disabled="uiFrozen"
                  @update:model-value="onConfigDraftSelect('nxtCoolantFloodID', $event)"
                  hint="Select Coolant / named output (clear to unassign)"
                  persistent-hint
                  clearable
                />
              </v-col>
              <v-col cols="12">
                <v-select
                  :model-value="effectiveBoardFanPins"
                  :items="boardFanPinItems"
                  item-title="title"
                  item-value="value"
                  chips
                  multiple
                  closable-chips
                  :label="$t('plugins.nxt.panels.configuration.boardFanPins')"
                  :hint="$t('plugins.nxt.panels.configuration.boardFanPinsHint')"
                  persistent-hint
                  :disabled="uiFrozen"
                  @update:model-value="onBoardFanPinsChange"
                />
              </v-col>
              <v-col cols="12" md="6">
                <v-select
                  :model-value="configDraft.nxtUartDevice"
                  :items="uartDeviceItems"
                  item-title="title"
                  item-value="value"
                  :label="$t('plugins.nxt.panels.configuration.uartDevice')"
                  :hint="$t('plugins.nxt.panels.configuration.uartDeviceHint')"
                  persistent-hint
                  :disabled="uiFrozen"
                  @update:model-value="onUartDeviceChange"
                />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field
                  :model-value="configDraft.nxtUartBaud"
                  type="number"
                  min="9600"
                  step="100"
                  :label="$t('plugins.nxt.panels.configuration.uartBaud')"
                  :disabled="uiFrozen || configDraft.nxtUartDevice === 0"
                  @update:model-value="onUartBaudChange"
                  hint="Default 57600"
                  persistent-hint
                />
              </v-col>
            </v-row>

            <p class="text-caption font-weight-medium mb-1 mt-4">
              Output test (hold to energize)
            </p>
            <p class="text-caption text-grey mb-2">
              {{ $t('plugins.nxt.panels.configuration.outputTestHint') }}
            </p>
            <v-row dense>
              <v-col
                v-for="row in gpOutTestRows"
                :key="row.key"
                cols="6"
                sm="4"
                md="3"
              >
                <v-btn
                  block
                  variant="outlined"
                  :color="gpOutTestingKey === row.key ? 'warning' : undefined"
                  :disabled="uiFrozen || !isConnected || !row.canTest"
                  @pointerdown.prevent="startGpOutTest(row, $event)"
                  @pointerup.prevent="stopGpOutTest"
                  @pointercancel="stopGpOutTest"
                >
                  <v-icon start size="small">
                    {{ gpOutTestingKey === row.key ? 'mdi-flash' : 'mdi-flash-outline' }}
                  </v-icon>
                  {{ row.label }}
                </v-btn>
              </v-col>
            </v-row>

            <v-row class="mt-2">
              <v-col cols="12" md="6">
                <v-switch
                  :model-value="configDraft.nxtCoolantMistPulseEnabled"
                  :label="$t('plugins.nxt.panels.configuration.coolantMistPulse')"
                  :hint="$t('plugins.nxt.panels.configuration.coolantMistPulseHint')"
                  persistent-hint
                  :disabled="uiFrozen || configDraft.nxtCoolantMistID === null"
                  @update:model-value="updateFeature('nxtCoolantMistPulseEnabled', $event)"
                  class="mt-0"
                />
              </v-col>
              <v-col cols="12" md="6">
                <v-switch
                  :model-value="configDraft.nxtCoolantFloodPulseEnabled"
                  :label="$t('plugins.nxt.panels.configuration.coolantFloodPulse')"
                  :hint="$t('plugins.nxt.panels.configuration.coolantFloodPulseHint')"
                  persistent-hint
                  :disabled="uiFrozen || configDraft.nxtCoolantFloodID === null"
                  @update:model-value="updateFeature('nxtCoolantFloodPulseEnabled', $event)"
                  class="mt-0"
                />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field
                  :model-value="configDraft.nxtCoolantPulseOnSec"
                  type="number"
                  min="1"
                  step="1"
                  :label="$t('plugins.nxt.panels.configuration.coolantPulseOnSec')"
                  :disabled="uiFrozen || !coolantPulseTimingConfigurable"
                  @update:model-value="onConfigDraftPulseSec('nxtCoolantPulseOnSec', $event)"
                  hint="Default 5"
                  persistent-hint
                />
              </v-col>
              <v-col cols="12" md="6">
                <v-text-field
                  :model-value="configDraft.nxtCoolantPulseOffSec"
                  type="number"
                  min="1"
                  step="1"
                  :label="$t('plugins.nxt.panels.configuration.coolantPulseOffSec')"
                  :disabled="uiFrozen || !coolantPulseTimingConfigurable"
                  @update:model-value="onConfigDraftPulseSec('nxtCoolantPulseOffSec', $event)"
                  hint="Default 25"
                  persistent-hint
                />
              </v-col>
            </v-row>

            <!-- Feature Toggle -->
            <v-row class="mt-4">
              <v-col cols="12">
                <v-divider class="mb-4" />
                <v-switch
                  :model-value="configDraft.nxtFeatureCoolantControl"
                  label="Enable Coolant Control Feature"
                  :disabled="uiFrozen || !coolantControlRequirementsMet"
                  @update:model-value="updateFeature('nxtFeatureCoolantControl', $event)"
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
          </v-expansion-panel-text>
        </v-expansion-panel>

        <!-- Fourth / A axis (Scylla drive 3; MosFourthAxis for steps/homea) -->
        <v-expansion-panel>
          <v-expansion-panel-title>
            <div>
              <v-icon class="mr-2">mdi-axis-z-rotate-clockwise</v-icon>
              <strong>Fourth Axis (A / Rotary)</strong>
              <v-spacer />
              <v-icon v-if="configDraft.nxtFeatureFourthAxis" size="small" color="success" class="mr-2">
                mdi-check-circle
              </v-icon>
            </div>
          </v-expansion-panel-title>
          <v-expansion-panel-text>
            <v-alert type="info" density="compact" variant="outlined" class="mb-3">
              <span class="text-caption">
                Uses firmware flag <code>global.nxtFeatureFourthAxis</code>. On Scylla, board pack
                loads <code>axis-a.g</code> (drive 3, <code>M584 A3 R1</code>) at the next boot with
                board bootstrap. On Custom, configure A travel / endstops / drives in the Custom
                section (optional); Save writes <code>homea.g</code> when A is complete.
                Install MosFourthAxis for shared A calibration macros if needed.
              </span>
            </v-alert>
            <v-switch
              :model-value="configDraft.nxtFeatureFourthAxis"
              label="Enable Fourth Axis Feature"
              :disabled="uiFrozen"
              @update:model-value="updateFeature('nxtFeatureFourthAxis', $event)"
              hint="Save Configuration, then reboot so the board pack can map A."
              persistent-hint
              class="mt-0"
            />
          </v-expansion-panel-text>
        </v-expansion-panel>

        <!-- RGB / Work Light Configuration -->
        <v-expansion-panel v-if="rgbHardwareConfigured">
          <v-expansion-panel-title>
            <div>
              <v-icon class="mr-2">mdi-lightbulb-on</v-icon>
              <strong>{{ $t('plugins.nxt.panels.configuration.rgbLight') }}</strong>
              <v-spacer />
              <v-icon v-if="configDraft.nxtFeatureRgbLight" size="small" color="success" class="mr-2">
                mdi-check-circle
              </v-icon>
            </div>
          </v-expansion-panel-title>
          <v-expansion-panel-text>
            <v-row>
              <v-col cols="12" md="4">
                <v-select
                  :model-value="configDraft.nxtRgbLedIndex"
                  :items="rgbLedSelectItems"
                  item-title="text"
                  item-value="value"
                  :label="$t('plugins.nxt.panels.configuration.rgbLedIndex')"
                  :disabled="uiFrozen"
                  @update:model-value="onConfigDraftSelect('nxtRgbLedIndex', $event)"
                  :hint="$t('plugins.nxt.panels.configuration.rgbLedIndexHint')"
                  persistent-hint
                />
              </v-col>
            </v-row>
            <v-row class="mt-2">
              <v-col cols="12">
                <v-switch
                  :model-value="configDraft.nxtFeatureRgbLight"
                  :label="$t('plugins.nxt.panels.configuration.rgbFeatureEnable')"
                  :disabled="uiFrozen"
                  @update:model-value="updateFeature('nxtFeatureRgbLight', $event)"
                  class="mt-0"
                />
              </v-col>
            </v-row>
          </v-expansion-panel-text>
        </v-expansion-panel>

        <!-- nxt globals snapshot (read-only) -->
        <v-expansion-panel>
          <v-expansion-panel-title>
            <div>
              <v-icon class="mr-2">mdi-database-eye</v-icon>
              <strong>{{ $t('plugins.nxt.panels.configuration.globalsSnapshotTitle') }}</strong>
            </div>
          </v-expansion-panel-title>
          <v-expansion-panel-text>
            <p class="body-2 text-grey-darken-1 mb-3">
              {{ $t('plugins.nxt.panels.configuration.globalsSnapshotIntro') }}
            </p>
            <div class="d-flex flex-wrap mb-2" style="gap: 8px">
              <v-btn size="small" variant="outlined" color="primary" :disabled="!isConnected" @click="copyNxtGlobalsSnapshot">
                <v-icon class="mr-2" size="small">mdi-content-copy</v-icon>
                {{ $t('plugins.nxt.panels.configuration.globalsSnapshotCopy') }}
              </v-btn>
            </div>
            <v-table density="compact" class="nxt-globals-snapshot-table">
              <template #default>
                <thead>
                  <tr>
                    <th class="text-left text-no-wrap">{{ $t('plugins.nxt.panels.configuration.globalsColKey') }}</th>
                    <th class="text-left">{{ $t('plugins.nxt.panels.configuration.globalsColDescription') }}</th>
                    <th class="text-left">{{ $t('plugins.nxt.panels.configuration.globalsColValue') }}</th>
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
            </v-table>
          </v-expansion-panel-text>
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
            <v-icon class="mr-2">mdi-content-save</v-icon>
            Save Configuration
          </v-btn>
          <v-btn
            color="secondary"
            class="ml-2"
            @click="loadConfiguration"
            :disabled="uiFrozen || !configurationUiAllowed"
            :loading="loading"
          >
            <v-icon class="mr-2">mdi-refresh</v-icon>
            Reload
          </v-btn>
        </v-col>
      </v-row>

      <!-- Status Messages -->
      <v-alert
        v-if="statusMessage"
        :type="statusType"
        closable
        class="mt-4"
        @update:model-value="statusMessage = ''"
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
import { defineNxtComponent } from '../base/BaseComponent.vue'
import { snapshotNxtGlobals } from '../../utils/nxtGlobalsManifest'
import {
  NXT_PLATFORM_OPTIONS,
  boardProfileSelectItems as getBundledBoardProfileSelectItems,
  nxtBoardPackRelPath,
  bundledBoardMeta,
  migrateLegacyBoardKitKey,
  migratePlatformProfileId,
  gpOutItemsForBoard,
  gpOutRoleLabelForId,
  probeSelectItemsForBoard,
  probeRoleLabelForId,
  probePinLiteralForIndex,
  resolveProbeM558Type,
  buildProbeM558PinCommand,
  NXT_GPOUT_ROLE_KEYS,
  NXT_PROBE_ROLE_KEYS,
  NXT_CUSTOM_ENDSTOP_ROLE_KEYS,
  NXT_NAMED_OUTPUT_ALIASES,
  defaultBoardFanPinsForVoltage,
  fanIndexForPinAlias,
  namedOutputSelectItems,
  platformStructureSummary,
  NXT_SCYLLA_MOTOR_VOLTAGE_ITEMS,
  endstopPinItemsForBoard,
  type NxtPlatformId,
  type GpOutItem,
  type ProbeSelectItem,
  type NxtCustomEndstopRoleKey,
  type EndstopPinSelectItem
} from '../../utils/nxtBoardManifest'
import { deployPlatformSysFiles } from '../../utils/nxtBoardSysDeploy'
import { nxtPlatformFromManifest } from '../../utils/nxtConfigManifestData'
import {
  NXT_USER_VARS_DWC_PATH,
  NXT_USER_PINMAP_DWC_PATH,
  uploadDwcFile
} from '../../utils/nxtFileUpload'
import { scanNxtConfigOnSd, formatSdScanWarnings } from '../../utils/nxtConfigSdScan'
import { reconcileBoardState } from '../../utils/nxtBoardStateReconcile'
import {
  applySingletonDefaults,
  buildInitialConfigDraft,
  emptyConfigDraft,
  nxtConfigPendingInOm,
  nxtUserVarsPresentInOm,
  snapshotConfigFromOm,
  formatPersistedStringVector,
  type NxtUserConfigDraft
} from '../../utils/nxtUserVarsPersistence'
import {
  ensureCustomGlobals,
  persistNxtUserConfig,
  syncCustomARequestedSentinel
} from '../../utils/nxtUserConfigPersist'
import {
  customAAxisPartiallyConfigured,
  formatDriveDirs,
  formatEndstopPinList,
  parseDriveDirs,
  parseDriveList,
  parseEndstopPinList,
  validateCustomMachineDraft
} from '../../utils/nxtCustomPackGenerate'
import { readFirmwareGlobal } from '../../utils/nxtToolChangerOm'
import {
  countOmLeds,
  isRgbLightHardwareConfigured,
  readOmLedsFromMachineModel,
  rgbLedIndexItems
} from '../../utils/nxtRgbAvailability'
import {
  getProbeByIndex,
  isProbeTriggered,
  probeReadingText
} from '../../utils/nxtProbeOm'
import {
  clearFirmwareGlobalIfExists,
  ensureSetFirmwareGlobal,
  formatOmRhs
} from '../../utils/nxtOmEnsureSet'

/**
 * nxt Configuration Panel
 *
 * Replaces G8000 wizard with direct UI-based configuration editing.
 * Allows configuration of all nxt settings including features, spindle,
 * touch probe, tool setter, and coolant control.
 */
export default defineNxtComponent({
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

      // Spindle test state
      spindleTesting: false,
      // Coolant / relay hold-to-test (M42 / M106) — capture id at press to avoid race
      gpOutTestingKey: null as string | null,
      gpOutTestingId: null as number | null,
      gpOutTestingMode: null as 'gpout' | 'fan' | null,
      gpOutTestSeq: 0,

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
        this.probeDeflectionConfigured
      )
    },

    probeDeflectionConfigured(): boolean {
      const d = this.configDraft.nxtProbeDeflection
      return d != null && d.length >= 2 && Number.isFinite(d[0]) && Number.isFinite(d[1])
    },

    probeDeflectionX(): number | null {
      const d = this.configDraft.nxtProbeDeflection
      return d != null && d.length >= 1 && Number.isFinite(d[0]) ? d[0] : null
    },

    probeDeflectionY(): number | null {
      const d = this.configDraft.nxtProbeDeflection
      return d != null && d.length >= 2 && Number.isFinite(d[1]) ? d[1] : null
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
      if (!this.probeDeflectionConfigured) missing.push('Deflection X/Y')
      return `Required: ${missing.join(', ')}`
    },
    /** Live OM probe row for the selected touch-probe sensor index. */
    selectedTouchProbeOm() {
      return getProbeByIndex(
        this.$store.state.machine.model.sensors?.probes,
        this.configDraft.nxtTouchProbeID
      )
    },

    touchProbeLiveTriggered(): boolean {
      return isProbeTriggered(this.selectedTouchProbeOm)
    },

    touchProbeLiveColor(): string {
      if (!this.isConnected) {
        return 'grey'
      }
      if (this.configDraft.nxtTouchProbeID === null) {
        return 'grey'
      }
      if (!this.selectedTouchProbeOm) {
        return 'warning'
      }
      return this.touchProbeLiveTriggered ? 'success' : 'grey darken-1'
    },

    touchProbeLiveIcon(): string {
      if (!this.isConnected || !this.selectedTouchProbeOm) {
        return 'mdi-lan-disconnect'
      }
      return this.touchProbeLiveTriggered ? 'mdi-check-circle' : 'mdi-circle-outline'
    },

    touchProbeLiveLabel(): string {
      if (!this.isConnected) {
        return 'Offline'
      }
      const id = this.configDraft.nxtTouchProbeID
      if (id === null) {
        return ''
      }
      if (!this.selectedTouchProbeOm) {
        return `Probe ${id}: —`
      }
      const reading = probeReadingText(this.selectedTouchProbeOm)
      return this.touchProbeLiveTriggered ? `Triggered (${reading})` : `Ready (${reading})`
    },

    touchProbeLiveTooltip(): string {
      const id = this.configDraft.nxtTouchProbeID
      if (id === null) {
        return ''
      }
      const probe = this.selectedTouchProbeOm
      if (!probe) {
        return `Probe ${id} not found in object model`
      }
      return `Probe ${id}: reading ${probeReadingText(probe)}, threshold ${probe.threshold ?? '—'}`
    },

    selectedToolSetterOm() {
      return getProbeByIndex(
        this.$store.state.machine.model.sensors?.probes,
        this.configDraft.nxtToolSetterID
      )
    },

    toolSetterLiveTriggered(): boolean {
      return isProbeTriggered(this.selectedToolSetterOm)
    },

    toolSetterLiveColor(): string {
      if (!this.isConnected) {
        return 'grey'
      }
      if (this.configDraft.nxtToolSetterID === null) {
        return 'grey'
      }
      if (!this.selectedToolSetterOm) {
        return 'warning'
      }
      return this.toolSetterLiveTriggered ? 'success' : 'grey darken-1'
    },

    toolSetterLiveIcon(): string {
      if (!this.isConnected || !this.selectedToolSetterOm) {
        return 'mdi-lan-disconnect'
      }
      return this.toolSetterLiveTriggered ? 'mdi-check-circle' : 'mdi-circle-outline'
    },

    toolSetterLiveLabel(): string {
      if (!this.isConnected) {
        return 'Offline'
      }
      const id = this.configDraft.nxtToolSetterID
      if (id === null) {
        return ''
      }
      if (!this.selectedToolSetterOm) {
        return `Probe ${id}: —`
      }
      const reading = probeReadingText(this.selectedToolSetterOm)
      return this.toolSetterLiveTriggered ? `Triggered (${reading})` : `Ready (${reading})`
    },

    toolSetterLiveTooltip(): string {
      const id = this.configDraft.nxtToolSetterID
      if (id === null) {
        return ''
      }
      const probe = this.selectedToolSetterOm
      if (!probe) {
        return `Probe ${id} not found in object model`
      }
      return `Probe ${id}: reading ${probeReadingText(probe)}, threshold ${probe.threshold ?? '—'}`
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

    /**
     * True when the motor/VFD relay output is configured (draft or OM).
     */
    coolantRelayReserved(): boolean {
      const draftId = this.configDraft.nxtRelayID
      if (typeof draftId === 'number' && draftId >= 0) {
        return true
      }
      const relayId = readFirmwareGlobal(this.$store.state.machine.model.global, 'nxtRelayID')
      return typeof relayId === 'number' && relayId >= 0
    },

    isCustomPlatform(): boolean {
      return this.configDraft.nxtPlatformProfile === 'custom'
    },

    customAxisLetters(): Array<'X' | 'Y' | 'Z' | 'A'> {
      return ['X', 'Y', 'Z', 'A']
    },

    customHomeAtItems(): Array<{ value: number; title: string }> {
      return [
        { value: 1, title: 'Min (home negative)' },
        { value: 2, title: 'Max (home positive)' }
      ]
    },

    customDriveDirItems(): Array<{ value: number; title: string }> {
      return [
        { value: 1, title: 'Forward (S1)' },
        { value: 0, title: 'Reverse (S0)' }
      ]
    },

    customEndstopOccupancy() {
      const d = this.configDraft
      return {
        nxtCustomXEndstopPin: d.nxtCustomXEndstopPin,
        nxtCustomYEndstopPin: d.nxtCustomYEndstopPin,
        nxtCustomZEndstopPin: d.nxtCustomZEndstopPin,
        nxtCustomAEndstopPin: d.nxtCustomAEndstopPin
      }
    },

    customMappedDriveIndices(): number[] {
      const d = this.configDraft
      const all = [
        ...parseDriveList(d.nxtCustomXDrives),
        ...parseDriveList(d.nxtCustomYDrives),
        ...parseDriveList(d.nxtCustomZDrives),
        ...parseDriveList(d.nxtCustomADrives)
      ]
      return Array.from(new Set(all)).sort((a, b) => a - b)
    },

    coolantPulseTimingConfigurable(): boolean {
      const d = this.configDraft
      return d.nxtCoolantMistPulseEnabled || d.nxtCoolantFloodPulseEnabled
    },

    rgbHardwareConfigured(): boolean {
      const g = this.$store.state.machine.model.global
      return isRgbLightHardwareConfigured({
        leds: readOmLedsFromMachineModel(this.$store.state.machine.model),
        boardShortName: this.resolvedBoardShortNameForPack,
        rgbPin: readFirmwareGlobal(g, 'nxtRGBPin'),
        rgbReady: readFirmwareGlobal(g, 'nxtRGBReady')
      })
    },

    rgbLedSelectItems(): Array<{ value: number; text: string }> {
      const n = countOmLeds(readOmLedsFromMachineModel(this.$store.state.machine.model))
      return rgbLedIndexItems(n > 0 ? n : 1)
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
        '; nxt: call early in config.g. If using board pack auto-load, create 0:/sys/nxt-board-bootstrap.requested.\n' +
        '; Pack loads after nxt-user-vars.g (motor voltage must be set for Scylla). Avoid duplicating drives/limits if the pack loads them.\n' +
        'M98 P"nxt.g"\n\n' +
        (kitLine ? `; Or load one pack entry only:\n${kitLine}\n` : '')
      )
    },

    boardKitGpOutputs(): GpOutItem[] {
      return this.gpOutItemsForRole(null)
    },

    gpOutOccupancy() {
      const d = this.configDraft
      return {
        nxtRelayID: d.nxtRelayID,
        nxtAux1ID: d.nxtAux1ID,
        nxtAux2ID: d.nxtAux2ID,
        nxtAux3ID: d.nxtAux3ID,
        nxtCoolantAirID: d.nxtCoolantAirID,
        nxtCoolantMistID: d.nxtCoolantMistID,
        nxtCoolantFloodID: d.nxtCoolantFloodID
      }
    },

    probeOccupancy() {
      return {
        nxtTouchProbeID: this.configDraft.nxtTouchProbeID,
        nxtToolSetterID: this.configDraft.nxtToolSetterID
      }
    },

    /** All OM probe slots (unfiltered) for pinmap enrichment. */
    omProbesForPinSelect(): Array<{ id: number; type: number }> {
      const probes = this.$store.state.machine.model.sensors?.probes || []
      return probes.map((probe: any, index: number) => ({
        id: index,
        type: typeof probe?.type === 'number' ? probe.type : 0
      }))
    },

    touchProbeSelectItems(): ProbeSelectItem[] {
      return probeSelectItemsForBoard(
        this.resolvedBoardShortNameForPack,
        this.omProbesForPinSelect,
        this.probeOccupancy,
        { currentRoleKey: 'nxtTouchProbeID' }
      ).map((item) => ({
        ...item,
        props: { disabled: Boolean(item.disabled) }
      })) as ProbeSelectItem[]
    },

    toolSetterSelectItems(): ProbeSelectItem[] {
      return probeSelectItemsForBoard(
        this.resolvedBoardShortNameForPack,
        this.omProbesForPinSelect,
        this.probeOccupancy,
        { currentRoleKey: 'nxtToolSetterID' }
      ).map((item) => ({
        ...item,
        props: { disabled: Boolean(item.disabled) }
      })) as ProbeSelectItem[]
    },

    gpOutTestRows(): Array<{
      key: string
      label: string
      id: number | null
      mode: 'gpout' | 'fan'
      canTest: boolean
      fanAlias?: string
    }> {
      const d = this.configDraft
      const fans = this.effectiveBoardFanPins as string[]
      const fanSet = new Set(fans.map((p: string) => p.toLowerCase()))
      const rows: Array<{
        key: string
        label: string
        id: number | null
        mode: 'gpout' | 'fan'
        canTest: boolean
        fanAlias?: string
      }> = [
        { key: 'nxtRelayID', label: 'Relay', id: d.nxtRelayID, mode: 'gpout', canTest: false },
        { key: 'nxtAux1ID', label: 'Aux 0', id: d.nxtAux1ID, mode: 'gpout', canTest: false },
        { key: 'nxtAux2ID', label: 'Aux 1', id: d.nxtAux2ID, mode: 'gpout', canTest: false },
        { key: 'nxtAux3ID', label: 'Aux 2', id: d.nxtAux3ID, mode: 'gpout', canTest: false },
        { key: 'nxtCoolantAirID', label: 'Air', id: d.nxtCoolantAirID, mode: 'gpout', canTest: false },
        { key: 'nxtCoolantMistID', label: 'Mist', id: d.nxtCoolantMistID, mode: 'gpout', canTest: false },
        { key: 'nxtCoolantFloodID', label: 'Flood', id: d.nxtCoolantFloodID, mode: 'gpout', canTest: false }
      ]
      for (const row of rows) {
        row.canTest = row.id != null && row.id >= 0
      }
      // Fan-mode named pins: test via M106 even if no gpOut role id
      for (const alias of NXT_NAMED_OUTPUT_ALIASES) {
        if (!fanSet.has(alias)) {
          continue
        }
        const fanIdx = fanIndexForPinAlias(fans, alias)
        if (fanIdx == null) {
          continue
        }
        rows.push({
          key: `fan:${alias}`,
          label: `Fan ${alias}`,
          id: fanIdx,
          mode: 'fan',
          canTest: true,
          fanAlias: alias
        })
      }
      return rows
    },

    effectiveBoardFanPins(): string[] {
      const d = this.configDraft.nxtBoardFanPins
      if (d != null) {
        return d
      }
      return defaultBoardFanPinsForVoltage(this.configDraft.nxtBoardMotorVoltage)
    },

    boardFanPinItems(): Array<{ value: string; title: string }> {
      return namedOutputSelectItems(this.resolvedBoardShortNameForPack)
    },

    uartDeviceItems(): Array<{ value: number; title: string }> {
      return [
        { value: 0, title: this.$t('plugins.nxt.panels.configuration.uartOff').toString() },
        { value: 1, title: this.$t('plugins.nxt.panels.configuration.uartPanelDue').toString() },
        { value: 2, title: this.$t('plugins.nxt.panels.configuration.uartTft').toString() },
        { value: 3, title: this.$t('plugins.nxt.panels.configuration.uartPendant').toString() }
      ]
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

  beforeUnmount() {
    void this.stopGpOutTest()
  },

  methods: {
    syncConfigDraftFromOm() {
      this.configDraft = snapshotConfigFromOm(this.$store.state.machine.model.global)
      applySingletonDefaults(this.configDraft, {
        spindles: this.availableSpindles,
        probes: this.availableProbes
      })
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
      applySingletonDefaults(this.configDraft, {
        spindles: this.availableSpindles,
        probes: this.availableProbes
      })
    },

    spindleSelectItemRaw(item: unknown): { id?: number; name?: string } | null {
      if (item == null || typeof item !== 'object') {
        return null
      }
      const slotItem = item as { raw?: { id?: number; name?: string }; id?: number; name?: string; title?: string }
      if (slotItem.raw != null && typeof slotItem.raw === 'object') {
        return slotItem.raw
      }
      if (typeof slotItem.id === 'number') {
        return {
          id: slotItem.id,
          name: slotItem.name ?? slotItem.title
        }
      }
      return null
    },

    spindleSelectItemTitle(item: unknown): string {
      const raw = this.spindleSelectItemRaw(item)
      if (raw?.name) {
        return raw.name
      }
      if (item != null && typeof item === 'object') {
        const slotItem = item as { title?: string; name?: string }
        if (typeof slotItem.title === 'string' && slotItem.title.length > 0) {
          return slotItem.title
        }
        if (typeof slotItem.name === 'string' && slotItem.name.length > 0) {
          return slotItem.name
        }
      }
      return ''
    },

    spindleSelectItemSubtitle(item: unknown): string {
      const raw = this.spindleSelectItemRaw(item)
      if (typeof raw?.id === 'number') {
        return `ID: ${raw.id}`
      }
      return ''
    },
    async onConfigDraftSelect(key: keyof NxtUserConfigDraft, value: unknown) {
      const v = value === undefined || value === '' ? null : value
      if (
        (NXT_GPOUT_ROLE_KEYS as readonly string[]).includes(String(key)) &&
        v !== null &&
        typeof v === 'number'
      ) {
        const occupancy = this.gpOutOccupancy
        for (const other of NXT_GPOUT_ROLE_KEYS) {
          if (other === key) {
            continue
          }
          if (occupancy[other] === v) {
            const role = gpOutRoleLabelForId(v, occupancy) ?? other
            this.showStatus(
              (this as any).$t('plugins.nxt.panels.configuration.outputRoleConflict', {
                id: v,
                role
              }),
              'error'
            )
            return
          }
        }
      }
      if (
        (NXT_PROBE_ROLE_KEYS as readonly string[]).includes(String(key)) &&
        v !== null &&
        typeof v === 'number'
      ) {
        const occupancy = this.probeOccupancy
        for (const other of NXT_PROBE_ROLE_KEYS) {
          if (other === key) {
            continue
          }
          if (occupancy[other] === v) {
            const role = probeRoleLabelForId(v, occupancy) ?? other
            this.showStatus(
              (this as any).$t('plugins.nxt.panels.configuration.outputRoleConflict', {
                id: v,
                role
              }),
              'error'
            )
            return
          }
        }
      }
      ;(this.configDraft as Record<string, unknown>)[key] = v
      await this.updateVariable(String(key), v)
      if (key === 'nxtTouchProbeID' && typeof v === 'number') {
        await this.applyProbePinPolarity(v, this.configDraft.nxtTouchProbeInvert, 'touch')
      }
      if (key === 'nxtToolSetterID' && typeof v === 'number') {
        await this.applyProbePinPolarity(v, this.configDraft.nxtToolSetterInvert, 'toolsetter')
      }
    },

    gpOutItemsForRole(roleKey: (typeof NXT_GPOUT_ROLE_KEYS)[number] | null): Array<
      GpOutItem & { props?: { disabled?: boolean } }
    > {
      const lim = this.$store.state.machine.model.limits as { gpOutPorts?: number } | undefined
      const n = lim?.gpOutPorts
      const maxPorts = typeof n === 'number' && n > 0 ? n : 8
      const fanIds = new Set<number>()
      const fans = this.effectiveBoardFanPins as string[]
      // Preferred indices match pinmap / gpio.g: mist0 coolant1 aux0→2 … relay5
      const preferred: Record<string, number> = {
        mist: 0,
        coolant: 1,
        aux0: 2,
        aux1: 3,
        aux2: 4,
        relay: 5
      }
      for (const a of fans) {
        const id = preferred[String(a).toLowerCase()]
        if (typeof id === 'number') {
          fanIds.add(id)
        }
      }
      return gpOutItemsForBoard(
        this.resolvedBoardShortNameForPack,
        maxPorts,
        this.gpOutOccupancy,
        { currentRoleKey: roleKey, motorVoltage: this.resolvedMotorVoltageForPack }
      ).map((item) => {
        const fanBlocked = fanIds.has(item.id)
        return {
          ...item,
          disabled: Boolean(item.disabled) || fanBlocked,
          props: { disabled: Boolean(item.disabled) || fanBlocked }
        }
      })
    },

    probeSelectItemRaw(
      item: unknown
    ): { id?: number; type?: number; disabled?: boolean; pinLabel?: string; name?: string; props?: { disabled?: boolean } } | null {
      if (item == null || typeof item !== 'object') {
        return null
      }
      const slotItem = item as {
        raw?: { id?: number; type?: number; disabled?: boolean; pinLabel?: string; name?: string; props?: { disabled?: boolean } }
        props?: { disabled?: boolean }
        title?: string
        id?: number
        name?: string
        type?: number
        disabled?: boolean
        pinLabel?: string
      }
      if (slotItem.raw != null && typeof slotItem.raw === 'object') {
        return slotItem.raw
      }
      // Vuetify may pass the ProbeSelectItem itself as `item`.
      if (typeof slotItem.id === 'number' && (typeof slotItem.name === 'string' || typeof slotItem.title === 'string')) {
        return {
          id: slotItem.id,
          name: slotItem.name ?? slotItem.title,
          type: slotItem.type,
          disabled: slotItem.disabled,
          pinLabel: slotItem.pinLabel,
          props: slotItem.props
        }
      }
      return null
    },

    probeSelectItemDisabled(item: unknown): boolean {
      const raw = this.probeSelectItemRaw(item)
      if (raw?.disabled) {
        return true
      }
      if (item != null && typeof item === 'object') {
        const slotItem = item as { props?: { disabled?: boolean } }
        return Boolean(slotItem.props?.disabled)
      }
      return false
    },

    probeSelectItemTitle(item: unknown): string {
      const raw = this.probeSelectItemRaw(item)
      if (raw?.name) {
        return raw.name
      }
      if (item != null && typeof item === 'object') {
        const slotItem = item as { title?: string; name?: string }
        if (typeof slotItem.title === 'string' && slotItem.title.length > 0) {
          return slotItem.title
        }
        if (typeof slotItem.name === 'string' && slotItem.name.length > 0) {
          return slotItem.name
        }
      }
      return ''
    },

    probeItemSubtitle(raw: { id?: number; type?: number; disabled?: boolean; pinLabel?: string } | null | undefined): string {
      if (raw == null) {
        return ''
      }
      const parts: string[] = []
      if (typeof raw.id === 'number') {
        parts.push(`Sensor ${raw.id}`)
      }
      if (typeof raw.type === 'number' && raw.type > 0) {
        parts.push(`type ${raw.type}`)
      }
      if (raw.disabled) {
        parts.push('already assigned')
      }
      return parts.join(' · ')
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

    async onProbeDeflectionComponent(index: 0 | 1, raw: string | number | null) {
      let v: number | null =
        raw === '' || raw === null || raw === undefined ? null : typeof raw === 'number' ? raw : Number(raw)
      if (v !== null && !Number.isFinite(v)) {
        return
      }
      const prev = this.configDraft.nxtProbeDeflection
      const next: number[] = [
        prev != null && prev.length >= 1 && Number.isFinite(prev[0]) ? prev[0] : 0,
        prev != null && prev.length >= 2 && Number.isFinite(prev[1]) ? prev[1] : 0
      ]
      if (v === null) {
        // Clearing one axis clears the whole vector (required pair)
        this.configDraft.nxtProbeDeflection = null
        await this.updateVariable('nxtProbeDeflection', null)
        return
      }
      next[index] = v
      this.configDraft.nxtProbeDeflection = next
      await this.updateVariable('nxtProbeDeflection', next)
    },

    customEndstopPinKey(axis: 'X' | 'Y' | 'Z' | 'A'): keyof NxtUserConfigDraft {
      return (`nxtCustom${axis}EndstopPin` as keyof NxtUserConfigDraft)
    },

    customEndstopRoleKey(axis: 'X' | 'Y' | 'Z' | 'A'): NxtCustomEndstopRoleKey {
      return `nxtCustom${axis}EndstopPin` as NxtCustomEndstopRoleKey
    },

    customEndstopPinList(axis: 'X' | 'Y' | 'Z' | 'A'): string[] {
      return parseEndstopPinList(this.configDraft[this.customEndstopPinKey(axis)] as string | null)
    },

    async onCustomEndstopPinList(axis: 'X' | 'Y' | 'Z' | 'A', raw: string[] | null) {
      const joined = formatEndstopPinList(Array.isArray(raw) ? raw : [])
      await this.onConfigDraftString(this.customEndstopPinKey(axis), joined)
    },

    customEndstopPinItemsForAxis(
      axis: 'X' | 'Y' | 'Z' | 'A'
    ): Array<EndstopPinSelectItem & { props?: { disabled?: boolean } }> {
      const roleKey = this.customEndstopRoleKey(axis)
      if (!(NXT_CUSTOM_ENDSTOP_ROLE_KEYS as readonly string[]).includes(roleKey)) {
        return []
      }
      return endstopPinItemsForBoard(
        this.resolvedBoardShortNameForPack,
        this.customEndstopOccupancy,
        { currentRoleKey: roleKey }
      ).map((item: EndstopPinSelectItem) => ({
        ...item,
        props: { disabled: Boolean(item.disabled) }
      }))
    },

    endstopSelectItemRaw(
      item: unknown
    ): { value?: string; title?: string; disabled?: boolean; pinLabel?: string; props?: { disabled?: boolean } } | null {
      if (item == null || typeof item !== 'object') {
        return null
      }
      const slotItem = item as {
        raw?: { value?: string; title?: string; disabled?: boolean; pinLabel?: string; props?: { disabled?: boolean } }
        props?: { disabled?: boolean }
        title?: string
        value?: string
        disabled?: boolean
        pinLabel?: string
      }
      if (slotItem.raw != null && typeof slotItem.raw === 'object') {
        return slotItem.raw
      }
      if (typeof slotItem.value === 'string' && (typeof slotItem.title === 'string' || typeof slotItem.pinLabel === 'string')) {
        return {
          value: slotItem.value,
          title: slotItem.title,
          disabled: slotItem.disabled,
          pinLabel: slotItem.pinLabel,
          props: slotItem.props
        }
      }
      return null
    },

    endstopSelectItemDisabled(item: unknown): boolean {
      const raw = this.endstopSelectItemRaw(item)
      if (raw?.disabled) {
        return true
      }
      if (item != null && typeof item === 'object') {
        const slotItem = item as { props?: { disabled?: boolean } }
        return Boolean(slotItem.props?.disabled)
      }
      return false
    },

    endstopSelectItemTitle(item: unknown): string {
      const raw = this.endstopSelectItemRaw(item)
      if (raw?.title) {
        return raw.title
      }
      if (raw?.pinLabel && raw?.value) {
        return `${raw.pinLabel} (${raw.value})`
      }
      if (item != null && typeof item === 'object') {
        const slotItem = item as { title?: string }
        if (typeof slotItem.title === 'string' && slotItem.title.length > 0) {
          return slotItem.title
        }
      }
      return ''
    },

    customHomeAtKey(axis: 'X' | 'Y' | 'Z' | 'A'): keyof NxtUserConfigDraft {
      return (`nxtCustom${axis}HomeAt` as keyof NxtUserConfigDraft)
    },

    customDriveDirValue(drive: number): number {
      const found = parseDriveDirs(this.configDraft.nxtCustomDriveDirs).find((e) => e.drive === drive)
      return found?.dir ?? 1
    },

    async onCustomDriveDirChange(drive: number, raw: unknown) {
      const dir = raw === 0 || raw === '0' ? 0 : 1
      const map = new Map(parseDriveDirs(this.configDraft.nxtCustomDriveDirs).map((e) => [e.drive, e.dir]))
      map.set(drive, dir as 0 | 1)
      for (const d of this.customMappedDriveIndices) {
        if (!map.has(d)) map.set(d, 1)
      }
      const entries = Array.from(map.entries()).map(([d, s]) => ({ drive: d, dir: s as 0 | 1 }))
      const compact = formatDriveDirs(entries)
      this.configDraft.nxtCustomDriveDirs = compact
      await this.updateVariable('nxtCustomDriveDirs', compact)
    },

    async onConfigDraftString(key: keyof NxtUserConfigDraft, raw: unknown) {
      const s =
        raw === null || raw === undefined || raw === ''
          ? null
          : String(raw).trim() || null
      ;(this.configDraft as Record<string, unknown>)[key] = s
      await this.updateVariable(String(key), s)
      if (
        key === 'nxtCustomXDrives' ||
        key === 'nxtCustomYDrives' ||
        key === 'nxtCustomZDrives' ||
        key === 'nxtCustomADrives'
      ) {
        await this.syncCustomDriveDirsWithMap()
      }
    },

    async syncCustomDriveDirsWithMap() {
      const mapped = this.customMappedDriveIndices
      if (!mapped.length) {
        this.configDraft.nxtCustomDriveDirs = null
        await this.updateVariable('nxtCustomDriveDirs', null)
        return
      }
      const existing = new Map(
        parseDriveDirs(this.configDraft.nxtCustomDriveDirs).map((e) => [e.drive, e.dir] as const)
      )
      const entries = mapped.map((d: number) => ({ drive: d, dir: (existing.get(d) ?? 1) as 0 | 1 }))
      const compact = formatDriveDirs(entries)
      this.configDraft.nxtCustomDriveDirs = compact
      await this.updateVariable('nxtCustomDriveDirs', compact)
    },

    async onConfigDraftPulseSec(key: 'nxtCoolantPulseOnSec' | 'nxtCoolantPulseOffSec', raw: string | number | null) {
      let v =
        raw === '' || raw === null || raw === undefined ? null : typeof raw === 'number' ? raw : Number(raw)
      if (v === null || !Number.isFinite(v)) {
        return
      }
      v = Math.max(1, Math.round(v))
      ;(this.configDraft as Record<string, unknown>)[key] = v
      await this.updateVariable(key, v)
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
        console.error('nxt: loadConfiguration', e)
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
        console.error('nxt: runBoardStateChecks', e)
      } finally {
        this.boardStateChecking = false
      }
    },

    async onPlatformProfileChange(value: NxtPlatformId | null) {
      const previous = this.configDraft.nxtPlatformProfile
      const migrated = migratePlatformProfileId(value)
      this.configDraft.nxtPlatformProfile = migrated
      await this.updateVariable('nxtPlatformProfile', migrated)
      value = migrated

      if (value != null && value !== '' && value !== previous) {
        const plat = nxtPlatformFromManifest(value)
        if (plat?.hasCommonDeploy && plat.sysDeployFiles.length > 0) {
          const msg = (this as any).$t('plugins.nxt.panels.configuration.boardDeployOnPlatformChange', {
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
      const msg = (this as any).$t('plugins.nxt.panels.configuration.boardDeployConfirm', {
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
        let written: string[]
        if (platformId === 'custom') {
          const errs = validateCustomMachineDraft(this.configDraft)
          if (errs.length) {
            this.showStatus(errs.join('; '), 'error')
            return
          }
          const result = await persistNxtUserConfig(this.configDraft, {
            uploadUserVars: false,
            syncBootstrap: false,
            syncCustomRequested: true,
            ensureCustomGlobals: true,
            deployCustomPack: true,
            sendCode: (c) => this.sendCode(c),
            isConnected: this.isConnected
          })
          written = result.customDeployed
          this.configDraft.nxtBoardSysDeployPlatform = 'custom'
        } else {
          written = await deployPlatformSysFiles(platformId)
          this.configDraft.nxtBoardSysDeployPlatform = platformId
          await this.updateVariable('nxtBoardSysDeployPlatform', platformId)
        }
        const msg = (this as any).$t('plugins.nxt.panels.configuration.boardDeploySuccess', {
          count: written.length
        })
        this.showStatus(typeof msg === 'string' ? msg : `Deployed ${written.length} file(s) to 0:/sys/`, 'success')
      } catch (e: any) {
        console.error('nxt: deployPlatformSysFiles', e)
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
        const msg = (this as any).$t('plugins.nxt.panels.configuration.boardSnippetCopied')
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
          '; nxt-user-pinmap.g - stub generated from nxt Configuration UI',
          '; Add M950 or other pin overrides below; load after nxt.g if needed.',
          '; ' + new Date().toISOString(),
          ''
        ]
        await uploadDwcFile(NXT_USER_PINMAP_DWC_PATH, lines.join('\n'))
        const msg = (this as any).$t('plugins.nxt.panels.configuration.boardPinmapSaved')
        this.showStatus(typeof msg === 'string' ? msg : 'Saved', 'success')
      } catch (e: any) {
        console.error('nxt: savePinmapStub', e)
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
        const msg = (this as any).$t('plugins.nxt.panels.configuration.globalsSnapshotCopied')
        this.showStatus(typeof msg === 'string' ? msg : 'Copied to clipboard', 'success')
      }
      const fail = () => {
        this.showStatus(
          (this as any).$t('plugins.nxt.panels.configuration.globalsSnapshotCopyFailed'),
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
          if (key === 'nxtFeatureRgbLight' && !this.rgbHardwareConfigured) {
            this.showStatus('Cannot enable RGB light: no LED strip configured', 'error')
            return
          }
        }

        await ensureSetFirmwareGlobal(String(key), formatOmRhs(value), (c) =>
          this.sendCode(c)
        )
        ;(this.configDraft as Record<string, unknown>)[key] = value
        this.showStatus(`${key} ${value ? 'enabled' : 'disabled'}`, 'success')
      } catch (error) {
        console.error('nxt: Failed to update feature', key, error)
        this.showStatus(`Failed to update ${key}`, 'error')
      }
    },

    /**
     * Update a variable value
     */
    async updateVariable(key: string, value: any) {
      try {
        if (String(key).startsWith('nxtCustom')) {
          const wantA =
            String(key).startsWith('nxtCustomA') ||
            customAAxisPartiallyConfigured(this.configDraft)
          await syncCustomARequestedSentinel(wantA)
          await ensureCustomGlobals((c) => this.sendCode(c))
        }
        // Deprecated kit key may be absent from OM — clear only if present.
        if (
          key === 'nxtBoardKitKey' &&
          (value === null || value === undefined || value === '')
        ) {
          await clearFirmwareGlobalIfExists('nxtBoardKitKey', (c) => this.sendCode(c))
          console.log(`nxt: Updated ${key} to ${value}`)
          return
        }
        await ensureSetFirmwareGlobal(String(key), formatOmRhs(value), (c) =>
          this.sendCode(c)
        )
        console.log(`nxt: Updated ${key} to ${value}`)
      } catch (error) {
        console.error('nxt: Failed to update variable', key, error)
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
        if (!this.rgbHardwareConfigured) {
          this.configDraft.nxtFeatureRgbLight = false
        }
        if (this.isCustomPlatform) {
          const errs = validateCustomMachineDraft(this.configDraft)
          if (errs.length) {
            this.showStatus(errs.join('; '), 'error')
            return
          }
        }
        const result = await persistNxtUserConfig(this.configDraft, {
          sendCode: (c) => this.sendCode(c),
          isConnected: this.isConnected,
          deployCustomPack: this.isCustomPlatform && this.isConnected
        })
        if (this.isConnected) {
          await this.runBoardStateChecks()
        }
        const extra =
          result.customDeployed.length > 0
            ? ` Custom pack + homing updated (${result.customDeployed.length} files).`
            : ''
        this.showStatus(
          `Configuration saved to ${result.userVarsPath} and bootstrap files synced (${result.bootMode}).${extra} Reload or reboot to apply.`,
          'success'
        )
      } catch (error: any) {
        console.error('nxt: Failed to save configuration', error)
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
        console.error('nxt: Spindle test start failed', error)
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
        console.error('nxt: Spindle stop failed', error)
        this.showStatus('Failed to stop spindle', 'error')
      }
    },

    async onProbeInvertChange(
      key: 'nxtTouchProbeInvert' | 'nxtToolSetterInvert',
      raw: unknown
    ) {
      const invert = raw === true || raw === 1
      ;(this.configDraft as Record<string, unknown>)[key] = invert
      await this.updateVariable(key, invert)
      const probeId =
        key === 'nxtTouchProbeInvert'
          ? this.configDraft.nxtTouchProbeID
          : this.configDraft.nxtToolSetterID
      await this.applyProbePinPolarity(
        probeId,
        invert,
        key === 'nxtTouchProbeInvert' ? 'touch' : 'toolsetter'
      )
    },

    async applyProbePinPolarity(
      probeId: number | null,
      invert: boolean,
      roleHint?: 'touch' | 'toolsetter' | null
    ) {
      if (probeId === null || !this.isConnected) {
        return
      }
      const pin = probePinLiteralForIndex(this.resolvedBoardShortNameForPack, probeId)
      if (pin == null) {
        this.showStatus(
          `Probe ${probeId}: invert saved, but no pinmap pin to apply M558`,
          'warning'
        )
        return
      }
      const om = getProbeByIndex(this.$store.state.machine.model.sensors?.probes, probeId)
      const omType = typeof om?.type === 'number' ? om.type : null
      const type = resolveProbeM558Type(omType, probeId, roleHint ?? null)
      // RRF requires P (type) on M558 — C alone fails with "Missing Z probe type number".
      const cmd = buildProbeM558PinCommand({ probeId, pinLiteral: pin, invert, type })
      try {
        await this.sendCode(cmd)
        this.showStatus(`Probe ${probeId}: ${cmd}`, 'success')
      } catch (e) {
        console.error('nxt: M558 pin polarity failed', e)
        this.showStatus(`Failed to apply ${cmd}`, 'error')
      }
    },

    async startGpOutTest(
      row: {
        key: string
        label: string
        id: number | null
        mode: 'gpout' | 'fan'
        canTest: boolean
      },
      ev?: PointerEvent
    ) {
      if (!row.canTest || row.id == null || this.uiFrozen || !this.isConnected) {
        return
      }
      if (this.gpOutTestingKey != null) {
        await this.stopGpOutTest()
      }
      const seq = ++this.gpOutTestSeq
      const id = row.id
      const mode = row.mode
      this.gpOutTestingKey = row.key
      this.gpOutTestingId = id
      this.gpOutTestingMode = mode
      try {
        const target = ev?.currentTarget
        if (target && typeof (target as HTMLElement).setPointerCapture === 'function' && ev?.pointerId != null) {
          ;(target as HTMLElement).setPointerCapture(ev.pointerId)
        }
      } catch {
        /* ignore capture failures */
      }
      try {
        const cmd = mode === 'fan' ? `M106 P${id} S1` : `M42 P${id} S1`
        await this.sendCode(cmd)
        if (seq !== this.gpOutTestSeq || this.gpOutTestingKey !== row.key) {
          // Release already requested — force OFF with captured id
          const off = mode === 'fan' ? `M106 P${id} S0` : `M42 P${id} S0`
          await this.sendCode(off)
          return
        }
        this.showStatus(
          mode === 'fan'
            ? `Fan ${id} ON (release to turn off)`
            : `Output ${id} ON (release to turn off)`,
          'info'
        )
      } catch (e) {
        console.error('nxt: gpOut test start failed', e)
        this.gpOutTestingKey = null
        this.gpOutTestingId = null
        this.gpOutTestingMode = null
        this.showStatus(`Failed to energize ${mode === 'fan' ? 'fan' : 'output'} ${id}`, 'error')
      }
    },

    async stopGpOutTest() {
      const key = this.gpOutTestingKey
      const id = this.gpOutTestingId
      const mode = this.gpOutTestingMode
      if (key == null || id == null || mode == null) {
        this.gpOutTestingKey = null
        this.gpOutTestingId = null
        this.gpOutTestingMode = null
        return
      }
      // Bump seq so a late ON completion turns OFF immediately
      this.gpOutTestSeq += 1
      this.gpOutTestingKey = null
      this.gpOutTestingId = null
      this.gpOutTestingMode = null
      try {
        const cmd = mode === 'fan' ? `M106 P${id} S0` : `M42 P${id} S0`
        await this.sendCode(cmd)
        this.showStatus(mode === 'fan' ? `Fan ${id} OFF` : `Output ${id} OFF`, 'success')
      } catch (e) {
        console.error('nxt: gpOut test stop failed', e)
        this.showStatus(`Failed to de-energize ${mode === 'fan' ? 'fan' : 'output'} ${id}`, 'error')
      }
    },

    async onBoardFanPinsChange(value: unknown) {
      const pins = Array.isArray(value)
        ? value.map((v) => String(v)).filter((s) => s.length > 0)
        : []
      this.configDraft.nxtBoardFanPins = pins
      try {
        const rhs = formatPersistedStringVector(pins)
        await ensureSetFirmwareGlobal('nxtBoardFanPins', rhs, (c) => this.sendCode(c))
        this.showStatus(
          this.$t('plugins.nxt.panels.configuration.boardFanPinsSaved').toString(),
          'warning'
        )
      } catch (e) {
        console.error('nxt: fan pins update failed', e)
        this.showStatus('Failed to update fan pin list', 'error')
      }
    },

    async onUartDeviceChange(value: unknown) {
      const n = value === '' || value == null ? 0 : Number(value)
      this.configDraft.nxtUartDevice = Number.isFinite(n) ? n : 0
      try {
        await ensureSetFirmwareGlobal(
          'nxtUartDevice',
          String(this.configDraft.nxtUartDevice),
          (c) => this.sendCode(c)
        )
        this.showStatus(
          this.$t('plugins.nxt.panels.configuration.uartSaved').toString(),
          'warning'
        )
      } catch (e) {
        console.error('nxt: uart device update failed', e)
        this.showStatus('Failed to update UART device', 'error')
      }
    },

    async onUartBaudChange(value: unknown) {
      const n = Number(value)
      this.configDraft.nxtUartBaud = Number.isFinite(n) && n >= 9600 ? Math.floor(n) : 57600
      try {
        await ensureSetFirmwareGlobal(
          'nxtUartBaud',
          String(this.configDraft.nxtUartBaud),
          (c) => this.sendCode(c)
        )
      } catch (e) {
        console.error('nxt: uart baud update failed', e)
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
        console.error('nxt: Acceleration measurement start failed', error)
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
        console.error('nxt: Acceleration measurement failed', error)
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
        console.error('nxt: Deceleration measurement start failed', error)
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
        console.error('nxt: Deceleration measurement failed', error)
        this.showStatus('Deceleration measurement failed', 'error')
      }
    },

    onTouchProbeTestClick() {
      const id = this.configDraft.nxtTouchProbeID
      if (id === null) {
        return
      }
      const probe = this.selectedTouchProbeOm
      if (!probe) {
        this.showStatus(`Touch probe ${id}: not found in object model`, 'warning')
        return
      }
      const reading = probeReadingText(probe)
      const th = probe.threshold ?? '—'
      const state = this.touchProbeLiveTriggered ? 'TRIGGERED' : 'ready'
      this.showStatus(`Touch probe ${id}: ${state} (reading ${reading}, threshold ${th})`, this.touchProbeLiveTriggered ? 'success' : 'info')
    },

    onToolSetterTestClick() {
      const id = this.configDraft.nxtToolSetterID
      if (id === null) {
        return
      }
      const probe = this.selectedToolSetterOm
      if (!probe) {
        this.showStatus(`Tool setter ${id}: not found in object model`, 'warning')
        return
      }
      const reading = probeReadingText(probe)
      const th = probe.threshold ?? '—'
      const state = this.toolSetterLiveTriggered ? 'TRIGGERED' : 'ready'
      this.showStatus(`Tool setter ${id}: ${state} (reading ${reading}, threshold ${th})`, this.toolSetterLiveTriggered ? 'success' : 'info')
    },

    /**
     * Switch to the Calibration tab on the main nxt dashboard.
     */
    navigateToCalibration() {
      try {
        if (this.$router && this.$route?.path && !String(this.$route.path).startsWith('/nxt')) {
          void this.$router.push({ path: '/nxt', query: { tab: 'calibration' } })
        }
      } catch {
        /* ignore router errors */
      }
      window.dispatchEvent(new CustomEvent('nxt-goto-calibration'))
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
        console.error('nxt: Failed to set tool setter position', error)
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
        console.error('nxt: Failed to update tool setter position', error)
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
.v-expansion-panel-text :deep(.v-expansion-panel-text__wrap) {
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
