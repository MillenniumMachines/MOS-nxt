<template>
  <div v-if="classification" class="mt-3">
    <v-alert
      :type="classification.kind === 'mixed' ? 'warning' : 'success'"
      density="compact"
      variant="outlined"
      class="mb-2"
    >
      {{ classification.summary }}
    </v-alert>
    <v-table density="compact" class="mb-2">
      <thead>
        <tr>
          <th>{{ $t('plugins.nxt.panels.calibration.travelCmd') }}</th>
          <th>{{ $t('plugins.nxt.panels.calibration.travelMeas') }}</th>
          <th>{{ $t('plugins.nxt.panels.calibration.travelErr') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(leg, i) in legs" :key="'cal-travel-leg-' + i">
          <td>{{ leg.commanded.toFixed(3) }}</td>
          <td>{{ leg.measured.toFixed(4) }}</td>
          <td>{{ (leg.measured - leg.commanded).toFixed(4) }}</td>
        </tr>
      </tbody>
    </v-table>
    <div class="d-flex flex-wrap ga-2">
      <v-btn
        size="small"
        color="primary"
        variant="outlined"
        :disabled="applyDisabled"
        @click="$emit('apply-backlash')"
      >
        {{ $t('plugins.nxt.panels.calibration.applyTravelBacklash') }}
      </v-btn>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent, type PropType } from 'vue'
import type { TravelClassification, TravelLeg } from '../../utils/nxtCalibrationMath'

export default defineComponent({
  name: 'CalTravelResults',
  props: {
    legs: {
      type: Array as PropType<TravelLeg[]>,
      required: true
    },
    classification: {
      type: Object as PropType<TravelClassification | null>,
      default: null
    },
    applyDisabled: {
      type: Boolean,
      default: false
    }
  },
  emits: ['apply-backlash']
})
</script>
