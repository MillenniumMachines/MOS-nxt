<template>
  <v-container fluid class="pa-2">
    <!-- nxt Main Dashboard Layout -->
    <!-- Status strip removed: CNC dashboard override supplies its own status UI -->

    <v-row>
      <!-- Action Confirmation Widget - Full width above main content -->
      <v-col v-if="hasActiveDialog" cols="12">
        <nxt-action-confirmation-widget />
      </v-col>

      <!-- Main Content Area -->
      <v-col cols="12">
        <v-card>
          <v-card-title>
            <v-icon class="mr-2">mdi-wrench</v-icon>
            {{ pageTitle }}
            <v-spacer />
            <div v-if="!isConnected" class="d-flex align-center">
              <v-icon size="small" class="mr-2" color="warning">mdi-lan-disconnect</v-icon>
              <span class="text-caption">{{ $t('plugins.nxt.messages.disconnectedShort') }}</span>
            </div>
          </v-card-title>
          
          <v-card-text>
            <!-- Restart Required Alert -->
            <v-alert 
              v-if="restartRequired" 
              type="error" 
              variant="outlined"
              class="mb-4"
            >
              <div class="d-flex align-center justify-space-between">
                <div>
                  <div class="font-weight-bold">
                    <v-icon class="mr-2">mdi-restart</v-icon>
                    {{ $t('plugins.nxt.messages.restartRequired') }}
                  </div>
                  <div class="text-caption mt-1">
                    {{ $t('plugins.nxt.messages.restartMessage') }}
                  </div>
                </div>
                <v-btn 
                  color="error" 
                  @click="restartMachine"
                  :loading="restarting"
                >
                  {{ $t('plugins.nxt.messages.restartButton') }}
                </v-btn>
              </div>
              <v-alert 
                type="warning" 
                density="compact" 
                variant="outlined" 
                class="mt-3 mb-0"
              >
                <v-icon class="mr-2" size="small">mdi-alert</v-icon>
                {{ $t('plugins.nxt.messages.restartWarning') }}
              </v-alert>
            </v-alert>

            <!-- Informational header - plugin readiness is shown on individual pages -->
            <v-alert type="info" variant="outlined" class="mb-4">
              <v-icon class="mr-2">mdi-information-outline</v-icon>
              {{ $t('plugins.nxt.messages.chooseSubsection') }}
              <span class="text-caption d-block mt-2">
                {{ $t('plugins.nxt.messages.toolLibraryInMenu') }}
              </span>
            </v-alert>

            <!-- Tab Navigation for different sections -->
            <v-tabs v-model="activeTab" grow>
              <v-tab>{{ $t('plugins.nxt.panels.status.caption') }}</v-tab>
              <v-tab>{{ $t('plugins.nxt.panels.configuration.caption') }}</v-tab>
              <v-tab>{{ $t('plugins.nxt.panels.calibration.caption') }}</v-tab>
              <v-tab>{{ $t('plugins.nxt.panels.probing.caption') }}</v-tab>
              <v-tab>{{ $t('plugins.nxt.panels.maintenance.caption') }}</v-tab>
            </v-tabs>

            <v-window v-model="activeTab">
              <!-- Status Tab -->
              <v-window-item>
                <div class="pa-4">
                  <nxt-machine-status-panel />
                </div>
              </v-window-item>

              <!-- Configuration Tab -->
              <v-window-item>
                <div class="pa-4">
                  <nxt-configuration-panel />
                </div>
              </v-window-item>

              <!-- Calibration Tab -->
              <v-window-item>
                <div class="pa-4">
                  <nxt-calibration-panel />
                </div>
              </v-window-item>

              <!-- Probing Tab -->
              <v-window-item>
                <div class="pa-4">
                  <v-row>
                    <v-col cols="12">
                      <nxt-probing-cycles-panel />
                    </v-col>
                    <v-col cols="12">
                      <nxt-probe-results-panel />
                    </v-col>
                  </v-row>
                </div>
              </v-window-item>

              <!-- Maintenance Tab -->
              <v-window-item>
                <div class="pa-4">
                  <nxt-maintenance-panel />
                </div>
              </v-window-item>
            </v-window>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script lang="ts">
import { defineNxtComponent } from './components/base/BaseComponent.vue'
import { readFirmwareGlobal } from './utils/nxtToolChangerOm'
import ActionConfirmationWidget from './components/panels/ActionConfirmationWidget.vue'
import MachineStatusPanel from './components/panels/MachineStatusPanel.vue'
import ConfigurationPanel from './components/panels/ConfigurationPanel.vue'
import ProbingCyclesPanel from './components/panels/ProbingCyclesPanel.vue'
import ProbeResultsPanel from './components/panels/ProbeResultsPanel.vue'
import MaintenancePanel from './components/panels/MaintenancePanel.vue'
import CalibrationPanel from './components/panels/CalibrationPanel.vue'

