/**
 * Base Components
 *
 * BaseComponent is never rendered directly (it's the Options API mixin every nxt panel
 * extends via `defineNxtComponent`), so it has nothing to globally register - just re-exported
 * for convenience.
 */

import BaseComponent, { defineNxtComponent } from './BaseComponent.vue'

export { BaseComponent, defineNxtComponent }
export default BaseComponent