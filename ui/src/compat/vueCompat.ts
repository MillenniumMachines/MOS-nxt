/**
 * vueCompat.ts — small Vue 3 helpers used while porting nxt's UI off Vue 2 APIs.
 *
 * `Vue.component(...)` (global registration off the Vue 2 constructor) and `Vue.extend(...)`
 * (component-options subclassing) have no equivalent on the Vue 3 module namespace - global
 * registration needs a live `app` instance, and `extends` moved to a plain `defineComponent`
 * option. This module re-exports the real Vue 3 API plus the two small helpers nxt needs to
 * keep the rest of its Options API code mostly unchanged.
 */
import { defineComponent, getCurrentInstance, type Component } from "vue";

export * from "vue";

/**
 * Components nxt has asked to register globally, keyed by tag name. Populated by
 * {@link registerGlobalComponent} regardless of whether a live `app` instance was available at
 * call time, so a caller (e.g. a diagnostic panel) can still enumerate what *should* be global
 */
const registeredComponents = new Map<string, Component>();

/**
 * Best-effort replacement for Vue 2's `Vue.component(name, component)`.
 *
 * External DWC plugins don't get a reference to the host `app` instance (`initPluginSystem`'s
 * `app` parameter is private to DWC core), so this only succeeds when called from inside a
 * component's setup/lifecycle (where `getCurrentInstance()` resolves the running app). nxt's own
 * components are imported locally wherever they're used as template tags (see `nxt.vue`'s
 * `components: {...}` map) specifically so global registration is never required for them to
 * render - this helper exists only for the rare case a plugin wants a tag name resolvable from
 * *outside* its own template tree (e.g. a DWC-side custom layout embedding an nxt widget by tag).
 *
 * @param name Tag name, e.g. "nxt-status-widget"
 * @param component Component definition
 */
export function registerGlobalComponent(name: string, component: Component): void {
	registeredComponents.set(name, component);
	const app = getCurrentInstance()?.appContext.app;
	if (app) {
		app.component(name, component);
	} else {
		console.warn(`[nxt] registerGlobalComponent("${name}"): no active app instance yet - component was recorded but not globally registered. Import it locally in the consuming component's "components" map instead.`);
	}
}

/**
 * Components registered via {@link registerGlobalComponent}, whether or not the global
 * registration itself succeeded
 */
export function getRegisteredComponents(): ReadonlyMap<string, Component> {
	return registeredComponents;
}

/**
 * Replacement for Vue 2's `BaseComponent.extend({ ... })`. Vue 3's Options API still supports
 * subclassing via the `extends` option on `defineComponent`, it just isn't exposed as a method on
 * the component definition the way `Vue.extend` was - so this wraps that pattern in the same call
 * shape nxt's existing panels already use (`BaseComponent.extend({...})` -> `extendComponent(BaseComponent, {...})`)
 *
 * @param base Base component definition to extend (e.g. nxt's `BaseComponent`)
 * @param options Component options to merge in (data/computed/methods/etc.)
 */
export function extendComponent(base: Component, options: Record<string, any>): Component {
	// `defineComponent`'s overloads can't resolve a generic `Component` passed to `extends` (that
	// typing only works when the base is a concrete `ComponentOptions` object at the call site) -
	// widen to `any` here so `base` and the merged options both accept structurally at the actual
	// call sites (`BaseComponent`, an object literal), which is what matters for consumers
	return defineComponent({ extends: base, ...options } as any);
}
