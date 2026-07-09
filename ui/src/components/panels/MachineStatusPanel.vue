<template>
  <v-card>
    <v-card-title>
      <v-icon left>mdi-information-outline</v-icon>
      {{ $t('plugins.nxt.panels.status.caption') }}
      <v-spacer />
      <div v-if="!isConnected || !nxtReady" class="d-flex align-center">
        <v-icon small class="mr-2" color="warning">{{ !isConnected ? 'mdi-lan-disconnect' : 'mdi-alert-circle-outline' }}</v-icon>
        <span class="text-caption">{{
          !isConnected ? $t('plugins.nxt.messages.disconnectedShort') : $t('plugins.nxt.messages.notReadyShort')
        }}</span>
      </div>
    </v-card-title>
    
    <v-card-text>
      <v-row>
        <!-- nxt System Status -->
        <v-col cols="12" md="6">
          <v-card outlined>
            <v-card-subtitle>nxt System</v-card-subtitle>
            <v-card-text>
              <v-list dense>
                <v-list-item>
                  <v-list-item-content>
                    <v-list-item-title>nxt loaded (firmware)</v-list-item-title>
                    <v-list-item-subtitle class="text-caption">
                      <code>global.nxtLoaded</code> true after successful boot
                    </v-list-item-subtitle>
                  </v-list-item-content>
                  <v-list-item-action>
                    <v-icon :color="nxtBackendReady ? 'success' : 'error'">
                      {{ nxtBackendReady ? 'mdi-check' : 'mdi-close' }}
                    </v-icon>
                  </v-list-item-action>
                </v-list-item>

                <v-list-item v-if="nxtErrorText">
                  <v-list-item-content>
                    <v-list-item-title class="error--text">
                      Last Error: {{ nxtErrorText }}
                    </v-list-item-title>
                  </v-list-item-content>
                </v-list-item>

                <v-list-item>
                  <v-list-item-content>
                    <v-list-item-title>Probe tool loaded (T{{ probeToolIdText }})</v-list-item-title>
                    <v-list-item-subtitle class="text-caption">
                      Current tool must match <code>global.nxtProbeToolID</code> to run probing cycles
                    </v-list-item-subtitle>
                  </v-list-item-content>
                  <v-list-item-action>
                    <v-icon :color="touchProbeToolLoaded ? 'success' : 'warning'">
                      {{ touchProbeToolLoaded ? 'mdi-check-circle' : 'mdi-close-circle-outline' }}
                    </v-icon>
                  </v-list-item-action>
                </v-list-item>
              </v-list>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- Machine Position -->
        <v-col cols="12" md="6">
          <v-card outlined>
            <v-card-subtitle>Axis Positions</v-card-subtitle>
            <v-card-text>
              <v-list dense>
                <v-list-item 
                  v-for="(axis, letter) in visibleAxesByLetter" 
                  :key="letter"
                >
                  <v-list-item-content>
                    <v-list-item-title>
                      {{ letter }}: {{ formatPosition(axis.machinePosition) }}
                    </v-list-item-title>
                    <v-list-item-subtitle v-if="axis.userPosition !== axis.machinePosition">
                      Work: {{ formatPosition(axis.userPosition) }}
                    </v-list-item-subtitle>
                  </v-list-item-content>
                  <v-list-item-action>
                    <v-icon 
                      :color="axis.homed ? 'success' : 'warning'"
                      small
                    >
                      {{ axis.homed ? 'mdi-home' : 'mdi-home-outline' }}
                    </v-icon>
                  </v-list-item-action>
                </v-list-item>
              </v-list>
            </v-card-text>
          </v-card>
        </v-col>

        <!-- Feature Status -->
        <v-col cols="12">
          <v-card outlined>
            <v-card-subtitle>nxt Features</v-card-subtitle>
            <v-card-text>
              <v-row>
                <v-col cols="6" sm="4">
                  <div class="feature-status">
                    <v-icon 
                      :color="globals.nxtFeatureTouchProbe ? 'success' : 'grey'"
                      left
                    >
                      mdi-target
                    </v-icon>
                    Touch Probe
                  </div>
                </v-col>
                
                <v-col cols="6" sm="4">
                  <div class="feature-status">
                    <v-icon 
                      :color="globals.nxtFeatureToolSetter ? 'success' : 'grey'"
                      left
                    >
                      mdi-wrench
                    </v-icon>
                    Tool Setter
                  </div>
                </v-col>
                
                <v-col cols="6" sm="4">
                  <div class="feature-status">
                    <v-icon 
                      :color="globals.nxtFeatureCoolantControl ? 'success' : 'grey'"
                      left
                    >
                      mdi-water
                    </v-icon>
                    Coolant Control
                  </div>
                </v-col>
                <v-col cols="6" sm="4" v-if="rgbHardwareConfigured">
                  <div class="feature-status">
                    <v-icon 
                      :color="globals.nxtFeatureRgbLight ? 'success' : 'grey'"
                      left
                    >
                      mdi-lightbulb-on
                    </v-icon>
                    RGB Work Light
                  </div>
                </v-col>
              </v-row>
            </v-card-text>
          </v-card>
        </v-col>

        <v-col v-if="rgbHardwareConfigured" cols="12">
          <nxt-rgb-light-control />
        </v-col>

        <v-col cols="12">
          <nxt-maintenance-panel />
        </v-col>
      </v-row>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import BaseComponent from '../base/BaseComponent.vue'
