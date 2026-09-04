<template>
  <v-card class="nxt-status-widget">
    <v-card-title class="py-2">
      <v-icon class="mr-2" size="small">mdi-information</v-icon>
      {{ $t('plugins.nxt.panels.status.caption') }}
    </v-card-title>
    
    <v-card-text class="py-2">
      <v-row no-gutters>
        <!-- Tool Status -->
        <v-col cols="6" sm="3">
          <div class="status-item">
            <div class="status-label">{{ $t('plugins.nxt.panels.status.tool') }}</div>
            <div class="status-value" :class="toolStatusClass">
              <v-icon class="mr-2" size="small">{{ toolIcon }}</v-icon>
              {{ toolDisplay }}
            </div>
          </div>
        </v-col>

        <!-- WCS Status -->
        <v-col cols="6" sm="3">
          <div class="status-item">
            <div class="status-label">{{ $t('plugins.nxt.panels.status.wcs') }}</div>
            <div class="status-value">
              <v-icon class="mr-2" size="small">mdi-axis-arrow</v-icon>
              G{{ 53 + currentWorkplace }}
            </div>
          </div>
        </v-col>

        <!-- Spindle Status -->
        <v-col cols="6" sm="3">
          <div class="status-item">
            <div class="status-label">{{ $t('plugins.nxt.panels.status.spindle') }}</div>
            <div class="status-value" :class="spindleStatusClass">
              <v-icon class="mr-2" size="small">{{ spindleIcon }}</v-icon>
              {{ spindleDisplay }}
            </div>
          </div>
        </v-col>

        <!-- Position Status -->
        <v-col cols="6" sm="3">
          <div class="status-item">
            <div class="status-label">{{ $t('plugins.nxt.panels.status.position') }}</div>
            <div class="status-value" :class="positionStatusClass">
              <v-icon class="mr-2" size="small">{{ positionIcon }}</v-icon>
              {{ positionDisplay }}
            </div>
          </div>
        </v-col>
      </v-row>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import { defineNxtComponent } from '../base/BaseComponent.vue'
import store from '../../compat/dwcStore'
import { formatToolLabelFromTools } from '../../utils/nxtLoadedToolStatus'

/**
 * nxt Status Widget
 * 
 * Persistent status display showing key machine information:
 * - Current tool
 * - Active WCS
 * - Spindle status
 * - Position/homing status
 */
export default defineNxtComponent({
  name: 'NxtStatusWidget',
  
  computed: {
    toolDisplay(): string {
      const idx = store.state.machine.model.state.currentTool
      if (typeof idx !== 'number' || idx < 0) {
        return 'None'
      }
      const label = formatToolLabelFromTools(store.state.machine.model.tools, idx)
      return label.length > 0 ? label : 'None'
    },

    toolIcon(): string {
      if (!this.currentTool) {
        return 'mdi-tools'
      }
      // Check if current tool is the probe tool
      const idx = store.state.machine.model.state.currentTool
      const probeId =
        this.probeTool != null && typeof (this.probeTool as { number?: number }).number === 'number'
          ? (this.probeTool as { number: number }).number
          : null
      if (probeId != null && idx === probeId) {
        return 'mdi-target'
      }
      // Prefer configured probe slot from globals when tool.number is absent
      const raw = (this.globals as { nxtProbeToolID?: number })?.nxtProbeToolID
      if (typeof raw === 'number' && idx === raw) {
        return 'mdi-target'
      }
      return 'mdi-drill'
    },

    toolStatusClass(): string {
      if (!this.currentTool) {
        return 'text--secondary'
      }
      const idx = store.state.machine.model.state.currentTool
      const raw = (this.globals as { nxtProbeToolID?: number })?.nxtProbeToolID
      if (typeof raw === 'number' && idx === raw) {
        return 'text-orange'
      }
      return 'text-primary'
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
      return spindle.active ? 'text-success' : 'text--secondary'
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
      return this.allAxesHomed ? 'text-success' : 'text-warning'
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