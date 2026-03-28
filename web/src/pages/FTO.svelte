<script lang="ts">
	import { onMount } from "svelte";
	import { isEnvBrowser } from "../utils/misc";
	import { fetchNui } from "../utils/fetchNui";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { globalNotifications } from "../services/notificationService.svelte";
	import { createSearchService } from "../services/searchService.svelte";
	import Pagination from "../components/Pagination.svelte";
	import PersonSearchModal from "../components/report-editor/PersonSearchModal.svelte";
	import type { createTabService } from "../services/tabService.svelte";
	import type { AuthService } from "../services/authService.svelte";

	let { tabService, authService }: { tabService?: ReturnType<typeof createTabService>; authService?: AuthService } = $props();

	interface FTOPhase {
		id: number;
		name: string;
		description?: string;
		duration_days?: number;
		sort_order: number;
	}

	interface FTOCompetency {
		id: number;
		name: string;
		category?: string;
		sort_order: number;
	}

	interface FTOAssignment {
		id: number;
		fto_number: string;
		trainee_name: string;
		trainee_citizenid: string;
		trainer_name: string;
		trainer_citizenid: string;
		current_phase: string;
		current_phase_id?: number;
		status: string;
		start_date: string;
		end_date?: string;
		notes?: string;
		dor_count: number;
		latest_rating?: number;
		created_at: string;
	}

	interface FTODor {
		id: number;
		shift_date: string;
		ratings: { competency_id: number; competency_name: string; rating: number }[];
		overall_rating: number;
		notes?: string;
		author_name?: string;
		created_at: string;
	}

	interface FTODetail {
		assignment: FTOAssignment;
		dors: FTODor[];
	}

	// State
	let assignments = $state<FTOAssignment[]>([]);
	let selectedDetail = $state<FTODetail | null>(null);
	let loading = $state(false);
	let searchQuery = $state("");
	let statusFilter = $state<string>("active");
	let page = $state(1);
	let perPage = $state(20);
	let showCreateForm = $state(false);
	let showDorForm = $state(false);

	// Phases & competencies (for create / DOR)
	let phases = $state<FTOPhase[]>([]);
	let competencies = $state<FTOCompetency[]>([]);

	// Create form state
	let newTraineeCitizenId = $state("");
	let newTraineeName = $state("");
	let newTrainerCitizenId = $state("");
	let newTrainerName = $state("");
	let newPhaseId = $state<number | undefined>(undefined);
	let newStartDate = $state("");
	let newNotes = $state("");
	let isSubmitting = $state(false);

	// DOR form state
	let dorShiftDate = $state("");
	let dorRatings = $state<{ competency_id: number; rating: number }[]>([]);
	let dorNotes = $state("");
	let dorSubmitting = $state(false);

	// Person search
	const searchService = createSearchService();
	let showTraineeSearch = $state(false);
	let showTrainerSearch = $state(false);
	let personSearchQuery = $state("");

	let canManage = $derived(authService?.hasPermission('fto_manage') ?? false);
	let mounted = false;

	const statusOptions = ["active", "completed", "failed", "suspended", "all"];

	onMount(async () => {
		await loadPhases();
		await loadCompetencies();
		if (isEnvBrowser()) {
			assignments = [
				{ id: 1, fto_number: 'FTO-2026-00001', trainee_name: 'Ofc. Williams', trainee_citizenid: 'ABC123', trainer_name: 'Sgt. Johnson', trainer_citizenid: 'XYZ789', current_phase: 'Phase 1', status: 'active', start_date: '2026-03-01', dor_count: 5, latest_rating: 3.8, created_at: '2026-03-01T10:00:00Z' },
				{ id: 2, fto_number: 'FTO-2026-00002', trainee_name: 'Ofc. Thompson', trainee_citizenid: 'DEF456', trainer_name: 'Lt. Baker', trainer_citizenid: 'UVW321', current_phase: 'Phase 3', status: 'completed', start_date: '2026-01-15', end_date: '2026-03-10', dor_count: 12, latest_rating: 4.2, created_at: '2026-01-15T08:00:00Z' },
			];
			loading = false;
			mounted = true;
			return;
		}
		await loadAssignments();
		mounted = true;
	});

	async function loadPhases() {
		try {
			const result = await fetchNui<FTOPhase[]>(NUI_EVENTS.FTO.GET_FTO_PHASES, {}, []);
			phases = result || [];
		} catch { phases = []; }
	}

	async function loadCompetencies() {
		try {
			const result = await fetchNui<FTOCompetency[]>(NUI_EVENTS.FTO.GET_FTO_COMPETENCIES, {}, []);
			competencies = result || [];
		} catch { competencies = []; }
	}

	async function loadAssignments() {
		loading = true;
		try {
			const data = await fetchNui<{ entries: FTOAssignment[]; hasMore?: boolean }>(
				NUI_EVENTS.FTO.GET_FTO_LIST,
				{ page, status: statusFilter === 'all' ? '' : statusFilter, search: searchQuery.trim() || '' },
				{ entries: [], hasMore: false }
			);
			assignments = data.entries || [];
		} catch (e) {
			console.error('[FTO] loadAssignments error:', e);
			globalNotifications.error("Failed to load FTO assignments");
		}
		loading = false;
	}

	async function selectAssignment(id: number) {
		loading = true;
		try {
			const response = await fetchNui<{ success: boolean; data?: { entry: FTOAssignment; dors: any[] } }>(
				NUI_EVENTS.FTO.GET_FTO,
				{ id },
				{ success: true, data: { entry: assignments.find(a => a.id === id)!, dors: [] } }
			);
			const raw = response?.data;
			const fallback = assignments.find(a => a.id === id)!;
			selectedDetail = {
				assignment: raw?.entry || fallback,
				dors: raw?.dors || [],
			};
		} catch {
			globalNotifications.error("Failed to load FTO assignment details");
		}
		loading = false;
	}

	function goBack() {
		selectedDetail = null;
		showDorForm = false;
		dorRatings = [];
		dorNotes = "";
		dorShiftDate = "";
		if (!isEnvBrowser()) loadAssignments();
	}

	function resetCreateForm() {
		newTraineeCitizenId = "";
		newTraineeName = "";
		newTrainerCitizenId = "";
		newTrainerName = "";
		newPhaseId = undefined;
		newStartDate = "";
		newNotes = "";
	}

	async function handleCreate() {
		if (!newTraineeCitizenId || !newTrainerCitizenId || isSubmitting) return;
		isSubmitting = true;
		try {
			const result = await fetchNui<{ success: boolean; error?: string }>(
				NUI_EVENTS.FTO.CREATE_FTO_ASSIGNMENT,
				{
					trainee_citizenid: newTraineeCitizenId,
					trainee_name: newTraineeName,
					trainer_citizenid: newTrainerCitizenId,
					trainer_name: newTrainerName,
					phase_id: newPhaseId || undefined,
					start_date: newStartDate || undefined,
					notes: newNotes.trim() || undefined,
				},
				{ success: true }
			);
			if (!result || result.success === false) {
				globalNotifications.error(result?.error || "Failed to create FTO assignment");
				isSubmitting = false;
				return;
			}
			globalNotifications.success("FTO assignment created");
			resetCreateForm();
			showCreateForm = false;
			if (!isEnvBrowser()) loadAssignments();
		} catch {
			globalNotifications.error("Failed to create FTO assignment");
		}
		isSubmitting = false;
	}

	async function handleDelete() {
		if (!selectedDetail || !canManage) return;
		try {
			await fetchNui(NUI_EVENTS.FTO.DELETE_FTO_ASSIGNMENT, { id: selectedDetail.assignment.id }, { success: true });
			globalNotifications.success("FTO assignment deleted");
			goBack();
		} catch {
			globalNotifications.error("Failed to delete FTO assignment");
		}
	}

	function initDorForm() {
		dorShiftDate = new Date().toISOString().split('T')[0];
		dorRatings = competencies.map(c => ({ competency_id: c.id, rating: 3 }));
		dorNotes = "";
		showDorForm = true;
	}

	let dorOverallRating = $derived.by(() => {
		if (dorRatings.length === 0) return 0;
		const sum = dorRatings.reduce((acc, r) => acc + r.rating, 0);
		return Math.round((sum / dorRatings.length) * 10) / 10;
	});

	async function handleCreateDor() {
		if (!selectedDetail || dorSubmitting) return;
		dorSubmitting = true;
		try {
			const result = await fetchNui<{ success: boolean; error?: string }>(
				NUI_EVENTS.FTO.CREATE_FTO_DOR,
				{
					assignment_id: selectedDetail.assignment.id,
					shift_date: dorShiftDate,
					ratings: dorRatings,
					overall_rating: dorOverallRating,
					notes: dorNotes.trim() || undefined,
				},
				{ success: true }
			);
			if (!result || result.success === false) {
				globalNotifications.error(result?.error || "Failed to create DOR");
				dorSubmitting = false;
				return;
			}
			globalNotifications.success("Daily Observation Report created");
			showDorForm = false;
			dorRatings = [];
			dorNotes = "";
			dorShiftDate = "";
			await selectAssignment(selectedDetail.assignment.id);
		} catch {
			globalNotifications.error("Failed to create DOR");
		}
		dorSubmitting = false;
	}

	async function handleDeleteDor(dorId: number) {
		if (!selectedDetail) return;
		try {
			await fetchNui(NUI_EVENTS.FTO.DELETE_FTO_DOR, {
				assignment_id: selectedDetail.assignment.id,
				dor_id: dorId,
			}, { success: true });
			await selectAssignment(selectedDetail.assignment.id);
		} catch {
			globalNotifications.error("Failed to delete DOR");
		}
	}

	function handleTraineeSearch(query: string) {
		personSearchQuery = query;
		if (!query.trim()) { searchService.clearResults(); return; }
		searchService.searchOfficers(query);
	}

	function handleTrainerSearch(query: string) {
		personSearchQuery = query;
		if (!query.trim()) { searchService.clearResults(); return; }
		searchService.searchOfficers(query);
	}

	function handleSelectTrainee(person: { citizenid?: string; id?: string; fullName?: string }) {
		newTraineeCitizenId = person.citizenid || person.id || '';
		newTraineeName = person.fullName || '';
		showTraineeSearch = false;
		searchService.clearResults();
		personSearchQuery = "";
	}

	function handleSelectTrainer(person: { citizenid?: string; id?: string; fullName?: string }) {
		newTrainerCitizenId = person.citizenid || person.id || '';
		newTrainerName = person.fullName || '';
		showTrainerSearch = false;
		searchService.clearResults();
		personSearchQuery = "";
	}

	function formatDateValue(value: string | undefined): string {
		if (!value) return "-";
		const date = new Date(value);
		if (Number.isNaN(date.getTime())) return "-";
		return date.toLocaleDateString("en-US", { month: "2-digit", day: "2-digit", year: "numeric" });
	}

	function formatDateTimeValue(value: string | undefined): string {
		if (!value) return "-";
		const date = new Date(value);
		if (Number.isNaN(date.getTime())) return "-";
		return date.toLocaleDateString("en-US", { month: "2-digit", day: "2-digit", year: "numeric" })
			+ " " + date.toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", hour12: false });
	}

	function getStatusPillClass(status: string): string {
		switch (status) {
			case 'active': return 'pill-green';
			case 'completed': return 'pill-blue';
			case 'failed': return 'pill-red';
			case 'suspended': return 'pill-orange';
			default: return 'pill-grey';
		}
	}

	function formatLabel(value: string): string {
		return value.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
	}

	// Phase progress
	let phaseProgress = $derived.by(() => {
		if (!selectedDetail || phases.length === 0) return { current: 0, total: 0, percent: 0 };
		const idx = phases.findIndex(p => p.id === selectedDetail!.assignment.current_phase_id || p.name === selectedDetail!.assignment.current_phase);
		const current = idx >= 0 ? idx + 1 : 1;
		const total = phases.length;
		return { current, total, percent: Math.round((current / total) * 100) };
	});

	let allFilteredAssignments = $derived.by(() => {
		let filtered = assignments;
		if (statusFilter !== 'all') {
			filtered = filtered.filter(a => a.status === statusFilter);
		}
		const query = searchQuery.trim().toLowerCase();
		if (query) {
			filtered = filtered.filter(a =>
				[a.fto_number, a.trainee_name, a.trainer_name, a.status, a.current_phase]
					.filter(Boolean)
					.some(val => String(val).toLowerCase().includes(query))
			);
		}
		return filtered;
	});

	let paginatedAssignments = $derived.by(() => {
		const start = (page - 1) * perPage;
		return allFilteredAssignments.slice(start, start + perPage);
	});

	$effect(() => {
		searchQuery;
		statusFilter;
		page = 1;
		if (mounted && !isEnvBrowser()) loadAssignments();
	});