import { isRgbLightHardwareConfigured, readOmLedsFromMachineModel } from '../../utils/nxtRgbAvailability'
import store from '@/store'

/**
 * nxt Machine Status Panel
 * 
 * Displays detailed machine and nxt system status information
 */
export default BaseComponent.extend({
  name: 'NxtMachineStatusPanel',

  computed: {
    /**
     * RRF may expose globals as strings, numbers, or occasionally structured values.
     * Normalize so Vuetify / Vue never receives a value that breaks text rendering.
     */
    nxtErrorText(): string {
      const e = this.globals.nxtError
      if (e == null || e === '') {
        return ''
      }
      if (typeof e === 'string') {
        return e
      }
      if (typeof e === 'number' || typeof e === 'boolean') {
        return String(e)
      }
      try {
        return JSON.stringify(e)
      } catch {
        return String(e)
      }
    },

    probeToolId(): number | null {
      const id = this.globals.nxtProbeToolID
      if (typeof id === 'number' && Number.isFinite(id)) {
        return id
      }
      return null
    },

    probeToolIdText(): string {
      return this.probeToolId === null ? 'unset' : String(this.probeToolId)
    },

    touchProbeToolLoaded(): boolean {
      if (!this.globals.nxtFeatureTouchProbe || this.probeToolId === null) {
        return false
      }
      return this.currentTool?.number === this.probeToolId
    },

    rgbHardwareConfigured(): boolean {
      const boards = store.state.machine.model.boards
      const boardShortName =
        this.globals.nxtBoardShortNameOverride != null &&
        String(this.globals.nxtBoardShortNameOverride).trim().length > 0
          ? String(this.globals.nxtBoardShortNameOverride).trim()
          : Array.isArray(boards) && boards[0]?.shortName
            ? String(boards[0].shortName)
            : null
      return isRgbLightHardwareConfigured({
        leds: readOmLedsFromMachineModel(store.state.machine.model),
        boardShortName
      })
    }
  },

  methods: {
    formatPosition(position: number | null | undefined): string {
      if (position === null || position === undefined) {
        return 'N/A'
      }
      return position.toFixed(3)
    }
  }
})
</script>

<style scoped>
.feature-status {
  display: flex;
  align-items: center;
  font-size: 0.875rem;
  padding: 4px 0;
}

.v-card {
  height: 100%;
}

.v-list-item-title {
  font-size: 0.875rem !important;
}

.v-list-item-subtitle {
  font-size: 0.75rem !important;
}
</style>