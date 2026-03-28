<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../../utils/fetchNui";
	import { isEnvBrowser } from "../../utils/misc";
	import { NUI_EVENTS } from "../../constants/nuiEvents";
	import { globalNotifications } from "../../services/notificationService.svelte";
	import type { createTabService } from "../../services/tabService.svelte";
	import type { AuthService } from "../../services/authService.svelte";
	import type { SearchResult } from "../../interfaces/IReportEditor";
	import PersonSearchModal from "../../components/report-editor/PersonSearchModal.svelte";

	interface Props {
		tabService: ReturnType<typeof createTabService>;
		authService: AuthService;
	}

	let { tabService, authService }: Props = $props();

	type OrderType = "restraining_order" | "subpoena" | "bail_conditions" | "search_warrant" | "arrest_warrant" | "other";
	type OrderStatus = "active" | "expired" | "revoked";

	interface CourtOrder {
		id: number;
		order_number: string;
		type: OrderType;
		title: string;
		target_name: string;
		target_citizenid: string;
		content: string;
		status: OrderStatus;
		effective_date: string;
		expiry_date?: string;
		issued_by?: string;
		created_at: string;
		updated_at?: string;
	}

	let orders = $state<CourtOrder[]>([]);
	let selectedOrder = $state<CourtOrder | null>(null);
	let isLoading = $state(false);
	let searchQuery = $state("");
	let typeFilter = $state<string>("all");
	let statusFilter = $state<string>("active");
	let showCreateModal = $state(false);

	let newOrder = $state({
		type: "restraining_order" as OrderType,
		title: "",
		target_citizenid: "",
		target_name: "",
		content: "",
		effective_date: "",
		expiry_date: "",
	});

	let showTargetSearch = $state(false);
	let targetSearchResults = $state<SearchResult[]>([]);

	async function handleTargetSearch(query: string) {
		if (query.length < 2) { targetSearchResults = []; return; }
		const results = await fetchNui<any[]>(NUI_EVENTS.CITIZEN.SEARCH_CITIZENS, { query }, []);
		targetSearchResults = (results || []).map((c: any) => ({
			id: c.citizenid || c.id,
			fullName: c.fullName || c.firstname + " " + c.lastname,
			citizenid: c.citizenid || c.id,
			image: c.profileImage || c.image,
		}));
	}

	function handleTargetSelect(person: SearchResult) {
		newOrder.target_citizenid = person.citizenid || person.id;
		newOrder.target_name = person.fullName;
		showTargetSearch = false;
		targetSearchResults = [];
	}

	const typeOptions: { value: string; label: string }[] = [
		{ value: "all", label: "All Types" },
		{ value: "restraining_order", label: "Restraining Order" },
		{ value: "subpoena", label: "Subpoena" },
		{ value: "bail_conditions", label: "Bail Conditions" },
		{ value: "search_warrant", label: "Search Warrant" },
		{ value: "arrest_warrant", label: "Arrest Warrant" },
		{ value: "other", label: "Other" },
	];

	const statusOptions = ["active", "expired", "revoked", "all"];

	function getStatusPillClass(status: string): string {
		switch (status) {
			case "active": return "pill-green";
			case "expired": return "pill-grey";
			case "revoked": return "pill-red";
			default: return "pill-grey";
		}
	}

	function getTypePillClass(type: string): string {
		switch (type) {
			case "restraining_order": return "pill-orange";
			case "subpoena": return "pill-blue";
			case "bail_conditions": return "pill-yellow";
			case "search_warrant": return "pill-blue";
			case "arrest_warrant": return "pill-red";
			default: return "pill-grey";
		}
	}

	function formatLabel(value: string): string {
		return value.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
	}

	function formatDateValue(value: string | undefined): string {
		if (!value) return "-";
		const date = new Date(value);
		if (Number.isNaN(date.getTime())) return "-";
		return date.toLocaleDateString("en-US", {
			month: "2-digit",
			day: "2-digit",
			year: "numeric",
		});
	}

	let allFilteredOrders = $derived.by(() => {
		let filtered = orders;
		if (statusFilter !== "all") {
			filtered = filtered.filter((o) => o.status === statusFilter);
		}
		if (typeFilter !== "all") {
			filtered = filtered.filter((o) => o.type === typeFilter);
		}
		const query = searchQuery.trim().toLowerCase();
		if (query) {
			filtered = filtered.filter((o) =>
				[o.order_number, o.title, o.target_name, o.type]
					.filter(Boolean)
					.some((val) => String(val).toLowerCase().includes(query)),
			);
		}
		return filtered;
	});

	let mounted = false;

	$effect(() => {
		searchQuery;
		statusFilter;
		typeFilter;
		if (mounted && !isEnvBrowser()) loadOrders();
	});

	onMount(async () => {
		if (isEnvBrowser()) {
			orders = [
				{ id: 1, order_number: "CO-2026-00001", type: "restraining_order", title: "Restraining Order - Johnson v. Smith", target_name: "James Smith", target_citizenid: "ABC123", content: "Respondent must maintain a distance of 100 meters from petitioner at all times.", status: "active", effective_date: "2026-03-01T00:00:00Z", expiry_date: "2026-09-01T00:00:00Z", issued_by: "Hon. Patricia Wells", created_at: "2026-03-01T10:00:00Z" },
				{ id: 2, order_number: "CO-2026-00002", type: "subpoena", title: "Subpoena - State v. Chen", target_name: "David Chen", target_citizenid: "DEF456", content: "Witness is ordered to appear in court on the specified date.", status: "active", effective_date: "2026-03-20T00:00:00Z", issued_by: "Hon. Robert Kim", created_at: "2026-03-15T14:00:00Z" },
				{ id: 3, order_number: "CO-2026-00003", type: "bail_conditions", title: "Bail Conditions - Tony Ramirez", target_name: "Tony Ramirez", target_citizenid: "GHI789", content: "Defendant must report to probation officer weekly. No contact with co-defendants. Must remain within city limits.", status: "active", effective_date: "2026-03-10T00:00:00Z", expiry_date: "2026-06-10T00:00:00Z", issued_by: "Hon. Patricia Wells", created_at: "2026-03-10T09:00:00Z" },
				{ id: 4, order_number: "CO-2026-00004", type: "search_warrant", title: "Search Warrant - 123 Grove St", target_name: "Marcus Johnson", target_citizenid: "JKL012", content: "Authorization to search premises at 123 Grove Street for evidence related to drug trafficking.", status: "expired", effective_date: "2026-02-15T00:00:00Z", expiry_date: "2026-02-22T00:00:00Z", issued_by: "Hon. Robert Kim", created_at: "2026-02-14T16:00:00Z" },
				{ id: 5, order_number: "CO-2026-00005", type: "arrest_warrant", title: "Arrest Warrant - Lisa Park", target_name: "Lisa Park", target_citizenid: "MNO345", content: "Warrant for arrest on charges of fraud and embezzlement.", status: "revoked", effective_date: "2026-01-20T00:00:00Z", issued_by: "Hon. Patricia Wells", created_at: "2026-01-20T08:00:00Z" },
			];
			mounted = true;
			return;
		}
		await loadOrders();
		mounted = true;
	});

	async function loadOrders() {
		isLoading = true;
		try {
			const data = await fetchNui<{ orders: CourtOrder[] }>(
				NUI_EVENTS.DOJ.GET_COURT_ORDERS,
				{ status: statusFilter === "all" ? "" : statusFilter, type: typeFilter === "all" ? "" : typeFilter, search: searchQuery.trim() || "" },
				{ orders: [] },
			);
			orders = data.orders || [];
		} catch {
			globalNotifications.error("Failed to load court orders");
		}
		isLoading = false;
	}

	function selectOrder(id: number) {
		selectedOrder = orders.find((o) => o.id === id) || null;
	}

	function goBack() {
		selectedOrder = null;
		if (!isEnvBrowser()) loadOrders();
	}

	async function handleCreateOrder() {
		if (!newOrder.title.trim()) return;
		isLoading = true;
		try {
			const result = await fetchNui<{ success: boolean; id?: number; error?: string }>(
				NUI_EVENTS.DOJ.CREATE_COURT_ORDER,
				{
					type: newOrder.type,
					title: newOrder.title.trim(),
					target_citizenid: newOrder.target_citizenid.trim(),
					content: newOrder.content.trim(),
					effective_date: newOrder.effective_date,
					expiry_date: newOrder.expiry_date || undefined,
				},
				{ success: true, id: Math.floor(Math.random() * 1000) },
			);
			if (result.success) {
				showCreateModal = false;
				newOrder = { type: "restraining_order", title: "", target_citizenid: "", target_name: "", content: "", effective_date: "", expiry_date: "" };
				globalNotifications.success("Court order created");
				await loadOrders();
			} else {
				globalNotifications.error(result.error || "Failed to create court order");
			}
		} catch {
			globalNotifications.error("Failed to create court order");
		}
		isLoading = false;
	}

	async function handleRevokeOrder() {
		if (!selectedOrder) return;
		isLoading = true;
		try {
			const result = await fetchNui<{ success: boolean; error?: string }>(
				NUI_EVENTS.DOJ.REVOKE_COURT_ORDER,
				{ id: selectedOrder.id },
				{ success: true },
			);
			if (result.success) {
				globalNotifications.success("Court order revoked");
				goBack();
				await loadOrders();
			} else {
				globalNotifications.error(result.error || "Failed to revoke court order");
			}
		} catch {
			globalNotifications.error("Failed to revoke court order");
		}
		isLoading = false;
	}
