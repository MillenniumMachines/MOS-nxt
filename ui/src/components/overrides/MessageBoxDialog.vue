<template>
  <!-- Custom MessageBoxDialog that provides conditional rendering -->
  <!-- When nxt UI is ready, render nothing (persistent display handled by ActionConfirmationWidget) -->
  <!-- Otherwise, fall back to standard modal dialog -->
  <div v-if="shouldShowModal">
    <v-dialog
      :model-value="hasMessage"
      persistent
      max-width="500"
    >
      <v-card>
        <v-card-title v-if="messageBox.title">
          {{ messageBox.title }}
        </v-card-title>

        <v-card-text>
          <div class="text-body-1" v-html="messageBox.message"></div>
        </v-card-text>

        <v-card-actions>
          <v-spacer />
          <v-btn
            v-for="(button, index) in dialogButtons"
            :key="index"
            :color="getButtonColor(button, index)"
            @click="respondToDialog(index)"
          >
            {{ button }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import store from '../../compat/dwcStore'
import { readFirmwareGlobal } from '../../utils/nxtToolChangerOm'
import {
  nxtBuildM292Ack,
  nxtMessageBoxButtons,
  type NxtMessageBoxLike
} from '../../utils/nxtMessageBoxRespond'

/**
 * nxt MessageBoxDialog Override (not active under DWC 3.7 Vue 3)
 *
 * Stock DWC App.vue binds its own MessageBoxDialog at compile time, so this file does not
 * replace the modal. Kept compiled for a future DWC override hook. Operator ack is stock
 * DWC only — nxt dashboard must not also send M292 (see nxt.vue).
 *
 * Ack helper: nxtMessageBoxRespond (M292 S{seq} for S2/S3; R{n} S{seq} for S4).
 */
export default defineComponent({
  name: 'MessageBoxDialog',

  computed: {
    messageBox(): NxtMessageBoxLike {
      return (store.state.machine.model.state.messageBox || {}) as NxtMessageBoxLike
    },

    hasMessage(): boolean {
      return !!(this.messageBox && this.messageBox.message)
    },

    nxtFirmwareReady(): boolean {
      const g = store.state.machine.model.global
      const v = readFirmwareGlobal(g, 'nxtLoaded')
      return v === true || v === 1
    },

    shouldShowModal(): boolean {
      if (!this.hasMessage) return false

      if (!this.nxtFirmwareReady) return true

      const message = (this.messageBox.message || '').toLowerCase()
      const title = (this.messageBox.title || '').toLowerCase()

      const criticalKeywords = ['emergency', 'error', 'fault', 'alarm', 'critical', 'warning']
      const isCritical = criticalKeywords.some(
        (keyword: string) => message.includes(keyword) || title.includes(keyword)
      )

      return isCritical
    },

    dialogButtons(): string[] {
      return nxtMessageBoxButtons(this.messageBox)
    }
  },

  methods: {
    getButtonColor(button: string, index: number): string {
      const lowerButton = button.toLowerCase()

      if (index === 0) {
        if (lowerButton.includes('cancel') || lowerButton.includes('abort') || lowerButton.includes('leave')) {
          return 'error'
        }
        return 'primary'
      }

      if (lowerButton.includes('cancel') || lowerButton.includes('abort') || lowerButton.includes('leave')) {
        return 'error'
      }
      if (
        lowerButton.includes('ok') ||
        lowerButton.includes('yes') ||
        lowerButton.includes('activate') ||
        lowerButton.includes('arm')
      ) {
        return 'success'
      }

      return 'default'
    },

    async respondToDialog(buttonIndex: number): Promise<void> {
      try {
        const code = nxtBuildM292Ack(this.messageBox, buttonIndex)
        // noWait: standalone PollConnector must not await M292 reply-seq
        await store.dispatch('machine/sendCode', { code, noWait: true, logReply: false })
        console.log(`nxt UI: MessageBoxDialog response sent: ${code}`)
      } catch (error) {
        console.error('nxt UI: Failed to send dialog response:', error)
      }
    }
  },

  mounted() {
    console.log('nxt UI: MessageBoxDialog override loaded')
  }
})
</script>

<style scoped>
.v-card-title {
  font-weight: 600;
  color: var(--v-primary-base);
}

.v-card-text {
  padding-top: 16px !important;
}

.text-body-1 {
  line-height: 1.5;
  white-space: pre-wrap;
  word-wrap: break-word;
}
</style>
