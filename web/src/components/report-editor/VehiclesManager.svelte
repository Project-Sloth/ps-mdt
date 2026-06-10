<script lang="ts">
	import type { ReportVehicle } from "../../interfaces/IReportEditor";
	import { fetchNui } from "../../utils/fetchNui";
	import { isEnvBrowser } from "../../utils/misc";
	import { NUI_EVENTS } from "../../constants/nuiEvents";

	interface Props {
		vehicles: ReportVehicle[];
		onAdd: (vehicle: ReportVehicle) => void;
		onRemove: (plate: string) => void;
		onIssueBolo?: (vehicle: ReportVehicle) => void;
	}

	let { vehicles, onAdd, onRemove, onIssueBolo }: Props = $props();

	let searchQuery = $state("");
	let searchResults = $state<ReportVehicle[]>([]);
	let isSearching = $state(false);
	let showSearch = $state(false);
	let searchTimeout: ReturnType<typeof setTimeout> | null = null;

	function toggleSearch() {
		showSearch = !showSearch;
		if (!showSearch) {
			searchQuery = "";
			searchResults = [];
		}
	}

	function handleSearchInput(e: Event) {
		const value = (e.target as HTMLInputElement).value;
		searchQuery = value;
		if (searchTimeout) clearTimeout(searchTimeout);
		if (!value.trim()) {
			searchResults = [];
			return;
		}
		searchTimeout = setTimeout(() => performSearch(value.trim()), 300);
	}

	async function performSearch(query: string) {
		if (!query) return;
		isSearching = true;
		try {
			if (isEnvBrowser()) {
				searchResults = [
					{ plate: "ABC 123", vehicle_label: "Karin Sultan", owner_name: "Marcus Johnson", owner_citizenid: "ABC12345" },
					{ plate: "XYZ 789", vehicle_label: "Truffade Adder", owner_name: "Sarah Williams", owner_citizenid: "DEF67890" },
				];
			} else {
				const results = await fetchNui<ReportVehicle[]>(
					NUI_EVENTS.REPORT.SEARCH_VEHICLES_FOR_REPORT,
					{ query },
					[],
				);
				searchResults = Array.isArray(results) ? results : [];
			}
		} catch {
			searchResults = [];
		}
		isSearching = false;
	}

	function addVehicle(vehicle: ReportVehicle) {
		onAdd(vehicle);
		searchResults = searchResults.filter(r => r.plate !== vehicle.plate);
	}

	function isAlreadyAdded(plate: string): boolean {
		return vehicles.some(v => v.plate === plate);
	}
</script>

