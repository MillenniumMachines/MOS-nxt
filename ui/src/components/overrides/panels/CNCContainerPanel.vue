<template>
	<div>
		<v-row align="stretch" dense>
			<!-- Status Information Panel (Left Column) -->
			<v-col cols="12" lg="4" md="5" sm="12" order="1">
				<v-card class="justify-center fill-height">
					<v-card-title class="py-2 font-weight-bold">
						{{ $t("panel.status.caption") }}
					</v-card-title>
					<v-card-text>
						<template v-if="isConnected && visibleAxes">
							<v-simple-table dense>
								<template v-slot:default>
									<tbody>
										<!-- Workplace (WCS) -->
										<tr>
											<td><strong>{{ $t("plugins.next.panels.status.workplace") }}</strong></td>
											<td align="right">
												<v-tooltip top>
													<template v-slot:activator="{ on, attrs }">
														<v-chip v-bind="attrs" v-on="on" label outlined small class="status-chip">
															<span class="pill-text">{{ currentWorkplaceGCode }}</span>
															<v-avatar right rounded :color="currentWorkplaceColor" class="ma-0">{{ currentWorkplace+1 }}</v-avatar>
														</v-chip>
													</template>
													<span>{{ currentWorkplaceTooltip }}</span>
												</v-tooltip>
											</td>
										</tr>

										<!-- Current Tool (always shown) -->
										<tr>
											<td><strong>{{ $t("plugins.next.panels.status.tool") }}</strong></td>
											<td align="right">
												<v-tooltip top>
													<template v-slot:activator="{ on, attrs }">
														<v-chip v-bind="attrs" v-on="on" label outlined small class="status-chip">
															<span class="pill-text">{{ toolNameShort || $t('plugins.next.panels.status.none') }}</span>
															<v-avatar right rounded :color="toolNumber !== null ? 'green' : 'grey'" class="ma-0">{{ toolNumber !== null ? toolNumber : '—' }}</v-avatar>
														</v-chip>
													</template>
													<span>{{ toolName || $t('plugins.next.panels.status.none') }}</span>
												</v-tooltip>
											</td>
										</tr>

										<!-- Tool Radius -->
										<tr v-if="toolRadius !== null">
											<td><strong>{{ $t("plugins.next.panels.status.toolRadius") }}</strong></td>
											<td align="right">
												<v-chip label outlined small class="status-chip">
													<span class="pill-text">{{ $display(toolRadius, 3, "mm") }}</span>
													<v-avatar right rounded color="primary" class="ma-0"><v-icon small>mdi-radius-outline</v-icon></v-avatar>
												</v-chip>
											</td>
										</tr>

										<!-- Tool Offset (Z) -->
										<tr v-if="toolOffset !== null">
											<td><strong>{{ $t("plugins.next.panels.status.toolOffset") }}</strong></td>
											<td align="right">
												<v-chip label outlined small class="status-chip">
													<span class="pill-text">{{ $display(toolOffset, 3, "mm") }}</span>
													<v-avatar right rounded color="primary" class="ma-0"><v-icon small>mdi-arrow-expand-vertical</v-icon></v-avatar>
												</v-chip>
											</td>
										</tr>

										<!-- Tool Role -->
										<tr v-if="loadedTool.role !== 'none'">
											<td><strong>{{ $t("plugins.next.panels.status.toolRole") }}</strong></td>
											<td align="right">
												<v-chip x-small :color="loadedToolRoleColor" text-color="white" label>
													{{ loadedToolRoleText }}
												</v-chip>
											</td>
										</tr>

										<!-- Tool Flutes -->
										<tr v-if="loadedTool.fluteCount !== null">
											<td><strong>{{ $t("plugins.next.panels.status.toolFlutes") }}</strong></td>
											<td align="right">
												<v-chip label outlined small class="status-chip">
													<span class="pill-text">{{ loadedTool.fluteCount }}</span>
													<v-avatar right rounded color="primary" class="ma-0"><v-icon small>mdi-format-list-numbered</v-icon></v-avatar>
												</v-chip>
											</td>
										</tr>

										<!-- Tool Flute Length -->
										<tr v-if="loadedTool.fluteLengthMm !== null">
											<td><strong>{{ $t("plugins.next.panels.status.toolFluteLength") }}</strong></td>
											<td align="right">
												<v-chip label outlined small class="status-chip">
													<span class="pill-text">{{ $display(loadedTool.fluteLengthMm, 3, "mm") }}</span>
													<v-avatar right rounded color="primary" class="ma-0"><v-icon small>mdi-ruler</v-icon></v-avatar>
												</v-chip>
											</td>
										</tr>

										<!-- Spindle Status -->
										<tr v-if="activeSpindle !== null">
											<td><strong>{{ $t("plugins.next.panels.status.spindle") }}</strong></td>
											<td align="right">
												<v-chip label outlined small class="status-chip">
													<span class="pill-text">{{ spindleStateText }}</span>
													<v-avatar right rounded :color="spindleStateColor" class="ma-0">
														<v-icon small>{{ spindleStateIcon }}</v-icon>
													</v-avatar>
												</v-chip>
											</td>
										</tr>

										<!-- Spindle RPM (when running) -->
										<tr v-if="activeSpindle !== null && spindleRPM !== null">
											<td><strong>{{ $t("plugins.next.panels.status.spindleRPM") }}</strong></td>
											<td align="right">
												<v-chip label outlined small class="status-chip">
													<span class="pill-text">{{ spindleRPM }} RPM</span>
													<v-avatar right rounded color="primary" class="ma-0"><v-icon small>mdi-rotate-right</v-icon></v-avatar>
												</v-chip>
											</td>
										</tr>

										<!-- Touch Probe -->
										<tr>
											<td><strong>{{ $t("plugins.next.panels.status.touchProbe") }}</strong></td>
											<td align="right">
												<v-chip label outlined small class="status-chip">
													<span class="pill-text">{{ touchProbeStatusText }}</span>
													<v-avatar right rounded :color="touchProbeStatusColor" class="ma-0">
														<v-icon small>{{ touchProbeStatusIcon }}</v-icon>
													</v-avatar>
												</v-chip>
											</td>
										</tr>

										<!-- Tool Setter -->
										<tr>
											<td><strong>{{ $t("plugins.next.panels.status.toolsetter") }}</strong></td>
											<td align="right">
												<v-chip label outlined small class="status-chip">
													<span class="pill-text">{{ toolsetterStatusText }}</span>
													<v-avatar right rounded :color="toolsetterStatusColor" class="ma-0">
														<v-icon small>{{ toolsetterStatusIcon }}</v-icon>
													</v-avatar>
												</v-chip>
											</td>
										</tr>

										<!-- Rotation Compensation (when active) -->
										<tr v-if="rotationCompensation !== 0">
											<td><strong>{{ $t("plugins.next.panels.status.rotation") }}</strong></td>
											<td align="right">
												<v-chip label outlined small class="status-chip">
													<span class="pill-text">{{ $display(rotationCompensation, 3, "°") }}</span>
													<v-avatar right rounded color="warning" class="ma-0"><v-icon small>mdi-rotate-3d-variant</v-icon></v-avatar>
												</v-chip>
											</td>
										</tr>
									</tbody>
								</template>
							</v-simple-table>
						</template>

						<!-- Disconnected State -->
						<template v-else>
							<v-alert type="info" dense text>
								<v-icon left>mdi-lan-disconnect</v-icon>
								{{ $t("plugins.next.panels.status.disconnected") }}
							</v-alert>
						</template>
					</v-card-text>
				</v-card>
			</v-col>

			<!-- Main Content Area (Right Column) -->
			<v-col cols="12" lg="8" md="7" sm="12" order="2">
				<v-row align="stretch" class="fill-height">
					<!-- Machine Position Display -->
					<v-col cols="12">
						<v-card class="fill-height">
							<v-card-title class="py-2 font-weight-bold">
								{{ toolPositionCaption }}
							</v-card-title>
							<v-card-text v-if="isConnected">
								<v-simple-table dense>
									<template v-slot:default>
										<thead>
											<tr>
												<th>Axis</th>
												<th align="right">Workplace</th>
												<th align="right">Machine</th>
											</tr>
										</thead>
										<tbody>
											<tr v-for="axis in visibleAxes" :key="axis.letter">
												<td>
													<v-chip small :color="axis.homed ? 'success' : 'grey'" class="px-2 white--text rounded-0">{{ axis.letter }}</v-chip>
												</td>
												<td align="right">{{ $display(axis.userPosition, 3, "mm") }}</td>
												<td align="right">{{ $display(axis.machinePosition, 3, "mm") }}</td>
											</tr>
										</tbody>
									</template>
								</v-simple-table>
							</v-card-text>
							<v-card-text v-else>
								<v-alert type="info" dense text>
									<v-icon left>mdi-lan-disconnect</v-icon>
									{{ $t('plugins.next.panels.status.disconnected') }}
								</v-alert>
							</v-card-text>
						</v-card>
					</v-col>

					<!-- RGB work light -->
					<v-col cols="12" v-if="rgbHardwareConfigured">
						<nxt-rgb-light-control compact />
					</v-col>

					<!-- Spindle control (spindle 0 only) -->
					<v-col cols="12" v-if="isConnected">
						<nxt-spindle0-control-panel />
					</v-col>
				</v-row>
			</v-col>
		</v-row>
	</div>
