<template>
  <v-card>
    <v-card-title>
      <v-icon left>mdi-target-variant</v-icon>
      {{ $t('plugins.next.panels.probing.caption') }}
      <v-spacer />
      <div v-if="!isConnected" class="d-flex align-center">
        <v-icon small class="mr-2" color="warning">mdi-lan-disconnect</v-icon>
        <span class="text-caption">{{ $t('plugins.next.messages.disconnectedShort') }}</span>
      </div>
    </v-card-title>
    <v-card-text>
      <v-row>
        <v-col cols="12">
          <v-alert type="info" outlined>
            <v-icon left small>mdi-information-outline</v-icon>
            {{ $t('plugins.next.messages.probingComingSoon') }}
          </v-alert>
        </v-col>
      </v-row>
      <v-row>
        <v-col cols="12">
          <!-- Minimal probe controls for now -->
          <v-card outlined>
            <v-card-subtitle>Probe Controls</v-card-subtitle>
            <v-card-text>
              <div class="text-caption mb-2">{{ $t('plugins.next.messages.basicProbeControls') }}</div>
              <v-btn color="primary" @click="sendProbeCommand('M5012')">{{ $t('plugins.next.actions.refreshProbe') }}</v-btn>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import BaseComponent from '../base/BaseComponent.vue'

export default BaseComponent.extend({
  name: 'ProbingPanel',
  methods: {
    async sendProbeCommand(code: string) {
      try {
        await this.sendCode(code)
      } catch (err) {
        console.error('ProbingPanel: failed to send probe command', err)
      }
    }
  }
})
</script>

<style scoped>
.v-card {
  height: 100%;
}
</style>
