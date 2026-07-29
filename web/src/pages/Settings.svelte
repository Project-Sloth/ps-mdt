<script lang="ts">
	import { getTabsForJob, getTabLabel, type MDTTab } from "../constants";
	import type { JobType } from "../interfaces/IUser";

	// authService is passed down from ContentArea so the Default Tab dropdown
	// only offers tabs this player can actually open (job + hide-permissions).
	// Structural type on purpose: only the two members we read, so the service
	// object doesn't need to satisfy the full AuthService interface.
	type AuthLike = { jobType: JobType; hasRawPermission: (perm: string) => boolean };
	let { authService = undefined }: { authService?: AuthLike } = $props();
	import { onMount } from "svelte";

	const STORAGE_KEY = "ps-mdt-preferences";

	// Preferences live in Lua's KVP store, which unlike localStorage survives a
	// CEF cache clear. localStorage stays as a mirror so the synchronous reads
	// below keep working and nothing configured before this change is lost.
	let kvpCache: string | null = null;

	// Same raw-fetch style the clientPrefs push below uses: these callbacks are
	// local to this page and not part of the typed NUI event map.
	function nui(name: string, body: unknown) {
		return fetch(`https://${(window as any).GetParentResourceName?.() ?? "ps-mdt"}/${name}`, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify(body),
		});
	}

	async function seedPrefs() {
		try {
			const res = await (await nui("getMdtPrefs", {})).json();
			if (res?.data) {
				kvpCache = res.data;
				// Keep the mirror in step so a later synchronous read agrees.
				try { localStorage.setItem(STORAGE_KEY, res.data); } catch { /* full or blocked */ }
			}
		} catch { /* client unreachable — localStorage stands */ }
	}

	function readPrefs(): string | null {
		if (kvpCache) return kvpCache;
		try { return localStorage.getItem(STORAGE_KEY); } catch { return null; }
	}

	function writePrefs(json: string) {
		kvpCache = json;
		nui("saveMdtPrefs", json).catch(() => { /* mirror still holds it */ });
		try { localStorage.setItem(STORAGE_KEY, json); } catch { /* full or blocked */ }
	}

	// Fixed steps rather than a slider. The control sits in the panel it resizes,
	// so dragging fights you — the handle moves out from under the cursor. One
	// click per step, and the labels say what they are for.
	// Two independent axes. Content zoom decides how big things are INSIDE the
	// content area; window size decides how much of the screen the MDT itself
	// takes. On a 4K screen you often want a smaller window with larger text,
	// which one control could never express.
	const WINDOW_STEPS: Array<[string, string, string]> = [
		["compact", "75vw", "72vh"],
		["default", "95vw", "90vh"],
		["full", "99vw", "96vh"],
	];
	const WINDOW_LABELS: Record<string, string> = {
		compact: "Compact", default: "Default", full: "Full",
	};

	const ZOOM_STEPS: Array<[number, string]> = [
		[100, "100%"],
		[115, "115%"],
		[130, "Default"],
		[150, "1440p"],
		[175, "4K"],
	];

	// Appearance
	let notificationSounds = $state(true);
	let uiZoom = $state(130);
	let windowSize = $state("default");

	// Map
	let defaultZoom = $state(5);
	let centerOnSelf = $state(true);

	// Patrol
	let patrolZoneNotifications = $state(true);

	// General
	let defaultTab = $state("last");
	let reducedMotion = $state(false);

	// Plate checks (radar / ANPR)
	let plateCheckAlerts = $state(true);
	let plateCheckIgnoreImpounds = $state(false);
	let plateCheckCriticalOnly = $state(false);

	// Dispatch
	let autoStatusNotifications = $state(true);
	let autoWaypoint = $state(true);
	let assignmentNotifications = $state(true);
	let bodycamAutoDuty = $state(true);

	let saveStatus: string | null = $state(null);
	let saveTimeout: ReturnType<typeof setTimeout> | null = null;

	// Tracks whether current values differ from the last saved state, so the
	// topbar can show an "Unsaved changes" hint.
	let savedSnapshot = $state("");
	function snapshot(): string {
		return JSON.stringify({ notificationSounds, uiZoom, windowSize, defaultZoom, centerOnSelf, patrolZoneNotifications, autoStatusNotifications, autoWaypoint, assignmentNotifications, bodycamAutoDuty, defaultTab, reducedMotion , plateCheckAlerts, plateCheckIgnoreImpounds, plateCheckCriticalOnly });
	}
	let isDirty = $derived(savedSnapshot !== "" && snapshot() !== savedSnapshot);

	onMount(() => {
		// Pull the stored preferences before anything reads them.
		seedPrefs();
		loadPreferences();
		savedSnapshot = snapshot();

		// Respond to Lua client asking for stored notification preferences.
		// Fires on resource start so the client has the correct values immediately.
		function handleNuiMessage(event: MessageEvent) {
			if (event.data?.type === "requestClientPrefs") {
				pushClientPrefs();
			applyReducedMotion(reducedMotion);
			}
			if (event.data?.type === "requestAutoStatusPref") {
				const saved = readPrefs();
				let enabled = true; // default
				try {
					if (saved) {
						const data = JSON.parse(saved);
						if (data.autoStatusNotifications !== undefined) {
							enabled = data.autoStatusNotifications;
						}
					}
				} catch { /* ignore */ }
				fetch(`https://${(window as any).GetParentResourceName?.() ?? "ps-mdt"}/autoStatusPref`, {
					method: "POST",
					headers: { "Content-Type": "application/json" },
					body: JSON.stringify({ enabled }),
				}).catch(() => {});
			}
			if (event.data?.type === "requestPatrolZonePref") {
				const saved = readPrefs();
				let enabled = true; // default
				try {
					if (saved) {
						const data = JSON.parse(saved);
						if (data.patrolZoneNotifications !== undefined) {
							enabled = data.patrolZoneNotifications;
						}
					}
				} catch { /* ignore */ }
				// Send back to Lua via NUI callback
				fetch(`https://${(window as any).GetParentResourceName?.() ?? "ps-mdt"}/patrolZonePref`, {
					method: "POST",
					headers: { "Content-Type": "application/json" },
					body: JSON.stringify({ enabled }),
				}).catch(() => {});
			}
		}

		window.addEventListener("message", handleNuiMessage);
		return () => window.removeEventListener("message", handleNuiMessage);
	});

	// Push the Lua-mirrored bundle (sounds, waypoint, assignment notify) to the
	// client. Reads the stored preferences so the resource-start request gets saved
	// values even before this component's state has hydrated.
	function pushClientPrefs() {
		let d: Record<string, unknown> = {};
		try { d = JSON.parse(readPrefs() ?? "{}"); } catch { /* defaults */ }
		fetch(`https://${(window as any).GetParentResourceName?.() ?? "ps-mdt"}/clientPrefs`, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify({
				notificationSounds: d.notificationSounds !== false,
				autoWaypoint: d.autoWaypoint !== false,
				assignmentNotifications: d.assignmentNotifications !== false,
				bodycamAutoDuty: d.bodycamAutoDuty !== false,
				// Plate-check alerts are decided server-side, so these travel
				// on to the server from preferences.lua.
				plateCheckAlerts: d.plateCheckAlerts !== false,
				plateCheckIgnoreImpounds: d.plateCheckIgnoreImpounds === true,
				plateCheckCriticalOnly: d.plateCheckCriticalOnly === true,
			}),
		}).catch(() => {});
	}

	// Tabs offered in the Default Tab dropdown: job-filtered and without tabs
	// hidden via tab_hidden_* permissions. Falls back to the full list when
	// authService isn't wired (e.g. dev preview).
	let defaultTabOptions = $derived.by(() => {
		// getTabsForJob takes the full JobType and handles anything that is not
		// leo/ems/doj itself, so the old narrowing dance is gone.
		const jt = authService?.jobType ?? "leo";
		return [
			{ value: "last", label: "Last used tab", icon: "history" },
			...getTabsForJob(jt)
				.filter(t => !authService?.hasRawPermission(`tab_hidden_${t.name.toLowerCase()}`))
				.map(t => ({ value: t.name, label: getTabLabel(t.name as MDTTab), icon: t.icon })),
		];
	});

	let tabDdOpen = $state(false);
	let selectedTabOption = $derived(
		defaultTabOptions.find(o => o.value === defaultTab) ?? defaultTabOptions[0],
	);

	function pickDefaultTab(value: string) {
		defaultTab = value;
		tabDdOpen = false;
	}

	// Close the dropdown on any click outside it (same pattern as Pagination).
	function handleDocClick(e: MouseEvent) {
		if (tabDdOpen && !(e.target as HTMLElement).closest(".tab-dd")) tabDdOpen = false;
	}

	// The number input's min/max only constrain the spinner buttons — typed
	// values sail right past them, so every path (input, load, save) clamps.
	function clampZoomLevel(z: unknown): number {
		const n = Math.round(Number(z));
		if (!Number.isFinite(n)) return 5;
		return Math.min(8, Math.max(2, n));
	}

	// Applies (or removes) the global animation kill-switch. Lives on the
	// document root so it reaches every page, Leaflet panes included.
	function applyReducedMotion(enabled: boolean) {
		document.documentElement.classList.toggle("mdt-reduced-motion", enabled);
	}

	function loadPreferences() {
		try {
			const saved = readPrefs();
			if (!saved) return;
			const data = JSON.parse(saved);
			if (data.notificationSounds !== undefined) notificationSounds = data.notificationSounds;
			if (data.uiZoom !== undefined) uiZoom = data.uiZoom;
			if (typeof data.windowSize === "string") applyWindow(data.windowSize);
			if (data.defaultZoom !== undefined) defaultZoom = clampZoomLevel(data.defaultZoom);
			if (data.centerOnSelf !== undefined) centerOnSelf = data.centerOnSelf;
			if (data.patrolZoneNotifications !== undefined) patrolZoneNotifications = data.patrolZoneNotifications;
			if (data.autoStatusNotifications !== undefined) autoStatusNotifications = data.autoStatusNotifications;
			if (data.plateCheckAlerts !== undefined) plateCheckAlerts = data.plateCheckAlerts;
			if (data.plateCheckIgnoreImpounds !== undefined) plateCheckIgnoreImpounds = data.plateCheckIgnoreImpounds;
			if (data.plateCheckCriticalOnly !== undefined) plateCheckCriticalOnly = data.plateCheckCriticalOnly;
			if (data.autoWaypoint !== undefined) autoWaypoint = data.autoWaypoint;
			if (data.assignmentNotifications !== undefined) assignmentNotifications = data.assignmentNotifications;
			if (data.bodycamAutoDuty !== undefined) bodycamAutoDuty = data.bodycamAutoDuty;
			if (typeof data.defaultTab === "string") defaultTab = data.defaultTab;
			if (data.reducedMotion !== undefined) reducedMotion = data.reducedMotion;
		} catch {
			// Ignore parse errors
		}
	}

	function savePreferences() {
		try {
			defaultZoom = clampZoomLevel(defaultZoom);
			const data = {
				notificationSounds,
				uiZoom,
				windowSize,
				defaultZoom,
				centerOnSelf,
				patrolZoneNotifications,
				autoStatusNotifications,
				plateCheckAlerts,
				plateCheckIgnoreImpounds,
				plateCheckCriticalOnly,
				autoWaypoint,
				assignmentNotifications,
				bodycamAutoDuty,
				defaultTab,
				reducedMotion,
			};
			writePrefs(JSON.stringify(data));
			savedSnapshot = snapshot();

			// Immediately sync notification prefs to the Lua client
			fetch(`https://${(window as any).GetParentResourceName?.() ?? "ps-mdt"}/patrolZonePref`, {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify({ enabled: patrolZoneNotifications }),
			}).catch(() => {});
			fetch(`https://${(window as any).GetParentResourceName?.() ?? "ps-mdt"}/autoStatusPref`, {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify({ enabled: autoStatusNotifications }),
			}).catch(() => {});
			pushClientPrefs();
			applyReducedMotion(reducedMotion);

			showSaveStatus("Preferences saved");
		} catch {
			showSaveStatus("Failed to save");
		}
	}

	function showSaveStatus(message: string) {
		saveStatus = message;
		if (saveTimeout) clearTimeout(saveTimeout);
		saveTimeout = setTimeout(() => {
			saveStatus = null;
		}, 2500);
	}

	function applyWindow(key: string) {
		windowSize = key;
		const step = WINDOW_STEPS.find(([k]) => k === key) ?? WINDOW_STEPS[1];
		document.documentElement.style.setProperty("--mdt-window-w", step[1]);
		document.documentElement.style.setProperty("--mdt-window-h", step[2]);
	}

	function applyZoom(value: number) {
		uiZoom = value;
		const el = document.querySelector(".content-area") as HTMLElement;
		if (el) {
			el.style.zoom = `${value}%`;
		}
	}

