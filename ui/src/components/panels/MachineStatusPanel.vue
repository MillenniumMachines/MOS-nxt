<template>
  <v-card>
    <v-card-title>
      <v-icon left>mdi-information-outline</v-icon>
      {{ $t('plugins.next.panels.status.caption') }}
      <v-spacer />
      <div v-if="!isConnected || !nxtReady" class="d-flex align-center">
        <v-icon small class="mr-2" color="warning">mdi-lan-disconnect</v-icon>
        <span class="text-caption">{{ $t('plugins.next.messages.disconnectedShort') }}</span>
      </div>
    </v-card-title>
    
    <v-card-text>
      <v-row>
        <!-- NeXT System Status -->
        <v-col cols="12" md="6">
          <v-card outlined>
            <v-card-subtitle>NeXT System</v-card-subtitle>
            <v-card-text>
              <v-list dense>
                <v-list-item>
                  <v-list-item-content>
                    <v-list-item-title>Backend Loaded</v-list-item-title>
                  </v-list-item-content>
                  <v-list-item-action>
                    <v-icon :color="globals.nxtLoaded ? 'success' : 'error'">
                      {{ globals.nxtLoaded ? 'mdi-check' : 'mdi-close' }}
                    </v-icon>
                  </v-list-item-action>
                </v-list-item>
                
                <v-list-item>
                  <v-list-item-content>
                    <v-list-item-title>UI Ready</v-list-item-title>
                  </v-list-item-content>
                  <v-list-item-action>
                    <v-icon :color="globals.nxtUiReady ? 'success' : 'error'">
                      {{ globals.nxtUiReady ? 'mdi-check' : 'mdi-close' }}
                    </v-icon>
                  </v-list-item-action>
                </v-list-item>

                <v-list-item v-if="globals.nxtError">
                  <v-list-item-content>
                    <v-list-item-title class="error--text">
                      Last Error: {{ globals.nxtError }}
                    </v-list-item-title>
                  </v-list-item-content>
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
            <v-card-subtitle>NeXT Features</v-card-subtitle>
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
              </v-row>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import BaseComponent from '../base/BaseComponent.vue'

/**
 * NeXT Machine Status Panel
 * 
 * Displays detailed machine and NeXT system status information
 */
export default BaseComponent.extend({
  name: 'NxtMachineStatusPanel',
  
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