/**
 * nxt Main Dashboard Component
 * 
 * Provides the primary interface for nxt functionality within DWC.
 * Includes the persistent status widget and action confirmation widget
 * as specified in the Phase 2.1 requirements.
 */
export default defineNxtComponent({
  name: 'nxt',
  components: {
    NxtActionConfirmationWidget: ActionConfirmationWidget,
    NxtMachineStatusPanel: MachineStatusPanel,
    NxtConfigurationPanel: ConfigurationPanel,
    NxtCalibrationPanel: CalibrationPanel,
    NxtProbingCyclesPanel: ProbingCyclesPanel,
    NxtProbeResultsPanel: ProbeResultsPanel,
    NxtMaintenancePanel: MaintenancePanel
  },
  data() {
    return {
      activeTab: 0,
      restarting: false,
    }
  },

  computed: {
    /**
     * Check if we're connected to a machine
     */
    isConnected(): boolean {
      return this.$store.getters["isConnected"]
    },

    /**
     * Check if machine restart is required (nxtLoaded variable doesn't exist)
     * Only check this if we're actually connected to a machine
     */
    restartRequired(): boolean {
      if (!this.isConnected) {
        return false
      }
      const g = this.$store.state.machine.model.global
      return readFirmwareGlobal(g, 'nxtLoaded') === undefined
    },

    /**
     * Check if there's an active dialog requiring user action
     */
    hasActiveDialog(): boolean {
      const messageBox = this.$store.state.machine.model.state.messageBox
      return messageBox && messageBox.message ? true : false
    },

    statusCaption(): string {
      const key = 'plugins.nxt.panels.status.caption'
      const t = (this as any).$t(key).toString()
      return t === key ? 'Status' : t
    },

    configurationCaption(): string {
      const key = 'plugins.nxt.panels.configuration.caption'
      const t = (this as any).$t(key).toString()
      return t === key ? 'Configuration' : t
    },

    stockPreparationCaption(): string {
      const key = 'plugins.nxt.panels.stockPreparation.caption'
      const t = (this as any).$t(key).toString()
      return t === key ? 'Stock Preparation' : t
    },

    probingCaption(): string {
      const key = 'plugins.nxt.panels.probing.caption'
      const t = (this as any).$t(key).toString()
      return t === key ? 'Probing' : t
    },

    maintenanceCaption(): string {
      const key = 'plugins.nxt.panels.maintenance.caption'
      const t = (this as any).$t(key).toString()
      return t === key ? 'Maintenance' : t
    },

    calibrationCaption(): string {
      const key = 'plugins.nxt.panels.calibration.caption'
      const t = (this as any).$t(key).toString()
      return t === key ? 'Calibration' : t
    },

    pageTitle(): string {
      const path = this.$route?.path || ''
      if (path.startsWith('/nxt/Configuration')) return this.configurationCaption
      if (path.startsWith('/nxt/StockPreparation')) return this.stockPreparationCaption
      if (path.startsWith('/nxt/Probing')) return this.probingCaption
      if (path === '/nxt' || path === '/nxt/') {
        if (this.activeTab === 1) return this.configurationCaption
        if (this.activeTab === 2) return this.calibrationCaption
        if (this.activeTab === 3) return this.probingCaption
        if (this.activeTab === 4) return this.maintenanceCaption
      }
      return this.statusCaption
    }
  },

  methods: {
    onGotoCalibration() {
      // Status=0, Configuration=1, Calibration=2
      this.activeTab = 2
    },
    applyTabFromQuery() {
      try {
        const q = new URLSearchParams(window.location.search)
        if (q.get('tab') === 'calibration' || window.location.hash === '#calibration') {
          this.activeTab = 2
        }
      } catch {
        /* ignore */
      }
    },
    /**
     * Restart the machine using M999
     */
    async restartMachine() {
      this.restarting = true
      try {
        await this.sendCode('M999')
        // M999 will restart the machine, so UI will disconnect
      } catch (error) {
        console.error('nxt: Failed to restart machine:', error)
        // Reset loading state if restart fails
        this.restarting = false
      }
    }
  },

  mounted() {
    window.addEventListener('nxt-goto-calibration', this.onGotoCalibration as EventListener)
    this.applyTabFromQuery()
    console.log('nxt: Main dashboard component mounted')
    console.log('nxt: Connected to machine:', this.isConnected)
    if (this.isConnected && this.restartRequired) {
      console.log('nxt: Machine restart required - nxtLoaded variable not found')
    } else if (!this.isConnected) {
      console.log('nxt: Not connected to machine - some features will be unavailable')
    }
  },

  beforeUnmount() {
    window.removeEventListener('nxt-goto-calibration', this.onGotoCalibration as EventListener)
  }
})
</script>

<style scoped>
/* Component-specific styles */
.v-card {
  height: 100%;
}

.v-alert {
  border-left: 4px solid currentColor !important;
}
</style>