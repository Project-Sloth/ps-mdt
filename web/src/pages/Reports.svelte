<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { useNuiEvent } from "../utils/useNuiEvent";
	import { debugError } from "../utils/debug";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { REPORT_TYPES } from "../constants";
	import ReportEditor from "./ReportEditor.svelte";
	import type { createInstanceStateService } from "../services/instanceStateService.svelte";
	import { createReportService } from "../services/reportService.svelte";
	import {
		pendingReportId,
		clearPendingReport,
	} from "../stores/reportsStore";
	import type { createTabService } from "../services/tabService.svelte";
	import type { MDTTab } from "../constants";
	import Pagination from "../components/Pagination.svelte";

	import type { JobType } from "../interfaces/IUser";

	interface Props {
		instanceStateService: ReturnType<typeof createInstanceStateService>;
		tabService?: ReturnType<typeof createTabService>;
		jobType?: JobType;
	}

	let { instanceStateService, tabService, jobType = 'leo' }: Props = $props();

	function navigateTo(tab: MDTTab) {
		if (!tabService) return;
		tabService.setActiveTab(tab);
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, tab);
		}
	}
	const reportService = createReportService();

	interface Report {
		id: string;
		title: string;
		reportId: string;
		author: string;
		type: string;
		datecreated: number;
		dateupdated: number;
		tag?: string;
		tagCount?: number;
	}

	let reports: Report[] = $state([]);
	let filteredReports: Report[] = $state([]);
	let searchQuery = $state("");
	let filterAuthor = $state("");
	let filterType = $state("");
	let filterStartDate = $state("");
	let filterEndDate = $state("");
	let analytics = $state({ incidents: 0, arrests: 0, warrants: 0 });
	let isLoading = $state(false);
	let currentPage = $state(1);
	let reportsPerPage = $state(50);
	let totalReports = $state(0);

	let showEditor = $state(false);
	let editingReportId: string | null = $state(null);
	let pendingOpenId = $state<string | null>(null);
	let debouncedSearchQuery = $state("");
	let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null;

	$effect(() => {
		pendingOpenId = $pendingReportId;
		if (pendingOpenId) {
			editingReportId = pendingOpenId === "new" ? null : String(pendingOpenId);
			showEditor = true;
			clearPendingReport();
		}
	});

	// Debounce search input (200ms)
	$effect(() => {
		const query = searchQuery;
		if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
		searchDebounceTimer = setTimeout(() => {
			debouncedSearchQuery = query;
		}, 200);
	});

	$effect(() => {
		if (debouncedSearchQuery.trim() === "") {
			filteredReports = reports;
		} else {
			const query = debouncedSearchQuery.toLowerCase();
			filteredReports = reports.filter(
				(report) =>
					report.title.toLowerCase().includes(query) ||
					report.reportId.toLowerCase().includes(query) ||
					report.author.toLowerCase().includes(query) ||
					report.type.toLowerCase().includes(query) ||
					(report.tag && report.tag.toLowerCase().includes(query)),
			);
		}
	});

	onMount(() => {
		if (isEnvBrowser()) {
			const now = Date.now();
			reports = [
				{ id: '1', title: 'Armed Robbery at Fleeca Bank', reportId: 'RPT-001', author: 'Ofc. Smith', type: 'Incident', datecreated: now - 86400000, dateupdated: now - 3600000, tag: 'Priority' },
				{ id: '2', title: 'Traffic Stop - Suspended License', reportId: 'RPT-002', author: 'Ofc. Johnson', type: 'Citation', datecreated: now - 172800000, dateupdated: now - 86400000 },
				{ id: '3', title: 'Drive-by Shooting on Vinewood Blvd', reportId: 'RPT-003', author: 'Det. Williams', type: 'Incident', datecreated: now - 259200000, dateupdated: now - 172800000, tag: 'Priority' },
				{ id: '4', title: 'Arrest Report - David Chen', reportId: 'RPT-004', author: 'Sgt. Garcia', type: 'Arrest', datecreated: now - 345600000, dateupdated: now - 259200000 },
				{ id: '5', title: 'Noise Complaint - Vespucci Beach', reportId: 'RPT-005', author: 'Ofc. Brown', type: 'Incident', datecreated: now - 432000000, dateupdated: now - 345600000 },
				{ id: '6', title: 'Warrant Execution - Marcus Johnson', reportId: 'RPT-006', author: 'Det. Williams', type: 'Arrest', datecreated: now - 518400000, dateupdated: now - 432000000, tag: 'Warrant' },
				{ id: '7', title: 'Hit and Run - Del Perro Pier', reportId: 'RPT-007', author: 'Ofc. Smith', type: 'Incident', datecreated: now - 604800000, dateupdated: now - 518400000 },
			];
			filteredReports = reports;
			analytics = { incidents: 4, arrests: 2, warrants: 1 };
			isLoading = false;
			return;
		}

		loadReports();
		loadAnalytics();

		return () => {
			if (searchDebounceTimer) {
				clearTimeout(searchDebounceTimer);
				searchDebounceTimer = null;
			}
		};
	});

	function hasActiveFilters() {
		return Boolean(
			filterStartDate ||
			filterEndDate ||
			filterType ||
			filterAuthor.trim(),
		);
	}

	useNuiEvent<{ reports: Report[] }>(
		NUI_EVENTS.REPORT.UPDATE_REPORTS,
		(data) => {
			reports = data.reports || [];
		},
	);

	async function loadReports(page: number = 1) {
		try {
			isLoading = true;
			const filters = {
				startDate: filterStartDate || undefined,
				endDate: filterEndDate || undefined,
				type: filterType || undefined,
				author: filterAuthor.trim() || undefined,
			};
			const response = await fetchNui(
				NUI_EVENTS.REPORT.GET_REPORTS,
				{ page, limit: reportsPerPage, filters },
			);

			reports = response.reports || [];
			totalReports = response.total ?? reports.length;
			currentPage = page;
		} catch (error) {
			debugError("Failed to load reports:", error);
		} finally {
			isLoading = false;
		}
	}

	async function refreshReports() {
		currentPage = 1;
		await loadReports(1);
		await loadAnalytics();
	}

	async function loadAnalytics() {
		try {
			const filters = {
				startDate: filterStartDate || undefined,
				endDate: filterEndDate || undefined,
				author: filterAuthor.trim() || undefined,
			};
			analytics = await reportService.getReportAnalytics(filters);
		} catch (error) {
			debugError("Failed to load report analytics:", error);
		}
	}

	function createNewReport() {
		editingReportId = null;
		showEditor = true;
	}

	function viewReport(reportId: string) {
		editingReportId = reportId;
		showEditor = true;
	}

	useNuiEvent<{ reportId: string }>(
		NUI_EVENTS.NAVIGATION.VIEW_REPORT,
		(data) => {
			if (data?.reportId) {
				viewReport(String(data.reportId));
			}
		},
	);

	function closeEditor() {
		showEditor = false;
		editingReportId = null;
		refreshReports();
	}

	function formatDate(timestamp: number): string {
		return new Date(timestamp).toLocaleDateString("en-US", {
			month: "2-digit",
			day: "2-digit",
			year: "numeric",
		});
	}

	function formatTime(timestamp: number): string {
		return new Date(timestamp).toLocaleTimeString("en-US", {
			hour: "2-digit",
			minute: "2-digit",
			hour12: false,
		});
	}

	function getTagColor(tag: string): string {
		if (!tag) return "hsl(145 70% 45%)";
		let hash = 0;
		for (let i = 0; i < tag.length; i += 1) {
			hash = (hash << 5) - hash + tag.charCodeAt(i);
			hash |= 0;
		}
		const hue = Math.abs(hash) % 360;
		return `hsl(${hue} 70% 45%)`;
	}

	function getTypePillClass(type: string): string {
		switch (type) {
			case "Incident": return "pill pill-blue";
			case "Citation": return "pill pill-orange";
			case "Arrest": return "pill pill-red";
			default: return "pill pill-grey";
		}
	}
