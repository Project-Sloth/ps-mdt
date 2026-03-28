<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../../utils/fetchNui";
	import { isEnvBrowser } from "../../utils/misc";
	import { NUI_EVENTS } from "../../constants/nuiEvents";

	interface TrackingConfig {
		[key: string]: boolean;
	}

	const TRACKING_CATEGORIES: { key: string; label: string; description: string }[] = [
		{ key: "authentication", label: "Authentication", description: "Login and logout events" },
		{ key: "reports", label: "Reports", description: "Report create, update, and delete" },
		{ key: "cases", label: "Cases", description: "Case CRUD, officer assignments, attachments" },
		{ key: "evidence", label: "Evidence", description: "Evidence CRUD, transfers, and images" },
		{ key: "warrants", label: "Warrants", description: "Warrant issued and closed" },
		{ key: "vehicles", label: "Vehicles", description: "Vehicle updates, impound, and release" },
		{ key: "weapons", label: "Weapons", description: "Weapon create, update, and delete" },
		{ key: "charges", label: "Charges & Fines", description: "Fines processed and charges updated" },
		{ key: "searches", label: "Searches", description: "Citizen, player, and officer searches" },
		{ key: "dispatch", label: "Dispatch", description: "Signal 100 activate and deactivate" },
		{ key: "officers", label: "Officers", description: "Callsign changes" },
		{ key: "sentencing", label: "Sentencing", description: "Jail sentencing" },
		{ key: "arrests", label: "Arrests", description: "Arrest logging" },
		{ key: "icu", label: "ICU", description: "ICU record deletion" },
		{ key: "cameras", label: "Cameras", description: "Security camera access" },
		{ key: "bodycams", label: "Bodycams", description: "Officer bodycam access" },
	];

	let trackingConfig: TrackingConfig = $state({});
	let isLoadingTracking = $state(false);
	let isSavingTracking = $state(false);
	let trackingStatus: { text: string; type: "success" | "error" } | null = $state(null);

	function showTrackingStatus(text: string, type: "success" | "error" = "success") {
		trackingStatus = { text, type };
		setTimeout(() => { trackingStatus = null; }, 3000);
	}

	async function loadTrackingConfig() {
		if (isEnvBrowser()) return;
		try {
			isLoadingTracking = true;
			const response = await fetchNui<TrackingConfig>(
				NUI_EVENTS.SETTINGS.GET_AUDIT_TRACKING,
				{},
				{},
			);
			if (response && typeof response === "object") {
				trackingConfig = { ...response };
			}
		} catch (error) {
			console.error("Failed to load tracking config:", error);
		} finally {
			isLoadingTracking = false;
		}
	}

	async function saveTrackingConfig() {
		if (isEnvBrowser()) {
			showTrackingStatus("Settings saved");
			return;
		}
		try {
			isSavingTracking = true;
			const result = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.SETTINGS.SAVE_AUDIT_TRACKING,
				trackingConfig,
				{ success: false },
			);
			if (result?.success) {
				showTrackingStatus("Activity tracking settings saved");
			} else {
				showTrackingStatus(result?.message || "Failed to save settings", "error");
			}
		} catch (error) {
			console.error("Failed to save tracking config:", error);
			showTrackingStatus("Failed to save settings", "error");
		} finally {
			isSavingTracking = false;
		}
	}

	function toggleCategory(key: string) {
		trackingConfig = { ...trackingConfig, [key]: !trackingConfig[key] };
	}

	function enableAll() {
		const updated: TrackingConfig = {};
		for (const cat of TRACKING_CATEGORIES) {
			updated[cat.key] = true;
		}
		trackingConfig = updated;
	}

	function disableAll() {
		const updated: TrackingConfig = {};
		for (const cat of TRACKING_CATEGORIES) {
			updated[cat.key] = false;
		}
		trackingConfig = updated;
	}

	if (isEnvBrowser()) {
		for (const cat of TRACKING_CATEGORIES) {
			trackingConfig[cat.key] = cat.key !== "searches";
		}
	}

	onMount(() => {
		loadTrackingConfig();
	});
</script>

<div class="tracking-page">
	<div class="tracking-card">
		<div class="card-title-row">
			<span class="card-label">Activity Tracking</span>
			<div class="tracking-actions">
				<button class="action-btn" onclick={enableAll}>Enable All</button>
				<button class="action-btn" onclick={disableAll}>Disable All</button>
			</div>
		</div>
		<p class="card-subtitle">Configure which actions are logged in the activity feed. Changes apply department-wide.</p>

		{#if isLoadingTracking}
			<div class="tracking-loading">
				<div class="loading-spinner"></div>
				<p>Loading tracking settings...</p>
			</div>
		{:else}
			<div class="tracking-scroll">
				<div class="tracking-grid">
					{#each TRACKING_CATEGORIES as category}
						<div class="tracking-row">
							<div class="setting-info">
								<span class="setting-label">{category.label}</span>
								<span class="setting-desc">{category.description}</span>
							</div>
							<label class="toggle">
								<input
									type="checkbox"
									checked={trackingConfig[category.key] === true}
									onchange={() => toggleCategory(category.key)}
								/>
								<span class="toggle-slider"></span>
							</label>
						</div>
					{/each}
				</div>
			</div>
		{/if}
	</div>

	{#if !isLoadingTracking}
		<div class="save-bar">
			<button class="btn-save" onclick={saveTrackingConfig} disabled={isSavingTracking}>
				<span class="material-icons btn-save-icon">save</span>
				{isSavingTracking ? "Saving..." : "Save Settings"}
			</button>
			{#if trackingStatus}
				<span class="save-status {trackingStatus.type}">{trackingStatus.text}</span>
			{/if}
		</div>
	{/if}
</div>

<style>
	.tracking-page {
		height: 100%;
		display: flex;
		flex-direction: column;
		overflow: hidden;
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
		animation: fadeIn 0.2s ease-out;
	}

	.save-status.success { color: rgba(110, 231, 183, 0.8); }
	.save-status.error { color: rgba(252, 165, 165, 0.8); }

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

	.btn-save:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.btn-save:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.btn-save-icon {
		font-size: 13px;
	}

	@keyframes fadeIn {
		0% { opacity: 0; }
		100% { opacity: 1; }
	}

	.tracking-card {
		background: transparent;
		border: none;
		border-radius: 0;
		padding: 12px 16px;
		flex: 1;
		min-height: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.tracking-scroll {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
	}

	.tracking-scroll::-webkit-scrollbar {
		width: 4px;
	}

	.tracking-scroll::-webkit-scrollbar-track {
		background: transparent;
	}

	.tracking-scroll::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	.card-label {
		display: block;
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.45);
		margin-bottom: 0;
		padding-bottom: 0;
		border-bottom: none;
	}

	.card-title-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.card-subtitle {
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		margin: 6px 0 12px 0;
		padding-bottom: 10px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.tracking-actions {
		display: flex;
		gap: 4px;
	}

	.action-btn {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
		padding: 2px 8px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.action-btn:hover {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.7);
	}

	.tracking-loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 100px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
	}

	.loading-spinner {
		width: 24px;
		height: 24px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left: 2px solid rgba(var(--accent-rgb), 0.5);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 10px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.tracking-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0 20px;
	}

	.tracking-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 7px 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
	}

	.tracking-row:last-child,
	.tracking-row:nth-last-child(2):nth-child(odd) {
		border-bottom: none;
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

	@media (max-width: 900px) {
		.tracking-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
