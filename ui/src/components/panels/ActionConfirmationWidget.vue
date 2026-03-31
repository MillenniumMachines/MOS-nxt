<template>
  <v-card class="nxt-action-widget" :class="{ 'elevation-8': hasActiveDialog }">
    <v-card-title class="py-2">
      <v-icon left small>mdi-check-circle</v-icon>
      Action Required
    </v-card-title>
    
    <!-- Active Dialog Display -->
    <v-card-text class="py-2">
      <div class="dialog-container">
        <div class="dialog-title">{{ dialogTitle }}</div>
        <div class="dialog-message">{{ dialogMessage }}</div>
        
        <v-divider class="my-3" />
        
        <div class="dialog-actions">
          <v-btn
            v-for="(button, index) in dialogButtons"
            :key="index"
            :color="getButtonColor(button, index)"
            :outlined="index !== 0"
            small
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
import BaseComponent from '../base/BaseComponent.vue'

/**
 * NeXT Action Confirmation Widget
 * 
 * Displays persistent dialog interface for M291 dialogs.
 * Intercepts M291 dialogs from the DWC object model and displays them
 * in a non-blocking persistent panel instead of modal dialogs.
 */
export default BaseComponent.extend({
  name: 'NxtActionConfirmationWidget',
  
  computed: {
    /**
     * Get active message box from DWC object model
     */
    activeMessageBox(): any {
      const messageBox = this.$store.state.machine.model.messageBox
      return messageBox && messageBox.message ? messageBox : null
    },

    hasActiveDialog(): boolean {
      return this.activeMessageBox !== null
    },

    dialogMessage(): string {
      return this.activeMessageBox?.message || ''
    },

    dialogTitle(): string {
      return this.activeMessageBox?.title || 'NeXT'
    },

    dialogButtons(): string[] {
      const messageBox = this.activeMessageBox
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
      if (lowerButton.includes('continue') || lowerButton.includes('ok') || lowerButton.includes('yes')) {
        return 'success'
      }
      
      return 'default'
    },

    async respondToDialog(buttonIndex: number): Promise<void> {
      const messageBox = this.activeMessageBox
      if (!messageBox) return

      try {
        // Send M292 response to the message box
        // M292 P<response> where response is the button index (0-based)
        await this.sendCode(`M292 P${buttonIndex}`)
        
        console.log(`NeXT UI: M291 dialog response sent: ${buttonIndex}`)
      } catch (error) {
        console.error('NeXT UI: Failed to send M291 dialog response:', error)
        this.$store.dispatch('machine/showMessage', {
          type: 'error',
          message: 'Failed to send dialog response'
        })
      }
    }
  },

  mounted() {
    // Listen for message box changes from RRF object model
    this.$store.subscribe((mutation: any) => {
      if (mutation.type === 'machine/model/update') {
        // React to message box changes
        const messageBox = mutation.payload.messageBox
        if (messageBox !== undefined) {
          console.log('NeXT UI: Message box state changed:', messageBox)
        }
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

/* Responsive adjustments */
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