<script lang="ts">
	import { onMount } from "svelte";
	import { formatDate, formatDateTime } from "../utils/datetime";
	import { isEnvBrowser } from "../utils/misc";
	import { fetchNui } from "../utils/fetchNui";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { globalNotifications } from "../services/notificationService.svelte";
	import { createSearchService } from "../services/searchService.svelte";
	import Pagination from "../components/Pagination.svelte";
	import PersonSearchModal from "../components/report-editor/PersonSearchModal.svelte";
	import type { createTabService } from "../services/tabService.svelte";
	import type { AuthService } from "../services/authService.svelte";
	import { permissionHint } from "../utils/permissionHint";

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
		phase_id?: number;
		phase_name?: string;
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
					phase_id: currentPhaseId,
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
			const res = await fetchNui<{ success: boolean; error?: string }>(NUI_EVENTS.FTO.DELETE_FTO_DOR, {
				id: dorId,
				dor_id: dorId,
				assignment_id: selectedDetail.assignment.id,
			}, { success: true });
			if (res?.success) {
				globalNotifications.success("DOR deleted");
				await selectAssignment(selectedDetail.assignment.id);
				await loadAssignments();
			} else {
				globalNotifications.error(res?.error || "Failed to delete DOR");
			}
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
		return formatDate(value, "-");
	}

	function formatDateTimeValue(value: string | undefined): string {
		return formatDateTime(value, "-");
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

	// ── Trainer-tool derived data ──────────────────────────────────────────────
	// Recommended readiness before advancing a phase. This is a SOFT gate: the
	// button warns and the confirm dialog flags it, but a trainer can still
	// proceed (they keep final authority). Tune these to your program.
	const ADVANCE_MIN_AVG = 3.0;   // required average score in the current phase
	const ADVANCE_MIN_DORS = 2;    // minimum DORs logged in the current phase

	let currentPhaseIndex = $derived.by(() => {
		if (!selectedDetail || phases.length === 0) return -1;
		const idx = phases.findIndex(p =>
			p.id === selectedDetail!.assignment.current_phase_id ||
			p.name === selectedDetail!.assignment.current_phase);
		// A trainee with no phase set yet is implicitly in the first phase.
		return idx >= 0 ? idx : 0;
	});
	let nextPhase = $derived(currentPhaseIndex >= 0 && currentPhaseIndex < phases.length - 1 ? phases[currentPhaseIndex + 1] : null);
	let prevPhase = $derived(currentPhaseIndex > 0 ? phases[currentPhaseIndex - 1] : null);
	// Resolved current phase id (falls back to the assignment field, then name match).
	let currentPhaseId = $derived(
		phases[currentPhaseIndex]?.id ?? selectedDetail?.assignment.current_phase_id ?? null
	);
	let isLastPhase = $derived(currentPhaseIndex === phases.length - 1 && phases.length > 0);
	let isActive = $derived(selectedDetail?.assignment.status === "active");
	let isCompleted = $derived(selectedDetail?.assignment.status === "completed");
	let isFailed = $derived(selectedDetail?.assignment.status === "failed");
	// Editing is only possible while the assignment is active.
	let canEdit = $derived(canManage && isActive);

	// Sidebar analytics
	let overallAvgAll = $derived.by(() => {
		const d = selectedDetail?.dors ?? [];
		if (!d.length) return 0;
		return d.reduce((s, x) => s + (Number(x.overall_rating) || 0), 0) / d.length;
	});
	let phaseBreakdown = $derived.by(() => {
		if (!selectedDetail) return [] as { name: string; count: number; avg: number }[];
		return phases.map(p => {
			const ds = selectedDetail!.dors.filter(x => x.phase_id === p.id);
			const avg = ds.length ? ds.reduce((s, x) => s + (Number(x.overall_rating) || 0), 0) / ds.length : 0;
			return { name: p.name, count: ds.length, avg };
		});
	});

	// DOR counts per phase id (strict — each DOR only counts for its own phase).
	let phaseDorCounts = $derived.by(() => {
		const m = new Map<number, number>();
		if (!selectedDetail) return m;
		for (const d of selectedDetail.dors) {
			if (d.phase_id != null) m.set(d.phase_id, (m.get(d.phase_id) ?? 0) + 1);
		}
		return m;
	});

	// Only DORs written for the current phase. Advancing to a new phase therefore
	// resets this to zero — the trainee must earn fresh DORs in each phase.
	let currentPhaseDors = $derived.by(() => {
		if (!selectedDetail || currentPhaseId == null) return [] as FTODor[];
		return selectedDetail.dors.filter(d => d.phase_id === currentPhaseId);
	});

	// Average is per-phase only, so the rating must be re-earned each phase.
	let avgOverall = $derived.by(() => {
		if (!currentPhaseDors.length) return 0;
		return currentPhaseDors.reduce((s, d) => s + (Number(d.overall_rating) || 0), 0) / currentPhaseDors.length;
	});

	// Whether the trainee meets the recommended criteria to move up a phase.
	let phaseReady = $derived(currentPhaseDors.length >= ADVANCE_MIN_DORS && avgOverall >= ADVANCE_MIN_AVG);

	// Program-wide progress: fully-cleared phases + how far through the current one.
	let overallProgress = $derived.by(() => {
		if (selectedDetail?.assignment.status === "completed") return 100;
		const total = phases.length;
		if (total === 0 || currentPhaseIndex < 0) return 0;
		const completed = currentPhaseIndex; // phases before the current one are done
		const frac = phaseReady ? 1 : Math.min(currentPhaseDors.length / ADVANCE_MIN_DORS, 1) * 0.85;
		return Math.min(100, Math.round(((completed + frac) / total) * 100));
	});

	// Average rating per competency across all DORs (the proficiency picture)
	let competencyAverages = $derived.by(() => {
		if (!selectedDetail) return [] as { id: number; name: string; category?: string; avg: number; count: number }[];
		const acc = new Map<number, { sum: number; count: number }>();
		for (const d of selectedDetail.dors) {
			for (const r of d.ratings || []) {
				const e = acc.get(r.competency_id) ?? { sum: 0, count: 0 };
				e.sum += Number(r.rating) || 0;
				e.count += 1;
				acc.set(r.competency_id, e);
			}
		}
		return competencies
			.map(c => {
				const e = acc.get(c.id);
				return { id: c.id, name: c.name, category: c.category, avg: e ? e.sum / e.count : 0, count: e?.count ?? 0 };
			})
			.filter(c => c.count > 0);
	});

	let daysInProgram = $derived.by(() => {
		const sd = selectedDetail?.assignment.start_date;
		if (!sd) return null;
		const start = new Date(sd);
		if (isNaN(start.getTime())) return null;
		return Math.max(0, Math.floor((Date.now() - start.getTime()) / 86400000));
	});

	let bestCompetency = $derived.by(() => [...competencyAverages].sort((a, b) => b.avg - a.avg)[0] ?? null);
	let weakestCompetency = $derived.by(() => [...competencyAverages].sort((a, b) => a.avg - b.avg)[0] ?? null);

	// Confirmation flow for consequential actions
	let phaseAction = $state<null | { kind: "advance" | "complete" | "back" | "fail" | "suspend"; note: string }>(null);
	let phaseActionBusy = $state(false);

	function askPhaseAction(kind: "advance" | "complete" | "back" | "fail" | "suspend") {
		phaseAction = { kind, note: "" };
	}

	async function confirmPhaseAction() {
		if (!selectedDetail || !phaseAction || phaseActionBusy) return;
		phaseActionBusy = true;
		const id = selectedDetail.assignment.id;
		const kind = phaseAction.kind;
		try {
			let res: { success: boolean; error?: string };
			if (kind === "advance" || kind === "complete") {
				res = await fetchNui(NUI_EVENTS.FTO.ADVANCE_FTO_PHASE, { assignment_id: id, direction: "next", note: phaseAction.note || undefined }, { success: true });
			} else if (kind === "back") {
				res = await fetchNui(NUI_EVENTS.FTO.ADVANCE_FTO_PHASE, { assignment_id: id, direction: "back" }, { success: true });
			} else {
				res = await fetchNui(NUI_EVENTS.FTO.SET_FTO_STATUS, { assignment_id: id, status: kind === "fail" ? "failed" : "suspended" }, { success: true });
			}
			if (res?.success) {
				const labels: Record<string, string> = { advance: "Advanced to next phase", complete: "Training completed", back: "Moved back a phase", fail: "Marked as failed", suspend: "Training suspended" };
				globalNotifications.success(labels[kind] || "Updated");
				phaseAction = null;
				await selectAssignment(id);
				await loadAssignments();
			} else {
				globalNotifications.error(res?.error || "Action failed");
			}
		} catch {
			globalNotifications.error("Action failed");
		} finally {
			phaseActionBusy = false;
		}
	}

	async function reactivateAssignment() {
		if (!selectedDetail) return;
		const id = selectedDetail.assignment.id;
		try {
			const res = await fetchNui<{ success: boolean; error?: string }>(NUI_EVENTS.FTO.SET_FTO_STATUS, { assignment_id: id, status: "active" }, { success: true });
			if (res?.success) {
				globalNotifications.success("Training reactivated");
				await selectAssignment(id);
				await loadAssignments();
			} else {
				globalNotifications.error(res?.error || "Action failed");
			}
		} catch {
			globalNotifications.error("Action failed");
		}
	}

	function ratingColor(v: number): string {
		if (v <= 0) return "rgba(255,255,255,0.15)";
		if (v < 2) return "#ef4444";
		if (v < 3) return "#f97316";
		if (v < 4) return "#eab308";
		return "#22c55e";
	}

	// ── 1–5 point rating scale (single source of truth, explained everywhere) ──
	// 1 = worst, 5 = best. Descriptions keep trainers consistent and honest.
	const RATING_SCALE = [
		{ value: 1, label: "Poor", desc: "Unsatisfactory — could not perform, needed to be taken over" },
		{ value: 2, label: "Needs Work", desc: "Below standard — frequent correction/prompting required" },
		{ value: 3, label: "Competent", desc: "Meets standard — performs the task with minimal guidance" },
		{ value: 4, label: "Proficient", desc: "Above standard — consistent, reliable, little to no help" },
		{ value: 5, label: "Excellent", desc: "Exceptional — independent and exceeds expectations" },
	] as const;

	function ratingLabel(v: number): string {
		const r = Math.round(v);
		return RATING_SCALE.find(s => s.value === r)?.label ?? "—";
	}

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
			{#if isCompleted}
				<div class="status-watermark wm-complete">COMPLETE</div>
			{:else if isFailed}
				<div class="status-watermark wm-failed">FAILED</div>
			{/if}
			<div class="detail-layout">
				<!-- Left Column: Main Content -->
				<div class="detail-main">
					<div class="section">
						<div class="section-header">
							<div class="section-title" style="margin-bottom:0;">Assignment Details</div>
							<div class="inline-controls">
								<button class="action-btn danger" use:permissionHint={canManage ? null : "fto_manage"} onclick={handleDelete}>Delete</button>
							</div>
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

					<!-- Training Progress (trainer tool) -->
					<div class="section">
						<div class="section-title">Training Progress</div>

						<!-- Overall program progress -->
						<div class="overall-progress">
							<div class="overall-progress-head">
								<span class="overall-progress-phase">Phase {phaseProgress.current} of {phaseProgress.total}</span>
								<span class="overall-progress-pct">{overallProgress}% complete</span>
							</div>
							<div class="overall-progress-track">
								<div class="overall-progress-fill" style="width:{overallProgress}%"></div>
							</div>
						</div>

						<!-- Phase stepper -->
						<div class="phase-stepper">
							{#each phases as p, i}
								<div class="phase-step {isCompleted || i < currentPhaseIndex ? 'done' : ''} {!isCompleted && i === currentPhaseIndex ? 'active' : ''}" title={p.description || p.name}>
									<div class="phase-step-dot">
										{#if isCompleted || i < currentPhaseIndex}
											<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
										{:else}
											{i + 1}
										{/if}
									</div>
									<div class="phase-step-body">
										<span class="phase-step-name">{p.name}</span>
										{#if (phaseDorCounts.get(p.id) ?? 0) > 0}
											<span class="phase-step-dors">{phaseDorCounts.get(p.id)} DOR{phaseDorCounts.get(p.id) === 1 ? "" : "s"}</span>
										{/if}
									</div>
								</div>
							{/each}
						</div>

						<!-- Current phase stats -->
						<div class="phase-stats">
							<div class="phase-stat">
								<span class="phase-stat-value">{phaseProgress.current}/{phaseProgress.total}</span>
								<span class="phase-stat-label">Phase</span>
							</div>
							<div class="phase-stat">
								<span class="phase-stat-value" style="color:{ratingColor(isCompleted ? overallAvgAll : avgOverall)}">{(isCompleted ? overallAvgAll : avgOverall) ? (isCompleted ? overallAvgAll : avgOverall).toFixed(1) : "—"}</span>
								<span class="phase-stat-label">{isCompleted ? "Final avg" : "Avg rating"}</span>
							</div>
							<div class="phase-stat">
								<span class="phase-stat-value">{isCompleted ? selectedDetail.dors.length : currentPhaseDors.length}</span>
								<span class="phase-stat-label">{isCompleted ? "Total DORs" : "DORs this phase"}</span>
							</div>
							<div class="phase-stat">
								<span class="phase-stat-value">{daysInProgram ?? "—"}</span>
								<span class="phase-stat-label">Days in program</span>
							</div>
						</div>

						<!-- Actions -->
						{#if canManage}
							{#if isActive}
								<div class="phase-readiness">
									{#if phaseReady}
										<span class="readiness-badge readiness-ok">✓ Meets advancement criteria — avg {avgOverall.toFixed(1)}/5 over {currentPhaseDors.length} DOR{currentPhaseDors.length === 1 ? "" : "s"} this phase</span>
									{:else}
										<span class="readiness-badge readiness-warn">Not yet recommended — needs avg ≥ {ADVANCE_MIN_AVG.toFixed(1)}/5 over ≥ {ADVANCE_MIN_DORS} DORs (now {avgOverall ? avgOverall.toFixed(1) : "0.0"}/5 over {currentPhaseDors.length})</span>
									{/if}
								</div>
								<div class="phase-actions">
									{#if isLastPhase}
										<button class="phase-btn {phaseReady ? 'phase-btn-complete' : 'phase-btn-warn'}" onclick={() => askPhaseAction("complete")}>
											<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
											Complete Training
										</button>
									{:else if nextPhase}
										<button class="phase-btn {phaseReady ? 'phase-btn-advance' : 'phase-btn-warn'}" onclick={() => askPhaseAction("advance")}>
											Advance to {nextPhase.name}
											<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
										</button>
									{/if}
									{#if prevPhase}
										<button class="phase-btn phase-btn-ghost" onclick={() => askPhaseAction("back")} title="Move back one phase">
											<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg>
											Back
										</button>
									{/if}
									<span class="phase-actions-spacer"></span>
									<button class="phase-btn phase-btn-warn" onclick={() => askPhaseAction("suspend")}>Suspend</button>
									<button class="phase-btn phase-btn-danger" onclick={() => askPhaseAction("fail")}>Fail</button>
								</div>
							{:else if selectedDetail.assignment.status === "suspended"}
								<div class="phase-actions">
									<button class="phase-btn phase-btn-advance" onclick={reactivateAssignment}>Reactivate training</button>
								</div>
							{/if}
						{/if}
					</div>

					<!-- Competency proficiency -->
					{#if competencyAverages.length > 0}
						<div class="section">
							<div class="section-title">Competency Proficiency</div>
							<div class="comp-averages">
								{#each competencyAverages as c}
									<div class="comp-avg-row">
										<span class="comp-avg-name">{c.name}{#if c.category}<span class="comp-avg-cat">{c.category}</span>{/if}</span>
										<div class="comp-avg-track">
											<div class="comp-avg-fill" style="width:{(c.avg / 5) * 100}%;background:{ratingColor(c.avg)}"></div>
										</div>
										<span class="comp-avg-value" style="color:{ratingColor(c.avg)}">{c.avg.toFixed(1)}</span>
									</div>
								{/each}
							</div>
						</div>
					{/if}

					<!-- DOR History -->
					<div class="section">
						<div class="section-header">
							<div class="section-title" style="margin-bottom:0;">Daily Observation Reports ({selectedDetail.dors.length})</div>
							{#if canEdit && !showDorForm}
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

								<div class="rating-legend">
									<span class="rating-legend-title">Score each competency from 1 to 5 — 1 = worst, 5 = best</span>
									<div class="rating-legend-scale">
										{#each RATING_SCALE as s}
											<span class="rating-legend-item" title={s.desc}>
												<span class="rating-legend-num" style="background:{ratingColor(s.value)}">{s.value}</span>
												<span class="rating-legend-lab">{s.label}</span>
											</span>
										{/each}
									</div>
									<span class="rating-legend-hint">Hover a level for its meaning. Be honest — these scores drive phase advancement.</span>
								</div>

								<div class="dor-ratings-grid">
									{#each competencies as comp, i}
										<div class="dor-rating-row">
											<span class="dor-comp-name">{comp.name}{#if comp.category}<span class="dor-comp-cat">{comp.category}</span>{/if}</span>
											<div class="rating-pills">
												{#each RATING_SCALE as s}
													<button
														type="button"
														class="rating-pill"
														class:selected={dorRatings[i].rating === s.value}
														style={dorRatings[i].rating === s.value ? `background:${ratingColor(s.value)};border-color:${ratingColor(s.value)};color:#0c0c0c;` : ""}
														title={`${s.value} — ${s.label}: ${s.desc}`}
														onclick={() => (dorRatings[i].rating = s.value)}
													>{s.value}</button>
												{/each}
											</div>
											<span class="rating-row-label" style="color:{ratingColor(dorRatings[i].rating)}">{ratingLabel(dorRatings[i].rating)}</span>
										</div>
									{/each}
								</div>

								<div class="dor-overall">
									<span class="field-label">Overall score (average)</span>
									<span class="dor-overall-value" style="color:{ratingColor(dorOverallRating)}">{dorOverallRating || "—"} / 5 · {ratingLabel(dorOverallRating)}</span>
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
											{#if dor.phase_name}
												<span class="dor-phase-badge">{dor.phase_name}</span>
											{/if}
											<span class="dor-overall-badge" style="color:{ratingColor(dor.overall_rating)};border-color:{ratingColor(dor.overall_rating)}">{dor.overall_rating}/5 · {ratingLabel(dor.overall_rating)}</span>
											{#if dor.author_name}
												<span class="dor-author">{dor.author_name}</span>
											{/if}
											{#if canEdit}
												<button class="chip-remove" onclick={() => handleDeleteDor(dor.id)}>
													<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
												</button>
											{/if}
										</div>
										{#if dor.ratings && dor.ratings.length > 0}
											<div class="dor-ratings-summary">
												{#each dor.ratings as r}
													<span class="dor-rating-chip" style="border-color:{ratingColor(r.rating)}"><span style="color:{ratingColor(r.rating)};font-weight:700">{r.rating}/5</span> {r.competency_name}</span>
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
					{#if isCompleted || isFailed}
						<div class="section outcome-card {isCompleted ? 'outcome-complete' : 'outcome-failed'}">
							<div class="outcome-icon">
								{#if isCompleted}
									<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
								{:else}
									<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>
								{/if}
							</div>
							<div class="outcome-title">{isCompleted ? "Training Completed" : "Training Failed"}</div>
							<div class="outcome-sub">
								{#if selectedDetail.assignment.end_date}Closed {formatDateValue(selectedDetail.assignment.end_date)}{/if}
								{#if daysInProgram != null} · {daysInProgram} day{daysInProgram === 1 ? "" : "s"}{/if}
							</div>
						</div>
					{/if}

					<div class="section">
						<div class="section-title">Summary</div>
						<div class="field-group">
							<span class="field-label">FTO Number</span>
							<span class="field-value">{selectedDetail.assignment.fto_number || "—"}</span>
						</div>
						<div class="field-group">
							<span class="field-label">Trainer</span>
							<span class="field-value">{selectedDetail.assignment.trainer_name}</span>
						</div>
						<div class="field-group">
							<span class="field-label">Current Phase</span>
							<span class="field-value">{selectedDetail.assignment.current_phase || "—"}</span>
						</div>
						<div class="field-group">
							<span class="field-label">Start Date</span>
							<span class="field-value">{formatDateValue(selectedDetail.assignment.start_date)}</span>
						</div>
						<div class="field-group">
							<span class="field-label">Days in Program</span>
							<span class="field-value">{daysInProgram ?? "—"}</span>
						</div>
					</div>

					<div class="section">
						<div class="section-title">Performance</div>
						<div class="perf-grid">
							<div class="perf-cell">
								<span class="perf-value" style="color:{ratingColor(overallAvgAll)}">{overallAvgAll ? overallAvgAll.toFixed(1) : "—"}</span>
								<span class="perf-label">Overall avg</span>
							</div>
							{#if isCompleted}
								<div class="perf-cell">
									<span class="perf-value" style="color:rgba(74,222,128,0.95)">{phaseProgress.total}/{phaseProgress.total}</span>
									<span class="perf-label">Phases done</span>
								</div>
							{:else}
								<div class="perf-cell">
									<span class="perf-value" style="color:{ratingColor(avgOverall)}">{avgOverall ? avgOverall.toFixed(1) : "—"}</span>
									<span class="perf-label">This phase</span>
								</div>
							{/if}
							<div class="perf-cell">
								<span class="perf-value">{selectedDetail.dors.length}</span>
								<span class="perf-label">Total DORs</span>
							</div>
						</div>
					</div>

					{#if phaseBreakdown.some(p => p.count > 0)}
						<div class="section">
							<div class="section-title">By Phase</div>
							<div class="pb-list">
								{#each phaseBreakdown as pb}
									<div class="pb-row">
										<span class="pb-name">{pb.name}</span>
										<span class="pb-count">{pb.count} DOR{pb.count === 1 ? "" : "s"}</span>
										<span class="pb-avg" style="color:{ratingColor(pb.avg)}">{pb.avg ? pb.avg.toFixed(1) : "—"}</span>
									</div>
								{/each}
							</div>
						</div>
					{/if}

					{#if bestCompetency || weakestCompetency}
						<div class="section">
							<div class="section-title">Highlights</div>
							{#if bestCompetency}
								<div class="hl-row">
									<span class="hl-tag hl-good">Strongest</span>
									<span class="hl-name">{bestCompetency.name}</span>
									<span class="hl-val" style="color:{ratingColor(bestCompetency.avg)}">{bestCompetency.avg.toFixed(1)}</span>
								</div>
							{/if}
							{#if weakestCompetency && weakestCompetency.id !== bestCompetency?.id}
								<div class="hl-row">
									<span class="hl-tag hl-bad">Needs work</span>
									<span class="hl-name">{weakestCompetency.name}</span>
									<span class="hl-val" style="color:{ratingColor(weakestCompetency.avg)}">{weakestCompetency.avg.toFixed(1)}</span>
								</div>
							{/if}
						</div>
					{/if}
				</div>
			</div>
		</div>

		{#if phaseAction}
			<!-- svelte-ignore a11y_click_events_have_key_events -->
			<!-- svelte-ignore a11y_no_static_element_interactions -->
			<div class="confirm-backdrop" onclick={(e) => { if (e.target === e.currentTarget) phaseAction = null; }}>
				<div class="confirm-modal" role="dialog" aria-modal="true">
					<div class="confirm-header">
						<span class="confirm-title">
							{#if phaseAction.kind === "advance"}Advance to {nextPhase?.name}?
							{:else if phaseAction.kind === "complete"}Complete training?
							{:else if phaseAction.kind === "back"}Move back to {prevPhase?.name}?
							{:else if phaseAction.kind === "fail"}Mark training as failed?
							{:else}Suspend training?{/if}
						</span>
						<button class="confirm-close" aria-label="Cancel" onclick={() => (phaseAction = null)}>
							<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
						</button>
					</div>
					<div class="confirm-body">
						<p class="confirm-text">
							{#if phaseAction.kind === "advance"}This moves {selectedDetail.assignment.trainee_name} from {selectedDetail.assignment.current_phase} to {nextPhase?.name}. DORs for the new phase start fresh.
							{:else if phaseAction.kind === "complete"}This graduates {selectedDetail.assignment.trainee_name} and marks the assignment as completed.
							{:else if phaseAction.kind === "back"}This steps {selectedDetail.assignment.trainee_name} back one phase.
							{:else if phaseAction.kind === "fail"}This closes the assignment as failed. You can reactivate it later if needed.
							{:else}This pauses the assignment. You can reactivate it later.{/if}
						</p>
						{#if (phaseAction.kind === "advance" || phaseAction.kind === "complete") && !phaseReady}
							<p class="confirm-warn">⚠ {selectedDetail.assignment.trainee_name} hasn't met the recommended criteria yet (avg ≥ {ADVANCE_MIN_AVG.toFixed(1)}/5 over ≥ {ADVANCE_MIN_DORS} DORs this phase). Proceed only if you have grounds to.</p>
						{/if}
						{#if phaseAction.kind === "advance" || phaseAction.kind === "complete"}
							<textarea class="confirm-note" rows="2" placeholder="Optional note for the record…" bind:value={phaseAction.note}></textarea>
						{/if}
					</div>
					<div class="confirm-footer">
						<button class="phase-btn phase-btn-ghost" disabled={phaseActionBusy} onclick={() => (phaseAction = null)}>Cancel</button>
						<button
							class="phase-btn {phaseAction.kind === 'fail' ? 'phase-btn-danger' : phaseAction.kind === 'suspend' ? 'phase-btn-warn' : 'phase-btn-advance'}"
							disabled={phaseActionBusy}
							onclick={confirmPhaseAction}
						>
							{phaseActionBusy ? "Working…" : phaseAction.kind === "advance" ? "Advance" : phaseAction.kind === "complete" ? "Complete" : phaseAction.kind === "back" ? "Move back" : phaseAction.kind === "fail" ? "Fail" : "Suspend"}
						</button>
					</div>
				</div>
			</div>
		{/if}
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
			<button class="primary-btn" use:permissionHint={canManage ? null : "fto_manage"} onclick={() => { showCreateForm = true; }}>
				<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
				New Assignment
			</button>
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
							<span><span class="phase-tag">{item.current_phase || "—"}</span></span>
							<span>
								<span class="pill {getStatusPillClass(item.status)}">{formatLabel(item.status)}</span>
							</span>
							<span>{formatDateValue(item.start_date)}</span>
							<span><span class="dor-count-badge">{item.dor_count}</span></span>
							<span>
								{#if item.latest_rating}
									<span class="rating-badge-sm" style="color:{ratingColor(item.latest_rating)};border-color:{ratingColor(item.latest_rating)};background:{ratingColor(item.latest_rating)}1a">{item.latest_rating}/5</span>
								{:else}
									<span class="muted-dash">—</span>
								{/if}
							</span>
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
		position: relative;
	}

	/* Completion / failure watermark across the page — readable underneath. */
	.status-watermark {
		position: absolute;
		top: 42%;
		left: 50%;
		transform: translate(-50%, -50%) rotate(-18deg);
		font-size: clamp(60px, 12vw, 150px);
		font-weight: 900;
		letter-spacing: 6px;
		pointer-events: none;
		user-select: none;
		z-index: 5;
		white-space: nowrap;
	}
	.wm-complete { color: rgba(34, 197, 94, 0.14); text-shadow: 0 0 30px rgba(34, 197, 94, 0.15); }
	.wm-failed { color: rgba(239, 68, 68, 0.14); text-shadow: 0 0 30px rgba(239, 68, 68, 0.15); }

	/* Outcome card in sidebar */
	.outcome-card {
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		gap: 4px;
		padding: 16px 12px;
	}
	.outcome-complete { border: 1px solid rgba(34, 197, 94, 0.3); background: rgba(34, 197, 94, 0.06); }
	.outcome-failed { border: 1px solid rgba(239, 68, 68, 0.3); background: rgba(239, 68, 68, 0.06); }
	.outcome-complete .outcome-icon { color: rgba(74, 222, 128, 0.95); }
	.outcome-failed .outcome-icon { color: rgba(248, 113, 113, 0.95); }
	.outcome-title { font-size: 14px; font-weight: 700; color: rgba(255, 255, 255, 0.9); }
	.outcome-sub { font-size: 10px; color: rgba(255, 255, 255, 0.45); }

	/* Performance grid */
	.perf-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
	.perf-cell {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 2px;
		padding: 8px 4px;
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 5px;
	}
	.perf-value { font-size: 17px; font-weight: 700; color: rgba(255, 255, 255, 0.9); line-height: 1; }
	.perf-label { font-size: 8px; text-transform: uppercase; letter-spacing: 0.3px; color: rgba(255, 255, 255, 0.4); }

	/* Phase breakdown */
	.pb-list { display: flex; flex-direction: column; gap: 4px; }
	.pb-row {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 5px 8px;
		background: rgba(255, 255, 255, 0.02);
		border-radius: 4px;
	}
	.pb-name { flex: 1; font-size: 11px; color: rgba(255, 255, 255, 0.7); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.pb-count { font-size: 9px; color: rgba(255, 255, 255, 0.4); }
	.pb-avg { font-size: 12px; font-weight: 700; min-width: 26px; text-align: right; }

	/* Highlights */
	.hl-row { display: flex; align-items: center; gap: 8px; padding: 5px 0; }
	.hl-tag { font-size: 8px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.3px; padding: 2px 6px; border-radius: 3px; }
	.hl-good { color: rgba(74, 222, 128, 0.9); background: rgba(34, 197, 94, 0.1); }
	.hl-bad { color: rgba(251, 146, 60, 0.9); background: rgba(249, 115, 22, 0.1); }
	.hl-name { flex: 1; font-size: 11px; color: rgba(255, 255, 255, 0.7); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.hl-val { font-size: 12px; font-weight: 700; }

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

	/* ===== Overall progress bar ===== */
	.overall-progress {
		margin-bottom: 14px;
	}
	.overall-progress-head {
		display: flex;
		justify-content: space-between;
		align-items: baseline;
		margin-bottom: 5px;
	}
	.overall-progress-phase {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.8);
	}
	.overall-progress-pct {
		font-size: 10px;
		font-weight: 600;
		color: rgba(var(--accent-text-rgb), 0.8);
	}
	.overall-progress-track {
		height: 8px;
		background: rgba(255, 255, 255, 0.05);
		border-radius: 4px;
		overflow: hidden;
	}
	.overall-progress-fill {
		height: 100%;
		background: linear-gradient(90deg, rgba(var(--accent-rgb), 0.5), rgba(var(--accent-rgb), 0.9));
		border-radius: 4px;
		transition: width 0.4s ease;
	}

	/* ===== Phase stepper ===== */
	.phase-stepper {
		display: flex;
		gap: 6px;
		margin-bottom: 14px;
		flex-wrap: wrap;
	}
	.phase-step {
		display: flex;
		align-items: center;
		gap: 7px;
		flex: 1 1 auto;
		min-width: 120px;
		padding: 8px 10px;
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 6px;
		transition: all 0.15s;
	}
	.phase-step.active {
		background: rgba(96, 165, 250, 0.08);
		border-color: rgba(96, 165, 250, 0.4);
	}
	.phase-step.done {
		border-color: rgba(34, 197, 94, 0.25);
	}
	.phase-step-dot {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 22px;
		height: 22px;
		flex-shrink: 0;
		border-radius: 50%;
		font-size: 11px;
		font-weight: 700;
		background: rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.5);
	}
	.phase-step.active .phase-step-dot {
		background: rgba(96, 165, 250, 0.9);
		color: #fff;
	}
	.phase-step.done .phase-step-dot {
		background: rgba(34, 197, 94, 0.85);
		color: #fff;
	}
	.phase-step-body {
		display: flex;
		flex-direction: column;
		gap: 1px;
		min-width: 0;
	}
	.phase-step-name {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.8);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}
	.phase-step-dors {
		font-size: 9px;
		color: rgba(255, 255, 255, 0.4);
	}

	/* ===== Phase stats ===== */
	.phase-stats {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 8px;
		margin-bottom: 14px;
	}
	.phase-stat {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 2px;
		padding: 10px 6px;
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 6px;
	}
	.phase-stat-value {
		font-size: 18px;
		font-weight: 700;
		color: rgba(255, 255, 255, 0.9);
		line-height: 1;
	}
	.phase-stat-label {
		font-size: 9px;
		text-transform: uppercase;
		letter-spacing: 0.4px;
		color: rgba(255, 255, 255, 0.4);
	}

	/* ===== Phase actions ===== */
	.phase-actions {
		display: flex;
		align-items: center;
		gap: 6px;
		flex-wrap: wrap;
	}
	.phase-actions-spacer { flex: 1; }

	.phase-readiness { margin-bottom: 8px; }
	.readiness-badge {
		display: inline-block;
		font-size: 10px;
		font-weight: 600;
		padding: 4px 9px;
		border-radius: 3px;
		border: 1px solid transparent;
	}
	.readiness-ok {
		color: rgba(74, 222, 128, 0.9);
		background: rgba(34, 197, 94, 0.08);
		border-color: rgba(34, 197, 94, 0.2);
	}
	.readiness-warn {
		color: rgba(234, 179, 8, 0.9);
		background: rgba(234, 179, 8, 0.07);
		border-color: rgba(234, 179, 8, 0.22);
	}
	.confirm-warn {
		margin: 0;
		font-size: 11px;
		line-height: 1.5;
		color: rgba(234, 179, 8, 0.9);
		background: rgba(234, 179, 8, 0.08);
		border: 1px solid rgba(234, 179, 8, 0.22);
		border-radius: 5px;
		padding: 8px 10px;
	}
	.phase-btn {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		padding: 4px 10px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		border: 1px solid transparent;
		transition: all 0.1s;
	}
	.phase-btn:disabled { opacity: 0.5; cursor: not-allowed; }
	.phase-btn-advance {
		background: rgba(var(--accent-rgb), 0.08);
		border-color: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.8);
	}
	.phase-btn-advance:hover:not(:disabled) { background: rgba(var(--accent-rgb), 0.14); color: rgba(var(--accent-text-rgb), 1); }
	.phase-btn-complete {
		background: rgba(34, 197, 94, 0.08);
		border-color: rgba(34, 197, 94, 0.18);
		color: rgba(74, 222, 128, 0.9);
	}
	.phase-btn-complete:hover:not(:disabled) { background: rgba(34, 197, 94, 0.16); }
	.phase-btn-ghost {
		background: rgba(255, 255, 255, 0.03);
		border-color: rgba(255, 255, 255, 0.08);
		color: rgba(255, 255, 255, 0.5);
	}
	.phase-btn-ghost:hover:not(:disabled) { color: rgba(255, 255, 255, 0.8); border-color: rgba(255, 255, 255, 0.15); }
	.phase-btn-warn {
		background: rgba(234, 179, 8, 0.06);
		border-color: rgba(234, 179, 8, 0.25);
		color: rgba(234, 179, 8, 0.85);
	}
	.phase-btn-warn:hover:not(:disabled) { background: rgba(234, 179, 8, 0.12); }
	.phase-btn-danger {
		background: rgba(239, 68, 68, 0.06);
		border-color: rgba(239, 68, 68, 0.3);
		color: rgba(248, 113, 113, 0.9);
	}
	.phase-btn-danger:hover:not(:disabled) { background: rgba(239, 68, 68, 0.12); }

	/* ===== Competency averages ===== */
	.comp-averages { display: flex; flex-direction: column; gap: 8px; }
	.comp-avg-row { display: flex; align-items: center; gap: 10px; }
	.comp-avg-name {
		flex: 0 0 34%;
		font-size: 11px;
		color: rgba(255, 255, 255, 0.75);
		display: flex;
		flex-direction: column;
		gap: 1px;
	}
	.comp-avg-cat { font-size: 9px; color: rgba(255, 255, 255, 0.35); }
	.comp-avg-track {
		flex: 1;
		height: 6px;
		background: rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		overflow: hidden;
	}
	.comp-avg-fill { height: 100%; border-radius: 3px; transition: width 0.3s ease; }
	.comp-avg-value { flex: 0 0 28px; text-align: right; font-size: 12px; font-weight: 700; }

	/* ===== Confirm modal ===== */
	.confirm-backdrop {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.65);
		backdrop-filter: blur(3px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}
	.confirm-modal {
		width: min(440px, 92vw);
		background: var(--card-dark-bg, #1a1d23);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 6px;
		overflow: hidden;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
		display: flex;
		flex-direction: column;
	}
	.confirm-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 10px 14px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}
	.confirm-title {
		font-size: 12px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}
	.confirm-close {
		display: flex;
		align-items: center;
		justify-content: center;
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 3px;
		color: rgba(255, 255, 255, 0.3);
		cursor: pointer;
		transition: all 0.1s;
	}
	.confirm-close:hover { color: rgba(255, 255, 255, 0.7); border-color: rgba(255, 255, 255, 0.12); }
	.confirm-body {
		padding: 14px;
		display: flex;
		flex-direction: column;
		gap: 10px;
	}
	.confirm-text {
		margin: 0;
		font-size: 11px;
		line-height: 1.5;
		color: rgba(255, 255, 255, 0.55);
	}
	.confirm-note {
		width: 100%;
		box-sizing: border-box;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 6px 8px;
		color: rgba(255, 255, 255, 0.85);
		font-size: 11px;
		font-family: inherit;
		resize: vertical;
		outline: none;
	}
	.confirm-note:focus { border-color: rgba(255, 255, 255, 0.12); }
	.confirm-footer {
		display: flex;
		justify-content: flex-end;
		gap: 6px;
		padding: 10px 14px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
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

	/* Rating scale legend + 1–5 pill selector */
	.rating-legend {
		display: flex;
		flex-direction: column;
		gap: 6px;
		padding: 10px;
		margin-bottom: 10px;
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 6px;
	}
	.rating-legend-title {
		font-size: 11px;
		font-weight: 700;
		color: rgba(255, 255, 255, 0.8);
	}
	.rating-legend-scale {
		display: flex;
		flex-wrap: wrap;
		gap: 10px;
	}
	.rating-legend-item {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		font-size: 10px;
		color: rgba(255, 255, 255, 0.6);
		cursor: help;
	}
	.rating-legend-num {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 16px;
		height: 16px;
		border-radius: 4px;
		color: #0c0c0c;
		font-size: 10px;
		font-weight: 800;
	}
	.rating-legend-lab { font-weight: 600; }
	.rating-legend-hint {
		font-size: 9px;
		color: rgba(255, 255, 255, 0.35);
		font-style: italic;
	}

	.rating-pills {
		display: flex;
		gap: 4px;
		flex-shrink: 0;
	}
	.rating-pill {
		width: 26px;
		height: 26px;
		border-radius: 5px;
		border: 1px solid rgba(255, 255, 255, 0.12);
		background: rgba(255, 255, 255, 0.03);
		color: rgba(255, 255, 255, 0.6);
		font-size: 12px;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.1s;
	}
	.rating-pill:hover { border-color: rgba(255, 255, 255, 0.3); color: rgba(255, 255, 255, 0.9); }
	.rating-pill.selected { color: #0c0c0c; }
	.rating-row-label {
		flex: 0 0 84px;
		text-align: right;
		font-size: 10px;
		font-weight: 700;
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
		border: 1px solid transparent;
		border-radius: 3px;
	}

	.dor-phase-badge {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.3px;
		color: rgba(255, 255, 255, 0.6);
		background: rgba(255, 255, 255, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.08);
		padding: 1px 6px;
		border-radius: 3px;
	}

	/* List: phase tag + colored DOR count + rating */
	.phase-tag {
		font-size: 10px;
		font-weight: 500;
		color: rgba(255, 255, 255, 0.7);
		background: rgba(255, 255, 255, 0.05);
		border: 1px solid rgba(255, 255, 255, 0.07);
		padding: 1px 7px;
		border-radius: 3px;
	}
	.dor-count-badge {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		min-width: 20px;
		padding: 1px 6px;
		font-size: 10px;
		font-weight: 700;
		color: rgba(var(--accent-text-rgb), 0.85);
		background: rgba(var(--accent-rgb), 0.1);
		border-radius: 3px;
	}
	.rating-badge-sm {
		font-size: 10px;
		font-weight: 700;
		padding: 1px 6px;
		border: 1px solid transparent;
		border-radius: 3px;
	}
	.muted-dash { color: rgba(255, 255, 255, 0.2); }

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