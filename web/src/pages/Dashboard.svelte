<script lang="ts">
	import { onMount, onDestroy } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import type { createTabService } from "../services/tabService.svelte";
	import { openReportInEditor } from "../stores/reportsStore";
	import { mdtStore } from "../stores/mdtStore";
	import { PRIORITY_COLORS } from "../constants";
	import { createDashboardService } from "../services/dashboardService.svelte";
	import { createDispatchService } from "../services/dispatchService.svelte";
	import ReportItem from "../components/dashboard/ReportItem.svelte";
	import type { PlayerData } from "@/interfaces/IPlayerData";
	interface ActiveBolo {
		id: number;
		reportId: string;
		name: string;
		type: string;
		notes: string;
	}

	import type { JobType } from "../interfaces/IUser";

	let {
		signOut,
		playerData,
		tabService,
		jobType = 'leo',
	}: {
		signOut: () => void;
		playerData: PlayerData | null;
		tabService: ReturnType<typeof createTabService>;
		jobType?: JobType;
	} = $props();

	let isLEO = $derived(jobType === 'leo');
	let isDOJ = $derived(jobType === 'doj');

	// DOJ dashboard data
	let dojWarrantReviews = $state<any[]>([]);
	let dojCourtCases = $state<any[]>([]);
	let dojCourtOrders = $state<any[]>([]);

	async function loadDojDashboard() {
		if (!isDOJ) return;
		const [reviews, cases, orders] = await Promise.all([
			fetchNui<any>(NUI_EVENTS.DOJ.GET_WARRANT_REQUESTS, { status: 'pending', limit: 5 }, []),
			fetchNui<any>(NUI_EVENTS.DOJ.GET_COURT_CASES, { limit: 5 }, []),
			fetchNui<any>(NUI_EVENTS.DOJ.GET_COURT_ORDERS, { limit: 5 }, []),
		]);
		dojWarrantReviews = Array.isArray(reviews) ? reviews.slice(0, 5) : [];
		dojCourtCases = Array.isArray(cases) ? cases.slice(0, 5) : [];
		dojCourtOrders = Array.isArray(orders) ? orders.slice(0, 5) : [];
	}

	// Create services
	const dashboardService = createDashboardService() as ReturnType<
		typeof createDashboardService
	> & {
		activeBolos?: ActiveBolo[];
		recentReportsHasMore?: boolean;
		loadMoreRecentReports?: () => Promise<void>;
	};
	const dispatchService = createDispatchService();

	// UI state (keep in component since it's view-specific)
	let expandedDispatch: string | null = $state(null);
	let reportOpened: number | null = $state(null);
	let warrantOpened: number | null = $state(null);

	// Pagination for warrants and BOLOs
	const PAGE_SIZE = 10;
	let warrantPage = $state(0);
	let boloPage = $state(0);

	let warrantTotalPages = $derived(Math.max(1, Math.ceil(dashboardService.activeWarrants.length / PAGE_SIZE)));
	let boloTotalPages = $derived(Math.max(1, Math.ceil((dashboardService.activeBolos || []).length / PAGE_SIZE)));

	let pagedWarrants = $derived(dashboardService.activeWarrants.slice(warrantPage * PAGE_SIZE, (warrantPage + 1) * PAGE_SIZE));
	let pagedBolos = $derived((dashboardService.activeBolos || []).slice(boloPage * PAGE_SIZE, (boloPage + 1) * PAGE_SIZE));

	onMount(() => {
		dashboardService.initialize();
		dashboardService.startCarouselTimer();
		loadDojDashboard();
	});

	onDestroy(() => {
		dashboardService.destroy();
	});

	function viewWarrant(warrantId: string) {
		tabService.setActiveTab("Warrants");
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, "Warrants");
		}
	}

	function viewBolo(boloId: number) {
		tabService.setActiveTab("BOLOs");
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, "BOLOs");
		}
	}

	function viewReport(reportId: string) {
		openReportInEditor(reportId);
		tabService.setActiveTab("Reports");
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, "Reports");
		}
	}

	function toggleDispatch(dispatchId: string) {
		expandedDispatch = expandedDispatch === dispatchId ? null : dispatchId;
	}

	function getPriorityColor(priority: number | string): string {
		return PRIORITY_COLORS[String(priority)] || PRIORITY_COLORS.default;
	}

	function toggleDuty() {
		fetchNui(NUI_EVENTS.NAVIGATION.TOGGLE_DUTY);
	}

	function handleSignOut() {
		mdtStore.reset();
		signOut();
	}

	function getTimeTranslated(time: number): string {
		const now = Date.now();
		let diffInMs = now - time;

		if (diffInMs < 0) return "in the future";

		const units = [
			{ label: "year", ms: 1000 * 60 * 60 * 24 * 365 },
			{ label: "month", ms: 1000 * 60 * 60 * 24 * 30 },
			{ label: "week", ms: 1000 * 60 * 60 * 24 * 7 },
			{ label: "day", ms: 1000 * 60 * 60 * 24 },
			{ label: "hour", ms: 1000 * 60 * 60 },
			{ label: "minute", ms: 1000 * 60 },
		];

		const parts = [];

		for (const unit of units) {
			const count = Math.floor(diffInMs / unit.ms);
			if (count >= 1) {
				parts.push(`${count} ${unit.label}${count !== 1 ? "s" : ""}`);
				diffInMs -= count * unit.ms;
			}
		}

		if (parts.length === 0) return "just now";

		return parts.join(", ") + " ago";
	}

	async function attachYourselfToDispatch(dispatchId: string) {
		const result =
			await dispatchService.attachYourselfToDispatch(dispatchId);
		if (result) {
			dashboardService.setRecentDispatches(result);
		}
	}

	async function detachYourselfFromDispatch(dispatchId: string) {
		const result =
			await dispatchService.detachYourselfFromDispatch(dispatchId);
		if (result) {
			dashboardService.setRecentDispatches(result);
		}
	}

	function openReport(id: number) {
		if (reportOpened === id) {
			reportOpened = null;
		} else {
			reportOpened = id;
		}
	}

	async function loadMoreReports() {
		await dashboardService.loadMoreRecentReports();
	}

	function openWarrant(reportId: number) {
		if (!reportId) return;
		openReportInEditor(reportId);
		tabService.setActiveTab("Reports");
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, "Reports");
		}
	}

	function getCarouselDotOpacity(index: number): number {
		if (index === dashboardService.currentBulletinIndex) {
			return 0.8 - dashboardService.carouselProgress * 0.5;
		}
		return 0.3;
	}
