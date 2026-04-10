<template>
  <!-- Custom MessageBoxDialog that provides conditional rendering -->
  <!-- When NeXT UI is ready, render nothing (persistent display handled by ActionConfirmationWidget) -->
  <!-- Otherwise, fall back to standard modal dialog -->
  <div v-if="shouldShowModal">
    <!-- Standard modal dialog fallback -->
    <v-dialog 
      :value="hasMessage" 
      persistent 
      max-width="500"
      :retain-focus="false"
    >
      <v-card>
        <v-card-title v-if="messageBox.title">
          {{ messageBox.title }}
        </v-card-title>
        
        <v-card-text>
          <div class="text-body-1">{{ messageBox.message }}</div>
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
import Vue from 'vue'
import { readFirmwareGlobal } from '../../utils/nxtToolChangerOm'

/**
 * NeXT MessageBoxDialog Override
 *
 * When NeXT firmware has booted (`nxtLoaded`), non-critical M291 traffic can stay off the
 * blocking modal (persistent UI handles it). If NeXT globals are not loaded, or the message
 * looks critical, show the standard modal.
 */
export default Vue.extend({
  name: 'MessageBoxDialog',
  
  computed: {
    /**
     * Get the current message box from the store
     */
    messageBox(): any {
      return this.$store.state.machine.model.messageBox || {}
    },

    /**
     * Check if there's an active message
     */
    hasMessage(): boolean {
      return !!(this.messageBox && this.messageBox.message)
    },

    /** NeXT macros/vars loaded and boot succeeded — safe to defer non-critical dialogs. */
    nxtFirmwareReady(): boolean {
      const g = this.$store.state.machine.model.global
      const v = readFirmwareGlobal(g, 'nxtLoaded')
      return v === true || v === 1
    },

    /**
     * Determine if we should show the modal dialog
     * Show modal when:
     * - NeXT firmware is not in a loaded state (fallback)
     * - Message is marked as critical
     * - Message contains specific critical keywords
     */
    shouldShowModal(): boolean {
      if (!this.hasMessage) return false
      
      if (!this.nxtFirmwareReady) return true
      
      // Check for critical message indicators
      const message = (this.messageBox.message || '').toLowerCase()
      const title = (this.messageBox.title || '').toLowerCase()
      
      // Show modal for critical/emergency messages
      const criticalKeywords = ['emergency', 'error', 'fault', 'alarm', 'critical', 'warning']
      const isCritical = criticalKeywords.some(keyword => 
        message.includes(keyword) || title.includes(keyword)
      )
      
      return isCritical
    },

    /**
     * Get dialog buttons based on message box mode
     */
    dialogButtons(): string[] {
      const messageBox = this.messageBox
      if (!messageBox) return ['OK']
      
      // Handle different M291 dialog types
      switch (messageBox.mode) {
        case 0: // Close dialog
          return []
        case 1: // OK button
          return ['OK']
        case 2: // OK/Cancel buttons
          return ['OK', 'Cancel']
        case 3: // Yes/No buttons
          return ['Yes', 'No']
        case 4: // Yes/No/Cancel buttons
          return ['Yes', 'No', 'Cancel']
        default:
          // Handle custom button labels if provided
          if (messageBox.choices && Array.isArray(messageBox.choices)) {
            return messageBox.choices
          }
          return ['OK']
      }
    }
  },

  methods: {
    getButtonColor(button: string, index: number): string {
      const lowerButton = button.toLowerCase()
      
      // Primary action (usually first button)
      if (index === 0) {
        if (lowerButton.includes('cancel') || lowerButton.includes('abort')) {
          return 'error'
        }
        return 'primary'
      }
      
      // Secondary actions
      if (lowerButton.includes('cancel') || lowerButton.includes('abort')) {
        return 'error'
      }
      if (lowerButton.includes('ok') || lowerButton.includes('yes')) {
        return 'success'
      }
      
      return 'default'
    },

    async respondToDialog(buttonIndex: number): Promise<void> {
      try {
        // Send M292 response to the message box
        await this.$store.dispatch('machine/sendCode', `M292 P${buttonIndex}`)
        console.log(`NeXT UI: MessageBoxDialog response sent: ${buttonIndex}`)
      } catch (error) {
        console.error('NeXT UI: Failed to send dialog response:', error)
      }
    }
  },

  mounted() {
    console.log('NeXT UI: MessageBoxDialog override loaded')
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