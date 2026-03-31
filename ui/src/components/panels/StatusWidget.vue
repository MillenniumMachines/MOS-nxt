<template>
  <v-card class="nxt-status-widget">
    <v-card-title class="py-2">
      <v-icon left small>mdi-information</v-icon>
      {{ $t('plugins.next.panels.status') }}
    </v-card-title>
    
    <v-card-text class="py-2">
      <v-row no-gutters>
        <!-- Tool Status -->
        <v-col cols="6" sm="3">
          <div class="status-item">
            <div class="status-label">{{ $t('plugins.next.status.tool') }}</div>
            <div class="status-value" :class="toolStatusClass">
              <v-icon small left>{{ toolIcon }}</v-icon>
              {{ toolDisplay }}
            </div>
          </div>
        </v-col>

        <!-- WCS Status -->
        <v-col cols="6" sm="3">
          <div class="status-item">
            <div class="status-label">{{ $t('plugins.next.status.wcs') }}</div>
            <div class="status-value">
              <v-icon small left>mdi-axis-arrow</v-icon>
              G{{ 53 + currentWorkplace }}
            </div>
          </div>
        </v-col>

        <!-- Spindle Status -->
        <v-col cols="6" sm="3">
          <div class="status-item">
            <div class="status-label">{{ $t('plugins.next.status.spindle') }}</div>
            <div class="status-value" :class="spindleStatusClass">
              <v-icon small left>{{ spindleIcon }}</v-icon>
              {{ spindleDisplay }}
            </div>
          </div>
        </v-col>

        <!-- Position Status -->
        <v-col cols="6" sm="3">
          <div class="status-item">
            <div class="status-label">{{ $t('plugins.next.status.position') }}</div>
            <div class="status-value" :class="positionStatusClass">
              <v-icon small left>{{ positionIcon }}</v-icon>
              {{ positionDisplay }}
            </div>
          </div>
        </v-col>
      </v-row>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import BaseComponent from '../base/BaseComponent.vue'

/**
 * NeXT Status Widget
 * 
 * Persistent status display showing key machine information:
 * - Current tool
 * - Active WCS
 * - Spindle status
 * - Position/homing status
 */
export default BaseComponent.extend({
  name: 'NxtStatusWidget',
  
  computed: {
    toolDisplay(): string {
      if (!this.currentTool) {
        return 'None'
      }
      return `T${this.currentTool.number}`
    },

    toolIcon(): string {
      if (!this.currentTool) {
        return 'mdi-tools'
      }
      // Check if current tool is the probe tool
      if (this.probeTool && this.currentTool.number === this.probeTool.number) {
        return 'mdi-target'
      }
      return 'mdi-drill'
    },

    toolStatusClass(): string {
      if (!this.currentTool) {
        return 'text--secondary'
      }
      if (this.probeTool && this.currentTool.number === this.probeTool.number) {
        return 'orange--text'
      }
      return 'primary--text'
    },

    spindleDisplay(): string {
      const spindles = this.$store.state.machine.model.spindles
      if (!spindles || spindles.length === 0) {
        return 'N/A'
      }
      
      const spindle = spindles[0] // Default to first spindle
      if (spindle.active) {
        const rpm = Math.round(spindle.current || 0)
        return `${rpm} RPM`
      }
      return 'Off'
    },

    spindleIcon(): string {
      const spindles = this.$store.state.machine.model.spindles
      if (!spindles || spindles.length === 0) {
        return 'mdi-fan-off'
      }
      
      const spindle = spindles[0]
      return spindle.active ? 'mdi-fan' : 'mdi-fan-off'
    },

    spindleStatusClass(): string {
      const spindles = this.$store.state.machine.model.spindles
      if (!spindles || spindles.length === 0) {
        return 'text--secondary'
      }
      
      const spindle = spindles[0]
      return spindle.active ? 'success--text' : 'text--secondary'
    },

    positionDisplay(): string {
      if (this.allAxesHomed) {
        return 'Homed'
      }
      
      const axes = this.$store.state.machine.model.move.axes
      const visibleAxes = this.$store.state.machine.settings.displayedAxes
      const homedCount = visibleAxes.filter((axisIndex: number) => {
        const axis = axes[axisIndex]
        return axis && axis.homed
      }).length
      
      return `${homedCount}/${visibleAxes.length}`
    },

    positionIcon(): string {
      return this.allAxesHomed ? 'mdi-home' : 'mdi-home-outline'
    },

    positionStatusClass(): string {
      return this.allAxesHomed ? 'success--text' : 'warning--text'
    }
  }
})
</script>

<style scoped>
:root {
  --dwc-toolbar-height: 64px;
}
.nxt-status-widget {
  position: sticky;
  top: var(--dwc-toolbar-height); /* Account for DWC toolbar */
  z-index: 10;
}

.status-item {
  text-align: center;
  padding: 4px;
}

.status-label {
  font-size: 0.75rem;
  font-weight: 500;
  opacity: 0.7;
  text-transform: uppercase;
  margin-bottom: 2px;
}

.status-value {
  font-size: 0.875rem;
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
}

.v-card-title {
  font-size: 0.875rem !important;
  background-color: rgba(0, 0, 0, 0.03);
}

.v-card-text {
  padding-top: 8px !important;
  padding-bottom: 8px !important;
}
</style>