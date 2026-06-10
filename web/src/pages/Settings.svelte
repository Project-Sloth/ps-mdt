<script lang="ts">
	import { onMount } from "svelte";

	const STORAGE_KEY = "ps-mdt-preferences";

	// Appearance
	let theme = $state("dark");
	let notificationSounds = $state(true);
	let uiZoom = $state(130);

	// Map
	let defaultZoom = $state(5);
	let showOfficers = $state(true);
	let showVehicles = $state(true);
	let showBodycams = $state(false);

	let saveStatus: string | null = $state(null);
	let saveTimeout: ReturnType<typeof setTimeout> | null = null;

	onMount(() => {
		loadPreferences();
	});

	function loadPreferences() {
		try {
			const saved = localStorage.getItem(STORAGE_KEY);
			if (!saved) return;
			const data = JSON.parse(saved);
			if (data.theme) theme = data.theme;
			if (data.notificationSounds !== undefined) notificationSounds = data.notificationSounds;
			if (data.uiZoom !== undefined) uiZoom = data.uiZoom;
			if (data.defaultZoom !== undefined) defaultZoom = data.defaultZoom;
			if (data.showOfficers !== undefined) showOfficers = data.showOfficers;
			if (data.showVehicles !== undefined) showVehicles = data.showVehicles;
			if (data.showBodycams !== undefined) showBodycams = data.showBodycams;
		} catch {
			// Ignore parse errors
		}
	}

	function savePreferences() {
		try {
			const data = {
				theme,
				notificationSounds,
				uiZoom,
				defaultZoom,
				showOfficers,
				showVehicles,
				showBodycams,
			};
			localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
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

	function applyZoom(value: number) {
		uiZoom = value;
		const el = document.querySelector(".content-area") as HTMLElement;
		if (el) {
			el.style.zoom = `${value}%`;
		}
	}

	function resetZoom() {
		applyZoom(130);
	}
</script>

<div class="settings-page">
	<div class="settings-grid">
		<div class="settings-card">
			<span class="card-label">Appearance</span>
			<div class="setting-row">
				<div class="setting-info">
					<span class="setting-label">Theme</span>
					<span class="setting-desc">Select the MDT color theme</span>
				</div>
				<select class="setting-select" bind:value={theme}>
					<option value="dark">Dark</option>
					<option value="light">Light</option>
				</select>
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
					<span class="setting-label">UI Zoom</span>
					<span class="setting-desc">Adjust the overall MDT interface size</span>
				</div>
				<div class="zoom-control">
					<input
						type="range"
						class="zoom-slider"
						min="100"
						max="200"
						step="5"
						value={uiZoom}
						oninput={(e) => applyZoom(parseInt(e.currentTarget.value))}
					/>
					<span class="zoom-value">{uiZoom}%</span>
					{#if uiZoom !== 130}
						<button class="zoom-reset" onclick={resetZoom} type="button">Reset</button>
					{/if}
				</div>
			</div>
		</div>

		<div class="settings-card">
			<span class="card-label">Map</span>
			<div class="setting-row">
				<div class="setting-info">
					<span class="setting-label">Default Zoom Level</span>
					<span class="setting-desc">Zoom level when opening the map (3-10)</span>
				</div>
				<input
					type="number"
					class="setting-input"
					bind:value={defaultZoom}
					min="3"
					max="10"
				/>
			</div>
			<div class="setting-row">
				<div class="setting-info">
					<span class="setting-label">Show Officers</span>
					<span class="setting-desc">Display officer positions on the map</span>
				</div>
				<label class="toggle">
					<input type="checkbox" bind:checked={showOfficers} />
					<span class="toggle-slider"></span>
				</label>
			</div>
			<div class="setting-row">
				<div class="setting-info">
					<span class="setting-label">Show Vehicles</span>
					<span class="setting-desc">Display tracked vehicles on the map</span>
				</div>
				<label class="toggle">
					<input type="checkbox" bind:checked={showVehicles} />
					<span class="toggle-slider"></span>
				</label>
			</div>
			<div class="setting-row">
				<div class="setting-info">
					<span class="setting-label">Show Bodycams</span>
					<span class="setting-desc">Display bodycam feeds on the map</span>
				</div>
				<label class="toggle">
					<input type="checkbox" bind:checked={showBodycams} />
					<span class="toggle-slider"></span>
				</label>
			</div>
		</div>

	</div>

	<div class="save-bar">
		<button class="btn-save" onclick={savePreferences}>
			<span class="material-icons btn-save-icon">save</span>
			Save Preferences
		</button>
		{#if saveStatus}
			<span class="save-status">{saveStatus}</span>
		{/if}
	</div>
</div>

<style>
	.settings-page {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
		overflow-y: auto;
	}

	.settings-page::-webkit-scrollbar {
		width: 4px;
	}

	.settings-page::-webkit-scrollbar-track {
		background: transparent;
	}

	.settings-page::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	.save-bar {
		display: flex;
		align-items: center;
		gap: 10px;
		flex-shrink: 0;
		padding: 10px 16px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}

	.save-status {
		font-size: 10px;
		color: rgba(110, 231, 183, 0.8);
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

	.btn-save-icon {
		font-size: 13px;
	}

	.settings-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0;
		flex: 1;
	}

	.settings-card {
		background: transparent;
		border: none;
		border-radius: 0;
		padding: 12px 16px;
	}

	.settings-card:first-child {
		border-right: 1px solid rgba(255, 255, 255, 0.06);
	}

	.card-label {
		display: block;
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.35);
		margin-bottom: 8px;
		padding-bottom: 8px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.setting-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 7px 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
	}

	.setting-row:last-child {
		border-bottom: none;
		padding-bottom: 0;
	}

	.setting-info {
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.setting-label {
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		font-weight: 500;
	}

	.setting-desc {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.setting-select {
		padding: 3px 24px 3px 8px;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		color: rgba(255, 255, 255, 0.7);
		font-size: 10px;
		outline: none;
	}

	.setting-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.7);
		padding: 3px 8px;
		border-radius: 3px;
		font-size: 10px;
		width: 48px;
		text-align: center;
		outline: none;
		transition: border-color 0.1s;
	}

	.setting-input:focus {
		border-color: rgba(255, 255, 255, 0.12);
	}

	/* Hide number input spinners */
	.setting-input::-webkit-outer-spin-button,
	.setting-input::-webkit-inner-spin-button {
		-webkit-appearance: none;
		margin: 0;
	}

	/* Zoom control */
	.zoom-control {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.zoom-slider {
		-webkit-appearance: none;
		appearance: none;
		width: 100px;
		height: 4px;
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
		outline: none;
		cursor: pointer;
	}

	.zoom-slider::-webkit-slider-thumb {
		-webkit-appearance: none;
		appearance: none;
		width: 12px;
		height: 12px;
		border-radius: 50%;
		background: rgba(var(--accent-text-rgb), 0.7);
		cursor: pointer;
		transition: background 0.1s;
	}

	.zoom-slider::-webkit-slider-thumb:hover {
		background: rgba(var(--accent-text-rgb), 0.9);
	}

	.zoom-value {
		font-size: 10px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.6);
		min-width: 32px;
		text-align: center;
		font-variant-numeric: tabular-nums;
	}

	.zoom-reset {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.zoom-reset:hover {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.6);
	}

	/* Toggle switch */
	.toggle {
		position: relative;
		display: inline-block;
		width: 32px;
		height: 18px;
		flex-shrink: 0;
	}

	.toggle input {
		opacity: 0;
		width: 0;
		height: 0;
	}

	.toggle-slider {
		position: absolute;
		cursor: pointer;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(255, 255, 255, 0.06);
		border-radius: 18px;
		transition: background 0.2s ease;
	}

	.toggle-slider::before {
		content: "";
		position: absolute;
		height: 12px;
		width: 12px;
		left: 3px;
		bottom: 3px;
		background: rgba(255, 255, 255, 0.4);
		border-radius: 50%;
		transition: transform 0.2s ease;
	}

	.toggle input:checked + .toggle-slider {
		background: rgba(var(--accent-rgb), 0.35);
	}

	.toggle input:checked + .toggle-slider::before {
		transform: translateX(14px);
		background: rgba(255, 255, 255, 0.85);
	}

	@keyframes fadeIn {
		0% { opacity: 0; }
		100% { opacity: 1; }
	}

	@media (max-width: 900px) {
		.settings-grid {
			grid-template-columns: 1fr;
		}

		.settings-card:first-child {
			border-right: none;
			border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		}
	}
</style>