</script>

<div class="page">
	{#if selectedOrder}
		<!-- DETAIL VIEW -->
		<div class="topbar">
			<button class="back-btn" onclick={goBack}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
				Back to Orders
			</button>
			<span class="topbar-case-number">{selectedOrder.order_number}</span>
			<span class="pill {getTypePillClass(selectedOrder.type)}">{formatLabel(selectedOrder.type)}</span>
			<span class="pill {getStatusPillClass(selectedOrder.status)}">{formatLabel(selectedOrder.status)}</span>
		</div>

		<div class="detail-scroll">
			<div class="detail-layout">
				<div class="detail-main">
					<div class="section">
						<div class="section-title">Order Information</div>
						<h3 class="order-title">{selectedOrder.title}</h3>
						<div class="field-row">
							<div class="field-group">
								<span class="field-label">Order Number</span>
								<span class="field-value">{selectedOrder.order_number}</span>
							</div>
							<div class="field-group">
								<span class="field-label">Type</span>
								<span class="pill {getTypePillClass(selectedOrder.type)}">{formatLabel(selectedOrder.type)}</span>
							</div>
							<div class="field-group">
								<span class="field-label">Status</span>
								<span class="pill {getStatusPillClass(selectedOrder.status)}">{formatLabel(selectedOrder.status)}</span>
							</div>
						</div>
					</div>

					<div class="section">
						<div class="section-title">Target</div>
						<div class="field-row">
							<div class="field-group">
								<span class="field-label">Name</span>
								<span class="field-value">{selectedOrder.target_name}</span>
							</div>
							<div class="field-group">
								<span class="field-label">Citizen ID</span>
								<span class="field-value mono">{selectedOrder.target_citizenid}</span>
							</div>
						</div>
					</div>

					<div class="section">
						<div class="section-title">Content</div>
						<p class="summary-text">{selectedOrder.content || "No content."}</p>
					</div>
				</div>

				<div class="detail-side">
					<div class="section">
						<div class="section-title">Dates</div>
						<div class="field-group">
							<span class="field-label">Effective Date</span>
							<span class="field-value">{formatDateValue(selectedOrder.effective_date)}</span>
						</div>
						<div class="field-group">
							<span class="field-label">Expiry Date</span>
							<span class="field-value">{formatDateValue(selectedOrder.expiry_date)}</span>
						</div>
						<div class="field-group">
							<span class="field-label">Issued By</span>
							<span class="field-value">{selectedOrder.issued_by || "-"}</span>
						</div>
					</div>

					{#if selectedOrder.status === "active"}
						<div class="section">
							<div class="section-title">Actions</div>
							<button class="danger-btn" onclick={handleRevokeOrder} disabled={isLoading}>
								Revoke Order
							</button>
						</div>
					{/if}
				</div>
			</div>
		</div>
	{:else}
		<!-- LIST VIEW -->
		<div class="topbar">
			<div class="search-box">
				<input type="text" placeholder="Search orders..." bind:value={searchQuery} />
			</div>
			<div class="filter-pills">
				{#each statusOptions as opt}
					<button class="filter-pill" class:active={statusFilter === opt} onclick={() => (statusFilter = opt)}>
						{formatLabel(opt)}
					</button>
				{/each}
			</div>
			<select class="filter-select" bind:value={typeFilter}>
				{#each typeOptions as opt}
					<option value={opt.value}>{opt.label}</option>
				{/each}
			</select>
			<div class="topbar-actions">
				<span class="result-count">{allFilteredOrders.length} order{allFilteredOrders.length !== 1 ? "s" : ""}</span>
				<button class="action-btn" onclick={loadOrders} disabled={isLoading}>{isLoading ? "Loading..." : "Refresh"}</button>
				<button class="primary-btn" onclick={() => (showCreateModal = true)}>New Court Order</button>
			</div>
		</div>

		<div class="list-panel">
			{#if isLoading && orders.length === 0}
				<div class="center-state">
					<div class="loading-spinner"></div>
					<p>Loading court orders...</p>
				</div>
			{:else if allFilteredOrders.length === 0}
				<div class="center-state">
					<h3>No Court Orders Found</h3>
					<p>{searchQuery ? "No orders match your search criteria." : "No court orders available."}</p>
				</div>
			{:else}
				<div class="table-header">
					<span>Order #</span>
					<span>Type</span>
					<span>Title</span>
					<span>Target</span>
					<span>Status</span>
					<span>Effective</span>
					<span>Expires</span>
				</div>
				<div class="table-body">
					{#each allFilteredOrders as item}
						<button class="table-row" onclick={() => selectOrder(item.id)}>
							<span class="row-case">{item.order_number}</span>
							<span><span class="pill {getTypePillClass(item.type)}">{formatLabel(item.type)}</span></span>
							<span class="row-title">{item.title}</span>
							<span>{item.target_name}</span>
							<span><span class="pill {getStatusPillClass(item.status)}">{formatLabel(item.status)}</span></span>
							<span>{formatDateValue(item.effective_date)}</span>
							<span>{formatDateValue(item.expiry_date)}</span>
						</button>
					{/each}
				</div>
			{/if}
		</div>
	{/if}
</div>

<!-- CREATE MODAL -->
{#if showCreateModal}
	<div class="modal-backdrop" onclick={() => (showCreateModal = false)} role="presentation">
		<div class="modal" onclick={(e) => e.stopPropagation()} role="dialog">
			<div class="modal-header">
				<span class="modal-title">New Court Order</span>
				<button class="modal-close" onclick={() => (showCreateModal = false)}>
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
				</button>
			</div>
			<div class="modal-body">
				<div class="form-group">
					<label class="form-label">Type</label>
					<select class="form-select" bind:value={newOrder.type}>
						<option value="restraining_order">Restraining Order</option>
						<option value="subpoena">Subpoena</option>
						<option value="bail_conditions">Bail Conditions</option>
						<option value="search_warrant">Search Warrant</option>
						<option value="arrest_warrant">Arrest Warrant</option>
						<option value="other">Other</option>
					</select>
				</div>
				<div class="form-group">
					<label class="form-label">Title</label>
					<input type="text" class="form-input" placeholder="Order title..." bind:value={newOrder.title} />
				</div>
				<div class="form-group">
					<label class="form-label">Target Citizen</label>
					{#if newOrder.target_citizenid}
						<div class="selected-citizen">
							<span class="citizen-name">{newOrder.target_name}</span>
							<span class="citizen-id">({newOrder.target_citizenid})</span>
							<button type="button" class="remove-citizen-btn" onclick={() => { newOrder.target_citizenid = ""; newOrder.target_name = ""; }}>x</button>
						</div>
					{:else}
						<button type="button" class="form-input search-citizen-btn" onclick={() => (showTargetSearch = true)}>Search citizen...</button>
					{/if}
				</div>
				<div class="form-group">
					<label class="form-label">Content</label>
					<textarea class="form-textarea" style="min-height: 100px;" placeholder="Order content..." bind:value={newOrder.content}></textarea>
				</div>
				<div class="form-row">
					<div class="form-group" style="flex: 1;">
						<label class="form-label">Effective Date</label>
						<input type="date" class="form-input" bind:value={newOrder.effective_date} />
					</div>
					<div class="form-group" style="flex: 1;">
						<label class="form-label">Expiry Date (optional)</label>
						<input type="date" class="form-input" bind:value={newOrder.expiry_date} />
					</div>
				</div>
			</div>
			<div class="modal-footer">
				<button class="back-btn" onclick={() => (showCreateModal = false)}>Cancel</button>
				<button class="primary-btn" disabled={!newOrder.title.trim()} onclick={handleCreateOrder}>Create Order</button>
			</div>
		</div>
	</div>
{/if}

<PersonSearchModal
	show={showTargetSearch}
	title="Search Target Citizen"
	searchResults={targetSearchResults}
	onClose={() => { showTargetSearch = false; targetSearchResults = []; }}
	onSearch={handleTargetSearch}
	onSelect={handleTargetSelect}
/>

<style>
	.page {
		height: 100%;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
		display: flex;
		flex-direction: column;
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

	.topbar-case-number {
		color: rgba(255, 255, 255, 0.3);
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.8px;
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

	.search-box {
		display: flex;
		align-items: center;
		min-width: 200px;
	}

	.search-box input {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.8);
		font-size: 12px;
		padding: 0;
		outline: none;
		width: 100%;
	}

	.search-box input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.filter-pills {
		display: flex;
		align-items: center;
		gap: 4px;
		overflow-x: auto;
	}

	.filter-pill {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 3px 8px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
		white-space: nowrap;
	}

	.filter-pill:hover {
		color: rgba(255, 255, 255, 0.6);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.filter-pill.active {
		background: rgba(var(--accent-rgb), 0.08);
		color: rgba(var(--accent-text-rgb), 0.8);
		border-color: rgba(var(--accent-rgb), 0.15);
	}

	.filter-select {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 3px 8px;
		color: rgba(255, 255, 255, 0.6);
		font-size: 10px;
		outline: none;
	}

	.back-btn {
		display: inline-flex;
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

	.back-btn:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.action-btn {
		display: inline-flex;
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

	.action-btn:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.action-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.primary-btn {
		background: rgba(var(--accent-rgb), 0.08);
		color: rgba(var(--accent-text-rgb), 0.8);
		border: 1px solid rgba(var(--accent-rgb), 0.12);
		border-radius: 3px;
		padding: 4px 10px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
		white-space: nowrap;
	}

	.primary-btn:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.14);
	}

	.primary-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.danger-btn {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(248, 113, 113, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.12);
		border-radius: 3px;
		padding: 5px 12px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
		width: 100%;
	}

	.danger-btn:hover:not(:disabled) {
		background: rgba(239, 68, 68, 0.14);
	}

	.danger-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.pill {
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 600;
		text-transform: capitalize;
		white-space: nowrap;
	}

	.pill-yellow {
		background: rgba(234, 179, 8, 0.08);
		color: rgba(250, 204, 21, 0.8);
		border: 1px solid rgba(234, 179, 8, 0.1);
	}

	.pill-blue {
		background: rgba(var(--accent-rgb), 0.08);
		color: rgba(96, 165, 250, 0.8);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
	}

	.pill-orange {
		background: rgba(245, 158, 11, 0.08);
		color: rgba(251, 191, 36, 0.8);
		border: 1px solid rgba(245, 158, 11, 0.1);
	}

	.pill-green {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(52, 211, 153, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.pill-grey {
		background: rgba(107, 114, 128, 0.08);
		color: rgba(156, 163, 175, 0.8);
		border: 1px solid rgba(107, 114, 128, 0.1);
	}

	.pill-red {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(248, 113, 113, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

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

	.table-header {
		display: grid;
		grid-template-columns: 1.1fr 1fr 2fr 1fr 0.7fr 0.8fr 0.8fr;
		gap: 8px;
		padding: 8px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.table-header span {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}

	.table-body {
		flex: 1;
		overflow-y: auto;
	}

	.table-row {
		display: grid;
		grid-template-columns: 1.1fr 1fr 2fr 1fr 0.7fr 0.8fr 0.8fr;
		gap: 8px;
		padding: 7px 16px;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		background: transparent;
		width: 100%;
		text-align: left;
		cursor: pointer;
		transition: background 0.1s;
		align-items: center;
	}

	.table-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.table-row span {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.45);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	.row-case {
		color: rgba(96, 165, 250, 0.7) !important;
		font-weight: 500;
	}

	.row-title {
		color: rgba(255, 255, 255, 0.75) !important;
		font-weight: 500;
	}

	.detail-layout {
		display: grid;
		grid-template-columns: 2fr 1fr;
		gap: 0;
	}

	.detail-main {
		display: flex;
		flex-direction: column;
		gap: 0;
		border-right: 1px solid rgba(255, 255, 255, 0.04);
	}

	.detail-side {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.detail-scroll {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 0;
		padding-bottom: 12px;
	}

	.section {
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 0;
		padding: 12px 16px;
		display: flex;
		flex-direction: column;
		gap: 8px;
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
		margin-bottom: 2px;
	}

	.order-title {
		color: rgba(255, 255, 255, 0.85);
		font-size: 14px;
		font-weight: 600;
		margin: 0;
	}

	.field-row {
		display: flex;
		gap: 10px;
		align-items: flex-start;
		flex-wrap: wrap;
	}

	.field-group {
		display: flex;
		flex-direction: column;
		gap: 3px;
		min-width: 120px;
		flex: 1;
	}

	.field-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.field-value {
		color: rgba(255, 255, 255, 0.75);
		font-size: 11px;
	}

	.field-value.mono {
		font-family: monospace;
		font-size: 10px;
		color: rgba(255, 255, 255, 0.35);
	}

	.summary-text {
		color: rgba(255, 255, 255, 0.5);
		font-size: 11px;
		margin: 0;
		line-height: 1.5;
		white-space: pre-wrap;
	}

	.form-select {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 22px 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 10px;
		text-transform: capitalize;
		outline: none;
		width: 100%;
		box-sizing: border-box;
	}

	.center-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		flex: 1;
		text-align: center;
		padding: 60px 20px;
	}

	.center-state h3 {
		color: rgba(255, 255, 255, 0.5);
		font-size: 14px;
		font-weight: 600;
		margin: 12px 0 4px;
	}

	.center-state p {
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
		margin: 0 0 12px;
	}

	.loading-spinner {
		width: 24px;
		height: 24px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left: 2px solid rgba(var(--accent-rgb), 0.5);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
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

	/* MODAL */
	.modal-backdrop {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.6);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 100;
	}

	.modal {
		background: var(--dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 8px;
		width: 480px;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.modal-title {
		color: rgba(255, 255, 255, 0.85);
		font-size: 13px;
		font-weight: 600;
	}

	.modal-close {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.3);
		cursor: pointer;
		padding: 4px;
		display: flex;
		transition: color 0.1s;
	}

	.modal-close:hover {
		color: rgba(255, 255, 255, 0.7);
	}

	.modal-body {
		padding: 16px;
		display: flex;
		flex-direction: column;
		gap: 12px;
		overflow-y: auto;
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 8px;
		padding: 12px 16px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}

	.form-row {
		display: flex;
		gap: 12px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.form-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.form-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		outline: none;
		transition: border-color 0.1s;
		width: 100%;
		box-sizing: border-box;
	}

	.form-input:focus {
		border-color: rgba(255, 255, 255, 0.1);
	}

	.form-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.form-textarea {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		outline: none;
		resize: vertical;
		width: 100%;
		box-sizing: border-box;
		min-height: 60px;
	}

	.form-textarea:focus {
		border-color: rgba(255, 255, 255, 0.1);
	}

	.form-textarea::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.selected-citizen {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 0 8px;
		height: 32px;
		background: rgba(255, 255, 255, 0.05);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 4px;
		font-size: 0.75rem;
	}

	.citizen-name {
		color: rgba(255, 255, 255, 0.85);
	}

	.citizen-id {
		color: rgba(255, 255, 255, 0.35);
		font-size: 0.7rem;
		font-family: monospace;
	}

	.remove-citizen-btn {
		margin-left: auto;
		background: none;
		border: none;
		color: rgba(255, 100, 100, 0.5);
		cursor: pointer;
		font-size: 0.75rem;
		padding: 0 2px;
		line-height: 1;
	}

	.remove-citizen-btn:hover {
		color: rgba(255, 100, 100, 1);
	}

	.search-citizen-btn {
		cursor: pointer;
		text-align: left;
		color: rgba(255, 255, 255, 0.3);
		font-size: 0.75rem;
		height: 32px;
		padding: 0 8px;
	}

	.search-citizen-btn:hover {
		border-color: rgba(255, 255, 255, 0.2);
	}
</style>
