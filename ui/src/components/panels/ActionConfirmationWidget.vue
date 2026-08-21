<template>
  <v-card class="nxt-action-widget" :class="{ 'elevation-8': hasActiveDialog }">
    <v-card-title class="py-2">
      <v-icon class="mr-2" size="small">mdi-check-circle</v-icon>
      Action Required
    </v-card-title>
    
    <!-- Active Dialog Display -->
    <v-card-text class="py-2">
      <div class="dialog-container">
        <div class="dialog-title">{{ dialogTitle }}</div>
        <div class="dialog-message" v-html="dialogMessage"></div>
        
        <v-divider class="my-3" />
        
        <div class="dialog-actions">
          <v-btn
            v-for="(button, index) in dialogButtons"
            :key="index"
            :color="getButtonColor(button, index)"
            :variant="index !== 0 ? 'outlined' : 'flat'"
            size="small"
            class="mr-2 mb-2"
            @click="respondToDialog(index)"
          >
            {{ button }}
          </v-btn>
        </div>
      </div>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import { defineNxtComponent } from '../base/BaseComponent.vue'
import {
  nxtBuildM292Ack,
  nxtMessageBoxButtons,
  type NxtMessageBoxLike
} from '../../utils/nxtMessageBoxRespond'

/**
 * nxt Action Confirmation Widget
 *
 * Not mounted from nxt.vue (stock DWC MessageBoxDialog is the sole M292 ack path).
 * Kept for a future DWC override hook. Do not remount beside the stock modal.
 */
export default defineNxtComponent({
  name: 'NxtActionConfirmationWidget',
  
  computed: {
    activeMessageBox(): NxtMessageBoxLike | null {
      const messageBox = this.$store.state.machine.model.state.messageBox as NxtMessageBoxLike | null | undefined
      if (messageBox == null || !messageBox.message) {
        return null
      }
      return messageBox
    },

    hasActiveDialog(): boolean {
      return this.activeMessageBox !== null
    },

    dialogMessage(): string {
      return this.activeMessageBox?.message || ''
    },

    dialogTitle(): string {
      return this.activeMessageBox?.title || 'nxt'
    },

    dialogButtons(): string[] {
      return nxtMessageBoxButtons(this.activeMessageBox)
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
        lowerButton.includes('continue') ||
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
      const messageBox = this.activeMessageBox
      if (!messageBox) return

      try {
        const code = nxtBuildM292Ack(messageBox, buttonIndex)
        await this.sendCode(code)
        console.log(`nxt UI: M291 dialog response sent: ${code}`)
      } catch (error) {
        console.error('nxt UI: Failed to send M291 dialog response:', error)
        this.$store.dispatch('machine/showMessage', {
          type: 'error',
          title: 'nxt',
          message: 'Failed to send dialog response'
        })
      }
    }
  },

  mounted() {
    this.$store.subscribe(() => {
      if (this.activeMessageBox) {
        console.log('nxt UI: Message box state changed:', this.activeMessageBox)
      }
    })
  }
})
</script>

<style scoped>
.nxt-action-widget {
  transition: box-shadow 0.3s ease;
}

.nxt-action-widget.elevation-8 {
  border-left: 4px solid var(--v-primary-base);
}

.dialog-container {
  min-height: 80px;
}

.dialog-title {
  font-size: 1rem;
  font-weight: 600;
  color: var(--v-primary-base);
  margin-bottom: 8px;
}

.dialog-message {
  font-size: 0.9rem;
  line-height: 1.4;
  margin-bottom: 12px;
  white-space: pre-wrap;
  word-wrap: break-word;
}

.dialog-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-start;
}

.v-card-title {
  font-size: 0.875rem !important;
  background-color: rgba(0, 0, 0, 0.03);
}

.v-card-text {
  padding-top: 12px !important;
  padding-bottom: 12px !important;
}

@media (max-width: 600px) {
  .dialog-actions {
    justify-content: center;
  }
  
  .dialog-actions .v-btn {
    margin: 2px;
    min-width: 80px;
  }
}
</style>