</script>

<div class="fto-page">
	{#if selectedDetail}
		<!-- ==================== DETAIL VIEW ==================== -->
		<div class="topbar">
			<button class="back-btn" onclick={goBack}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
				Back to FTO List
			</button>
			<span class="topbar-case-number">{selectedDetail.assignment.fto_number}</span>
			<span class="pill {getStatusPillClass(selectedDetail.assignment.status)}">{formatLabel(selectedDetail.assignment.status)}</span>
		</div>

		<div class="detail-scroll">
			<div class="detail-layout">
				<!-- Left Column: Main Content -->
				<div class="detail-main">
					<div class="section">
						<div class="section-header">
							<div class="section-title" style="margin-bottom:0;">Assignment Details</div>
							{#if canManage}
								<div class="inline-controls">
									<button class="action-btn danger" onclick={handleDelete}>Delete</button>
								</div>
							{/if}
						</div>
						<div class="field-row">
							<div class="field-group">
								<span class="field-label">Trainee</span>
								<span class="field-value">{selectedDetail.assignment.trainee_name || '-'}</span>
							</div>
							<div class="field-group">
								<span class="field-label">Trainer (FTO)</span>
								<span class="field-value">{selectedDetail.assignment.trainer_name || '-'}</span>
							</div>
							<div class="field-group">
								<span class="field-label">Status</span>
								<span class="pill {getStatusPillClass(selectedDetail.assignment.status)}">{formatLabel(selectedDetail.assignment.status)}</span>
							</div>
							<div class="field-group">
								<span class="field-label">Start Date</span>
								<span class="field-value">{formatDateValue(selectedDetail.assignment.start_date)}</span>
							</div>
							{#if selectedDetail.assignment.end_date}
								<div class="field-group">
									<span class="field-label">End Date</span>
									<span class="field-value">{formatDateValue(selectedDetail.assignment.end_date)}</span>
								</div>
							{/if}
						</div>
						{#if selectedDetail.assignment.notes}
							<div class="field-group" style="margin-top:6px;">
								<span class="field-label">Notes</span>
								<p class="summary-text">{selectedDetail.assignment.notes}</p>
							</div>
						{/if}
					</div>

					<!-- Phase Progress -->
					<div class="section">
						<div class="section-title">Phase Progress</div>
						<div class="phase-info">
							<span class="phase-label">{selectedDetail.assignment.current_phase}</span>
							<span class="phase-count">{phaseProgress.current} / {phaseProgress.total}</span>
						</div>
						<div class="progress-bar-track">
							<div class="progress-bar-fill" style="width: {phaseProgress.percent}%"></div>
						</div>
					</div>

					<!-- DOR History -->
					<div class="section">
						<div class="section-header">
							<div class="section-title" style="margin-bottom:0;">Daily Observation Reports ({selectedDetail.dors.length})</div>
							{#if canManage && !showDorForm}
								<button class="action-btn" onclick={initDorForm}>
									<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
									New DOR
								</button>
							{/if}
						</div>

						{#if showDorForm}
							<div class="dor-form">
								<div class="form-group">
									<span class="form-label">Shift Date</span>
									<input type="date" class="form-input" bind:value={dorShiftDate} />
								</div>

								<div class="dor-ratings-grid">
									{#each competencies as comp, i}
										<div class="dor-rating-row">
											<span class="dor-comp-name">{comp.name}</span>
											{#if comp.category}
												<span class="dor-comp-cat">{comp.category}</span>
											{/if}
											<select class="form-select dor-rating-select" bind:value={dorRatings[i].rating}>
												<option value={1}>1</option>
												<option value={2}>2</option>
												<option value={3}>3</option>
												<option value={4}>4</option>
												<option value={5}>5</option>
											</select>
										</div>
									{/each}
								</div>

								<div class="dor-overall">
									<span class="field-label">Overall Rating (Auto)</span>
									<span class="dor-overall-value">{dorOverallRating}</span>
								</div>

								<div class="form-group">
									<span class="form-label">Notes</span>
									<textarea class="form-textarea" rows="3" bind:value={dorNotes} placeholder="Observation notes..."></textarea>
								</div>

								<div class="form-actions">
									<button class="action-btn" onclick={() => { showDorForm = false; }}>Cancel</button>
									<button class="primary-btn" onclick={handleCreateDor} disabled={dorSubmitting || !dorShiftDate}>
										{dorSubmitting ? 'Submitting...' : 'Submit DOR'}
									</button>
								</div>
							</div>
						{:else if selectedDetail.dors.length > 0}
							<div class="dor-list">
								{#each selectedDetail.dors as dor}
									<div class="dor-item">
										<div class="dor-header">
											<span class="dor-date">{formatDateValue(dor.shift_date)}</span>
											<span class="dor-overall-badge">Rating: {dor.overall_rating}</span>
											{#if dor.author_name}
												<span class="dor-author">{dor.author_name}</span>
											{/if}
											{#if canManage}
												<button class="chip-remove" onclick={() => handleDeleteDor(dor.id)}>
													<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
												</button>
											{/if}
										</div>
										{#if dor.ratings && dor.ratings.length > 0}
											<div class="dor-ratings-summary">
												{#each dor.ratings as r}
													<span class="dor-rating-chip">{r.competency_name}: {r.rating}</span>
												{/each}
											</div>
										{/if}
										{#if dor.notes}
											<p class="dor-notes">{dor.notes}</p>
										{/if}
									</div>
								{/each}
							</div>
						{:else}
							<p class="muted-text">No DORs recorded yet.</p>
						{/if}
					</div>
				</div>

				<!-- Right Column: Sidebar -->
				<div class="detail-side">
					<div class="section">
						<div class="section-title">Summary</div>
						<div class="field-group">
							<span class="field-label">DOR Count</span>
							<span class="field-value">{selectedDetail.assignment.dor_count}</span>
						</div>
						<div class="field-group">
							<span class="field-label">Latest Rating</span>
							<span class="field-value">{selectedDetail.assignment.latest_rating ?? '-'}</span>
						</div>
						<div class="field-group">
							<span class="field-label">Created</span>
							<span class="field-value">{formatDateTimeValue(selectedDetail.assignment.created_at)}</span>
						</div>
					</div>
				</div>
			</div>
		</div>
	{:else if showCreateForm}
		<!-- ==================== CREATE FORM ==================== -->
		<div class="topbar">
			<button class="back-btn" onclick={() => { showCreateForm = false; resetCreateForm(); }}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
				Back to FTO List
			</button>
		</div>

		<div class="create-form">
			<h3>New FTO Assignment</h3>

			<div class="form-group">
				<span class="form-label">Trainee</span>
				<button
					class="officer-search-trigger"
					class:placeholder={!newTraineeName}
					onclick={() => (showTraineeSearch = true)}
				>
					{newTraineeName || 'Click to search for a trainee...'}
				</button>
			</div>

			<div class="form-group">
				<span class="form-label">Trainer (FTO)</span>
				<button
					class="officer-search-trigger"
					class:placeholder={!newTrainerName}
					onclick={() => (showTrainerSearch = true)}
				>
					{newTrainerName || 'Click to search for a trainer...'}
				</button>
			</div>

			<div class="form-row">
				<div class="form-group">
					<span class="form-label">Starting Phase</span>
					<select class="form-select" bind:value={newPhaseId}>
						<option value={undefined}>-- Select Phase --</option>
						{#each phases as phase}
							<option value={phase.id}>{phase.name}</option>
						{/each}
					</select>
				</div>
				<div class="form-group">
					<span class="form-label">Start Date</span>
					<input type="date" class="form-input" bind:value={newStartDate} />
				</div>
			</div>

			<div class="form-group">
				<span class="form-label">Notes</span>
				<textarea class="form-textarea" rows="3" bind:value={newNotes} placeholder="Additional notes..."></textarea>
			</div>

			<div class="form-actions">
				<button class="action-btn" onclick={() => { showCreateForm = false; resetCreateForm(); }}>Cancel</button>
				<button class="primary-btn" onclick={handleCreate} disabled={isSubmitting || !newTraineeCitizenId || !newTrainerCitizenId}>
					{isSubmitting ? 'Submitting...' : 'Create Assignment'}
				</button>
			</div>
		</div>
	{:else}
		<!-- ==================== LIST VIEW ==================== -->
		<div class="topbar">
			<div class="filter-pills">
				{#each statusOptions as opt}
					<button
						class="filter-pill"
						class:active={statusFilter === opt}
						onclick={() => { statusFilter = opt; }}
					>
						{opt === 'all' ? 'All' : formatLabel(opt)}
					</button>
				{/each}
			</div>
		</div>

		<div class="topbar">
			<div class="search-box">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.3)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
				<input type="text" placeholder="Search by trainee or trainer name..." bind:value={searchQuery} />
			</div>
			<div style="flex:1;"></div>
			{#if canManage}
				<button class="primary-btn" onclick={() => { showCreateForm = true; }}>
					<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
					New Assignment
				</button>
			{/if}
			<button class="back-btn" onclick={loadAssignments} disabled={loading}>
				<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
				Refresh
			</button>
		</div>

		<div class="list-panel">
			{#if loading && assignments.length === 0}
				<div class="center-state">
					<div class="loading-spinner"></div>
					<p>Loading FTO assignments...</p>
				</div>
			{:else if paginatedAssignments.length === 0}
				<div class="center-state">
					<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.2)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
					<h3>No FTO Assignments Found</h3>
					<p>{searchQuery ? "No assignments match your search criteria." : "No FTO assignments have been created yet."}</p>
				</div>
			{:else}
				<div class="table-header">
					<span>#</span>
					<span>Trainee</span>
					<span>Trainer</span>
					<span>Phase</span>
					<span>Status</span>
					<span>Start Date</span>
					<span>DORs</span>
					<span>Rating</span>
				</div>
				<div class="table-body">
					{#each paginatedAssignments as item}
						<button class="table-row" onclick={() => selectAssignment(item.id)}>
							<span class="row-case">{item.fto_number}</span>
							<span>{item.trainee_name}</span>
							<span>{item.trainer_name}</span>
							<span>{item.current_phase}</span>
							<span>
								<span class="pill {getStatusPillClass(item.status)}">{formatLabel(item.status)}</span>
							</span>
							<span>{formatDateValue(item.start_date)}</span>
							<span>{item.dor_count}</span>
							<span>{item.latest_rating ?? '-'}</span>
						</button>
					{/each}
				</div>
			{/if}
			<Pagination
				currentPage={page}
				totalItems={allFilteredAssignments.length}
				perPage={perPage}
				onPageChange={(p) => { page = p; }}
				onPerPageChange={(pp) => { perPage = pp; page = 1; }}
			/>
		</div>
	{/if}
</div>

<PersonSearchModal
	show={showTraineeSearch}
	title="Search Trainee"
	searchQuery={personSearchQuery}
	searchResults={searchService.state.results}
	onClose={() => {
		showTraineeSearch = false;
		personSearchQuery = "";
	}}
	onSearch={handleTraineeSearch}
	onSelect={handleSelectTrainee}
/>

<PersonSearchModal
	show={showTrainerSearch}
	title="Search Trainer (FTO)"
	searchQuery={personSearchQuery}
	searchResults={searchService.state.results}
	onClose={() => {
		showTrainerSearch = false;
		personSearchQuery = "";
	}}
	onSearch={handleTrainerSearch}
	onSelect={handleSelectTrainer}
/>

<style>
	/* ===== PAGE ===== */
	.fto-page {
		height: 100%;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	/* ===== TOPBAR ===== */
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

	/* ===== FILTER PILLS ===== */
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

	/* ===== SEARCH BOX ===== */
	.search-box {
		display: flex;
		align-items: center;
		gap: 8px;
		background: transparent;
		border: none;
		padding: 0;
		min-width: 240px;
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

	/* ===== BUTTONS ===== */
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

	.back-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.action-btn {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		background: rgba(var(--accent-rgb), 0.06);
		color: rgba(var(--accent-text-rgb), 0.7);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		padding: 4px 10px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
		flex-shrink: 0;
		white-space: nowrap;
	}

	.action-btn:hover {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.action-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.action-btn.danger {
		color: #ef4444;
		border-color: rgba(239, 68, 68, 0.3);
	}

	.action-btn.danger:hover {
		background: rgba(239, 68, 68, 0.1);
	}

	.primary-btn {
		display: inline-flex;
		align-items: center;
		gap: 5px;
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

	/* ===== PILLS ===== */
	.pill {
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 600;
		text-transform: capitalize;
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

	.pill-green {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(52, 211, 153, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.pill-blue {
		background: rgba(var(--accent-rgb), 0.08);
		color: rgba(96, 165, 250, 0.8);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
	}

	.pill-grey {
		background: rgba(107, 114, 128, 0.08);
		color: rgba(156, 163, 175, 0.8);
		border: 1px solid rgba(107, 114, 128, 0.1);
	}

	/* ===== LIST PANEL (TABLE) ===== */
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
		grid-template-columns: 1.2fr 1fr 1fr 0.8fr 0.7fr 0.8fr 0.5fr 0.5fr;
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
		grid-template-columns: 1.2fr 1fr 1fr 0.8fr 0.7fr 0.8fr 0.5fr 0.5fr;
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

	/* ===== DETAIL LAYOUT ===== */
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

	/* ===== SECTIONS ===== */
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

	.section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 6px;
	}

	.section-title {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		margin-bottom: 2px;
	}

	/* ===== FIELD LAYOUT ===== */
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

	.summary-text {
		color: rgba(255, 255, 255, 0.5);
		font-size: 11px;
		margin: 0;
		line-height: 1.5;
		white-space: pre-wrap;
	}

	.muted-text {
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
		margin: 0;
	}

	.inline-controls {
		display: flex;
		gap: 6px;
		align-items: center;
	}

	/* ===== PHASE PROGRESS ===== */
	.phase-info {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.phase-label {
		font-size: 12px;
		color: rgba(255, 255, 255, 0.7);
		font-weight: 500;
	}

	.phase-count {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.4);
	}

	.progress-bar-track {
		width: 100%;
		height: 6px;
		background: rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		overflow: hidden;
	}

	.progress-bar-fill {
		height: 100%;
		background: var(--accent-60, rgba(96, 165, 250, 0.6));
		border-radius: 3px;
		transition: width 0.3s ease;
	}

	/* ===== DOR ===== */
	.dor-form {
		display: flex;
		flex-direction: column;
		gap: 10px;
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 6px;
		padding: 12px;
	}

	.dor-ratings-grid {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.dor-rating-row {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 4px 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
	}

	.dor-comp-name {
		flex: 1;
		font-size: 11px;
		color: rgba(255, 255, 255, 0.7);
	}

	.dor-comp-cat {
		font-size: 9px;
		color: rgba(255, 255, 255, 0.3);
		background: rgba(255, 255, 255, 0.04);
		padding: 1px 5px;
		border-radius: 3px;
	}

	.dor-rating-select {
		width: 60px;
		flex-shrink: 0;
	}

	.dor-overall {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 0;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}

	.dor-overall-value {
		font-size: 16px;
		font-weight: 700;
		color: var(--accent-text, rgba(96, 165, 250, 0.9));
	}

	.dor-list {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.dor-item {
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 4px;
		padding: 8px 10px;
	}

	.dor-header {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-bottom: 4px;
	}

	.dor-date {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.7);
		font-weight: 500;
	}

	.dor-overall-badge {
		font-size: 10px;
		font-weight: 600;
		color: var(--accent-text, rgba(96, 165, 250, 0.8));
		background: rgba(var(--accent-rgb), 0.08);
		padding: 1px 6px;
		border-radius: 3px;
	}

	.dor-author {
		font-size: 9px;
		color: rgba(255, 255, 255, 0.35);
		flex: 1;
		text-align: right;
	}

	.dor-ratings-summary {
		display: flex;
		flex-wrap: wrap;
		gap: 4px;
		margin-bottom: 4px;
	}

	.dor-rating-chip {
		font-size: 9px;
		color: rgba(255, 255, 255, 0.5);
		background: rgba(255, 255, 255, 0.04);
		padding: 1px 5px;
		border-radius: 3px;
	}

	.dor-notes {
		color: rgba(255, 255, 255, 0.5);
		font-size: 10px;
		margin: 0;
		line-height: 1.4;
		white-space: pre-wrap;
	}

	.chip-remove {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.15);
		cursor: pointer;
		padding: 2px;
		display: flex;
		align-items: center;
		transition: color 0.1s;
	}

	.chip-remove:hover {
		color: rgba(248, 113, 113, 0.8);
	}

	/* ===== FORM INPUTS ===== */
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

	.form-select {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 22px 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 10px;
		text-transform: capitalize;
		outline: none;
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

	/* ===== CREATE FORM ===== */
	.create-form {
		padding: 16px;
		display: flex;
		flex-direction: column;
		gap: 12px;
		overflow-y: auto;
		flex: 1;
	}

	.create-form h3 {
		color: rgba(255, 255, 255, 0.8);
		font-size: 14px;
		font-weight: 600;
		margin: 0;
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

	.form-row {
		display: flex;
		gap: 12px;
	}

	.form-row .form-group {
		flex: 1;
	}

	.form-actions {
		display: flex;
		gap: 8px;
		justify-content: flex-end;
		padding-top: 8px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}

	.officer-search-trigger {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		cursor: pointer;
		text-align: left;
		width: 100%;
		transition: border-color 0.1s;
	}

	.officer-search-trigger:hover {
		border-color: rgba(255, 255, 255, 0.1);
	}

	.officer-search-trigger.placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	/* ===== STATES ===== */
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

	/* ===== SCROLLBAR ===== */
	.table-body::-webkit-scrollbar,
	.detail-scroll::-webkit-scrollbar {
		width: 4px;
	}

	.table-body::-webkit-scrollbar-track,
	.detail-scroll::-webkit-scrollbar-track {
		background: transparent;
	}

	.table-body::-webkit-scrollbar-thumb,
	.detail-scroll::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}
</style>
