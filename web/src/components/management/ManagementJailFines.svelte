<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../../utils/fetchNui";
	import { isEnvBrowser } from "../../utils/misc";
	import { NUI_EVENTS } from "../../constants/nuiEvents";

	interface JailFinesConfig {
		reductionOffers: number[];
		maxFineAmount: number;
	}

	let config: JailFinesConfig = $state({
		reductionOffers: [10, 25, 50],
		maxFineAmount: 100000,
	});

	let isLoading = $state(false);
	let isSaving = $state(false);
	let statusMsg: { text: string; type: "success" | "error" } | null = $state(null);
	let newOfferValue = $state("");

	function showStatus(text: string, type: "success" | "error" = "success") {
		statusMsg = { text, type };
		setTimeout(() => { statusMsg = null; }, 3000);
	}

	async function loadConfig() {
		if (isEnvBrowser()) return;
		try {
			isLoading = true;
			const response = await fetchNui<JailFinesConfig>(
				NUI_EVENTS.SETTINGS.GET_JAIL_FINES_CONFIG,
				{},
				{ reductionOffers: [10, 25, 50], maxFineAmount: 100000 },
			);
			if (response && typeof response === "object") {
				config = {
					reductionOffers: Array.isArray(response.reductionOffers) ? [...response.reductionOffers] : [10, 25, 50],
					maxFineAmount: response.maxFineAmount ?? 100000,
				};
			}
		} catch (error) {
			console.error("Failed to load jail/fines config:", error);
		} finally {
			isLoading = false;
		}
	}

	async function saveConfig() {
		if (isEnvBrowser()) {
			showStatus("Settings saved");
			return;
		}
		try {
			isSaving = true;
			const result = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.SETTINGS.SAVE_JAIL_FINES_CONFIG,
				config,
				{ success: false },
			);
			if (result?.success) {
				showStatus("Jail & Fines settings saved");
			} else {
				showStatus(result?.message || "Failed to save settings", "error");
			}
		} catch (error) {
			console.error("Failed to save jail/fines config:", error);
			showStatus("Failed to save settings", "error");
		} finally {
			isSaving = false;
		}
	}

	function addOffer() {
		const val = parseInt(newOfferValue, 10);
		if (!val || val < 1 || val > 100) {
			showStatus("Enter a value between 1 and 100", "error");
			return;
		}
		if (config.reductionOffers.includes(val)) {
			showStatus("That percentage already exists", "error");
			return;
		}
		config.reductionOffers = [...config.reductionOffers, val].sort((a, b) => a - b);
		newOfferValue = "";
	}

	function removeOffer(val: number) {
		config.reductionOffers = config.reductionOffers.filter((v) => v !== val);
	}

	function handleOfferKeydown(e: KeyboardEvent) {
		if (e.key === "Enter") {
			e.preventDefault();
			addOffer();
		}
	}

	onMount(() => {
		loadConfig();
	});
</script>