</script>

<div class="dashboard">
	<!-- Top Bar: Stats + Bulletin + Quick Actions -->
	<div class="top-section">
		<div class="stats-strip">
			<div class="stat-item">
				<div class="stat-icon rank-icon">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
				</div>
				<div class="stat-content">
					<span class="stat-value">{dashboardService.jobInfo.rank}</span>
					<span class="stat-label">{dashboardService.jobInfo.payRate}</span>
				</div>
			</div>
			<div class="stat-divider"></div>
			<div class="stat-item">
				<div class="stat-icon reports-icon">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
				</div>
				<div class="stat-content">
					<span class="stat-value">{dashboardService.reportsInfo.totalThisWeek} <span class="stat-change" class:positive={dashboardService.reportsInfo.changeFromLastWeek > 0} class:negative={dashboardService.reportsInfo.changeFromLastWeek < 0}>{#if dashboardService.reportsInfo.changeFromLastWeek > 0}+{/if}{dashboardService.reportsInfo.changeFromLastWeek}</span></span>
					<span class="stat-label">Reports this week</span>
				</div>
			</div>
			<div class="stat-divider"></div>
			<div class="stat-item">
				<div class="stat-icon units-icon">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87"/><path d="M16 3.13a4 4 0 010 7.75"/></svg>
				</div>
				<div class="stat-content">
					<span class="stat-value">{dashboardService.activeUnits.count} <span class="stat-badge">On Duty</span></span>
					<span class="stat-label">Active units</span>
				</div>
			</div>

			<div class="stat-divider"></div>

			<!-- Bulletin inline -->
			<div class="stat-item bulletin-item">
				<div class="stat-icon bulletin-icon">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 17H2a3 3 0 006 0h8a3 3 0 006 0zm0 0V5a2 2 0 00-2-2H4a2 2 0 00-2 2v12"/></svg>
				</div>
				<div class="stat-content bulletin-content">
					{#if dashboardService.bulletins.length > 0}
						<span class="bulletin-text">{dashboardService.bulletins[dashboardService.currentBulletinIndex]?.content || dashboardService.bulletinContent}</span>
						{#if dashboardService.bulletins.length > 1}
							<div class="carousel-dots">
								{#each dashboardService.bulletins as _, index}
									<button
										class="carousel-dot"
										class:active={index === dashboardService.currentBulletinIndex}
										style="opacity: {getCarouselDotOpacity(index)}"
										onclick={() => dashboardService.goToBulletin(index)}
										aria-label="Go to bulletin {index + 1}"
									></button>
								{/each}
							</div>
						{/if}
					{:else}
						<span class="bulletin-empty">No active bulletins</span>
					{/if}
				</div>
			</div>

			<div class="stat-divider"></div>

			<!-- Quick Actions inline -->
			<div class="quick-actions">
				<button class="qa-btn qa-duty" onclick={toggleDuty} title="Toggle Duty">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2v4m0 12v4M4.93 4.93l2.83 2.83m8.48 8.48l2.83 2.83M2 12h4m12 0h4M4.93 19.07l2.83-2.83m8.48-8.48l2.83-2.83"/></svg>
				</button>
				<button class="qa-btn qa-signout" onclick={handleSignOut} title="Sign Out">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
				</button>
			</div>
		</div>
	</div>

	<!-- Main Content Grid -->
	<div class="main-grid">
		{#if isLEO}
		<!-- Left Column: Warrants + BOLOs (LEO only) -->
		<div class="column">
			<div class="panel">
				<div class="panel-header">
					<span class="panel-title">Warrants</span>
					<span class="panel-count">{dashboardService.activeWarrants.length}</span>
				</div>
				<div class="panel-body">
					{#if dashboardService.activeWarrants.length === 0}
						<div class="empty-state">No active warrants</div>
					{:else}
						{#each pagedWarrants as warrant}
							<button class="list-item" onclick={() => openWarrant(warrant.reportid)}>
								<div class="item-left">
									<span class="item-name">{warrant.name}</span>
									<span class="item-meta">
										#{warrant.reportid} · Exp. {new Date(warrant.expirydate).toLocaleDateString()}
									</span>
									<div class="pill-row">
										{#if warrant.felonies > 0}<span class="pill pill-red">{warrant.felonies} Felony</span>{/if}
										{#if warrant.misdemeanors > 0}<span class="pill pill-orange">{warrant.misdemeanors} Misd.</span>{/if}
										{#if warrant.infractions > 0}<span class="pill pill-green">{warrant.infractions} Infr.</span>{/if}
									</div>
								</div>
								<svg class="item-arrow" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>
							</button>
						{/each}
					{/if}
				</div>
				{#if warrantTotalPages > 1}
					<div class="pager">
						<button class="pager-btn" disabled={warrantPage === 0} onclick={() => warrantPage--}>
							<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg>
						</button>
						<span class="pager-info">{warrantPage + 1}/{warrantTotalPages}</span>
						<button class="pager-btn" disabled={warrantPage >= warrantTotalPages - 1} onclick={() => warrantPage++}>
							<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg>
						</button>
					</div>
				{/if}
			</div>

			<div class="panel">
				<div class="panel-header">
					<span class="panel-title">BOLOs</span>
					<span class="panel-count">{(dashboardService.activeBolos || []).length}</span>
				</div>
				<div class="panel-body">
					{#if (dashboardService.activeBolos || []).length === 0}
						<div class="empty-state">No active BOLOs</div>
					{:else}
						{#each pagedBolos as bolo}
							<button class="list-item" onclick={() => viewBolo(bolo.id)}>
								<div class="item-left">
									<span class="item-name">{bolo.name}</span>
									<span class="item-meta">
										#{bolo.reportId} · <span class="pill pill-blue">{bolo.type}</span>
									</span>
									{#if bolo.notes && bolo.notes.trim()}
										<span class="item-notes">{bolo.notes}</span>
									{/if}
								</div>
								<svg class="item-arrow" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>
							</button>
						{/each}
					{/if}
				</div>
				{#if boloTotalPages > 1}
					<div class="pager">
						<button class="pager-btn" disabled={boloPage === 0} onclick={() => boloPage--}>
							<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg>
						</button>
						<span class="pager-info">{boloPage + 1}/{boloTotalPages}</span>
						<button class="pager-btn" disabled={boloPage >= boloTotalPages - 1} onclick={() => boloPage++}>
							<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg>
						</button>
					</div>
				{/if}
			</div>
		</div>
		{/if}

		<!-- Center Column: Recent Reports -->
		<div class="column">
			<div class="panel">
				<div class="panel-header">
					<span class="panel-title">Recent Reports</span>
					<span class="panel-count">{dashboardService.recentReports.length}</span>
				</div>
				<div class="panel-body">
					{#if dashboardService.recentReports.length === 0}
						<div class="empty-state">No recent reports</div>
					{:else}
						{#each dashboardService.recentReports as report}
							<ReportItem
								{report}
								isExpanded={reportOpened === report.id}
								onToggle={openReport}
								onNavigate={viewReport}
							/>
						{/each}
					{/if}
				</div>
				{#if dashboardService.recentReportsHasMore}
					<button class="load-more-btn" onclick={loadMoreReports}>Load more</button>
				{/if}
			</div>
		</div>

		<!-- Right Column: Dispatches (LEO/EMS) or DOJ Panels -->
		<div class="column">
			{#if isDOJ}
				<div class="panel">
					<div class="panel-header">
						<span class="panel-title">Pending Warrant Reviews</span>
						<span class="panel-count">{dojWarrantReviews.length}</span>
					</div>
					<div class="panel-body">
						{#if dojWarrantReviews.length === 0}
							<div class="empty-state">No pending warrants</div>
						{:else}
							{#each dojWarrantReviews as wr}
								<button class="list-item-btn" onclick={() => tabService.openTab('warrant_review')}>
									<span class="item-name">{wr.citizen_name || wr.citizenid}</span>
									<span class="item-meta">{wr.status || 'pending'} · {new Date(wr.created_at).toLocaleDateString()}</span>
								</button>
							{/each}
						{/if}
					</div>
				</div>
				<div class="panel">
					<div class="panel-header">
						<span class="panel-title">Court Cases</span>
						<span class="panel-count">{dojCourtCases.length}</span>
					</div>
					<div class="panel-body">
						{#if dojCourtCases.length === 0}
							<div class="empty-state">No court cases</div>
						{:else}
							{#each dojCourtCases as cc}
								<button class="list-item-btn" onclick={() => tabService.openTab('court_cases')}>
									<span class="item-name">{cc.title || cc.case_number}</span>
									<span class="item-meta">{cc.status} · {new Date(cc.created_at || cc.filed_date).toLocaleDateString()}</span>
								</button>
							{/each}
						{/if}
					</div>
				</div>
				<div class="panel">
					<div class="panel-header">
						<span class="panel-title">Court Orders</span>
						<span class="panel-count">{dojCourtOrders.length}</span>
					</div>
					<div class="panel-body">
						{#if dojCourtOrders.length === 0}
							<div class="empty-state">No court orders</div>
						{:else}
							{#each dojCourtOrders as co}
								<button class="list-item-btn" onclick={() => tabService.openTab('court_orders')}>
									<span class="item-name">{co.title || co.order_number}</span>
									<span class="item-meta">{co.status} · {new Date(co.created_at).toLocaleDateString()}</span>
								</button>
							{/each}
						{/if}
					</div>
				</div>
			{:else}
				<div class="panel">
					<div class="panel-header">
						<span class="panel-title">Dispatches</span>
						<span class="panel-count">{(dashboardService.recentDispatches && Array.isArray(dashboardService.recentDispatches) ? dashboardService.recentDispatches : []).length}</span>
					</div>
					<div class="panel-body">
						{#each dashboardService.recentDispatches && Array.isArray(dashboardService.recentDispatches) ? dashboardService.recentDispatches.slice().reverse() : [] as dispatch}
							<div class="dispatch-item" class:expanded={expandedDispatch === dispatch.id}>
								<button
									class="dispatch-btn"
									onclick={() => toggleDispatch(dispatch.id)}
									aria-expanded={expandedDispatch === dispatch.id}
								>
									<div class="priority-bar" style="background: {getPriorityColor(dispatch.priority)}"></div>
									<div class="item-left">
										<span class="item-name">{dispatch.message}</span>
										<span class="item-meta">{dispatch.street} · {getTimeTranslated(dispatch.time)}</span>
									</div>
								</button>

								{#if expandedDispatch === dispatch.id}
									<div class="dispatch-detail">
										<div class="dispatch-detail-header">
											<span class="detail-label">Attached Units</span>
											<div class="dispatch-btns">
												<button
													class="d-action-btn"
													onclick={() =>
														dispatchService.isUserAttachedToDispatch(dispatch, playerData)
															? detachYourselfFromDispatch(dispatch.id)
															: attachYourselfToDispatch(dispatch.id)}
												>
													{dispatchService.isUserAttachedToDispatch(dispatch, playerData) ? "Detach" : "Attach"}
												</button>
												<button
													class="d-action-btn"
													onclick={() => dispatchService.routeToDispatch(dispatch)}
												>
													Route
												</button>
											</div>
										</div>
										<div class="unit-chips">
											{#each dispatch.units as unit}
												<span class="unit-chip">
													{dispatchService.getCallSign(unit.metadata?.callsign)} - {unit.charinfo?.firstname} {unit.charinfo?.lastname}
												</span>
											{/each}
										</div>
									</div>
								{/if}
							</div>
						{/each}
					</div>
				</div>
			{/if}
		</div>
	</div>
</div>

<style>
	/* ===== Layout ===== */
	.dashboard {
		display: flex;
		flex-direction: column;
		height: 100%;
		overflow: hidden;
		background: var(--card-dark-bg);
	}

	/* ===== Top Stats Strip ===== */
	.top-section {
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.stats-strip {
		display: flex;
		align-items: center;
		padding: 0 20px;
		height: 52px;
		gap: 0;
	}

	.stat-divider {
		width: 1px;
		height: 28px;
		background: rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
	}

	.stat-item {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 0 16px;
		flex-shrink: 0;
	}

	.bulletin-item {
		flex: 1;
		min-width: 0;
	}

	.stat-icon {
		width: 30px;
		height: 30px;
		border-radius: 8px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.rank-icon { background: rgba(168, 85, 247, 0.12); color: #a78bfa; }
	.reports-icon { background: rgba(16, 185, 129, 0.12); color: #34d399; }
	.units-icon { background: rgba(var(--accent-rgb), 0.12); color: #60a5fa; }
	.bulletin-icon { background: rgba(251, 191, 36, 0.12); color: #fbbf24; }

	.stat-content {
		display: flex;
		flex-direction: column;
		min-width: 0;
	}

	.bulletin-content {
		flex: 1;
	}

	.stat-value {
		color: rgba(255, 255, 255, 0.9);
		font-size: 13px;
		font-weight: 600;
		line-height: 1.2;
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.stat-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.stat-change {
		font-size: 11px;
		font-weight: 600;
	}
	.stat-change.positive { color: #34d399; }
	.stat-change.negative { color: #f87171; }

	.stat-badge {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		background: rgba(var(--accent-rgb), 0.15);
		color: #60a5fa;
		padding: 1px 6px;
		border-radius: 3px;
	}

	/* ===== Bulletin (inline) ===== */
	.bulletin-text {
		color: rgba(255, 255, 255, 0.6);
		font-size: 12px;
		line-height: 1.3;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.bulletin-empty {
		color: rgba(255, 255, 255, 0.3);
		font-size: 11px;
	}

	.carousel-dots {
		display: flex;
		gap: 4px;
		margin-top: 2px;
	}

	.carousel-dot {
		width: 4px;
		height: 4px;
		border-radius: 50%;
		border: none;
		background: rgba(255, 255, 255, 0.8);
		cursor: pointer;
		padding: 0;
		transition: opacity 0.1s ease, transform 0.2s ease;
	}

	.carousel-dot.active {
		transform: scale(1.4);
	}

	.carousel-dot:hover {
		opacity: 0.9 !important;
	}

	/* ===== Quick Actions (inline) ===== */
	.quick-actions {
		display: flex;
		gap: 6px;
		padding-left: 16px;
		flex-shrink: 0;
	}

	.qa-btn {
		width: 32px;
		height: 32px;
		border-radius: 8px;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: all 0.15s;
		border: 1px solid transparent;
	}

	.qa-duty {
		background: rgba(16, 185, 129, 0.1);
		color: #34d399;
		border-color: rgba(16, 185, 129, 0.15);
	}

	.qa-duty:hover {
		background: rgba(16, 185, 129, 0.2);
		border-color: rgba(16, 185, 129, 0.3);
	}

	.qa-signout {
		background: rgba(239, 68, 68, 0.08);
		color: #f87171;
		border-color: rgba(239, 68, 68, 0.1);
	}

	.qa-signout:hover {
		background: rgba(239, 68, 68, 0.15);
		border-color: rgba(239, 68, 68, 0.25);
	}

	/* ===== Main Grid ===== */
	.main-grid {
		display: grid;
		grid-template-columns: 1fr 1fr 1fr;
		flex: 1;
		min-height: 0;
	}

	.column {
		display: flex;
		flex-direction: column;
		min-height: 0;
		border-right: 1px solid rgba(255, 255, 255, 0.06);
	}

	.column:last-child {
		border-right: none;
	}

	/* ===== Panels ===== */
	.panel {
		display: flex;
		flex-direction: column;
		flex: 1;
		min-height: 0;
		overflow: hidden;
	}

	.panel + .panel {
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}

	.panel-header {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px 16px 10px;
		flex-shrink: 0;
	}

	.panel-title {
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 1px;
	}

	.panel-count {
		background: rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		font-weight: 600;
		padding: 0 5px;
		border-radius: 4px;
		line-height: 16px;
	}

	/* ===== Panel Body ===== */
	.panel-body {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		padding: 0 10px 10px;
		display: flex;
		flex-direction: column;
		gap: 2px;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.08) transparent;
	}

	.panel-body::-webkit-scrollbar { width: 3px; }
	.panel-body::-webkit-scrollbar-track { background: transparent; }
	.panel-body::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.08); border-radius: 2px; }

	/* ===== List Items ===== */
	.list-item {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 10px;
		border-radius: 6px;
		background: transparent;
		border: none;
		cursor: pointer;
		transition: background 0.1s;
		text-align: left;
		color: inherit;
		font: inherit;
		width: 100%;
	}

	.list-item:hover {
		background: rgba(255, 255, 255, 0.04);
	}

	.item-left {
		display: flex;
		flex-direction: column;
		gap: 2px;
		flex: 1;
		min-width: 0;
	}

	.item-name {
		color: rgba(255, 255, 255, 0.85);
		font-size: 12px;
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.item-meta {
		color: rgba(255, 255, 255, 0.3);
		font-size: 11px;
		display: flex;
		align-items: center;
		gap: 4px;
	}

	.item-notes {
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
		line-height: 1.3;
		margin-top: 1px;
		display: -webkit-box;
		-webkit-line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}

	.item-arrow {
		color: rgba(255, 255, 255, 0.15);
		flex-shrink: 0;
		transition: color 0.12s;
	}

	.list-item:hover .item-arrow {
		color: rgba(255, 255, 255, 0.4);
	}

	/* ===== Pills ===== */
	.pill-row {
		display: flex;
		gap: 4px;
		margin-top: 3px;
		flex-wrap: wrap;
	}

	.pill {
		padding: 1px 5px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
		letter-spacing: 0.2px;
		border: 1px solid transparent;
	}

	.pill-red { background: rgba(239, 68, 68, 0.12); color: #f87171; border-color: rgba(239, 68, 68, 0.15); }
	.pill-orange { background: rgba(245, 158, 11, 0.12); color: #fbbf24; border-color: rgba(245, 158, 11, 0.15); }
	.pill-green { background: rgba(16, 185, 129, 0.12); color: #34d399; border-color: rgba(16, 185, 129, 0.15); }
	.pill-blue { background: rgba(var(--accent-rgb), 0.12); color: #60a5fa; border-color: rgba(var(--accent-rgb), 0.15); }

	/* ===== Pager ===== */
	.pager {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		padding: 6px 16px 10px;
		flex-shrink: 0;
	}

	.pager-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 22px;
		height: 22px;
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 4px;
		color: rgba(255, 255, 255, 0.35);
		cursor: pointer;
		transition: all 0.12s;
	}

	.pager-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.7);
	}

	.pager-btn:disabled {
		opacity: 0.2;
		cursor: default;
	}

	.pager-info {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.35);
		font-weight: 500;
	}

	/* ===== Empty & Load More ===== */
	.empty-state {
		color: rgba(255, 255, 255, 0.2);
		font-size: 11px;
		text-align: center;
		padding: 24px 0;
	}

	.load-more-btn {
		background: transparent;
		color: rgba(255, 255, 255, 0.35);
		border: none;
		border-top: 1px solid rgba(255, 255, 255, 0.04);
		padding: 8px;
		font-size: 11px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.12s;
		text-align: center;
		flex-shrink: 0;
	}

	.load-more-btn:hover {
		color: rgba(255, 255, 255, 0.5);
		background: rgba(255, 255, 255, 0.02);
	}

	/* ===== Dispatch Items ===== */
	.dispatch-item {
		border-radius: 6px;
		overflow: hidden;
		transition: background 0.1s;
	}

	.dispatch-item:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.dispatch-item.expanded {
		background: rgba(255, 255, 255, 0.03);
	}

	.dispatch-btn {
		width: 100%;
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 8px 10px;
		background: none;
		border: none;
		cursor: pointer;
		color: inherit;
		font: inherit;
		text-align: left;
	}

	.priority-bar {
		width: 3px;
		height: 24px;
		border-radius: 2px;
		flex-shrink: 0;
	}

	.dispatch-detail {
		padding: 0 10px 10px 23px;
	}

	.dispatch-detail-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding-bottom: 6px;
	}

	.detail-label {
		color: rgba(255, 255, 255, 0.3);
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.dispatch-btns {
		display: flex;
		gap: 4px;
	}

	.d-action-btn {
		background: rgba(var(--accent-rgb), 0.1);
		color: #60a5fa;
		border: 1px solid rgba(var(--accent-rgb), 0.15);
		padding: 3px 8px;
		border-radius: 4px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.12s;
	}

	.d-action-btn:hover {
		background: rgba(var(--accent-rgb), 0.18);
		border-color: rgba(var(--accent-rgb), 0.3);
	}

	.unit-chips {
		display: flex;
		flex-wrap: wrap;
		gap: 4px;
	}

	.unit-chip {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.5);
		padding: 2px 7px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
	}

	.list-item-btn {
		display: flex;
		flex-direction: column;
		gap: 2px;
		width: 100%;
		padding: 8px 12px;
		background: none;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		cursor: pointer;
		text-align: left;
		color: inherit;
	}

	.list-item-btn:hover {
		background: rgba(255, 255, 255, 0.04);
	}
</style>
