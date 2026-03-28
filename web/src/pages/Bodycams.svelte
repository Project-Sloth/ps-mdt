<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { globalNotifications } from "../services/notificationService.svelte";

	let bodycams = $state<Bodycam[]>([]);
	let isLoading = $state(false);
	let searchQuery = $state("");

	type Bodycam = {
		id: number | string;
		officerName: string;
		callsign: string;
		rank: string;
		isOnline: boolean;
		viewerCount: number;
	};

	type GetBodycamsResponse = {
		data?: Bodycam[];
		[key: string]: any;
	};

	let filteredBodycams = $derived.by(() => {
		const query = searchQuery.trim().toLowerCase();
		return !query
			? bodycams
			: bodycams.filter(
					(bodycam) =>
						bodycam.officerName.toLowerCase().includes(query) ||
						bodycam.callsign.toLowerCase().includes(query) ||
						bodycam.rank.toLowerCase().includes(query),
				);
	});

	async function loadBodycams() {
		if (isEnvBrowser()) {
			return;
		}

		try {
			isLoading = true;
			const response = await fetchNui<GetBodycamsResponse>(
				NUI_EVENTS.BODYCAM.GET_BODYCAMS,
				{},
				[],
			);
			bodycams =
				response.data ??
				(Array.isArray(response) ? response : []) ??
				[];
		} catch (error) {
			globalNotifications.error("Failed to load bodycams");
			bodycams = [];
		} finally {
			isLoading = false;
		}
	}

	onMount(() => {
		if (isEnvBrowser()) {
			bodycams = [
				{
					id: "001",
					officerName: "John Smith",
					callsign: "401",
					rank: "Chief",
					isOnline: true,
					viewerCount: 5,
				},
				{
					id: "002",
					officerName: "Sarah Johnson",
					callsign: "405",
					rank: "Sergeant",
					isOnline: true,
					viewerCount: 0,
				},
				{
					id: "003",
					officerName: "Michael Davis",
					callsign: "455",
					rank: "Deputy",
					isOnline: false,
					viewerCount: 0,
				},
				{
					id: "004",
					officerName: "Emily Brown",
					callsign: "496",
					rank: "Officer",
					isOnline: true,
					viewerCount: 2,
				},
				{
					id: "005",
					officerName: "Robert Wilson",
					callsign: "431",
					rank: "Sergeant",
					isOnline: true,
					viewerCount: 0,
				},
				{
					id: "006",
					officerName: "Lisa Garcia",
					callsign: "402",
					rank: "Assistant Chief",
					isOnline: false,
					viewerCount: 0,
				},
			];
		} else {
			loadBodycams();
		}
	});

	function viewBodycam(bodycam: any) {
		fetchNui(NUI_EVENTS.BODYCAM.VIEW_BODYCAM, bodycam.id);
	}
</script>

<div class="bodycams-page">
	<div class="topbar">
		<input
			type="text"
			placeholder="Search by name, callsign or rank..."
			bind:value={searchQuery}
			class="search-input"
		/>
		<div class="topbar-right">
			<span class="result-count">{filteredBodycams.length} officer{filteredBodycams.length !== 1 ? "s" : ""}</span>
			<button
				class="btn-secondary"
				onclick={loadBodycams}
				disabled={isLoading}
			>
				{isLoading ? "Loading..." : "Refresh"}
			</button>
		</div>
	</div>

	<div class="list-panel">
		<div class="table-header">
			<span class="col-callsign">Callsign</span>
			<span class="col-name">Officer</span>
			<span class="col-rank">Rank</span>
			<span class="col-status">Status</span>
			<span class="col-viewers">Viewers</span>
			<span class="col-action"></span>
		</div>

		<div class="table-body">
			{#if isLoading && bodycams.length === 0}
				<div class="empty-state">
					<div class="loading-spinner"></div>
					<p>Loading bodycams...</p>
				</div>
			{:else if filteredBodycams.length === 0}
				<div class="empty-state">
					<p class="empty-title">No Bodycams Found</p>
					<p class="empty-sub">
						{searchQuery
							? "No officers match your search criteria."
							: "No officers with bodycams are currently on duty."}
					</p>
				</div>
			{:else}
				{#each filteredBodycams as bodycam (bodycam.id)}
					<div class="table-row">
						<span class="col-callsign">
							<span class="callsign-tag">{bodycam.callsign}</span>
						</span>
						<span class="col-name">{bodycam.officerName}</span>
						<span class="col-rank">{bodycam.rank}</span>
						<span class="col-status">
							{#if bodycam.isOnline}
								<span class="pill pill-green">Online</span>
							{:else}
								<span class="pill pill-grey">Offline</span>
							{/if}
						</span>
						<span class="col-viewers">
							{#if bodycam.viewerCount > 0}
								<span class="viewer-count">{bodycam.viewerCount}</span>
							{:else}
								<span class="muted">0</span>
							{/if}
						</span>
						<span class="col-action">
							{#if bodycam.isOnline}
								<button class="view-btn" onclick={() => viewBodycam(bodycam)}>
									<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
									View
								</button>
							{/if}
						</span>
					</div>
				{/each}
			{/if}
		</div>
	</div>
</div>

<style>
	.bodycams-page {
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

	.topbar-right {
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
		grid-template-columns: 80px 1.5fr 1fr 80px 70px 80px;
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

	.table-row {
		display: grid;
		grid-template-columns: 80px 1.5fr 1fr 80px 70px 80px;
		gap: 8px;
		padding: 7px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		font-size: 11px;
		align-items: center;
		transition: background 0.1s;
	}

	.table-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.table-row:last-child {
		border-bottom: none;
	}

	.col-name {
		font-weight: 500;
		color: rgba(255, 255, 255, 0.85);
		font-size: 11px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.col-rank {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.col-viewers {
		text-align: center;
	}

	.col-action {
		text-align: right;
	}

	.callsign-tag {
		font-size: 10px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.35);
		font-family: monospace;
		background: rgba(255, 255, 255, 0.03);
		padding: 1px 6px;
		border-radius: 3px;
	}

	.pill {
		display: inline-flex;
		align-items: center;
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
	}

	.pill-green {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(110, 231, 183, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.pill-grey {
		background: rgba(255, 255, 255, 0.03);
		color: rgba(255, 255, 255, 0.4);
		border: 1px solid rgba(255, 255, 255, 0.05);
	}

	.viewer-count {
		color: rgba(255, 255, 255, 0.6);
		font-weight: 500;
		font-size: 11px;
	}

	.muted {
		color: rgba(255, 255, 255, 0.15);
	}

	.view-btn {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		background: rgba(var(--accent-rgb), 0.06);
		color: rgba(var(--accent-text-rgb), 0.7);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		padding: 2px 8px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.view-btn:hover {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
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
</style>
