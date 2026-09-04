<template>
	<div class="nxt-cnc-status">
		<v-row density="compact" class="nxt-cnc-status__row">
			<!-- Status Information -->
			<v-col cols="12" md="5" lg="4" class="d-flex">
				<v-card variant="outlined" class="nxt-cnc-status__card flex-grow-1">
					<v-card-title class="py-2 font-weight-bold text-body-1 d-flex align-center">
						<span>{{ $t("panel.status.caption") }}</span>
						<v-spacer />
						<StatusLabel v-if="hasMachineStatus" />
					</v-card-title>
					<v-card-text class="pt-0">
						<template v-if="isConnected && visibleAxes.length > 0">
							<v-table density="compact" class="nxt-cnc-status__table nxt-cnc-status__table--status">
								<tbody>
									<tr>
										<td><strong>{{ $t("plugins.nxt.panels.status.workplace") }}</strong></td>
										<td class="text-right">
											<v-tooltip location="top">
												<template v-slot:activator="{ props }">
													<v-chip v-bind="props" label variant="outlined" size="small" class="status-chip">
														<span class="pill-text">{{ currentWorkplaceGCode }}</span>
														<template #append>
															<v-avatar :color="currentWorkplaceColor" size="24" rounded>
																{{ currentWorkplace }}
															</v-avatar>
														</template>
													</v-chip>
												</template>
												<span>{{ currentWorkplaceTooltip }}</span>
											</v-tooltip>
										</td>
									</tr>

									<tr>
										<td><strong>{{ $t("plugins.nxt.panels.status.tool") }}</strong></td>
										<td class="text-right">
											<v-tooltip location="top">
												<template v-slot:activator="{ props }">
													<v-chip v-bind="props" label variant="outlined" size="small" class="status-chip">
														<span class="pill-text">{{ toolLabelShort || $t('plugins.nxt.panels.status.none') }}</span>
														<template #append>
															<v-avatar
																:color="toolNumber !== null ? 'green' : 'grey'"
																size="24"
																rounded
															>
																{{ toolNumber !== null ? toolNumber : '—' }}
															</v-avatar>
														</template>
													</v-chip>
												</template>
												<span>{{ toolLabel || $t('plugins.nxt.panels.status.none') }}</span>
											</v-tooltip>
										</td>
									</tr>

									<tr v-if="toolRadius !== null">
										<td><strong>{{ $t("plugins.nxt.panels.status.toolRadius") }}</strong></td>
										<td class="text-right">
											<span class="text-body-2">{{ formatDisplay(toolRadius, 3, "mm") }}</span>
										</td>
									</tr>

									<tr v-if="toolOffset !== null">
										<td><strong>{{ $t("plugins.nxt.panels.status.toolOffset") }}</strong></td>
										<td class="text-right">
											<span class="text-body-2">{{ formatDisplay(toolOffset, 3, "mm") }}</span>
										</td>
									</tr>

									<tr v-if="loadedTool.role !== 'none'">
										<td><strong>{{ $t("plugins.nxt.panels.status.toolRole") }}</strong></td>
										<td class="text-right">
											<v-chip size="x-small" :color="loadedToolRoleColor" label>
												{{ loadedToolRoleText }}
											</v-chip>
										</td>
									</tr>

									<tr v-if="loadedTool.fluteCount !== null">
										<td><strong>{{ $t("plugins.nxt.panels.status.toolFlutes") }}</strong></td>
										<td class="text-right">
											<span class="text-body-2">{{ loadedTool.fluteCount }}</span>
										</td>
									</tr>

									<tr v-if="loadedTool.fluteLengthMm !== null">
										<td><strong>{{ $t("plugins.nxt.panels.status.toolFluteLength") }}</strong></td>
										<td class="text-right">
											<span class="text-body-2">{{ formatDisplay(loadedTool.fluteLengthMm, 3, "mm") }}</span>
										</td>
									</tr>

									<tr v-if="activeSpindle !== null">
										<td><strong>{{ $t("plugins.nxt.panels.status.spindle") }}</strong></td>
										<td class="text-right">
											<v-chip label variant="outlined" size="small" class="status-chip">
												<span class="pill-text">{{ spindleStateText }}</span>
												<template #append>
													<v-avatar :color="spindleStateColor" size="24" rounded>
														<v-icon size="small">{{ spindleStateIcon }}</v-icon>
													</v-avatar>
												</template>
											</v-chip>
										</td>
									</tr>

									<tr v-if="activeSpindle !== null && spindleRPM !== null">
										<td><strong>{{ $t("plugins.nxt.panels.status.spindleRPM") }}</strong></td>
										<td class="text-right">
											<span class="text-body-2">{{ spindleRPM }} RPM</span>
										</td>
									</tr>

									<tr>
										<td><strong>{{ $t("plugins.nxt.panels.status.touchProbe") }}</strong></td>
										<td class="text-right">
											<v-chip label variant="outlined" size="small" class="status-chip">
												<span class="pill-text">{{ touchProbeStatusText }}</span>
												<template #append>
													<v-avatar :color="touchProbeStatusColor" size="24" rounded>
														<v-icon size="small">{{ touchProbeStatusIcon }}</v-icon>
													</v-avatar>
												</template>
											</v-chip>
										</td>
									</tr>

									<tr>
										<td><strong>{{ $t("plugins.nxt.panels.status.toolsetter") }}</strong></td>
										<td class="text-right">
											<v-chip label variant="outlined" size="small" class="status-chip">
												<span class="pill-text">{{ toolsetterStatusText }}</span>
												<template #append>
													<v-avatar :color="toolsetterStatusColor" size="24" rounded>
														<v-icon size="small">{{ toolsetterStatusIcon }}</v-icon>
													</v-avatar>
												</template>
											</v-chip>
										</td>
									</tr>

									<tr v-if="rotationCompensation !== 0">
										<td><strong>{{ $t("plugins.nxt.panels.status.rotation") }}</strong></td>
										<td class="text-right">
											<span class="text-body-2">{{ formatDisplay(rotationCompensation, 3, "°") }}</span>
										</td>
									</tr>
								</tbody>
							</v-table>
						</template>
						<template v-else>
							<v-alert type="info" density="compact" variant="text" class="mb-0">
								<v-icon class="mr-2">mdi-lan-disconnect</v-icon>
								{{ $t("plugins.nxt.panels.status.disconnected") }}
							</v-alert>
						</template>
					</v-card-text>
				</v-card>
			</v-col>

			<!-- Positions + spindle (wider column so axis values are not clipped) -->
			<v-col cols="12" md="7" lg="8" class="d-flex flex-column ga-2">
				<v-card variant="outlined" class="nxt-cnc-status__card flex-grow-1">
					<v-card-title class="py-2 font-weight-bold text-body-1">
						{{ toolPositionCaption }}
					</v-card-title>
					<v-card-text class="pt-0">
						<template v-if="isConnected">
							<v-table density="compact" class="nxt-cnc-status__table nxt-cnc-status__table--axes">
								<thead>
									<tr>
										<th>Axis</th>
										<th class="text-right">Workplace</th>
										<th class="text-right">Machine</th>
									</tr>
								</thead>
								<tbody>
									<tr v-for="axis in visibleAxes" :key="axis.letter">
										<td>
											<v-chip
												size="small"
												:color="axis.homed ? 'success' : 'grey'"
												class="px-2 text-white rounded-0"
											>
												{{ axis.letter }}
											</v-chip>
										</td>
										<td class="text-right nxt-cnc-status__pos">{{ formatDisplay(axis.userPosition, 3, "mm") }}</td>
										<td class="text-right nxt-cnc-status__pos">{{ formatDisplay(axis.machinePosition, 3, "mm") }}</td>
									</tr>
								</tbody>
							</v-table>
						</template>
						<template v-else>
							<v-alert type="info" density="compact" variant="text" class="mb-0">
								<v-icon class="mr-2">mdi-lan-disconnect</v-icon>
								{{ $t('plugins.nxt.panels.status.disconnected') }}
							</v-alert>
						</template>
					</v-card-text>
				</v-card>

				<Spindle0ControlPanel v-if="isConnected" class="nxt-cnc-status__spindle" />
			</v-col>
		</v-row>

		<!-- Status-light colors only (not the full work-light tester) -->
		<v-row v-if="rgbHardwareConfigured || rgbFeatureEnabled" density="compact" class="mt-2">
			<v-col cols="12">
				<RgbLightControl compact />
			</v-col>
		</v-row>
	</div>