<div class="jf-page">
	<div class="jf-card">
		<span class="card-label">Jail & Fines Configuration</span>
		<p class="card-subtitle">Configure reduction offers and fine limits. Changes apply department-wide.</p>

		{#if isLoading}
			<div class="jf-loading">
				<div class="loading-spinner"></div>
				<p>Loading settings...</p>
			</div>
		{:else}
			<div class="jf-scroll">
				<!-- Reduction Offers -->
				<div class="setting-group">
					<div class="setting-group-header">
						<span class="group-label">Reduction Offers</span>
						<span class="group-desc">Percentage options shown when offering a reduction on charges</span>
					</div>

					<div class="offers-list">
						{#each config.reductionOffers as offer}
							<div class="offer-chip">
								<span class="offer-value">{offer}%</span>
								<button class="offer-remove" onclick={() => removeOffer(offer)} aria-label="Remove {offer}%">
									<svg width="8" height="8" viewBox="0 0 24 24" fill="currentColor"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
								</button>
							</div>
						{/each}
						{#if config.reductionOffers.length === 0}
							<span class="no-offers">No reduction offers configured</span>
						{/if}
					</div>

					<div class="add-offer-row">
						<input
							type="number"
							class="offer-input"
							placeholder="e.g. 25"
							min="1"
							max="100"
							bind:value={newOfferValue}
							onkeydown={handleOfferKeydown}
						/>
						<span class="offer-input-suffix">%</span>
						<button class="add-offer-btn" onclick={addOffer}>Add</button>
					</div>
				</div>

				<!-- Max Fine Amount -->
				<div class="setting-group">
					<div class="setting-group-header">
						<span class="group-label">Maximum Fine Amount</span>
						<span class="group-desc">The highest fine amount that can be processed through the MDT</span>
					</div>

					<div class="fine-input-row">
						<span class="fine-prefix">$</span>
						<input
							type="number"
							class="fine-input"
							min="0"
							bind:value={config.maxFineAmount}
						/>
					</div>
				</div>
			</div>
		{/if}
	</div>

	{#if !isLoading}
		<div class="save-bar">
			<button class="btn-save" onclick={saveConfig} disabled={isSaving}>
				<span class="material-icons btn-save-icon">save</span>
				{isSaving ? "Saving..." : "Save Settings"}
			</button>
			{#if statusMsg}
				<span class="save-status {statusMsg.type}">{statusMsg.text}</span>
			{/if}
		</div>
	{/if}
</div>

<style>
	.jf-page {
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
		padding: 5px 16px;
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

	.jf-card {
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

	.jf-scroll {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
	}

	.jf-scroll::-webkit-scrollbar {
		width: 4px;
	}

	.jf-scroll::-webkit-scrollbar-track {
		background: transparent;
	}

	.jf-scroll::-webkit-scrollbar-thumb {
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
	}

	.card-subtitle {
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		margin: 6px 0 12px 0;
		padding-bottom: 10px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.jf-loading {
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

	/* Setting Groups */
	.setting-group {
		margin-bottom: 16px;
	}

	.setting-group-header {
		margin-bottom: 8px;
	}

	.group-label {
		display: block;
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.8);
		margin-bottom: 2px;
	}

	.group-desc {
		display: block;
		font-size: 10px;
		color: rgba(255, 255, 255, 0.35);
	}

	/* Offers */
	.offers-list {
		display: flex;
		flex-wrap: wrap;
		gap: 5px;
		margin-bottom: 8px;
	}

	.offer-chip {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		background: rgba(var(--accent-rgb), 0.06);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		border-radius: 3px;
		padding: 2px 8px 2px 10px;
	}

	.offer-value {
		font-size: 10px;
		font-weight: 600;
		color: rgba(var(--accent-text-rgb), 0.7);
	}

	.offer-remove {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 14px;
		height: 14px;
		background: rgba(239, 68, 68, 0.1);
		border: none;
		border-radius: 50%;
		color: rgba(255, 255, 255, 0.4);
		cursor: pointer;
		transition: all 0.1s;
	}

	.offer-remove:hover {
		background: rgba(239, 68, 68, 0.25);
		color: rgba(255, 255, 255, 0.8);
	}

	.no-offers {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.2);
		font-style: italic;
	}

	.add-offer-row {
		display: flex;
		align-items: center;
		gap: 4px;
	}

	.offer-input {
		width: 60px;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 6px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 10px;
		text-align: center;
		outline: none;
	}

	.offer-input:focus {
		border-color: rgba(255, 255, 255, 0.12);
	}

	.offer-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.offer-input-suffix {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.3);
		font-weight: 500;
	}

	.add-offer-btn {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.4);
		padding: 4px 10px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
		margin-left: 4px;
	}

	.add-offer-btn:hover {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.7);
	}

	/* Fine input */
	.fine-input-row {
		display: flex;
		align-items: center;
		gap: 4px;
	}

	.fine-prefix {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.35);
	}

	.fine-input {
		width: 120px;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		outline: none;
	}

	.fine-input:focus {
		border-color: rgba(255, 255, 255, 0.12);
	}
</style>
