<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { globalNotifications } from "../services/notificationService.svelte";
	import { openReportInEditor } from "../stores/reportsStore";
	import type { createTabService } from "../services/tabService.svelte";
	import Pagination from "../components/Pagination.svelte";

	let { tabService }: { tabService: ReturnType<typeof createTabService> } = $props();

	interface Vehicle {
		id: number;
		model: string;
		label: string;
		plate: string;
		owner: string;
		class: string;
		type: string;
		flags: string[];
		image?: string;
		seenIn?: number;
		points?: number;
		status?: string;
		core_state?: number;
	}

	interface VehicleDetails extends Vehicle {
		brand?: string;
		information?: string;
		stolen?: boolean;
		boloactive?: boolean;
		core_state?: number;
		bolos?: Array<{
			id: number;
			reportId: string;
			notes: string;
			status: string;
			type: string;
		}>;
	}

	let vehicleList: Vehicle[] = $state([]);
	let searchQuery = $state("");
	let loading = $state(false);
	let selectedVehicle: VehicleDetails | null = $state(null);
	let vehicleDetailLoading = $state(false);
	let vehicleDetailError = $state<string | null>(null);
	let vehicleSaving = $state(false);
	let vehicleForm = $state({
		points: 0,
		status: "valid",
		reason: "",
	});

	let linkedReports: Array<{ id: number; title: string; type: string; datecreated: string; authorplaintext: string }> = $state([]);
	let linkedReportsLoading = $state(false);

	let statusFilter = $state("all");

	let vehiclePage = $state(1);
	let vehiclePerPage = $state(25);

	let allFilteredVehicles = $derived.by(() => {
		let list = vehicleList;

		// Status filter
		if (statusFilter !== "all") {
			if (statusFilter === "active") {
				list = list.filter(v => (v.status === "valid" || !v.status) && v.core_state === 0);
			} else if (statusFilter === "garaged") {
				list = list.filter(v => v.core_state === 1);
			} else if (statusFilter === "impounded") {
				list = list.filter(v => v.core_state === 2 || v.status === "impounded");
			} else if (statusFilter === "stolen") {
				list = list.filter(v => v.status === "stolen" || v.flags?.includes("Stolen"));
			}
		}

		// Text search
		const query = searchQuery.trim().toLowerCase();
		if (query) {
			list = list.filter(({ label, plate, owner, class: vehicleClass, type }) =>
				[label, plate, owner, vehicleClass, type].some(val => val?.toLowerCase().includes(query))
			);
		}

		return list;
	});

	let filteredVehicles = $derived.by(() => {
		const start = (vehiclePage - 1) * vehiclePerPage;
		return allFilteredVehicles.slice(start, start + vehiclePerPage);
	});

	// Reset page on search
	$effect(() => {
		searchQuery;
		vehiclePage = 1;
	});

	function getFlagClass(flag: string): string {
		switch (flag) {
			case "Stolen": return "pill pill-red";
			case "Active Warrant": return "pill pill-red";
			case "Bolo": return "pill pill-orange";
			case "Flight Risk": return "pill pill-orange";
			default: return "pill pill-grey";
		}
	}

	function getStatusClass(status: string): string {
		switch (status?.toLowerCase()) {
			case "stolen": return "status-stolen";
			case "bolo": return "status-bolo";
			case "suspended": return "status-suspended";
			case "expired": return "status-expired";
			case "impounded": return "status-impounded";
			case "valid": return "status-valid";
			case "clear": return "status-valid";
			default: return "status-valid";
		}
	}

	async function viewVehicle(plate: string) {
		vehicleDetailError = null;
		vehicleDetailLoading = true;
		selectedVehicle = null;
		if (isEnvBrowser()) {
			const match = vehicleList.find(
				(vehicle) => vehicle.plate?.toLowerCase() === plate.toLowerCase(),
			);
			if (match) {
				selectedVehicle = {
					...match,
					information: "",
					stolen: match.flags?.includes("Stolen") || false,
					boloactive: match.flags?.includes("Bolo") || false,
					bolos: [],
				};
				vehicleForm.points = match.points ?? 0;
				vehicleForm.status = match.status ?? "valid";
				vehicleForm.reason = "";
				linkedReports = [
					{ id: 42, title: "Armed Robbery - Fleeca Bank", type: "Incident Report", datecreated: "2026-03-19", authorplaintext: "D2020 Ofc. Smith" },
				];
			}
			vehicleDetailLoading = false;
			return;
		}

		try {
			const response = await fetchNui(NUI_EVENTS.VEHICLE.GET_VEHICLE, { plate });
			if (response?.vehicle) {
				selectedVehicle = response.vehicle;
				vehicleForm.points = response.vehicle.points ?? 0;
				vehicleForm.status = response.vehicle.status ?? "valid";
				vehicleForm.reason = "";
			} else {
				vehicleDetailError = response?.message || "Failed to load vehicle";
			}
		} catch (error) {
			globalNotifications.error("Failed to load vehicle");
			vehicleDetailError = "Failed to load vehicle";
		} finally {
			vehicleDetailLoading = false;
		}

		// Load linked reports
		if (selectedVehicle) {
			linkedReportsLoading = true;
			try {
				const reportsResponse = await fetchNui<{ success: boolean; reports: typeof linkedReports }>(
					NUI_EVENTS.VEHICLE.GET_REPORTS_BY_PLATE,
					{ plate: selectedVehicle!.plate },
					{ success: true, reports: [] },
				);
				linkedReports = reportsResponse?.reports || [];
			} catch {
				linkedReports = [];
			}
			linkedReportsLoading = false;
		}
	}

	function goToReport(reportId: number | string) {
		openReportInEditor(String(reportId));
		tabService.setActiveTab("Reports");
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, "Reports");
		}
	}

	function closeVehicle() {
		selectedVehicle = null;
		vehicleDetailError = null;
		vehicleDetailLoading = false;
		vehicleSaving = false;
		linkedReports = [];
	}

	async function saveVehicle() {
		if (!selectedVehicle) return;
		vehicleSaving = true;
		try {
			const response = await fetchNui(NUI_EVENTS.VEHICLE.UPDATE_VEHICLE, {
				plate: selectedVehicle.plate,
				points: vehicleForm.points,
				status: vehicleForm.status,
			});
			if (!response?.success) {
				vehicleDetailError = response?.message || "Failed to update vehicle";
				return;
			}
			selectedVehicle = {
				...selectedVehicle,
				points: vehicleForm.points,
				status: vehicleForm.status,
			};
			vehicleList = vehicleList.map((vehicle) =>
				vehicle.plate === selectedVehicle?.plate
					? { ...vehicle, points: vehicleForm.points, status: vehicleForm.status }
					: vehicle,
			);
		} catch (error) {
			globalNotifications.error("Failed to update vehicle");
			vehicleDetailError = "Failed to update vehicle";
		} finally {
			vehicleSaving = false;
		}
	}

	onMount(async () => {
		if (isEnvBrowser()) {
			vehicleList = [
				{ id: 1, model: 'sultan', label: 'Karin Sultan', plate: 'ABC 123', owner: 'Marcus Johnson', class: 'Sports', type: 'car', flags: ['Stolen'], status: 'stolen', points: 3 },
				{ id: 2, model: 'adder', label: 'Truffade Adder', plate: 'XYZ 789', owner: 'Sarah Williams', class: 'Super', type: 'car', flags: [], status: 'valid', points: 0 },
				{ id: 3, model: 'bati801', label: 'Pegassi Bati 801', plate: 'MOT 456', owner: 'David Chen', class: 'Motorcycles', type: 'bike', flags: ['Bolo'], status: 'bolo', points: 1 },
				{ id: 4, model: 'zentorno', label: 'Pegassi Zentorno', plate: 'SPD 001', owner: 'LSPD Fleet', class: 'Super', type: 'car', flags: [], status: 'valid', points: 0 },
				{ id: 5, model: 'sanchez', label: 'Sanchez', plate: 'DRT 321', owner: 'James Miller', class: 'Off-Road', type: 'bike', flags: ['Active Warrant'], status: 'impounded', points: 6 },
			];
			loading = false;
		} else {
			loading = true;
			try {
				const response = await fetchNui(NUI_EVENTS.VEHICLE.GET_VEHICLES);
				vehicleList = Array.isArray(response.vehicles) ? response.vehicles : [];
			} catch (error) {
				globalNotifications.error("Failed to load vehicles");
				vehicleList = [];
			}
			loading = false;
		}
	});

	async function refreshVehicles() {
		if (isEnvBrowser()) return;
		loading = true;
		try {
			const response = await fetchNui(NUI_EVENTS.VEHICLE.GET_VEHICLES);
			vehicleList = Array.isArray(response.vehicles) ? response.vehicles : [];
		} catch (error) {
			globalNotifications.error("Failed to load vehicles");
			vehicleList = [];
		}
		loading = false;
	}
