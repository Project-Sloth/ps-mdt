<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { useNuiEvent } from "../utils/useNuiEvent";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { openReportInEditor } from "../stores/reportsStore";
	import type { createTabService } from "../services/tabService.svelte";
	import { globalNotifications } from "../services/notificationService.svelte";

	let { tabService }: { tabService: ReturnType<typeof createTabService> } = $props();

	interface Warrant {
		reportid: number | string;
		citizenid: string;
		name: string;
		felonies: number;
		misdemeanors: number;
		infractions: number;
		expirydate: string;
	}

	let warrants = $state<Warrant[]>([]);
	let isLoading = $state(false);
	let searchQuery = $state("");

	let filteredWarrants = $derived.by(() => {
		const query = searchQuery.trim().toLowerCase();
		if (!query) return warrants;
		return warrants.filter((warrant) =>
			[warrant.name, warrant.citizenid, String(warrant.reportid)].some(
				(value) => String(value).toLowerCase().includes(query),
			),
		);
	});

	function formatExpiry(value: string): string {
		if (!value) return "Unknown";
		const date = new Date(value);
		if (Number.isNaN(date.getTime())) return value;
		return date.toLocaleDateString("en-US", {
			month: "2-digit",
			day: "2-digit",
			year: "numeric",
		});
	}

	function openReport(reportId: number | string) {
		if (!reportId) return;
		openReportInEditor(String(reportId));
		tabService.setActiveTab("Reports");
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, "Reports");
		}
	}

	function createWarrantReport() {
		openReportInEditor("new");
		tabService.setActiveTab("Reports");
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, "Reports");
		}
	}

	async function loadWarrants() {
		try {
			isLoading = true;
			const response = await fetchNui<Warrant[]>(
				NUI_EVENTS.DASHBOARD.GET_ACTIVE_WARRANTS,
			);
			warrants = Array.isArray(response) ? response : [];
		} catch (error) {
			globalNotifications.error("Failed to load warrants");
			warrants = [];
		} finally {
			isLoading = false;
		}
	}

	onMount(() => {
		if (isEnvBrowser()) {
			warrants = [
				{ reportid: 1, citizenid: 'ABC123', name: 'Marcus Johnson', felonies: 2, misdemeanors: 1, infractions: 0, expirydate: new Date(Date.now() + 7 * 86400000).toISOString() },
				{ reportid: 3, citizenid: 'DEF456', name: 'David Chen', felonies: 0, misdemeanors: 3, infractions: 2, expirydate: new Date(Date.now() + 14 * 86400000).toISOString() },
				{ reportid: 7, citizenid: 'GHI789', name: 'James Miller', felonies: 1, misdemeanors: 0, infractions: 0, expirydate: new Date(Date.now() + 3 * 86400000).toISOString() },
				{ reportid: 12, citizenid: 'JKL012', name: 'Tony Ramirez', felonies: 0, misdemeanors: 0, infractions: 4, expirydate: new Date(Date.now() + 30 * 86400000).toISOString() },
			];
			return;
		}
		loadWarrants();
	});

	useNuiEvent<Warrant[]>(
		NUI_EVENTS.DASHBOARD.UPDATE_ACTIVE_WARRANTS,
		(data) => {
			warrants = Array.isArray(data) ? data : [];
		},
	);
</script>