</script>

<svelte:document onclick={handleDocClick} />
<div class="settings-page">
	<div class="topbar">
		<span class="page-title">Settings</span>
		<span class="topbar-hint">Preferences are saved locally on this device</span>
		<div class="topbar-right">
			{#if saveStatus}
				<span class="save-status">{saveStatus}</span>
			{:else if isDirty}
				<span class="dirty-hint">Unsaved changes</span>
			{/if}
			<button class="btn-save" class:dirty={isDirty} onclick={savePreferences}>
				<span class="material-icons btn-save-icon">save</span>
				Save Preferences
			</button>
		</div>
	</div>

	<div class="settings-scroll">
		<div class="settings-grid">
			<div class="settings-card">
				<div class="card-head">
					<span class="material-icons card-icon">tune</span>
					<span class="card-label">General</span>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Default Tab</span>
						<span class="setting-desc">Which tab the MDT opens on — "Last used tab" keeps the current behavior</span>
					</div>
					<div class="tab-dd">
						<button class="tab-dd-trigger" class:open={tabDdOpen} onclick={() => tabDdOpen = !tabDdOpen} type="button">
							<span class="material-icons tab-dd-icon">{selectedTabOption.icon}</span>
							<span class="tab-dd-label">{selectedTabOption.label}</span>
							<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
								<polyline points={tabDdOpen ? "18 15 12 9 6 15" : "6 9 12 15 18 9"}/>
							</svg>
						</button>
						{#if tabDdOpen}
							<div class="tab-dd-menu">
								{#each defaultTabOptions as t (t.value)}
									<button class="tab-dd-option" class:active={t.value === defaultTab} onclick={() => pickDefaultTab(t.value)} type="button">
										<span class="material-icons tab-dd-icon">{t.icon}</span>
										{t.label}
									</button>
								{/each}
							</div>
						{/if}
					</div>
				</div>
			</div>

			<div class="settings-card">
				<div class="card-head">
					<span class="material-icons card-icon">route</span>
					<span class="card-label">Patrol</span>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Zone Notifications</span>
						<span class="setting-desc">Notify when you enter or leave your assigned patrol zone</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={patrolZoneNotifications} />
						<span class="toggle-slider"></span>
					</label>
				</div>
			</div>

			<div class="settings-card">
				<div class="card-head">
					<span class="material-icons card-icon">palette</span>
					<span class="card-label">Appearance</span>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Notification Sounds</span>
						<span class="setting-desc">Play sounds for dispatch alerts and messages</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={notificationSounds} />
						<span class="toggle-slider"></span>
					</label>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Reduced Motion</span>
						<span class="setting-desc">Disable pulse effects, transitions and other animations — calmer and lighter on weak PCs</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={reducedMotion} />
						<span class="toggle-slider"></span>
					</label>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Window Size</span>
						<span class="setting-desc">How much of the screen the MDT itself takes up</span>
					</div>
					<div class="zoom-control">
						<div class="zoom-steps">
							{#each WINDOW_STEPS as [key]}
								<button
									class="zoom-step"
									class:active={windowSize === key}
									type="button"
									onclick={() => applyWindow(key)}
								>{WINDOW_LABELS[key]}</button>
							{/each}
						</div>
					</div>
				</div>

				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Content Zoom</span>
						<span class="setting-desc">Size of text and boxes inside the content area</span>
					</div>
					<div class="zoom-control">
						<div class="zoom-steps">
							{#each ZOOM_STEPS as [value, label]}
								<button
									class="zoom-step"
									class:active={uiZoom === value}
									type="button"
									onclick={() => applyZoom(value)}
								>{label}</button>
							{/each}
						</div>
						{#if !ZOOM_STEPS.some(([v]) => v === uiZoom)}
							<span class="zoom-value">{uiZoom}%</span>
						{/if}
					</div>
				</div>
			</div>

			<div class="settings-card">
				<div class="card-head">
					<span class="material-icons card-icon">notifications_active</span>
					<span class="card-label">Dispatch</span>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Automatic Status Notifications</span>
						<span class="setting-desc">Notify when a call automatically changes your status (En Route, On Scene, back to Active)</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={autoStatusNotifications} />
						<span class="toggle-slider"></span>
					</label>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Automatic Waypoint</span>
						<span class="setting-desc">Set a GPS waypoint when you attach or get assigned to a call</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={autoWaypoint} />
						<span class="toggle-slider"></span>
					</label>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Assignment Notifications</span>
						<span class="setting-desc">Notify when a dispatcher assigns you to a call</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={assignmentNotifications} />
						<span class="toggle-slider"></span>
					</label>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Bodycam Follows Duty</span>
						<span class="setting-desc">Switch your bodycam on when you go on duty and off when you go off. Manual changes are always logged.</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={bodycamAutoDuty} />
						<span class="toggle-slider"></span>
					</label>
				</div>
			</div>

			<div class="settings-card">
				<div class="card-head">
					<span class="material-icons card-icon">map</span>
					<span class="card-label">Map</span>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Default Zoom Level</span>
						<span class="setting-desc">Zoom level when opening the map (2-8)</span>
					</div>
					<input
						type="number"
						class="setting-input"
						min="2"
						max="8"
						bind:value={defaultZoom}
						onchange={() => defaultZoom = clampZoomLevel(defaultZoom)}
					/>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Center On My Position</span>
						<span class="setting-desc">Pan the map to your own position when opening the Map tab</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={centerOnSelf} />
						<span class="toggle-slider"></span>
					</label>
				</div>
			</div>

			<div class="settings-card">
				<div class="card-head">
					<span class="material-icons card-icon">pin_invoke</span>
					<span class="card-label">Plate Checks</span>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Plate Check Alerts</span>
						<span class="setting-desc">Receive dispatch alerts when a scanned plate is flagged</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={plateCheckAlerts} />
						<span class="toggle-slider"></span>
					</label>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Ignore Impound History</span>
						<span class="setting-desc">Stay quiet when a repeat impound record is the only thing flagged</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={plateCheckIgnoreImpounds} />
						<span class="toggle-slider"></span>
					</label>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Critical Hits Only</span>
						<span class="setting-desc">Only BOLOs, stolen vehicles and wanted owners — skip paperwork flags</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={plateCheckCriticalOnly} />
						<span class="toggle-slider"></span>
					</label>
				</div>
			</div>
		</div>
	</div>
</div>

<style>
	.settings-page {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
		overflow: hidden;
	}

	/* ===== Topbar (same pattern as every other tab) ===== */
	.topbar {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 0 16px;
		height: 42px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}
	.page-title {
		font-size: 12px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}
	.topbar-hint {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.3);
	}
	.topbar-right {
		margin-left: auto;
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.save-status {
		font-size: 10px;
		color: rgba(110, 231, 183, 0.8);
		animation: fadeIn 0.2s ease-out;
	}
	.dirty-hint {
		font-size: 10px;
		color: rgba(234, 179, 8, 0.75);
		animation: fadeIn 0.2s ease-out;
	}

	.btn-save {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		background: rgba(var(--accent-rgb), 0.06);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}
	.btn-save:hover {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}
	.btn-save.dirty {
		background: rgba(var(--accent-rgb), 0.14);
		border-color: rgba(var(--accent-rgb), 0.25);
		color: rgba(var(--accent-text-rgb), 0.95);
	}
	.btn-save-icon { font-size: 13px; }

	/* ===== Scroll area + card grid ===== */
	.settings-scroll {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		padding: 14px 16px;
	}
	.settings-scroll::-webkit-scrollbar { width: 4px; }
	.settings-scroll::-webkit-scrollbar-track { background: transparent; }
	.settings-scroll::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	/* Multi-column rather than a 2-column grid: the browser distributes the
	   cards so both columns end at roughly the same height, whatever they
	   contain. A grid pairs cards by DOM order instead, so one card growing —
	   or a new one appearing — left the opposite column empty and needed the
	   order rebalancing by hand every time. This cannot drift. */
	.settings-grid {
		column-count: 2;
		column-gap: 12px;
	}

	.settings-card {
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 6px;
		padding: 12px 14px;
		/* A card must never be torn across the column break, and spacing now
		   comes from the card itself since there is no grid gap any more. */
		break-inside: avoid;
		-webkit-column-break-inside: avoid;
		margin-bottom: 12px;
	}

	.card-head {
		display: flex;
		align-items: center;
		gap: 6px;
		padding-bottom: 8px;
		margin-bottom: 4px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}
	.card-icon {
		font-size: 14px;
		color: rgba(var(--accent-text-rgb), 0.55);
	}
	.card-label {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.35);
	}

	/* ===== Rows ===== */
	.setting-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		padding: 8px 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
	}
	.setting-row:last-child { border-bottom: none; padding-bottom: 2px; }

	.setting-info { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
	.setting-label { color: rgba(255, 255, 255, 0.8); font-size: 11px; font-weight: 500; }
	.setting-desc  { color: rgba(255, 255, 255, 0.35); font-size: 10px; }

	/* ===== Controls ===== */

	.setting-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.75);
		padding: 4px 8px;
		border-radius: 3px;
		font-size: 10px;
		width: 48px;
		text-align: center;
		outline: none;
		transition: border-color 0.1s;
	}
	.setting-input:hover, .setting-input:focus { border-color: rgba(255, 255, 255, 0.12); }
	.setting-input::-webkit-outer-spin-button,
	.setting-input::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }

	/* Fixed width on both rows so the two button groups line up under each
	   other. Left to their content, three buttons and five buttons ended at
	   different points and the block looked ragged. */
	.zoom-control { display: flex; align-items: center; justify-content: flex-end; gap: 8px; width: 330px; }
	/* Zoom presets. Same construction as the other choice rows in the MDT:
	   quiet until selected, accent when active. */
	.zoom-steps {
		display: flex;
		gap: 3px;
		flex: 1;
		padding: 3px;
		background: rgba(0, 0, 0, 0.22);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 4px;
	}
	.zoom-step {
		flex: 1;
		padding: 5px 2px;
		background: transparent;
		border: none;
		border-radius: 3px;
		color: rgba(255, 255, 255, 0.45);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
		white-space: nowrap;
	}
	.zoom-step:hover { color: rgba(255, 255, 255, 0.8); }
	.zoom-step.active {
		background: rgba(var(--accent-rgb), 0.18);
		color: rgba(var(--accent-text-rgb), 0.95);
	}

	/* ===== Toggle ===== */
	/* Custom dropdown, same visual language as Pagination's per-page menu —
	   trigger chip + dark popover, with each tab's material icon in front. */
	.tab-dd { position: relative; }

	.tab-dd-trigger {
		display: flex;
		align-items: center;
		gap: 7px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 6px;
		color: rgba(255, 255, 255, 0.65);
		font-size: 0.78rem;
		padding: 6px 10px;
		min-width: 180px;
		cursor: pointer;
		transition: all 0.15s ease;
	}
	.tab-dd-trigger:hover,
	.tab-dd-trigger.open {
		background: rgba(255, 255, 255, 0.07);
		color: rgba(255, 255, 255, 0.85);
		border-color: rgba(255, 255, 255, 0.12);
	}
	.tab-dd-trigger .tab-dd-label { flex: 1; text-align: left; }
	.tab-dd-trigger svg { opacity: 0.6; flex-shrink: 0; }

	.tab-dd-icon { font-size: 15px; opacity: 0.7; }

	.tab-dd-menu {
		position: absolute;
		top: calc(100% + 4px);
		right: 0;
		background: var(--secondary-bg, #16181d);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 8px;
		padding: 4px;
		min-width: 200px;
		max-height: 260px;
		overflow-y: auto;
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
		z-index: 50;
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.tab-dd-option {
		display: flex;
		align-items: center;
		gap: 8px;
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.6);
		font-size: 0.76rem;
		padding: 6px 10px;
		border-radius: 5px;
		cursor: pointer;
		text-align: left;
		transition: all 0.1s ease;
	}
	.tab-dd-option:hover {
		background: rgba(255, 255, 255, 0.08);
		color: rgba(255, 255, 255, 0.9);
	}
	.tab-dd-option.active {
		background: rgba(var(--accent-rgb, 59, 130, 246), 0.15);
		color: #93c5fd;
		font-weight: 600;
	}
	.tab-dd-option.active .tab-dd-icon { opacity: 1; }


	.toggle {
		position: relative;
		display: inline-block;
		width: 32px;
		height: 18px;
		flex-shrink: 0;
	}
	.toggle input { opacity: 0; width: 0; height: 0; }
	.toggle-slider {
		position: absolute;
		cursor: pointer;
		top: 0; left: 0; right: 0; bottom: 0;
		background: rgba(255, 255, 255, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 18px;
		transition: background 0.2s ease, border-color 0.2s ease;
	}
	.toggle-slider:hover { border-color: rgba(255, 255, 255, 0.12); }
	.toggle-slider::before {
		content: "";
		position: absolute;
		height: 12px;
		width: 12px;
		left: 2px;
		bottom: 2px;
		background: rgba(255, 255, 255, 0.4);
		border-radius: 50%;
		transition: transform 0.2s ease, background 0.2s ease;
	}
	.toggle input:checked + .toggle-slider {
		background: rgba(var(--accent-rgb), 0.35);
		border-color: rgba(var(--accent-rgb), 0.3);
	}
	.toggle input:checked + .toggle-slider::before {
		transform: translateX(14px);
		background: rgba(255, 255, 255, 0.85);
	}

	@keyframes fadeIn {
		0%   { opacity: 0; }
		100% { opacity: 1; }
	}

	@media (max-width: 900px) {
		.settings-grid { column-count: 1; }
	}
</style>