</script>

{#if showEditor}
	<ReportEditor
		reportId={editingReportId}
		onClose={closeEditor}
		{instanceStateService}
		{tabService}
		{jobType}
	/>
{:else}
	<div class="reports-page">
		<!-- Topbar -->
		<div class="topbar">
			<div class="topbar-left">
				<div class="search-box">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
					<input type="text" bind:value={searchQuery} placeholder="Search by title, author, ID, type or tag..." />
				</div>
			</div>
			<div class="topbar-right">
				<input
					type="date"
					bind:value={filterStartDate}
					class="filter-input"
					aria-label="Filter start date"
				/>
				<input
					type="date"
					bind:value={filterEndDate}
					class="filter-input"
					aria-label="Filter end date"
				/>
				<select
					class="filter-select"
					bind:value={filterType}
					aria-label="Filter report type"
				>
					<option value="">All Types</option>
					{#each REPORT_TYPES as type}
						<option value={type}>{type}</option>
					{/each}
				</select>
				<input
					type="text"
					placeholder="Author"
					bind:value={filterAuthor}
					class="filter-input filter-author"
					aria-label="Filter author"
				/>
				<button class="topbar-btn" onclick={refreshReports} disabled={isLoading}>Apply</button>
				<button
					class="topbar-btn"
					onclick={() => {
						filterStartDate = "";
						filterEndDate = "";
						filterType = "";
						filterAuthor = "";
						refreshReports();
					}}
					disabled={isLoading || !hasActiveFilters()}
				>Clear</button>
		<button class="topbar-btn btn-primary" onclick={createNewReport}>New Report</button>
			</div>
		</div>

		<!-- Analytics Strip -->
		<div class="analytics-strip">
			<div class="stat-item">
				<svg class="stat-icon stat-icon-blue" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
				<span class="stat-value">{analytics.incidents}</span>
				<span class="stat-label">Incidents</span>
			</div>
			<div class="stat-divider"></div>
			<div class="stat-item">
				<svg class="stat-icon stat-icon-red" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"/></svg>
				<span class="stat-value">{analytics.arrests}</span>
				<span class="stat-label">Arrests</span>
			</div>
			<div class="stat-divider"></div>
			<div class="stat-item">
				<svg class="stat-icon stat-icon-amber" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
				<span class="stat-value">{analytics.warrants}</span>
				<span class="stat-label">Warrants</span>
			</div>
		</div>

		<!-- List Panel -->
		<div class="list-panel">
			<div class="list-header">
				<span>Title</span>
				<span>Report ID</span>
				<span>Author</span>
				<span>Type</span>
				<span>Created</span>
				<span>Updated</span>
				<span>Tag</span>
			</div>
			<div class="list-body">
				{#if isLoading && reports.length === 0}
					<div class="empty-state">
						<div class="loading-spinner"></div>
						Loading reports...
					</div>
				{:else if filteredReports.length === 0}
					<div class="empty-state">
						<div class="empty-content">
							<svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" style="opacity: 0.3; margin-bottom: 12px;"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>
							<span class="empty-title">No Reports Found</span>
							<span class="empty-sub">
								{searchQuery
									? "No reports match your search criteria."
									: "No reports have been created yet."}
							</span>
							{#if !searchQuery}
								<button class="topbar-btn btn-primary" onclick={createNewReport} style="margin-top: 12px;">
									Create First Report
								</button>
							{/if}
						</div>
					</div>
				{:else}
					{#each filteredReports.slice().reverse() as report}
						<button class="report-row" onclick={() => viewReport(report.id)}>
							<span class="col-title">{report.title}</span>
							<span class="col-id mono">{report.reportId}</span>
							<span class="col-author">{report.author}</span>
							<span class="col-type">
								<span class={getTypePillClass(report.type)}>{report.type}</span>
							</span>
							<span class="col-date">{formatDate(report.datecreated)}</span>
							<span class="col-date">{formatDate(report.dateupdated)}</span>
							<span class="col-tag">
								{#if report.tag}
									<span
										class="pill tag-pill"
										style="background: {getTagColor(report.tag)}22; color: {getTagColor(report.tag)}; border: 1px solid {getTagColor(report.tag)}33;"
									>{report.tag}</span>
									{#if (report.tagCount ?? 0) > 1}
										<span class="tag-more">+{(report.tagCount ?? 0) - 1}</span>
									{/if}
								{/if}
							</span>
						</button>
					{/each}
				{/if}
			</div>
			<Pagination
				currentPage={currentPage}
				totalItems={totalReports}
				perPage={reportsPerPage}
				onPageChange={(p) => loadReports(p)}
				onPerPageChange={(pp) => { reportsPerPage = pp; loadReports(1); }}
			/>
		</div>
	</div>
{/if}

<style>
	/* ===== Page ===== */
	.reports-page {
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
		padding: 0 20px;
		height: 48px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.topbar-left {
		flex: 1;
		min-width: 0;
	}

	.topbar-right {
		display: flex;
		align-items: center;
		gap: 6px;
		flex-shrink: 0;
	}

	.search-box {
		display: flex;
		align-items: center;
		gap: 8px;
		background: transparent;
		border: none;
		padding: 0;
		max-width: 420px;
		color: rgba(255, 255, 255, 0.3);
	}

	.search-box input {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.9);
		font-size: 12px;
		padding: 0;
		width: 100%;
		outline: none;
	}

	.search-box input::placeholder {
		color: rgba(255, 255, 255, 0.35);
	}

	.filter-input {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 4px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.7);
		font-size: 11px;
		outline: none;
		transition: border-color 0.15s ease;
		color-scheme: dark;
	}

	.filter-select {
		border-radius: 4px;
		padding: 5px 24px 5px 8px;
		font-size: 11px;
	}

	.filter-input:focus,
	.filter-select:focus {
		border-color: rgba(255, 255, 255, 0.15);
	}

	.filter-input::-webkit-calendar-picker-indicator {
		filter: invert(0.5);
		cursor: pointer;
	}

	.filter-author {
		width: 80px;
	}

	.topbar-btn {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 4px;
		padding: 5px 12px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 11px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.15s ease;
		white-space: nowrap;
	}

	.topbar-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.7);
	}

	.topbar-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.btn-primary {
		background: rgba(var(--accent-rgb), 0.1);
		color: rgba(var(--accent-text-rgb), 0.8);
		border-color: rgba(var(--accent-rgb), 0.2);
	}

	.btn-primary:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.18);
		color: #93c5fd;
	}

	/* ===== Analytics Strip ===== */
	.analytics-strip {
		display: flex;
		align-items: center;
		padding: 0 20px;
		height: 40px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		gap: 0;
	}

	.stat-item {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 0 16px;
	}

	.stat-item:first-child {
		padding-left: 0;
	}

	.stat-icon {
		opacity: 0.7;
		flex-shrink: 0;
	}

	.stat-icon-blue { color: #60a5fa; }
	.stat-icon-red { color: #f87171; }
	.stat-icon-amber { color: #fbbf24; }

	.stat-value {
		font-size: 14px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}

	.stat-label {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.3);
		text-transform: uppercase;
		letter-spacing: 0.5px;
		font-weight: 500;
	}

	.stat-divider {
		width: 1px;
		height: 18px;
		background: rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
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
		grid-template-columns: 2fr 0.8fr 1fr 0.8fr 0.8fr 0.8fr 0.8fr;
		gap: 12px;
		padding: 8px 20px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.8px;
		flex-shrink: 0;
	}

	.list-body {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.08) transparent;
	}

	.list-body::-webkit-scrollbar { width: 3px; }
	.list-body::-webkit-scrollbar-track { background: transparent; }
	.list-body::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.08); border-radius: 2px; }

	/* ===== Report Row ===== */
	.report-row {
		display: grid;
		grid-template-columns: 2fr 0.8fr 1fr 0.8fr 0.8fr 0.8fr 0.8fr;
		gap: 12px;
		padding: 9px 20px;
		align-items: center;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		background: transparent;
		cursor: pointer;
		transition: background 0.12s ease;
		width: 100%;
		text-align: left;
		font: inherit;
		color: inherit;
	}

	.report-row:hover {
		background: rgba(255, 255, 255, 0.03);
	}

	.col-title {
		color: rgba(255, 255, 255, 0.85);
		font-size: 12px;
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.col-id {
		color: rgba(255, 255, 255, 0.4);
		font-size: 11px;
	}

	.col-author {
		color: rgba(255, 255, 255, 0.4);
		font-size: 11px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.col-type {
		display: flex;
		align-items: center;
	}

	.col-date {
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
	}

	.col-tag {
		display: flex;
		align-items: center;
	}

	.mono {
		font-family: monospace;
		letter-spacing: 0.5px;
	}

	/* ===== Pills ===== */
	.pill {
		padding: 2px 7px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 600;
		letter-spacing: 0.3px;
		white-space: nowrap;
	}

	.pill-blue {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.8);
		border: 1px solid rgba(var(--accent-rgb), 0.15);
	}

	.pill-orange {
		background: rgba(245, 158, 11, 0.12);
		color: rgba(251, 191, 36, 0.8);
		border: 1px solid rgba(245, 158, 11, 0.15);
	}

	.pill-red {
		background: rgba(239, 68, 68, 0.12);
		color: rgba(248, 113, 113, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.15);
	}

	.pill-grey {
		background: rgba(107, 114, 128, 0.12);
		color: rgba(156, 163, 175, 0.8);
		border: 1px solid rgba(107, 114, 128, 0.15);
	}

	.tag-pill {
		border-radius: 3px;
		text-transform: uppercase;
	}

	.tag-more {
		font-size: 9px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.2);
		margin-left: 2px;
		white-space: nowrap;
	}

	/* ===== Empty / Loading ===== */
	.empty-state {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 60px 20px;
		color: rgba(255, 255, 255, 0.3);
		font-size: 12px;
	}

	.empty-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		gap: 4px;
	}

	.empty-title {
		color: rgba(255, 255, 255, 0.4);
		font-size: 14px;
		font-weight: 600;
	}

	.empty-sub {
		color: rgba(255, 255, 255, 0.35);
		font-size: 12px;
	}

	.loading-spinner {
		width: 20px;
		height: 20px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left: 2px solid rgba(255, 255, 255, 0.25);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-right: 10px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
</style>
