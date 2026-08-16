<template>
  <!-- Base component - not meant to be rendered directly -->
  <div></div>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import { Axis } from "@duet3d/objectmodel";
import store from "../../compat/dwcStore";
import { extendComponent } from "../../compat/vueCompat";
import { readFirmwareGlobal } from "../../utils/nxtToolChangerOm";

/**
 * BaseComponent - Foundation component for all nxt UI components
 *
 * Provides common computed properties and methods for consistent
 * interaction with the DWC store (via the compat/dwcStore shim) and RRF object model.
 */
const BaseComponent = defineComponent({
  name: 'BaseComponent',

  beforeCreate() {
    // Vue 3 Options API has no Vuex-style `this.$store` injection; `defineProperty` in
    // `beforeCreate` installs it as a getter on every instance that extends this component
    // (see compat/dwcStore.ts for the ComponentCustomProperties augmentation that types it)
    Object.defineProperty(this, '$store', { get: () => store, configurable: true })
  },

  computed: {
    /**
     * Check if connected to a machine
     */
    isConnected(): boolean {
      return store.getters.isConnected
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
     * Current WCS as 1-based index (1 = G54 … 9 = G59.3).
     * RRF move.workplaceNumber is 0-based (0 = G54); do not use `|| 1` (turns G54 into 1 then +1 → WCS2).
     */
    currentWorkplace: {
      get(): number {
        const move = store.state.machine.model.move as {
          workplaceNumber?: number
          motionSystems?: Array<{ workplaceNumber?: number }>
        }
        const fromSystem = move?.motionSystems?.[0]?.workplaceNumber
        const raw =
          typeof fromSystem === 'number'
            ? fromSystem
            : typeof move?.workplaceNumber === 'number'
              ? move.workplaceNumber
              : 0
        return raw + 1
      },
      set(workplace: number) {
        // 1-based WCS. G59.1–G59.3 are not G60–G62 — use nxt-select-wcs.g.
        const w = typeof workplace === 'number' && workplace >= 1 && workplace <= 9
          ? workplace
          : 1
        this.sendCode(`M98 P"nxt-select-wcs.g" W${w}`)
      }
    },

    /**
     * User position per visible axis (WCS already applied by RRF).
     * Machine G10 L2 origins live in move.axes[].workplaceOffsets.
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
     * RRF / JSON may expose booleans as true or 1 in the object model.
     */
    nxtBackendReady(): boolean {
      const v = readFirmwareGlobal(store.state.machine.model.global, 'nxtLoaded')
      return v === true || v === 1
    },

    /**
     * nxt firmware globals are present and boot reported success (`global.nxtLoaded`).
     * No DWC→RRF UI handshake; avoids false negatives when OM lags or Map shape differs.
     */
    nxtReady(): boolean {
      return this.nxtBackendReady
    },

    /**
     * Get available spindles from RRF configuration (configured slots only).
     */
    availableSpindles(): Array<{ id: number, name: string }> {
      const spindles = store.state.machine.model.spindles || []
      return spindles
        .map((spindle: { state?: string } | null, index: number) => ({
          id: index,
          name: `Spindle ${index}`,
          configured: spindle != null && spindle.state !== 'unconfigured'
        }))
        .filter((s: { configured: boolean }) => s.configured)
        .map((s: { id: number; name: string }) => ({ id: s.id, name: s.name }))
    },

    /**
     * Get available probes from RRF configuration
     * Only returns probes with type 5-8 (touch probes)
     */
    availableProbes(): Array<{ id: number, name: string, type: number }> {
      const probes = store.state.machine.model.sensors?.probes || []
      const typeLabel = (t: number): string => {
        if (t === 5) return 'switch'
        if (t === 6) return 'digital'
        if (t === 7) return 'filtered'
        if (t === 8) return 'analog'
        return `type ${t}`
      }
      return probes
        .map((probe: any, index: number) => {
          const type = probe?.type || 0
          return {
            id: index,
            name: `Probe ${index} — ${typeLabel(type)} (type ${type})`,
            type
          }
        })
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
        console.error('nxt UI: Failed to send code:', code, error)
        throw error
      }
    }
  }
})

/**
 * Replacement for the old `BaseComponent.extend({ ... })` call shape (Vue 2's `Vue.extend`).
 * See compat/vueCompat.ts for details.
 */
export function defineNxtComponent(options: Record<string, any>) {
  return extendComponent(BaseComponent, options)
}

export default BaseComponent
</script>
