<template>
  <!-- Base component - not meant to be rendered directly -->
  <div></div>
</template>

<script lang="ts">
import Vue from 'vue'
import { Axis, AxisLetter, Tool } from "@duet3d/objectmodel";
import store from "@/store";

/**
 * BaseComponent - Foundation component for all NeXT UI components
 * 
 * Provides common computed properties and methods for consistent
 * interaction with the DWC store and RRF object model.
 */
export default Vue.extend({
  name: 'BaseComponent',
  computed: {
    /**
     * Check if connected to a machine
     */
    isConnected(): boolean {
      return store.getters["isConnected"]
    },

    /**
     * Check if UI is frozen (during macro execution, etc.)
     */
    uiFrozen(): boolean {
      return store.state.machine.model.state.status === 'processing'
    },

    /**
     * Check if all visible axes are homed
     */
    allAxesHomed(): boolean {
      const axes = store.state.machine.model.move.axes
      const visibleAxes = axes.filter((axis: Axis) => axis.visible)
      return visibleAxes.every((axis: Axis) => axis.homed)
    },

    /**
     * Get visible axes as an array
     */
    visibleAxes(): Array<Axis> {
      return store.state.machine.model.move.axes.filter((axis: Axis) => axis.visible)
    },

    /**
     * Get visible axes mapped by letter (X, Y, Z, etc.)
     */
    visibleAxesByLetter(): { [key: string]: Axis } {
      return this.visibleAxes.reduce((acc, axis) => {
        acc[axis.letter] = axis
        return acc
      }, {} as { [key: string]: Axis })
    },

    /**
     * Get the currently selected tool
     */
    currentTool(): any {
      const tools = store.state.machine.model.tools
      const currentToolIndex = store.state.machine.model.state.currentTool
      return tools[currentToolIndex] || null
    },

    /**
     * Get the configured probe tool (last tool by default)
     */
    probeTool(): any {
      const tools = store.state.machine.model.tools
      const globals = this.globals
      const probeToolId = globals.nxtProbeToolID
      if (probeToolId !== undefined && tools[probeToolId]) {
        return tools[probeToolId]
      }
      // Default to last tool if nxtProbeToolID not set
      return tools[tools.length - 1] || null
    },

    /**
     * Get/Set current workplace coordinate system (1-based, maps to G54-G59.3)
     */
    currentWorkplace: {
      get(): number {
        return store.state.machine.model.move.workplaceNumber || 1
      },
      set(workplace: number) {
        this.sendCode(`G${53 + workplace}`)
      }
    },

    /**
     * Calculate absolute machine position for visible axes
     * Note: RRF doesn't expose workplace offsets in the object model yet,
     * so this returns the user position which already has offsets applied
     */
    absolutePosition(): Record<string, number> {
      const result: Record<string, number> = {}
      this.visibleAxes.forEach(axis => {
        result[axis.letter] = axis.userPosition || 0
      })
      return result
    },

    /**
     * Get global variables from RRF object model
     */
    globals(): Record<string, any> {
      return store.state.machine.model.global || {} as Record<string, any>
    },

    /**
     * Check if NeXT system is loaded and ready
     */
    nxtReady(): boolean {
      return this.globals.nxtLoaded === true && this.globals.nxtUiReady === true
    },

    /**
     * Get available spindles from RRF configuration
     */
    availableSpindles(): Array<{ id: number, name: string }> {
      const spindles = store.state.machine.model.spindles || []
      return spindles.map((_: any, index: number) => ({
        id: index,
        name: `Spindle ${index}`
      }))
    },

    /**
     * Get available probes from RRF configuration
     * Only returns probes with type 5-8 (touch probes)
     */
    availableProbes(): Array<{ id: number, name: string, type: number }> {
      const probes = store.state.machine.model.sensors?.probes || []
      return probes
        .map((probe: any, index: number) => ({
          id: index,
          name: `Probe ${index}`,
          type: probe?.type || 0
        }))
        .filter((p: any) => p.type >= 5 && p.type <= 8)
    },

    /**
     * Get available GPIO output ports from RRF configuration
     * Note: RRF doesn't expose GPIO outputs in the object model yet,
     * so we return a fixed list based on typical board configurations
     */
    availableGpOutputs(): Array<{ id: number, name: string }> {
      // Return a reasonable default list of GPIO outputs (0-7)
      // User will need to know their board's GPIO configuration
      return Array.from({ length: 8 }, (_, index) => ({
        id: index,
        name: `GP Out ${index}`
      }))
    }
  },

  methods: {
    /**
     * Send G-code command to the machine
     */
    async sendCode(code: string): Promise<any> {
      try {
        return await store.dispatch('machine/sendCode', code)
      } catch (error) {
        console.error('NeXT UI: Failed to send code:', code, error)
        throw error
      }
    }
  }
})
</script>