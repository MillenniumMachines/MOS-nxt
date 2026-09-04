<template>
  <v-card>
    <v-card-title class="d-flex align-center">
      <v-icon class="mr-2">mdi-axis-arrow</v-icon>
      {{ $t('plugins.nxt.panels.workplaceOrigins.title') }}
    </v-card-title>

    <v-card-text>
      <div class="text-caption text-medium-emphasis mb-3">
        {{ $t('plugins.nxt.panels.workplaceOrigins.caption') }}
      </div>

      <v-data-table
        :headers="headers"
        :items="wcsRows"
        :items-per-page="-1"
        :hide-default-footer="true"
        density="compact"
        class="elevation-1 nxt-wcs-table"
        item-value="wcs"
        :row-props="wcsRowProps"
        @click:row="onClickRow"
      >
        <template v-slot:item.wcs="{ item }: { item: any }">
          <div class="d-flex align-center">
            <span>{{ wcsRow(item).label }}</span>
            <v-chip
              v-if="wcsRow(item).wcs === currentWorkplace"
              class="ml-2"
              size="x-small"
              color="success"
              variant="tonal"
            >
              {{ $t('plugins.nxt.panels.workplaceOrigins.active') }}
            </v-chip>
          </div>
        </template>
        <template v-slot:item.x="{ item }: { item: any }">
          <v-text-field
            :model-value="axisField(wcsRow(item).wcs, 'X', wcsRow(item).x)"
            density="compact"
            variant="outlined"
            hide-details
            type="number"
            step="0.001"
            class="nxt-wcs-cell"
            :disabled="!canEdit"
            @click.stop
            @update:model-value="(v: string | number) => setDraft(wcsRow(item).wcs, 'X', v)"
            @blur="commitAxis(wcsRow(item).wcs, 'X')"
            @keyup.enter="commitAxis(wcsRow(item).wcs, 'X')"
          />
        </template>
        <template v-slot:item.y="{ item }: { item: any }">
          <v-text-field
            :model-value="axisField(wcsRow(item).wcs, 'Y', wcsRow(item).y)"
            density="compact"
            variant="outlined"
            hide-details
            type="number"
            step="0.001"
            class="nxt-wcs-cell"
            :disabled="!canEdit"
            @click.stop
            @update:model-value="(v: string | number) => setDraft(wcsRow(item).wcs, 'Y', v)"
            @blur="commitAxis(wcsRow(item).wcs, 'Y')"
            @keyup.enter="commitAxis(wcsRow(item).wcs, 'Y')"
          />
        </template>
        <template v-slot:item.z="{ item }: { item: any }">
          <v-text-field
            :model-value="axisField(wcsRow(item).wcs, 'Z', wcsRow(item).z)"
            density="compact"
            variant="outlined"
            hide-details
            type="number"
            step="0.001"
            class="nxt-wcs-cell"
            :disabled="!canEdit"
            @click.stop
            @update:model-value="(v: string | number) => setDraft(wcsRow(item).wcs, 'Z', v)"
            @blur="commitAxis(wcsRow(item).wcs, 'Z')"
            @keyup.enter="commitAxis(wcsRow(item).wcs, 'Z')"
          />
        </template>
        <template v-slot:item.a="{ item }: { item: any }">
          <v-text-field
            :model-value="axisField(wcsRow(item).wcs, 'A', wcsRow(item).a)"
            density="compact"
            variant="outlined"
            hide-details
            type="number"
            step="0.001"
            class="nxt-wcs-cell"
            :disabled="!canEdit"
            @click.stop
            @update:model-value="(v: string | number) => setDraft(wcsRow(item).wcs, 'A', v)"
            @blur="commitAxis(wcsRow(item).wcs, 'A')"
            @keyup.enter="commitAxis(wcsRow(item).wcs, 'A')"
          />
        </template>
        <template v-slot:item.rotation="{ item }: { item: any }">
          {{ formatRotation(wcsRow(item).rotation) }}
        </template>
        <template v-slot:item.actions="{ item }: { item: any }">
          <div class="d-flex" @click.stop>
            <v-tooltip location="top">
              <template v-slot:activator="{ props }">
                <v-btn
                  v-bind="props"
                  size="x-small"
                  icon
                  variant="text"
                  :disabled="!canEdit"
                  @click="activateWcs(wcsRow(item).wcs)"
                >
                  <v-icon size="small">mdi-check</v-icon>
                </v-btn>
              </template>
              <span>{{ $t('plugins.nxt.panels.workplaceOrigins.activate') }}</span>
            </v-tooltip>
            <v-tooltip location="top">
              <template v-slot:activator="{ props }">
                <v-btn
                  v-bind="props"
                  size="x-small"
                  icon
                  variant="text"
                  color="primary"
                  :disabled="!canProbe"
                  @click="probeWcs(wcsRow(item).wcs)"
                >
                  <v-icon size="small">mdi-crosshairs-gps</v-icon>
                </v-btn>
              </template>
              <span>{{ $t('plugins.nxt.panels.workplaceOrigins.probe') }}</span>
            </v-tooltip>
            <v-tooltip location="top">
              <template v-slot:activator="{ props }">
                <v-btn
                  v-bind="props"
                  size="x-small"
                  icon
                  variant="text"
                  color="error"
                  :disabled="!canEdit"
                  @click="clearWcs(wcsRow(item).wcs)"
                >
                  <v-icon size="small">mdi-delete</v-icon>
                </v-btn>
              </template>
              <span>{{ $t('plugins.nxt.panels.workplaceOrigins.clear') }}</span>
            </v-tooltip>
          </div>
        </template>
      </v-data-table>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import type { Axis } from '@duet3d/objectmodel'