</template>

<script lang="ts">
// @ts-nocheck — Vue 2 + BaseComponent.extend(): tsc does not merge computeds onto `this`.
import BaseComponent from "../../base/BaseComponent.vue";
import { Probe, Axis, Spindle, SpindleState } from "@duet3d/objectmodel";
import store from "@/store";
import { readFirmwareGlobal } from "../../../utils/nxtToolChangerOm";
import { buildLoadedToolStatus } from "../../../utils/nxtLoadedToolStatus";
import { isRgbLightHardwareConfigured, readOmLedsFromMachineModel } from "../../../utils/nxtRgbAvailability";

const enum WorkplaceSet {
	NONE,
	SOME,
	ALL
}

export default BaseComponent.extend({
	name: 'CNCContainerPanel',

	computed: {
		// Title helpers
		toolPositionCaption(): string {
			const key = 'panel.tools.toolPosition';
			const translated = (this as any).$t(key).toString();
			return translated === key ? 'Tool Position' : translated;
		},

		status(): string { 
			return store.state.machine.model.state.status; 
		},

		// Visible axes helper
		visibleAxes(): Array<Axis> {
			return store.state.machine.model.move.axes.filter((axis: Axis) => axis.visible);
		},

		// Workplace (WCS) information
		currentWorkplaceGCode(): string {
			return `G${53 + store.state.machine.model.move.workplaceNumber + 1}`;
		},

		currentWorkplaceValid(): WorkplaceSet {
			const axes = store.state.machine.model.move.axes.filter((axis: Axis) => axis.visible);
			const workplace = store.state.machine.model.move.workplaceNumber;
			const offsets = axes.map((axis: Axis) => axis.workplaceOffsets[workplace]);

			if (offsets.every((offset: number) => offset !== 0)) {
				return WorkplaceSet.ALL;
			}

			return offsets.some((offset: number) => offset !== 0) ? WorkplaceSet.SOME : WorkplaceSet.NONE;
		},

		currentWorkplaceColor(): string {
			const valid = this.currentWorkplaceValid as any as WorkplaceSet;
			switch(valid) {
				case WorkplaceSet.ALL:
					return 'success';
				case WorkplaceSet.SOME:
					return 'warning';
				default:
					return 'grey';
			}
		},

		currentWorkplaceTooltip(): string {
			const translations = {
				[WorkplaceSet.ALL]: 'plugins.next.panels.status.workplaceValid',
				[WorkplaceSet.SOME]: 'plugins.next.panels.status.workplacePartial',
				[WorkplaceSet.NONE]: 'plugins.next.panels.status.workplaceInvalid'
			};
			const valid = this.currentWorkplaceValid as any as WorkplaceSet;
			const gcode = this.currentWorkplaceGCode as any as string;
			return (this as any).$t(translations[valid], [gcode]).toString();
		},

		// Tool information
		toolNumber(): number | null {
			const t = store.state.machine.model.state.currentTool ?? -1;
			return t < 0 ? null : t;
		},

		loadedTool() {
			const model = store.state.machine.model;
			const idx = model.state.currentTool ?? -1;
			return buildLoadedToolStatus(model.tools, idx, model.global);
		},

		toolName(): string | null {
			return this.loadedTool.name;
		},

		toolNameShort(): string {
			return this.loadedTool.nameShort;
		},

		toolRadius(): number | null {
			return this.loadedTool.radiusMm;
		},

		toolOffset(): number | null {
			return this.loadedTool.zOffset;
		},

		loadedToolRoleText(): string {
			const role = this.loadedTool.role;
			if (role === 'probe') {
				return (this as any).$t('plugins.next.panels.toolManagement.statusProbe').toString();
			}
			if (role === 'spindle') {
				return (this as any).$t('plugins.next.panels.toolManagement.statusInSpindle').toString();
			}
			return (this as any).$t('plugins.next.panels.status.none').toString();
		},

		loadedToolRoleColor(): string {
			const role = this.loadedTool.role;
			if (role === 'probe') {
				return 'deep-purple';
			}
			if (role === 'spindle') {
				return 'success';
			}
			return 'grey';
		},

		rgbHardwareConfigured(): boolean {
			const g = store.state.machine.model.global;
			const override = readFirmwareGlobal(g, 'nxtBoardShortNameOverride');
			const boardShortName =
				override != null && String(override).trim().length > 0
					? String(override).trim()
					: store.state.machine.model.boards?.[0]?.shortName ?? null;
			return isRgbLightHardwareConfigured({
				leds: readOmLedsFromMachineModel(store.state.machine.model),
				boardShortName: boardShortName != null ? String(boardShortName) : null
			});
		},

		// Spindle information
		activeSpindle(): Spindle | null {
			const spindles = store.state.machine.model.spindles;
			if (!spindles || spindles.length === 0) return null;
			// Get the first spindle (typically spindle 0)
			return spindles[0];
		},

		spindleStateText(): string {
			const spindle = this.activeSpindle as Spindle | null;
			if (!spindle) return '';
			
			switch (spindle.state) {
				case SpindleState.forward:
					return (this as any).$t('plugins.next.panels.status.spindleForward').toString();
				case SpindleState.reverse:
					return (this as any).$t('plugins.next.panels.status.spindleReverse').toString();
				case SpindleState.stopped:
					return (this as any).$t('plugins.next.panels.status.spindleStopped').toString();
				default:
					return (this as any).$t('plugins.next.panels.status.spindleUnconfigured').toString();
			}
		},

		spindleStateColor(): string {
			const spindle = this.activeSpindle as Spindle | null;
			if (!spindle) return 'grey';
			
			switch (spindle.state) {
				case SpindleState.forward:
					return 'green';
				case SpindleState.reverse:
					return 'orange';
				case SpindleState.stopped:
					return 'grey';
				default:
					return 'grey';
			}
		},

		spindleStateIcon(): string {
			const spindle = this.activeSpindle as Spindle | null;
			if (!spindle) return 'mdi-fan-off';
			
			switch (spindle.state) {
				case SpindleState.forward:
					return 'mdi-rotate-right';
				case SpindleState.reverse:
					return 'mdi-rotate-left';
				case SpindleState.stopped:
					return 'mdi-fan-off';
				default:
					return 'mdi-help-circle';
			}
		},

		spindleRPM(): number | null {
			const spindle = this.activeSpindle as Spindle | null;
			if (!spindle) return null;
			if (spindle.state === SpindleState.stopped || 
			    spindle.state === SpindleState.unconfigured) {
				return null;
			}
			return spindle.current;
		},

		// Probe information
		touchProbeEnabled(): boolean {
			const feat = readFirmwareGlobal(store.state.machine.model.global, 'nxtFeatureTouchProbe');
			const legacyFeat = readFirmwareGlobal(store.state.machine.model.global, 'nxtFeatTouchProbe');
			const enabled = feat === true || feat === 1 || legacyFeat === true || legacyFeat === 1;
			const id =
				readFirmwareGlobal(store.state.machine.model.global, 'nxtTouchProbeID') ??
				readFirmwareGlobal(store.state.machine.model.global, 'nxtTPID');
			return enabled && id !== null && id !== undefined;
		},

		toolsetterEnabled(): boolean {
			const feat = readFirmwareGlobal(store.state.machine.model.global, 'nxtFeatureToolSetter');
			const legacyFeat = readFirmwareGlobal(store.state.machine.model.global, 'nxtFeatToolSetter');
			const enabled = feat === true || feat === 1 || legacyFeat === true || legacyFeat === 1;
			const id =
				readFirmwareGlobal(store.state.machine.model.global, 'nxtToolSetterID') ??
				readFirmwareGlobal(store.state.machine.model.global, 'nxtTSID');
			return enabled && id !== null && id !== undefined;
		},

		touchProbe(): Probe | null {
			const raw =
				readFirmwareGlobal(store.state.machine.model.global, 'nxtTouchProbeID') ??
				readFirmwareGlobal(store.state.machine.model.global, 'nxtTPID');
			const nxtTPID = typeof raw === 'number' ? raw : null;
			if (nxtTPID === null) return null;
			const p = store.state.machine.model.sensors.probes.at(nxtTPID);
			return p ? p : null;
		},

		toolsetter(): Probe | null {
			const raw =
				readFirmwareGlobal(store.state.machine.model.global, 'nxtToolSetterID') ??
				readFirmwareGlobal(store.state.machine.model.global, 'nxtTSID');
			const nxtTSID = typeof raw === 'number' ? raw : null;
			if (nxtTSID === null) return null;
			const p = store.state.machine.model.sensors.probes.at(nxtTSID);
			return p ? p : null;
		},

		// Rotation compensation
		rotationCompensation(): number {
			return store.state.machine.model.move.rotation.angle;
		},

		// Touch probe status (always shown)
		touchProbeStatusText(): string {
			if (!this.touchProbeEnabled || this.touchProbe === null) return (this as any).$t('plugins.next.panels.status.disabled').toString();
			return (this as any).probeText(this.touchProbe as Probe);
		},
		touchProbeStatusColor(): string {
			if (!this.touchProbeEnabled || this.touchProbe === null) return 'grey';
			return (this as any).probeColor(this.touchProbe as Probe);
		},
		touchProbeStatusIcon(): string {
			if (!this.touchProbeEnabled || this.touchProbe === null) return 'mdi-cancel';
			return (this as any).probeIcon(this.touchProbe as Probe);
		},

		// Toolsetter status (always shown)
		toolsetterStatusText(): string {
			if (!this.toolsetterEnabled || this.toolsetter === null) return (this as any).$t('plugins.next.panels.status.disabled').toString();
			return (this as any).probeText(this.toolsetter as Probe);
		},
		toolsetterStatusColor(): string {
			if (!this.toolsetterEnabled || this.toolsetter === null) return 'grey';
			return (this as any).probeColor(this.toolsetter as Probe);
		},
		toolsetterStatusIcon(): string {
			if (!this.toolsetterEnabled || this.toolsetter === null) return 'mdi-cancel';
			return (this as any).probeIcon(this.toolsetter as Probe);
		},
	},

	methods: {
		probeColor(probe: Probe): string {
			return (probe.value[0] >= probe.threshold) ? 'red' : 'green';
		},

		probeText(probe: Probe): string {
			const key = (probe.value[0] >= probe.threshold) ? 
				'plugins.next.panels.status.probeTriggered' : 
				'plugins.next.panels.status.probeNotTriggered';
			return (this as any).$t(key, [probe.value[0]]).toString();
		},

		probeIcon(probe: Probe): string {
			return (probe.value[0] >= probe.threshold) ? 'mdi-bell-ring' : 'mdi-bell-sleep';
		},
	}
});
</script>

<style scoped>
.v-simple-table tbody tr td:first-child {
	width: 50%;
}

/* Tight right edge for status chips; preserve spacing via .pill-text */
.status-chip { padding-right: 0 !important; overflow: visible !important; }
.status-chip .v-chip__content { padding-right: 0 !important; }
.status-chip .v-avatar { margin-left: 0 !important; margin-right: -2px !important; }
.pill-text { margin-right: 8px; }
</style>