</script>

{#if selectedVehicle || vehicleDetailLoading || vehicleDetailError}
	<!-- Vehicle Detail View -->
	<div class="vehicles-page">
		<div class="topbar">
			<button class="back-btn" onclick={closeVehicle}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5"/><polyline points="12 19 5 12 12 5"/></svg>
				Back
			</button>
			{#if selectedVehicle}
				<div class="topbar-info">
					<span class="topbar-name">{selectedVehicle.label}</span>
					<span class="topbar-plate">{selectedVehicle.plate}</span>
				</div>
				<div class="topbar-flags">
					{#if selectedVehicle.stolen}
						<span class="pill pill-red">Stolen</span>
					{/if}
					{#if selectedVehicle.boloactive}
						<span class="pill pill-orange">BOLO</span>
					{/if}
					<span class="pill {getStatusClass(selectedVehicle.status || 'valid')}">{selectedVehicle.status || 'Valid'}</span>
				</div>
			{/if}
		</div>

		{#if vehicleDetailLoading}
			<div class="loading-state">Loading vehicle details...</div>
		{:else if vehicleDetailError}
			<div class="error-state">{vehicleDetailError}</div>
		{:else if selectedVehicle}
			<div class="detail-scroll">
				<!-- Vehicle Info Grid -->
				<div class="info-grid">
					<div class="info-card">
						<div class="info-card-icon">
							{#if selectedVehicle.image}
								<img src={selectedVehicle.image} alt="Vehicle" class="info-card-img" />
							{:else}
								<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M7 17m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"/><path d="M17 17m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"/><path d="M5 17H3v-6l2-5h9l4 5h1a2 2 0 0 1 2 2v4h-2m-4 0H9m-6-6h15m-6 0V6"/></svg>
							{/if}
						</div>
						<div class="info-card-body">
							<span class="info-card-label">Owner</span>
							<span class="info-card-value">{selectedVehicle.owner}</span>
						</div>
					</div>
					<div class="info-item"><span class="info-label">Plate</span><span class="info-value mono">{selectedVehicle.plate}</span></div>
					<div class="info-item"><span class="info-label">Model</span><span class="info-value">{selectedVehicle.label}</span></div>
					<div class="info-item"><span class="info-label">Class</span><span class="info-value">{selectedVehicle.class}</span></div>
					<div class="info-item"><span class="info-label">Type</span><span class="info-value">{selectedVehicle.type}</span></div>
					<div class="info-item"><span class="info-label">Brand</span><span class="info-value">{selectedVehicle.brand || 'Unknown'}</span></div>
					<div class="info-item"><span class="info-label">Reports</span><span class="info-value">{selectedVehicle.seenIn || 0}</span></div>
					<div class="info-item"><span class="info-label">Points</span><span class="info-value" class:accent-red={(selectedVehicle.points ?? 0) > 0}>{selectedVehicle.points ?? 0}</span></div>
					<div class="info-item">
						<span class="info-label">State</span>
						<span class="info-value" class:state-active={selectedVehicle.core_state === 0} class:state-garaged={selectedVehicle.core_state === 1} class:state-impounded-state={selectedVehicle.core_state === 2}>
							{selectedVehicle.core_state === 0 ? 'Out' : selectedVehicle.core_state === 1 ? 'Garaged' : selectedVehicle.core_state === 2 ? 'Impounded' : 'Unknown'}
						</span>
					</div>
				</div>

				{#if selectedVehicle.flags && selectedVehicle.flags.length}
					<div class="section">
						<div class="section-title">Flags</div>
						<div class="flags-row">
							{#each selectedVehicle.flags as flag}
								<span class={getFlagClass(flag)}>{flag}</span>
							{/each}
						</div>
					</div>
				{/if}

				{#if selectedVehicle.information}
					<div class="section">
						<div class="section-title">Information</div>
						<p class="section-text">{selectedVehicle.information}</p>
					</div>
				{/if}

				<div class="section">
					<div class="section-title">DMV Updates</div>
					<div class="dmv-form">
						<div class="form-row">
							<label class="form-field">
								<span>Points</span>
								<input type="number" min="0" bind:value={vehicleForm.points} />
							</label>
							<label class="form-field">
								<span>Status</span>
								<select bind:value={vehicleForm.status}>
									<option value="valid">Valid</option>
									<option value="suspended">Suspended</option>
									<option value="expired">Expired</option>
									<option value="impounded">Impounded</option>
								</select>
							</label>
							<label class="form-field form-grow">
								<span>Reason</span>
								<input type="text" placeholder="Optional note" bind:value={vehicleForm.reason} />
							</label>
						</div>
						<button class="save-btn" onclick={saveVehicle} disabled={vehicleSaving} type="button">
							{vehicleSaving ? "Saving..." : "Save DMV"}
						</button>
					</div>
				</div>

				{#if selectedVehicle.bolos && selectedVehicle.bolos.length}
					<div class="section">
						<div class="section-title">Related BOLOs</div>
						<div class="bolos-list">
							{#each selectedVehicle.bolos as bolo}
								<div class="bolo-item">
									<div class="bolo-item-top">
										<span class="bolo-item-id">{bolo.reportId}</span>
										<span class="pill pill-orange">{bolo.status}</span>
									</div>
									{#if bolo.notes}
										<p class="bolo-item-notes">{bolo.notes}</p>
									{/if}
								</div>
							{/each}
						</div>
					</div>
				{/if}

				<div class="section">
					<div class="section-title">Linked Reports <span class="report-count">{linkedReports.length}</span></div>
					{#if linkedReportsLoading}
						<div class="section-empty">Loading reports...</div>
					{:else if linkedReports.length > 0}
						<div class="linked-reports-list">
							{#each linkedReports as lr}
								<div class="linked-report-item">
									<div class="lr-info">
										<span class="lr-title">{lr.title}</span>
										<span class="lr-meta">{lr.type} &middot; {lr.authorplaintext} &middot; {lr.datecreated}</span>
									</div>
									<button class="lr-view-btn" onclick={() => goToReport(lr.id)}>View</button>
								</div>
							{/each}
						</div>
					{:else}
						<div class="section-empty">No reports linked to this vehicle</div>
					{/if}
				</div>
			</div>
		{/if}
	</div>
{:else}
	<!-- Vehicle List View -->
	<div class="vehicles-page">
		<div class="topbar">
			<div class="search-box">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
				<input type="text" bind:value={searchQuery} placeholder="Search vehicles by owner, plate, class..." />
			</div>
			<button class="refresh-btn" onclick={refreshVehicles} disabled={loading}>
				{loading ? "Loading..." : "Refresh"}
			</button>
		</div>

		<div class="filter-tabs">
			<button class="filter-tab" class:active={statusFilter === "all"} onclick={() => { statusFilter = "all"; vehiclePage = 1; }}>All</button>
			<button class="filter-tab" class:active={statusFilter === "active"} onclick={() => { statusFilter = "active"; vehiclePage = 1; }}>Active</button>
			<button class="filter-tab" class:active={statusFilter === "garaged"} onclick={() => { statusFilter = "garaged"; vehiclePage = 1; }}>Garaged</button>
			<button class="filter-tab" class:active={statusFilter === "impounded"} onclick={() => { statusFilter = "impounded"; vehiclePage = 1; }}>Impounded</button>
			<button class="filter-tab" class:active={statusFilter === "stolen"} onclick={() => { statusFilter = "stolen"; vehiclePage = 1; }}>Stolen</button>
		</div>

		<div class="list-panel">
			<div class="list-header">
				<span class="col-name">Vehicle</span>
				<span class="col-plate">Plate</span>
				<span class="col-owner">Owner</span>
				<span class="col-class">Class</span>
				<span class="col-points">Points</span>
				<span class="col-status">Status</span>
				<span class="col-flags">Flags</span>
			</div>
			<div class="list-body">
				{#if loading}
					<div class="empty-state">Loading vehicles...</div>
				{:else if filteredVehicles.length === 0}
					<div class="empty-state">{searchQuery ? "No vehicles match your search." : "No vehicles found."}</div>
				{:else}
					{#each filteredVehicles as vehicle}
						<button class="vehicle-row" onclick={() => viewVehicle(vehicle.plate)}>
							<span class="col-name">{vehicle.label}</span>
							<span class="col-plate mono">{vehicle.plate}</span>
							<span class="col-owner">{vehicle.owner}</span>
							<span class="col-class">{vehicle.class}</span>
							<span class="col-points" class:accent-red={(vehicle.points ?? 0) > 0}>{vehicle.points ?? 0}</span>
							<span class="col-status">
								<span class="status-pill {getStatusClass(vehicle.status || 'valid')}">{vehicle.status || 'Valid'}</span>
							</span>
							<span class="col-flags">
								{#each vehicle.flags || [] as flag}
									<span class={getFlagClass(flag)}>{flag}</span>
								{/each}
							</span>
						</button>
					{/each}
				{/if}
			</div>
			<Pagination
				currentPage={vehiclePage}
				totalItems={allFilteredVehicles.length}
				perPage={vehiclePerPage}
				onPageChange={(p) => { vehiclePage = p; }}
				onPerPageChange={(pp) => { vehiclePerPage = pp; vehiclePage = 1; }}
			/>
		</div>
	</div>
{/if}

<style>
	/* ===== Page ===== */
	.vehicles-page {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: var(--card-dark-bg);
		overflow: hidden;
	}

	/* ===== Topbar ===== */
	.topbar {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 0 16px;
		height: 42px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.topbar-info {
		display: flex;
		align-items: baseline;
		gap: 8px;
	}

	.topbar-name {
		color: rgba(255, 255, 255, 0.85);
		font-size: 13px;
		font-weight: 600;
	}

	.topbar-plate {
		color: rgba(255, 255, 255, 0.3);
		font-size: 11px;
		font-family: monospace;
	}

	.topbar-flags {
		display: flex;
		gap: 5px;
		margin-left: auto;
	}

	.back-btn {
		display: flex;
		align-items: center;
		gap: 5px;
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

	.back-btn:hover {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.search-box {
		display: flex;
		align-items: center;
		gap: 8px;
		background: transparent;
		border: none;
		padding: 0;
		flex: 1;
		max-width: 400px;
		color: rgba(255, 255, 255, 0.2);
	}

	.search-box input {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.8);
		font-size: 12px;
		padding: 0;
		width: 100%;
		outline: none;
	}

	.search-box input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.refresh-btn {
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

	.refresh-btn:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.refresh-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	/* ===== Filter Tabs ===== */
	.filter-tabs {
		display: flex;
		gap: 2px;
		flex-shrink: 0;
		padding: 0 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.filter-tab {
		background: transparent;
		border: none;
		border-bottom: 2px solid transparent;
		border-radius: 0;
		padding: 6px 10px;
		color: rgba(255, 255, 255, 0.3);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.filter-tab:hover {
		color: rgba(255, 255, 255, 0.6);
	}

	.filter-tab.active {
		color: rgba(96, 165, 250, 0.9);
		border-bottom-color: rgba(var(--accent-rgb), 0.5);
	}

	/* ===== List Panel ===== */
	.list-panel {
		background: transparent;
		border: none;
		border-radius: 0;
		flex: 1;
		min-height: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.list-header {
		display: grid;
		grid-template-columns: 2fr 1fr 1.5fr 0.8fr 0.6fr 0.8fr 1.5fr;
		gap: 8px;
		padding: 8px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		flex-shrink: 0;
	}

	.list-body {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.06) transparent;
	}

	.list-body::-webkit-scrollbar { width: 4px; }
	.list-body::-webkit-scrollbar-track { background: transparent; }
	.list-body::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	.vehicle-row {
		display: grid;
		grid-template-columns: 2fr 1fr 1.5fr 0.8fr 0.6fr 0.8fr 1.5fr;
		gap: 8px;
		padding: 7px 16px;
		align-items: center;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		background: transparent;
		cursor: pointer;
		transition: background 0.1s;
		width: 100%;
		text-align: left;
		font: inherit;
		color: inherit;
	}

	.vehicle-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.col-name {
		color: rgba(255, 255, 255, 0.85);
		font-size: 11px;
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.col-plate {
		color: rgba(255, 255, 255, 0.5);
		font-size: 10px;
	}

	.col-owner {
		color: rgba(255, 255, 255, 0.45);
		font-size: 11px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.col-class, .col-type {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.col-points {
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 600;
	}

	.accent-red { color: rgba(248, 113, 113, 0.8) !important; }

	.col-status { display: flex; align-items: center; }
	.col-flags { display: flex; gap: 3px; flex-wrap: wrap; }

	.mono { font-family: monospace; letter-spacing: 0.5px; }

	/* ===== Pills ===== */
	.pill {
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
		letter-spacing: 0.3px;
		white-space: nowrap;
	}

	.pill-red {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(248, 113, 113, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	.pill-orange {
		background: rgba(245, 158, 11, 0.08);
		color: rgba(251, 191, 36, 0.8);
		border: 1px solid rgba(245, 158, 11, 0.1);
	}

	.pill-grey {
		background: rgba(107, 114, 128, 0.08);
		color: rgba(156, 163, 175, 0.8);
		border: 1px solid rgba(107, 114, 128, 0.1);
	}

	/* ===== Status Pills ===== */
	.status-pill {
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
		text-transform: capitalize;
		letter-spacing: 0.3px;
	}

	.status-valid {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(52, 211, 153, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.status-stolen {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(248, 113, 113, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	.status-bolo {
		background: rgba(245, 158, 11, 0.08);
		color: rgba(251, 191, 36, 0.8);
		border: 1px solid rgba(245, 158, 11, 0.1);
	}

	.status-suspended {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(248, 113, 113, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	.status-expired {
		background: rgba(107, 114, 128, 0.08);
		color: rgba(156, 163, 175, 0.8);
		border: 1px solid rgba(107, 114, 128, 0.1);
	}

	.status-impounded {
		background: rgba(245, 158, 11, 0.08);
		color: rgba(251, 191, 36, 0.8);
		border: 1px solid rgba(245, 158, 11, 0.1);
	}

	/* ===== Empty / Loading ===== */
	.empty-state, .loading-state, .error-state {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 60px 20px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
	}

	.error-state { color: rgba(248, 113, 113, 0.8); }

	/* ===== Detail View ===== */
	.detail-scroll {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 0;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.06) transparent;
	}

	.detail-scroll::-webkit-scrollbar { width: 4px; }
	.detail-scroll::-webkit-scrollbar-track { background: transparent; }
	.detail-scroll::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	/* Info Grid */
	.info-grid {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 8px;
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 0;
		padding: 12px 16px;
	}

	.info-card {
		grid-column: 1 / -1;
		display: flex;
		align-items: center;
		gap: 10px;
		padding-bottom: 10px;
		margin-bottom: 2px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.info-card-icon {
		width: 36px;
		height: 36px;
		border-radius: 3px;
		background: rgba(255, 255, 255, 0.03);
		display: flex;
		align-items: center;
		justify-content: center;
		color: rgba(255, 255, 255, 0.15);
		flex-shrink: 0;
		overflow: hidden;
	}

	.info-card-img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.info-card-body {
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.info-card-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.info-card-value {
		color: rgba(255, 255, 255, 0.85);
		font-size: 12px;
		font-weight: 600;
	}

	.info-item {
		display: flex;
		flex-direction: column;
		gap: 2px;
		padding: 4px 0;
	}

	.info-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}

	.info-value {
		color: rgba(255, 255, 255, 0.7);
		font-size: 11px;
		font-weight: 500;
	}

	.info-value.mono { font-family: monospace; letter-spacing: 0.5px; }

	.section {
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 0;
		padding: 12px 16px;
	}

	.section:last-child {
		border-bottom: none;
	}

	.section-title {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		margin-bottom: 8px;
	}

	.section-text {
		margin: 0;
		color: rgba(255, 255, 255, 0.5);
		font-size: 11px;
		line-height: 1.5;
	}

	.flags-row {
		display: flex;
		gap: 4px;
		flex-wrap: wrap;
	}

	/* ===== DMV Form ===== */
	.dmv-form {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.form-row {
		display: flex;
		gap: 8px;
		align-items: flex-end;
	}

	.form-field {
		display: flex;
		flex-direction: column;
		gap: 3px;
		min-width: 100px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.form-grow { flex: 1; }

	.form-field input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
	}

	.form-field select {
		padding: 5px 22px 5px 8px;
		font-size: 10px;
	}

	.form-field input:focus,
	.form-field select:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.1);
	}

	.save-btn {
		align-self: flex-start;
		background: rgba(16, 185, 129, 0.06);
		color: rgba(52, 211, 153, 0.7);
		border: 1px solid rgba(16, 185, 129, 0.1);
		padding: 4px 12px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.save-btn:hover:not(:disabled) {
		background: rgba(16, 185, 129, 0.12);
		color: rgba(110, 231, 183, 0.9);
	}

	.save-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	/* ===== BOLOs in Detail ===== */
	.bolos-list {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.bolo-item {
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		border-radius: 0;
		padding: 6px 0;
	}

	.bolo-item:last-child {
		border-bottom: none;
	}

	.bolo-item-top {
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.bolo-item-id {
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-family: monospace;
	}

	.bolo-item-notes {
		margin: 3px 0 0;
		color: rgba(255, 255, 255, 0.3);
		font-size: 10px;
		line-height: 1.4;
	}

	.report-count {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.3);
		font-size: 9px;
		padding: 1px 5px;
		border-radius: 3px;
		font-weight: 600;
		margin-left: 4px;
	}

	.linked-reports-list {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.linked-report-item {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 6px 0;
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		border-radius: 0;
		transition: background 0.1s;
	}

	.linked-report-item:last-child {
		border-bottom: none;
	}

	.linked-report-item:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.lr-info {
		display: flex;
		flex-direction: column;
		gap: 1px;
		min-width: 0;
		flex: 1;
	}

	.lr-view-btn {
		background: rgba(var(--accent-rgb), 0.06);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		color: rgba(var(--accent-text-rgb), 0.7);
		font-size: 10px;
		font-weight: 500;
		padding: 3px 8px;
		border-radius: 3px;
		cursor: pointer;
		white-space: nowrap;
		flex-shrink: 0;
		transition: all 0.1s;
		opacity: 0;
	}

	.linked-report-item:hover .lr-view-btn {
		opacity: 1;
	}

	.lr-view-btn:hover {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.lr-title {
		color: rgba(255, 255, 255, 0.85);
		font-size: 11px;
		font-weight: 500;
	}

	.lr-meta {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.section-empty {
		color: rgba(255, 255, 255, 0.2);
		font-size: 10px;
		text-align: center;
		padding: 12px 0;
	}

	.state-active { color: rgba(52, 211, 153, 0.8) !important; }
	.state-garaged { color: rgba(var(--accent-text-rgb), 0.8) !important; }
	.state-impounded-state { color: rgba(251, 191, 36, 0.8) !important; }
</style>
