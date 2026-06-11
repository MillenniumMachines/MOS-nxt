/**
 * Base Components Registration
 * 
 * Registers base components for nxt UI
 */

import Vue from 'vue'
import BaseComponent from './BaseComponent.vue'

// Register base component (though it's not typically used directly)
Vue.component('nxt-base-component', BaseComponent)

export { BaseComponent }
export default BaseComponent