<div class="warrants-page">
	<div class="topbar">
		<input
			type="text"
			placeholder="Search by name, ID, or report..."
			bind:value={searchQuery}
			class="search-input"
		/>
		<div class="topbar-actions">
			<span class="result-count">{filteredWarrants.length} warrant{filteredWarrants.length !== 1 ? "s" : ""}</span>
			<button
				class="btn-secondary"
				onclick={loadWarrants}
				disabled={isLoading}
			>
				{isLoading ? "Loading..." : "Refresh"}
			</button>
			<button
				class="btn-primary"
				onclick={createWarrantReport}
			>
				New Warrant
			</button>
		</div>
	</div>

	<div class="list-panel">
		<div class="table-header">
			<span>Name</span>
			<span>Citizen ID</span>
			<span>Report</span>
			<span>Felonies</span>
			<span>Misdemeanors</span>
			<span>Infractions</span>
			<span>Expires</span>
			<span></span>
		</div>

		<div class="table-body">
			{#if isLoading && warrants.length === 0}
				<div class="empty-state">
					<div class="loading-spinner"></div>
					<p>Loading warrants...</p>
				</div>
			{:else if filteredWarrants.length === 0}
				<div class="empty-state">
					<p class="empty-title">No Warrants Found</p>
					<p class="empty-sub">
						{searchQuery
							? "No warrants match your search criteria."
							: "No active warrants available."}
					</p>
				</div>
			{:else}
				{#each filteredWarrants as warrant}
					<button class="table-row" onclick={() => openReport(warrant.reportid)}>
						<span class="cell-name">{warrant.name}</span>
						<span class="cell-id">{warrant.citizenid}</span>
						<span class="cell-report">#{warrant.reportid}</span>
						<span>
							{#if warrant.felonies > 0}
								<span class="pill pill-red">{warrant.felonies}</span>
							{:else}
								<span class="cell-muted">0</span>
							{/if}
						</span>
						<span>
							{#if warrant.misdemeanors > 0}
								<span class="pill pill-orange">{warrant.misdemeanors}</span>
							{:else}
								<span class="cell-muted">0</span>
							{/if}
						</span>
						<span>
							{#if warrant.infractions > 0}
								<span class="pill pill-grey">{warrant.infractions}</span>
							{:else}
								<span class="cell-muted">0</span>
							{/if}
						</span>
						<span class="cell-date">{formatExpiry(warrant.expirydate)}</span>
						<span class="cell-action">
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>
						</span>
					</button>
				{/each}
			{/if}
		</div>
	</div>
</div>

<style>
	.warrants-page {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
		overflow: hidden;
	}

	.topbar {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 0 16px;
		height: 42px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.search-input {
		flex: 1;
		max-width: 360px;
		background: transparent;
		border: none;
		padding: 0;
		color: rgba(255, 255, 255, 0.8);
		font-size: 12px;
	}

	.search-input:focus {
		outline: none;
	}

	.search-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.topbar-actions {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-left: auto;
	}

	.result-count {
		color: rgba(255, 255, 255, 0.2);
		font-size: 10px;
	}

	.btn-secondary {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-secondary:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.btn-secondary:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.btn-primary {
		background: rgba(var(--accent-rgb), 0.06);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-primary:hover {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.list-panel {
		flex: 1;
		min-height: 0;
		background: transparent;
		border: none;
		border-radius: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.table-header {
		display: grid;
		grid-template-columns: 1.5fr 0.8fr 0.6fr 0.7fr 0.9fr 0.7fr 0.8fr 40px;
		gap: 8px;
		padding: 8px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.35);
	}

	.table-body {
		flex: 1;
		overflow-y: auto;
	}

	.table-row {
		display: grid;
		grid-template-columns: 1.5fr 0.8fr 0.6fr 0.7fr 0.9fr 0.7fr 0.8fr 40px;
		gap: 8px;
		padding: 7px 16px;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		background: transparent;
		color: rgba(255, 255, 255, 0.85);
		font-size: 11px;
		cursor: pointer;
		transition: background 0.1s;
		text-align: left;
		width: 100%;
		align-items: center;
	}

	.table-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.table-row:last-child {
		border-bottom: none;
	}

	.cell-name {
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.cell-id {
		font-family: monospace;
		font-size: 10px;
		color: rgba(255, 255, 255, 0.35);
	}

	.cell-report {
		color: rgba(var(--accent-text-rgb), 0.7);
		font-weight: 500;
		font-size: 10px;
	}

	.cell-muted {
		color: rgba(255, 255, 255, 0.2);
	}

	.cell-date {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.cell-action {
		display: flex;
		align-items: center;
		justify-content: center;
		color: rgba(255, 255, 255, 0.15);
		transition: color 0.1s;
	}

	.table-row:hover .cell-action {
		color: rgba(var(--accent-text-rgb), 0.7);
	}

	.pill {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 600;
		min-width: 18px;
	}

	.pill-red {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(252, 165, 165, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	.pill-orange {
		background: rgba(249, 115, 22, 0.08);
		color: rgba(253, 186, 116, 0.8);
		border: 1px solid rgba(249, 115, 22, 0.1);
	}

	.pill-grey {
		background: rgba(255, 255, 255, 0.03);
		color: rgba(255, 255, 255, 0.4);
		border: 1px solid rgba(255, 255, 255, 0.05);
	}

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 300px;
		text-align: center;
		color: rgba(255, 255, 255, 0.35);
	}

	.empty-title {
		font-size: 14px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.4);
		margin: 0 0 4px;
	}

	.empty-sub {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.35);
		margin: 0;
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

	.table-body::-webkit-scrollbar {
		width: 4px;
	}

	.table-body::-webkit-scrollbar-track {
		background: transparent;
	}

	.table-body::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}
</style>