</template>

<script lang="ts">
import { defineNxtComponent } from "../../base/BaseComponent.vue";
import { Probe, Axis, Spindle, SpindleState } from "@duet3d/objectmodel";
import { StatusLabel } from "DuetWebControl/components";
import { display } from "@/utils/display";
import store from "../../../compat/dwcStore";
import { readFirmwareGlobal } from "../../../utils/nxtToolChangerOm";
import { buildLoadedToolStatus, type LoadedToolStatus } from "../../../utils/nxtLoadedToolStatus";
import {
	isRgbFeatureEnabled,
	isRgbLightHardwareConfigured,
	readOmLedsFromMachineModel
} from "../../../utils/nxtRgbAvailability";
import RgbLightControl from "../../panels/RgbLightControl.vue";
import Spindle0ControlPanel from "../../panels/Spindle0ControlPanel.vue";

const enum WorkplaceSet {
	NONE,
	SOME,
	ALL
}

export default defineNxtComponent({
	name: 'CNCContainerPanel',

	components: {
		RgbLightControl,
		Spindle0ControlPanel,
		StatusLabel,
	},

	methods: {
		formatDisplay(
			value: number | Array<number> | string | null | undefined,
			precision?: number,
			unit?: string
		): string {
			return display(value, precision, unit);
		},

		probeColor(probe: Probe): string {
			return (probe.value[0] >= probe.threshold) ? 'red' : 'green';
		},

		probeText(probe: Probe): string {
			const key = (probe.value[0] >= probe.threshold) ?
				'plugins.nxt.panels.status.probeTriggered' :
				'plugins.nxt.panels.status.probeNotTriggered';
			return this.$t(key, [probe.value[0]]).toString();
		},

		probeIcon(probe: Probe): string {
			return (probe.value[0] >= probe.threshold) ? 'mdi-bell-ring' : 'mdi-bell-sleep';
		},
	},

	computed: {
		toolPositionCaption(): string {
			const key = 'panel.tools.toolPosition';
			const translated = this.$t(key).toString();
			return translated === key ? 'Tool Position' : translated;
		},

		hasMachineStatus(): boolean {
			return !!store.state.machine.model.state.status;
		},

		visibleAxes(): Array<Axis> {
			return store.state.machine.model.move.axes.filter((axis: Axis) => axis.visible);
		},

		currentWorkplaceGCode(): string {
			return `G${53 + this.currentWorkplace}`;
		},

		currentWorkplaceValid(): WorkplaceSet {
			const axes = store.state.machine.model.move.axes.filter((axis: Axis) => axis.visible);
			const move = store.state.machine.model.move as {
				workplaceNumber?: number
				motionSystems?: Array<{ workplaceNumber?: number }>
			};
			const fromSystem = move?.motionSystems?.[0]?.workplaceNumber;
			const workplace =
				typeof fromSystem === 'number'
					? fromSystem
					: typeof move?.workplaceNumber === 'number'
						? move.workplaceNumber
						: 0;
			const offsets = axes.map((axis: Axis) => axis.workplaceOffsets[workplace]);

			if (offsets.every((offset: number) => offset !== 0)) {
				return WorkplaceSet.ALL;
			}

			return offsets.some((offset: number) => offset !== 0) ? WorkplaceSet.SOME : WorkplaceSet.NONE;
		},

		currentWorkplaceColor(): string {
			switch (this.currentWorkplaceValid) {
				case WorkplaceSet.ALL:
					return 'success';
				case WorkplaceSet.SOME:
					return 'warning';
				default:
					return 'grey';
			}
		},

		currentWorkplaceTooltip(): string {
			const valid = this.currentWorkplaceValid as WorkplaceSet;
			const translations: Record<WorkplaceSet, string> = {
				[WorkplaceSet.ALL]: 'plugins.nxt.panels.status.workplaceValid',
				[WorkplaceSet.SOME]: 'plugins.nxt.panels.status.workplacePartial',
				[WorkplaceSet.NONE]: 'plugins.nxt.panels.status.workplaceInvalid'
			};
			return this.$t(translations[valid], [this.currentWorkplaceGCode]).toString();
		},

		toolNumber(): number | null {
			const t = store.state.machine.model.state.currentTool ?? -1;
			return t < 0 ? null : t;
		},

		loadedTool(): LoadedToolStatus {
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

		toolLabel(): string {
			return this.loadedTool.label;
		},

		toolLabelShort(): string {
			return this.loadedTool.labelShort;
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
				return this.$t('plugins.nxt.panels.toolManagement.statusProbe').toString();
			}
			if (role === 'spindle') {
				return this.$t('plugins.nxt.panels.toolManagement.statusInSpindle').toString();
			}
			return this.$t('plugins.nxt.panels.status.none').toString();
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
				boardShortName: boardShortName != null ? String(boardShortName) : null,
				rgbPin: readFirmwareGlobal(g, 'nxtRGBPin'),
				rgbReady: readFirmwareGlobal(g, 'nxtRGBReady')
			});
		},

		rgbFeatureEnabled(): boolean {
			return isRgbFeatureEnabled(store.state.machine.model.global);
		},

		activeSpindle(): Spindle | null {
			const spindles = store.state.machine.model.spindles;
			if (!spindles || spindles.length === 0) return null;
			return spindles[0] ?? null;
		},

		spindleStateText(): string {
			const spindle = this.activeSpindle;
			if (!spindle) return '';

			switch (spindle.state) {
				case SpindleState.forward:
					return this.$t('plugins.nxt.panels.status.spindleForward').toString();
				case SpindleState.reverse:
					return this.$t('plugins.nxt.panels.status.spindleReverse').toString();
				case SpindleState.stopped:
					return this.$t('plugins.nxt.panels.status.spindleStopped').toString();
				default:
					return this.$t('plugins.nxt.panels.status.spindleUnconfigured').toString();
			}
		},

		spindleStateColor(): string {
			const spindle = this.activeSpindle;
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
			const spindle = this.activeSpindle;
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
			const spindle = this.activeSpindle;
			if (!spindle) return null;
			if (spindle.state === SpindleState.stopped ||
			    spindle.state === SpindleState.unconfigured) {
				return null;
			}
			return spindle.current;
		},

		touchProbeEnabled(): boolean {
			const feat = readFirmwareGlobal(store.state.machine.model.global, 'nxtFeatureTouchProbe');
			const enabled = feat === true || feat === 1;
			const id =
				readFirmwareGlobal(store.state.machine.model.global, 'nxtTouchProbeID') ??
				readFirmwareGlobal(store.state.machine.model.global, 'nxtTPID');
			return Boolean(enabled && id !== null && id !== undefined);
		},

		toolsetterEnabled(): boolean {
			const feat = readFirmwareGlobal(store.state.machine.model.global, 'nxtFeatureToolSetter');
			const enabled = feat === true || feat === 1;
			const id =
				readFirmwareGlobal(store.state.machine.model.global, 'nxtToolSetterID') ??
				readFirmwareGlobal(store.state.machine.model.global, 'nxtTSID');
			return Boolean(enabled && id !== null && id !== undefined);
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

		rotationCompensation(): number {
			return store.state.machine.model.move.rotation.angle;
		},

		touchProbeStatusText(): string {
			if (!this.touchProbeEnabled || this.touchProbe === null) {
				return this.$t('plugins.nxt.panels.status.disabled').toString();
			}
			return this.probeText(this.touchProbe);
		},
		touchProbeStatusColor(): string {
			if (!this.touchProbeEnabled || this.touchProbe === null) return 'grey';
			return this.probeColor(this.touchProbe);
		},
		touchProbeStatusIcon(): string {
			if (!this.touchProbeEnabled || this.touchProbe === null) return 'mdi-cancel';
			return this.probeIcon(this.touchProbe);
		},

		toolsetterStatusText(): string {
			if (!this.toolsetterEnabled || this.toolsetter === null) {
				return this.$t('plugins.nxt.panels.status.disabled').toString();
			}
			return this.probeText(this.toolsetter);
		},
		toolsetterStatusColor(): string {
			if (!this.toolsetterEnabled || this.toolsetter === null) return 'grey';
			return this.probeColor(this.toolsetter);
		},
		toolsetterStatusIcon(): string {
			if (!this.toolsetterEnabled || this.toolsetter === null) return 'mdi-cancel';
			return this.probeIcon(this.toolsetter);
		},
	},
});
</script>

<style scoped>
.nxt-cnc-status__card {
	width: 100%;
	overflow: visible;
}
.nxt-cnc-status__table--status :deep(td:first-child) {
	width: 42%;
	white-space: nowrap;
}
.nxt-cnc-status__table--axes :deep(.v-table__wrapper) {
	overflow-x: auto;
}
.nxt-cnc-status__table--axes :deep(th),
.nxt-cnc-status__table--axes :deep(td) {
	white-space: nowrap;
}
.nxt-cnc-status__table--axes :deep(th:first-child),
.nxt-cnc-status__table--axes :deep(td:first-child) {
	width: 1%;
}
.nxt-cnc-status__pos {
	font-variant-numeric: tabular-nums;
	min-width: 7.5rem;
}
.nxt-cnc-status__spindle :deep(.v-card) {
	width: 100%;
}
.status-chip .pill-text {
	margin-right: 6px;
}
</style>
