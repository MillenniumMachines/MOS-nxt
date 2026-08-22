/**
 * dwcStore.ts — Vuex-compatible shim for DWC 3.7 (Pinia + Composition API).
 *
 * DWC 3.6 exposed a Vuex store (`@/store`) with `store.state.machine.model`,
 * `store.getters["isConnected"]`, `store.dispatch("machine/...")` etc. nxt's UI (Options API
 * components ported from that era) still calls those exact shapes. DWC 3.7 replaced Vuex with
 * Pinia stores (`useMachineStore`, `useSettingsStore`, `useUiStore`), so rather than rewriting
 * every panel's computed/methods in one pass, this module re-creates the old Vuex-shaped surface
 * on top of the new stores. Existing Options API code (`this.$store.state.machine.model.move.axes`,
 * `this.$store.dispatch('machine/sendCode', code)`, ...) keeps working unmodified.
 *
 * `@/stores/*` resolves to `window.DWC` at build time for the external plugin bundle (see
 * DuetWebControl/scripts/build-plugin.js PLUGIN_GLOBALS / external() regex), so this shim compiles
 * against DWC's real Pinia stores and keeps working once loaded into a live DWC 3.7 instance.
 */
import type { ComponentCustomProperties } from "vue";
import { useMachineStore } from "@/stores/machine";
import { useSettingsStore } from "@/stores/settings";
import { useUiStore, LogLevel } from "@/stores/ui";

export { LogLevel };

function machineStore() {
	return useMachineStore();
}

function settingsStore() {
	return useSettingsStore();
}

function uiStore() {
	return useUiStore();
}

/**
 * DWC 3.6's `machine/settings` Vuex module held `displayedAxes` (indices into `move.axes`) and
 * `spindleRPM` / `moveSteps` presets. In 3.7 the axis-visibility presets moved to per-component
 * settings (`useComponentSettings`) and the remaining presets live on the settings Pinia store.
 * nxt only ever reads `displayedAxes` to count/enumerate *visible* axes, so that's reconstructed
 * here directly from the object model's own `axis.visible` flag instead of a settings preset -
 * behaviourally equivalent for nxt's use (it never lets a user hide/reorder axes independently).
 */
function buildMachineSettingsShim() {
	return {
		get spindleRPM(): Array<number> {
			return settingsStore().spindleRPM;
		},
		get moveSteps(): Record<string, Array<number>> {
			return settingsStore().moveSteps;
		},
		get displayedAxes(): Array<number> {
			const axes = machineStore().model.move.axes;
			const visible: Array<number> = [];
			for (let i = 0; i < axes.length; i++) {
				if (axes[i]?.visible) {
					visible.push(i);
				}
			}
			return visible;
		}
	};
}

function buildMachineStateShim() {
	return {
		get model() {
			return machineStore().model;
		},
		get settings() {
			return buildMachineSettingsShim();
		}
	};
}

function buildSettingsStateShim() {
	return {
		get plugins(): Record<string, any> {
			return settingsStore().plugins;
		}
	};
}

/**
 * Map a Vuex-era `showMessage({ type })` string ("error" | "warning" | "success" | "info") onto
 * {@link LogLevel}. The string literals already match the enum's runtime values; this only exists
 * so callers can pass a plain string without importing LogLevel themselves.
 */
function toLogLevel(type: unknown): LogLevel {
	if (typeof type === "string" && (Object.values(LogLevel) as Array<string>).includes(type)) {
		return type as LogLevel;
	}
	return LogLevel.info;
}

export interface DwcCompatStore {
	getters: { readonly isConnected: boolean };
	state: {
		machine: ReturnType<typeof buildMachineStateShim>;
		settings: ReturnType<typeof buildSettingsStateShim>;
	};
	dispatch(action: string, payload?: any): Promise<any>;
	subscribe(callback: (mutation: { type: string; payload?: any }) => void): () => void;
}

const store: DwcCompatStore = {
	get getters() {
		return {
			get isConnected(): boolean {
				return machineStore().isConnected;
			}
		};
	},

	get state() {
		return {
			get machine() {
				return buildMachineStateShim();
			},
			get settings() {
				return buildSettingsStateShim();
			}
		} as unknown as DwcCompatStore["state"];
	},

	async dispatch(action: string, payload?: any): Promise<any> {
		switch (action) {
			case "machine/sendCode": {
				// String (legacy) or { code, noWait?, fromInput?, logReply? } for M292 / fire-and-forget
				if (payload != null && typeof payload === "object" && typeof payload.code === "string") {
					const fromInput = payload.fromInput === true;
					const logReply = payload.logReply !== false;
					const noWait = payload.noWait === true;
					return await machineStore().sendCode(payload.code, fromInput, logReply, noWait);
				}
				return await machineStore().sendCode(payload as string);
			}

			case "machine/showMessage": {
				const { type, message, title } = payload ?? {};
				return uiStore().makeNotification(toLogLevel(type), title || "nxt", message ?? null);
			}

			case "machine/upload": {
				const { filename, content, showProgress, showSuccess, showError } = payload ?? {};
				return await machineStore().upload({ filename, content }, showProgress, showSuccess, showError);
			}

			case "machine/delete": {
				const filename = typeof payload === "string" ? payload : payload?.filename;
				return await machineStore().delete(filename);
			}

			case "machine/download": {
				const { filename, type, showProgress, showSuccess, showError } =
					typeof payload === "string" ? { filename: payload, type: undefined, showProgress: undefined, showSuccess: undefined, showError: undefined } : (payload ?? {});
				return await machineStore().download({ filename, type }, showProgress, showSuccess, showError);
			}

			case "machine/getFileList":
				return await machineStore().getFileList(payload as string);

			default:
				console.warn(`[nxt] dwcStore.dispatch: unsupported action "${action}"`);
				return undefined;
		}
	},

	/**
	 * Vuex's `store.subscribe` fired on every mutation; nxt's only caller (ActionConfirmationWidget)
	 * used it purely for a console.log side-effect, never to drive reactive state. Pinia has no
	 * matching global mutation feed (only per-store `$subscribe`/`$onAction`), so this is a
	 * best-effort no-op that keeps the call site working without silently throwing. Returns an
	 * unsubscribe function to match Vuex's signature
	 */
	subscribe(_callback: (mutation: { type: string; payload?: any }) => void): () => void {
		return () => {};
	}
};

export default store;

/**
 * Back-compat for the old `PluginDataType.globalSetting` enum. DWC 3.7's settings store has a
 * single flat `registerPluginData` / `setPluginData` API (no data-type distinction), so this is
 * kept only so call sites don't need to change their call shape
 */
export const PluginDataType = {
	globalSetting: "globalSetting"
} as const;

export function registerPluginData(plugin: string, _type: string, key: string, defaultValue: any): void {
	settingsStore().registerPluginData(plugin, key, defaultValue);
}

export function setPluginData(plugin: string, _type: string, key: string, value: any): void {
	settingsStore().setPluginData(plugin, key, value);
}

// Lets Options API components declare `this.$store` (installed by BaseComponent's `beforeCreate`)
// without every file needing its own module augmentation
declare module "vue" {
	interface ComponentCustomProperties {
		$store: DwcCompatStore;
	}
}
export type { ComponentCustomProperties };