<div class="metadata-section">
	<div class="section-header">
		<span class="section-label">VEHICLES INVOLVED</span>
		<button class="add-btn" onclick={toggleSearch} type="button">
			{showSearch ? "× Close" : "+ Add"}
		</button>
	</div>

	{#if showSearch}
		<div class="search-area">
			<input
				type="text"
				placeholder="Search by plate, owner name..."
				value={searchQuery}
				oninput={handleSearchInput}
				class="search-input"
			/>
			{#if isSearching}
				<div class="search-status">Searching...</div>
			{:else if searchResults.length > 0}
				<div class="search-results">
					{#each searchResults as result}
						<button
							class="search-result"
							disabled={isAlreadyAdded(result.plate)}
							onclick={() => addVehicle(result)}
							type="button"
						>
							<span class="result-plate">{result.plate}</span>
							<span class="result-label">{result.vehicle_label}</span>
							<span class="result-owner">{result.owner_name}</span>
							{#if isAlreadyAdded(result.plate)}
								<span class="result-added">Added</span>
							{/if}
						</button>
					{/each}
				</div>
			{:else if searchQuery.trim().length > 0}
				<div class="search-status">No vehicles found</div>
			{/if}
		</div>
	{/if}

	{#each vehicles as vehicle}
		<div class="vehicle-card">
			<div class="card-header">
				<div class="vehicle-info">
					<span class="vehicle-plate">{vehicle.plate}</span>
					<span class="vehicle-secondary">{vehicle.vehicle_label}</span>
				</div>
				<button class="remove-btn" onclick={() => onRemove(vehicle.plate)} type="button" aria-label="Remove vehicle">
					<svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor">
						<path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" />
					</svg>
				</button>
			</div>
			<span class="vehicle-owner">Owner: {vehicle.owner_name}</span>
			{#if onIssueBolo}
				<div class="vehicle-actions">
					<button
						class="action-btn bolo"
						onclick={() => onIssueBolo(vehicle)}
						disabled={!vehicle.plate}
						type="button"
						aria-label="Issue BOLO for vehicle {vehicle.plate}"
					>
						Issue BOLO
					</button>
				</div>
			{/if}
		</div>
	{/each}
</div>

<style>
	.metadata-section {
		padding-bottom: 12px;
		margin-bottom: 12px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.metadata-section:last-child {
		margin-bottom: 0;
		padding-bottom: 0;
		border-bottom: none;
	}

	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 8px;
	}

	.section-label {
		font-size: 10px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.3);
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}

	.add-btn {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.35);
		cursor: pointer;
		font-size: 10px;
		font-weight: 500;
		padding: 2px 6px;
		transition: color 0.1s;
	}

	.add-btn:hover {
		color: rgba(255, 255, 255, 0.5);
	}

	/* ── Search ── */
	.search-area {
		margin-bottom: 8px;
	}

	.search-input {
		width: 100%;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 4px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.7);
		font-size: 11px;
		outline: none;
		box-sizing: border-box;
	}

	.search-input:focus {
		border-color: rgba(255, 255, 255, 0.1);
	}

	.search-input::placeholder {
		color: rgba(255, 255, 255, 0.4);
	}

	.search-status {
		color: rgba(255, 255, 255, 0.4);
		font-size: 11px;
		padding: 6px 0;
		text-align: center;
	}

	.search-results {
		display: flex;
		flex-direction: column;
		gap: 2px;
		margin-top: 4px;
		max-height: 150px;
		overflow-y: auto;
	}

	.search-result {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 5px 8px;
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 4px;
		cursor: pointer;
		transition: background 0.12s;
		text-align: left;
		font: inherit;
		color: inherit;
		width: 100%;
	}

	.search-result:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.06);
	}

	.search-result:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.result-plate {
		font-family: monospace;
		font-size: 11px;
		font-weight: 600;
		color: #93c5fd;
		letter-spacing: 0.5px;
		flex-shrink: 0;
	}

	.result-label {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.7);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.result-owner {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.4);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		margin-left: auto;
	}

	.result-added {
		font-size: 10px;
		color: rgba(16, 185, 129, 0.7);
		font-weight: 600;
		flex-shrink: 0;
	}

	/* ── Vehicle Cards ── */
	.vehicle-card {
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		border-radius: 0;
		padding: 8px 0;
		margin-bottom: 0;
	}

	.vehicle-card:last-child {
		border-bottom: none;
		margin-bottom: 0;
	}

	.vehicle-card:hover .remove-btn {
		opacity: 1;
	}

	.card-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 8px;
		margin-bottom: 2px;
	}

	.vehicle-info {
		display: flex;
		align-items: baseline;
		gap: 7px;
		flex: 1;
	}

	.vehicle-plate {
		font-family: monospace;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
		font-size: 12px;
		letter-spacing: 0.5px;
	}

	.vehicle-secondary {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.3);
	}

	.vehicle-owner {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.35);
	}

	.remove-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 14px;
		height: 14px;
		background: rgba(239, 68, 68, 0.12);
		border: none;
		border-radius: 50%;
		color: rgba(255, 255, 255, 0.5);
		cursor: pointer;
		flex-shrink: 0;
		opacity: 0;
		transition: opacity 0.1s;
	}

	.remove-btn:hover {
		background: rgba(239, 68, 68, 0.25);
	}

	.vehicle-actions {
		display: flex;
		gap: 5px;
		margin-top: 4px;
	}

	.action-btn {
		padding: 3px 7px;
		border-radius: 3px;
		border: 1px solid rgba(255, 255, 255, 0.05);
		background: transparent;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.action-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.6);
	}

	.action-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.action-btn.bolo {
		background: rgba(245, 158, 11, 0.06);
		border-color: rgba(245, 158, 11, 0.1);
		color: rgba(251, 191, 36, 0.7);
	}

	.action-btn.bolo:hover:not(:disabled) {
		background: rgba(245, 158, 11, 0.12);
		color: rgba(251, 191, 36, 0.9);
	}
</style>