import { defineNxtComponent } from '../base/BaseComponent.vue'
import {
  findVisibleAxis,
  formatMmDisplay,
  formatMmGcode,
  mmUnchanged,
  nxtWcsLabel,
  readWorkplaceOffset,
  readWpDeg,
  workplaceCount,
  workplaceOffsetLength
} from '../../utils/nxtWorkplaceOffsets'
import {
  readNxtUiState,
  writeNxtUiSelectedWcs
} from '../../utils/nxtProbeResultsUi'

interface WcsRow {
  wcs: number
  label: string
  x: number | null
  y: number | null
  z: number | null
  a: number | null
  rotation: number | null
}

type WcsRowSlot = WcsRow | { raw?: WcsRow }

function asWcsRow(item: WcsRowSlot): WcsRow {
  if (item != null && typeof item === 'object' && 'raw' in item && item.raw != null) {
    return item.raw
  }
  return item as WcsRow
}

export default defineNxtComponent({
  name: 'WorkplaceOriginsPanel',
  emits: ['probe'],
  props: {
    canProbe: {
      type: Boolean,
      default: false
    }
  },
  data() {
    return {
      drafts: {} as Record<string, string>,
      busy: false
    }
  },
  computed: {
    pluginsState(): unknown {
      return this.$store.state.settings?.plugins
    },
    selectedWcs(): number {
      const ui = readNxtUiState(this.pluginsState)
      const w = ui?.selectedWcs
      return typeof w === 'number' && w >= 1 && w <= 9 ? w : 1
    },
    hasAAxis(): boolean {
      return findVisibleAxis(this.visibleAxes, 'A') != null
    },
    canEdit(): boolean {
      return this.isConnected && !this.uiFrozen && !this.busy
    },
    headers(): { title: string; key: string; sortable: boolean; width?: string }[] {
      const t = (k: string) => this.$t(`plugins.nxt.panels.workplaceOrigins.${k}`).toString()
      const cols: { title: string; key: string; sortable: boolean; width?: string }[] = [
        { title: t('colWcs'), key: 'wcs', sortable: false },
        { title: t('colX'), key: 'x', sortable: false },
        { title: t('colY'), key: 'y', sortable: false },
        { title: t('colZ'), key: 'z', sortable: false }
      ]
      if (this.hasAAxis) {
        cols.push({ title: t('colA'), key: 'a', sortable: false })
      }
      cols.push({ title: t('colRot'), key: 'rotation', sortable: false })
      cols.push({ title: '', key: 'actions', sortable: false, width: '132px' })
      return cols
    },
    wcsRows(): WcsRow[] {
      const axes = this.visibleAxes as Axis[]
      const axisX = findVisibleAxis(axes, 'X')
      const axisY = findVisibleAxis(axes, 'Y')
      const axisZ = findVisibleAxis(axes, 'Z')
      const axisA = findVisibleAxis(axes, 'A')
      const limits = this.$store.state.machine.model.limits as { workplaces?: number } | undefined
      const count = workplaceCount({
        limitsWorkplaces: limits?.workplaces,
        offsetLength: workplaceOffsetLength(axisX ?? axisY ?? axisZ)
      })
      const globalVal = this.$store.state.machine.model.global
      const rows: WcsRow[] = []
      for (let i = 0; i < count; i++) {
        const wcs = i + 1
        rows.push({
          wcs,
          label: nxtWcsLabel(wcs),
          x: readWorkplaceOffset(axisX, i),
          y: readWorkplaceOffset(axisY, i),
          z: readWorkplaceOffset(axisZ, i),
          a: this.hasAAxis ? readWorkplaceOffset(axisA, i) : null,
          rotation: readWpDeg(globalVal, i)
        })
      }
      return rows
    }
  },
  methods: {
    wcsRow(item: any): WcsRow {
      return asWcsRow(item as WcsRowSlot)
    },
    wcsRowProps(data: { item: any }): { class: string } {
      const row = asWcsRow(data.item as WcsRowSlot)
      const classes: string[] = []
      if (row.wcs === this.selectedWcs) classes.push('nxt-wcs-row--selected')
      if (row.wcs === this.currentWorkplace) classes.push('nxt-wcs-row--active')
      return { class: classes.join(' ') }
    },
    onClickRow(_event: MouseEvent, data: { item: any }): void {
      this.selectWcs(asWcsRow(data.item as WcsRowSlot).wcs)
    },
    selectWcs(wcs: number): void {
      writeNxtUiSelectedWcs(wcs, this.pluginsState)
    },
    draftKey(wcs: number, letter: string): string {
      return `${wcs}:${letter}`
    },
    liveOffset(wcs: number, letter: string): number | null {
      const row = this.wcsRows.find((r: WcsRow) => r.wcs === wcs)
      if (row == null) return null
      if (letter === 'X') return row.x
      if (letter === 'Y') return row.y
      if (letter === 'Z') return row.z
      if (letter === 'A') return row.a
      return null
    },
    axisField(wcs: number, letter: string, live: number | null): string {
      const key = this.draftKey(wcs, letter)
      if (Object.prototype.hasOwnProperty.call(this.drafts, key)) {
        return this.drafts[key]
      }
      return live == null || !Number.isFinite(live) ? '' : formatMmDisplay(live)
    },
    setDraft(wcs: number, letter: string, value: string | number): void {
      this.drafts[this.draftKey(wcs, letter)] = String(value)
    },
    formatRotation(deg: number | null): string {
      if (deg == null || !Number.isFinite(deg) || Math.abs(deg) < 0.0005) {
        return '—'
      }
      return `${deg.toFixed(3)}°`
    },
    async commitAxis(wcs: number, letter: string): Promise<void> {
      const key = this.draftKey(wcs, letter)
      if (!Object.prototype.hasOwnProperty.call(this.drafts, key)) return
      const raw = this.drafts[key]
      delete this.drafts[key]
      const n = Number(raw)
      if (!Number.isFinite(n)) return
      const live = this.liveOffset(wcs, letter)
      if (mmUnchanged(live, n)) return
      this.selectWcs(wcs)
      this.busy = true
      try {
        const cmd = `M98 P"nxt-wcs-set.g" W${wcs} ${letter}${formatMmGcode(n)}`
        await this.sendCode(cmd)
      } catch (error) {
        this.$store.dispatch('machine/showMessage', {
          type: 'error',
          message: `${this.$t('plugins.nxt.panels.workplaceOrigins.setFailed').toString()}: ${error}`
        })
      } finally {
        this.busy = false
      }
    },
    async activateWcs(wcs: number): Promise<void> {
      this.selectWcs(wcs)
      this.busy = true
      try {
        await this.sendCode(`M98 P"nxt-select-wcs.g" W${wcs}`)
        await this.sendCode('M98 P"nxt-user-wcs-sync.g"')
        this.$store.dispatch('machine/showMessage', {
          type: 'success',
          message: this.$t('plugins.nxt.panels.workplaceOrigins.activated', [
            nxtWcsLabel(wcs)
          ]).toString()
        })
      } catch (error) {
        this.$store.dispatch('machine/showMessage', {
          type: 'error',
          message: `${this.$t('plugins.nxt.panels.workplaceOrigins.activateFailed').toString()}: ${error}`
        })
      } finally {
        this.busy = false
      }
    },
    probeWcs(wcs: number): void {
      this.selectWcs(wcs)
      this.$emit('probe', wcs)
    },
    async clearWcs(wcs: number): Promise<void> {
      const label = nxtWcsLabel(wcs)
      const msg = this.$t('plugins.nxt.panels.workplaceOrigins.clearConfirm', [label]).toString()
      if (!window.confirm(msg)) return
      this.selectWcs(wcs)
      this.busy = true
      try {
        await this.sendCode(`M98 P"nxt-wcs-clear.g" W${wcs}`)
        this.$store.dispatch('machine/showMessage', {
          type: 'success',
          message: this.$t('plugins.nxt.panels.workplaceOrigins.cleared', [label]).toString()
        })
      } catch (error) {
        this.$store.dispatch('machine/showMessage', {
          type: 'error',
          message: `${this.$t('plugins.nxt.panels.workplaceOrigins.clearFailed').toString()}: ${error}`
        })
      } finally {
        this.busy = false
      }
    }
  }
})
</script>

<style scoped>
.nxt-wcs-cell {
  max-width: 7.5rem;
  min-width: 5.5rem;
}
.nxt-wcs-table :deep(tr.nxt-wcs-row--selected) {
  background: rgba(var(--v-theme-primary), 0.08);
}
.nxt-wcs-table :deep(tr.nxt-wcs-row--active td:first-child) {
  font-weight: 600;
}
</style>
