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
            <v-icon left>mdi-wrench</v-icon>
            {{ pageTitle }}
            <v-spacer />
            <div v-if="!isConnected" class="d-flex align-center">
              <v-icon small class="mr-2" color="warning">mdi-lan-disconnect</v-icon>
              <span class="text-caption">{{ $t('plugins.nxt.messages.disconnectedShort') }}</span>
            </div>
          </v-card-title>
          
          <v-card-text>
            <!-- Restart Required Alert -->
            <v-alert 
              v-if="restartRequired" 
              type="error" 
              outlined
              class="mb-4"
            >
              <div class="d-flex align-center justify-space-between">
                <div>
                  <div class="font-weight-bold">
                    <v-icon left>mdi-restart</v-icon>
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
                dense 
                outlined 
                class="mt-3 mb-0"
              >
                <v-icon left small>mdi-alert</v-icon>
                {{ $t('plugins.nxt.messages.restartWarning') }}
              </v-alert>
            </v-alert>

            <!-- Informational header - plugin readiness is shown on individual pages -->
            <v-alert type="info" outlined class="mb-4">
              <v-icon left>mdi-information-outline</v-icon>
              {{ $t('plugins.nxt.messages.chooseSubsection') }}
              <span class="text-caption d-block mt-2">
                {{ $t('plugins.nxt.messages.toolLibraryInMenu') }}
              </span>
            </v-alert>

            <!-- Tab Navigation for different sections -->
            <v-tabs v-model="activeTab" grow>
              <v-tab>{{ $t('plugins.nxt.panels.status.caption') }}</v-tab>
              <v-tab>{{ $t('plugins.nxt.panels.configuration.caption') }}</v-tab>
              <v-tab>{{ $t('plugins.nxt.panels.probing.caption') }}</v-tab>
            </v-tabs>

            <v-tabs-items v-model="activeTab">
              <!-- Status Tab -->
              <v-tab-item>
                <div class="pa-4">
                  <nxt-machine-status-panel />
                </div>
              </v-tab-item>

              <!-- Configuration Tab -->
              <v-tab-item>
                <div class="pa-4">
                  <nxt-configuration-panel />
                </div>
              </v-tab-item>

              <!-- Probing Tab -->
              <v-tab-item>
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
              </v-tab-item>
            </v-tabs-items>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script lang="ts">
import BaseComponent from './components/base/BaseComponent.vue'
import { readFirmwareGlobal } from './utils/nxtToolChangerOm'

/**
 * nxt Main Dashboard Component
 * 
 * Provides the primary interface for nxt functionality within DWC.
 * Includes the persistent status widget and action confirmation widget
 * as specified in the Phase 2.1 requirements.
 */
export default BaseComponent.extend({
  name: 'nxt',
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
      const messageBox = this.$store.state.machine.model.messageBox
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

    pageTitle(): string {
      const path = this.$route?.path || ''
      if (path.startsWith('/nxt/Configuration')) return this.configurationCaption
      if (path.startsWith('/nxt/StockPreparation')) return this.stockPreparationCaption
      if (path.startsWith('/nxt/Probing')) return this.probingCaption
      if (path === '/nxt' || path === '/nxt/') {
        if (this.activeTab === 1) return this.configurationCaption
        if (this.activeTab === 2) return this.probingCaption
      }
      return this.statusCaption
    }
  },

  methods: {
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
    console.log('nxt: Main dashboard component mounted')
    console.log('nxt: Connected to machine:', this.isConnected)
    if (this.isConnected && this.restartRequired) {
      console.log('nxt: Machine restart required - nxtLoaded variable not found')
    } else if (!this.isConnected) {
      console.log('nxt: Not connected to machine - some features will be unavailable')
    }
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