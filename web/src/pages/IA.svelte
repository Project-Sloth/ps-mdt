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

	interface IAComplaint {
		id: number;
		complaint_number: string;
		complainant_name: string;
		complainant_phone?: string;
		officer_name: string;
		officer_badge?: string;
		category: string;
		description: string;
		incident_date?: string;
		incident_location?: string;
		witnesses?: string;
		evidence?: string;
		status: string;
		assigned_to?: string;
		assigned_to_name?: string;
		created_at: string;
		updated_at?: string;
	}

	interface IANote {
		id: number;
		content: string;
		author_name?: string;
		created_at?: string;
	}

	interface IAComplaintDetail {
		complaint: IAComplaint;
		notes: IANote[];
	}

	let complaints = $state<IAComplaint[]>([]);
	let selectedComplaint = $state<IAComplaintDetail | null>(null);
	let loading = $state(false);
	let searchQuery = $state("");
	let statusFilter = $state<string>("all");
	let page = $state(1);
	let perPage = $state(20);
	let noteContent = $state("");
	let noteSubmitting = $state(false);
	let statusUpdateValue = $state("");
	let assignInvestigatorValue = $state("");
	let editOfficerName = $state("");
	let editOfficerBadge = $state("");
	let editIncidentDate = $state("");
	let editIncidentLocation = $state("");
	let editMode = $state(false);
	let showOfficerSearchForEdit = $state(false);

	const searchService = createSearchService();
	let showInvestigatorSearch = $state(false);
	let investigatorSearchQuery = $state("");

	let canManage = $derived(authService?.hasPermission('ia_manage') ?? false);
	let mounted = false;

	const statusOptions = ["all", "open", "under_review", "investigated", "sustained", "exonerated", "unfounded", "closed"];

	onMount(async () => {
		if (isEnvBrowser()) {
			complaints = [
				{ id: 1, complaint_number: 'IA-2026-00001', complainant_name: 'John Smith', officer_name: 'Ofc. Williams', officer_badge: '1234', category: 'excessive_force', description: 'Officer used excessive force during a traffic stop.', status: 'open', assigned_to_name: null as any, created_at: '2026-03-20T10:00:00Z' },
				{ id: 2, complaint_number: 'IA-2026-00002', complainant_name: 'Maria Garcia', officer_name: 'Sgt. Johnson', officer_badge: '5678', category: 'misconduct', description: 'Sergeant engaged in unprofessional conduct during arrest.', status: 'under_review', assigned_to_name: 'Det. Chen', created_at: '2026-03-18T14:30:00Z' },
				{ id: 3, complaint_number: 'IA-2026-00003', complainant_name: 'Robert Davis', officer_name: 'Ofc. Thompson', officer_badge: '9012', category: 'corruption', description: 'Officer suspected of accepting bribes.', status: 'sustained', assigned_to_name: 'Lt. Baker', created_at: '2026-03-15T08:00:00Z' },
			];
			loading = false;
			mounted = true;
			return;
		}
		await loadComplaints();
		mounted = true;
	});

	async function loadComplaints() {
		loading = true;
		try {
			const data = await fetchNui<{ complaints: IAComplaint[]; hasMore?: boolean; error?: string }>(
				NUI_EVENTS.IA.GET_IA_COMPLAINTS,
				{ page, status: statusFilter === 'all' ? '' : statusFilter, search: searchQuery.trim() || '' },
				{ complaints: [], hasMore: false }
			);
			complaints = data.complaints || [];
		} catch (e) {
			console.error('[IA] loadComplaints error:', e);
			globalNotifications.error("Failed to load complaints");
		}
		loading = false;
	}

	async function selectComplaint(id: number) {
		loading = true;
		try {
			const response = await fetchNui<{ success: boolean; data?: IAComplaintDetail }>(
				NUI_EVENTS.IA.GET_IA_COMPLAINT,
				{ id },
				{ success: true, data: { complaint: complaints.find(c => c.id === id)!, notes: [] } }
			);
			const detail = response?.data || { complaint: complaints.find(c => c.id === id)!, notes: [] };
			selectedComplaint = detail;
			if (detail?.complaint) {
				statusUpdateValue = detail.complaint.status;
				assignInvestigatorValue = detail.complaint.assigned_to_name || "";
				editOfficerName = detail.complaint.officer_name || "";
				editOfficerBadge = detail.complaint.officer_badge || "";
				editIncidentDate = detail.complaint.incident_date || "";
				editIncidentLocation = detail.complaint.incident_location || "";
			}
		} catch {
			globalNotifications.error("Failed to load complaint details");
		}
		loading = false;
	}

	function goBack() {
		selectedComplaint = null;
		noteContent = "";
		editMode = false;
		if (!isEnvBrowser()) loadComplaints();
	}

	async function handleUpdateStatus() {
		if (!selectedComplaint || !statusUpdateValue) return;
		const newStatus = statusUpdateValue;
		const complaintId = selectedComplaint.complaint.id;
		try {
			const result = await fetchNui<{ success: boolean; error?: string }>(
				NUI_EVENTS.IA.UPDATE_IA_STATUS,
				{ id: complaintId, status: newStatus },
				{ success: true }
			);
			if (!result || result.success === false) {
				globalNotifications.error(result?.error || "Failed to update status");
				return;
			}
			// Update local state immediately
			selectedComplaint.complaint.status = newStatus;
			const idx = complaints.findIndex(c => c.id === complaintId);
			if (idx !== -1) complaints[idx].status = newStatus;
			globalNotifications.success("Status updated");
			// Refresh list in background
			loadComplaints();
		} catch {
			globalNotifications.error("Failed to update status");
		}
	}

	async function handleSelfAssign() {
		if (!selectedComplaint) return;
		const cid = authService?.playerData?.citizenid;
		if (!cid) {
			globalNotifications.error("Could not determine your citizen ID");
			return;
		}
		try {
			await fetchNui(NUI_EVENTS.IA.ASSIGN_IA_COMPLAINT, {
				id: selectedComplaint.complaint.id,
				citizenid: cid,
			});
			await selectComplaint(selectedComplaint.complaint.id);
			globalNotifications.success("Assigned to you");
		} catch {
			globalNotifications.error("Failed to assign investigator");
		}
	}

	async function handleUnassign() {
		if (!selectedComplaint) return;
		try {
			await fetchNui(NUI_EVENTS.IA.ASSIGN_IA_COMPLAINT, {
				id: selectedComplaint.complaint.id,
				citizenid: "__unassign__",
			});
			await selectComplaint(selectedComplaint.complaint.id);
			globalNotifications.success("Investigator unassigned");
		} catch {
			globalNotifications.error("Failed to unassign investigator");
		}
	}

	async function handleInvestigatorSearch(query: string) {
		investigatorSearchQuery = query;
		if (!query.trim()) {
			searchService.clearResults();
			return;
		}
		await searchService.searchOfficers(query);
	}

	async function handleSelectInvestigator(person: { citizenid?: string; id?: string }) {
		if (!selectedComplaint) return;
		const citizenid = person.citizenid || person.id;
		if (!citizenid) return;
		try {
			await fetchNui(NUI_EVENTS.IA.ASSIGN_IA_COMPLAINT, {
				id: selectedComplaint.complaint.id,
				citizenid,
			});
			showInvestigatorSearch = false;
			searchService.clearResults();
			investigatorSearchQuery = "";
			await selectComplaint(selectedComplaint.complaint.id);
			globalNotifications.success("Investigator assigned");
		} catch {
			globalNotifications.error("Failed to assign investigator");
		}
	}

	async function handleAddNote() {
		if (!selectedComplaint || !noteContent.trim() || noteSubmitting) return;
		noteSubmitting = true;
		try {
			await fetchNui(NUI_EVENTS.IA.ADD_IA_NOTE, {
				complaintId: selectedComplaint.complaint.id,
				content: noteContent.trim(),
			});
			noteContent = "";
			await selectComplaint(selectedComplaint.complaint.id);
		} catch {
			globalNotifications.error("Failed to add note");
		}
		noteSubmitting = false;
	}

	async function handleDeleteNote(noteId: number) {
		if (!selectedComplaint) return;
		try {
			await fetchNui(NUI_EVENTS.IA.DELETE_IA_NOTE, {
				complaintId: selectedComplaint.complaint.id,
				noteId: noteId,
			});
			await selectComplaint(selectedComplaint.complaint.id);
		} catch {
			globalNotifications.error("Failed to delete note");
		}
	}

	async function handleSaveComplaintInfo() {
		if (!selectedComplaint || !canManage) return;
		try {
			await fetchNui(NUI_EVENTS.IA.UPDATE_IA_COMPLAINT_INFO, {
				id: selectedComplaint.complaint.id,
				officer_name: editOfficerName.trim(),
				officer_badge: editOfficerBadge.trim(),
				incident_date: editIncidentDate,
				incident_location: editIncidentLocation.trim(),
			});
			editMode = false;
			await selectComplaint(selectedComplaint.complaint.id);
			globalNotifications.success("Complaint info updated");
		} catch {
			globalNotifications.error("Failed to update complaint info");
		}
	}

	async function handleOfficerSearchForEdit(query: string) {
		if (!query.trim()) {
			searchService.clearResults();
			return;
		}
		await searchService.searchOfficers(query);
	}

	function handleSelectOfficerForEdit(person: { citizenid?: string; id?: string; fullName?: string; badgeId?: string }) {
		editOfficerName = person.fullName || '';
		editOfficerBadge = person.badgeId || '';
		showOfficerSearchForEdit = false;
		searchService.clearResults();
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

	function formatDateTimeValue(value: string | undefined): string {
		if (!value) return "-";
		const date = new Date(value);
		if (Number.isNaN(date.getTime())) return "-";
		return date.toLocaleDateString("en-US", {
			month: "2-digit",
			day: "2-digit",
			year: "numeric",
		}) + " " + date.toLocaleTimeString("en-US", {
			hour: "2-digit",
			minute: "2-digit",
			hour12: false,
		});
	}

	function getStatusPillClass(status: string): string {
		switch (status) {
			case 'open': return 'pill-blue';
			case 'under_review': return 'pill-orange';
			case 'investigated': return 'pill-yellow';
			case 'sustained': return 'pill-red';
			case 'exonerated': return 'pill-green';
			case 'unfounded':
			case 'closed': return 'pill-grey';
			default: return 'pill-grey';
		}
	}

	function parseEvidence(evidence: string | undefined): string[] {
		if (!evidence) return [];
		try {
			const parsed = JSON.parse(evidence);
			if (Array.isArray(parsed)) return parsed;
			return [];
		} catch {
			return [];
		}
	}

	let allFilteredComplaints = $derived.by(() => {
		let filtered = complaints;
		if (statusFilter !== 'all') {
			filtered = filtered.filter(c => c.status === statusFilter);
		}
		const query = searchQuery.trim().toLowerCase();
		if (query) {
			filtered = filtered.filter(c =>
				[c.complaint_number, c.complainant_name, c.officer_name, c.category, c.assigned_to_name]
					.filter(Boolean)
					.some(val => String(val).toLowerCase().includes(query))
			);
		}
		return filtered;
	});

	let paginatedComplaints = $derived.by(() => {
		const start = (page - 1) * perPage;
		return allFilteredComplaints.slice(start, start + perPage);
	});

	$effect(() => {
		searchQuery;
		statusFilter;
		page = 1;
		if (mounted && !isEnvBrowser()) loadComplaints();
	});
</script>

<div class="ia-page">
	{#if selectedComplaint}
		<!-- ==================== DETAIL VIEW ==================== -->
		<div class="topbar">
			<button class="back-btn" onclick={goBack}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
				Back to Complaints
			</button>
			<span class="topbar-case-number">{selectedComplaint.complaint.complaint_number}</span>
			<span class="pill {getStatusPillClass(selectedComplaint.complaint.status)}">{formatLabel(selectedComplaint.complaint.status)}</span>
		</div>

		<div class="detail-scroll">
			<div class="detail-layout">
				<!-- Left Column: Main Content -->
				<div class="detail-main">
					<div class="section">
						<div class="section-header">
							<div class="section-title" style="margin-bottom:0;">Complaint Information</div>
							{#if canManage}
								<div class="inline-controls">
									{#if editMode}
										<button class="action-btn" onclick={handleSaveComplaintInfo}>Save</button>
										<button class="action-btn" onclick={() => { editMode = false; }}>Cancel</button>
									{:else}
										<button class="action-btn" onclick={() => { editMode = true; }}>Edit</button>
									{/if}
								</div>
							{/if}
						</div>
						{#if editMode && canManage}
							<div class="field-row">
								<div class="field-group">
									<span class="field-label">Officer</span>
									<div class="inline-controls">
										<input type="text" class="form-input" bind:value={editOfficerName} placeholder="Officer name" />
										<button class="action-btn" onclick={() => (showOfficerSearchForEdit = true)}>Search</button>
									</div>
								</div>
								<div class="field-group">
									<span class="field-label">Badge</span>
									<input type="text" class="form-input" bind:value={editOfficerBadge} placeholder="Badge #" />
								</div>
								<div class="field-group">
									<span class="field-label">Incident Date</span>
									<input type="date" class="form-input" bind:value={editIncidentDate} />
								</div>
								<div class="field-group">
									<span class="field-label">Location</span>
									<input type="text" class="form-input" bind:value={editIncidentLocation} placeholder="Location" />
								</div>
							</div>
						{:else}
							<div class="field-row">
								<div class="field-group">
									<span class="field-label">Officer</span>
									<span class="field-value">{selectedComplaint.complaint.officer_name || '-'}{selectedComplaint.complaint.officer_badge ? ` (#${selectedComplaint.complaint.officer_badge})` : ''}</span>
								</div>
								<div class="field-group">
									<span class="field-label">Category</span>
									<span class="field-value">{formatLabel(selectedComplaint.complaint.category)}</span>
								</div>
								<div class="field-group">
									<span class="field-label">Incident Date</span>
									<span class="field-value">{selectedComplaint.complaint.incident_date || '-'}</span>
								</div>
								<div class="field-group">
									<span class="field-label">Location</span>
									<span class="field-value">{selectedComplaint.complaint.incident_location || '-'}</span>
								</div>
							</div>
						{/if}
					</div>

					<div class="section">
						<div class="section-title">Description</div>
						<p class="summary-text">{selectedComplaint.complaint.description || 'No description provided.'}</p>
					</div>

					{#if selectedComplaint.complaint.witnesses}
						<div class="section">
							<div class="section-title">Witnesses</div>
							<p class="summary-text">{selectedComplaint.complaint.witnesses}</p>
						</div>
					{/if}

					{#if selectedComplaint.complaint.evidence}
						{@const evidenceLinks = parseEvidence(selectedComplaint.complaint.evidence)}
						{#if evidenceLinks.length > 0}
							<div class="section">
								<div class="section-title">Evidence</div>
								<div class="evidence-links">
									{#each evidenceLinks as link, i}
										<a href={link} target="_blank" rel="noopener noreferrer" class="evidence-link">
											<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>
											Evidence #{i + 1}
										</a>
									{/each}
								</div>
							</div>
						{/if}
					{/if}
				</div>

				<!-- Right Column: Sidebar -->
				<div class="detail-side">
					<div class="section">
						<div class="section-title">Complainant</div>
						<div class="field-group">
							<span class="field-label">Name</span>
							<span class="field-value">{selectedComplaint.complaint.complainant_name}</span>
						</div>
						{#if selectedComplaint.complaint.complainant_phone}
							<div class="field-group">
								<span class="field-label">Phone</span>
								<span class="field-value">{selectedComplaint.complaint.complainant_phone}</span>
							</div>
						{/if}
					</div>

					{#if canManage}
						<div class="section">
							<div class="section-title">Status Management</div>
							<div class="inline-controls">
								<select class="form-select" bind:value={statusUpdateValue}>
									{#each statusOptions.filter(s => s !== 'all') as opt}
										<option value={opt}>{formatLabel(opt)}</option>
									{/each}
								</select>
								<button class="primary-btn" onclick={handleUpdateStatus}>Update</button>
							</div>
						</div>

						<div class="section">
							<div class="section-title">Investigator</div>
							{#if selectedComplaint.complaint.assigned_to_name}
								<p class="assigned-name">{selectedComplaint.complaint.assigned_to_name}</p>
							{:else}
								<p class="muted-text">No investigator assigned</p>
							{/if}
							<div class="inline-controls">
								<button class="action-btn" onclick={() => (showInvestigatorSearch = true)}>Search</button>
								<button class="action-btn" onclick={handleSelfAssign}>Self</button>
								{#if selectedComplaint.complaint.assigned_to_name}
									<button class="action-btn danger" onclick={handleUnassign}>Unassign</button>
								{/if}
							</div>
						</div>
					{/if}

					<div class="section">
						<div class="section-title">Internal Notes</div>
						<div class="note-input-row">
							<textarea
								class="form-textarea"
								rows="2"
								placeholder="Add a note..."
								bind:value={noteContent}
							></textarea>
							<button class="action-btn" onclick={handleAddNote} disabled={noteSubmitting || !noteContent.trim()}>
								{noteSubmitting ? 'Adding...' : 'Add Note'}
							</button>
						</div>
						{#if selectedComplaint.notes.length > 0}
							<div class="notes-list">
								{#each selectedComplaint.notes as note}
									<div class="note-item">
										<div class="note-header">
											<span class="note-author">{note.author_name || 'Unknown'}</span>
											<span class="note-date">{formatDateTimeValue(note.created_at)}</span>
											{#if canManage}
												<button class="chip-remove" onclick={() => handleDeleteNote(note.id)}>
													<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
												</button>
											{/if}
										</div>
										<p class="note-content">{note.content}</p>
									</div>
								{/each}
							</div>
						{:else}
							<p class="muted-text">No notes yet.</p>
						{/if}
					</div>
				</div>
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
				<input type="text" placeholder="Search complaints..." bind:value={searchQuery} />
			</div>
			<div style="flex:1;"></div>
			<button class="back-btn" onclick={loadComplaints} disabled={loading}>
				<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
				Refresh
			</button>
		</div>

		<div class="list-panel">
			{#if loading && complaints.length === 0}
				<div class="center-state">
					<div class="loading-spinner"></div>
					<p>Loading complaints...</p>
				</div>
			{:else if paginatedComplaints.length === 0}
				<div class="center-state">
					<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.2)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
					<h3>No Complaints Found</h3>
					<p>{searchQuery ? "No complaints match your search criteria." : "No complaints have been filed yet."}</p>
				</div>
			{:else}
				<div class="table-header">
					<span>#</span>
					<span>Status</span>
					<span>Category</span>
					<span>Officer</span>
					<span>Complainant</span>
					<span>Date</span>
					<span>Assigned To</span>
				</div>
				<div class="table-body">
					{#each paginatedComplaints as item}
						<button class="table-row" onclick={() => selectComplaint(item.id)}>
							<span class="row-case">{item.complaint_number}</span>
							<span>
								<span class="pill {getStatusPillClass(item.status)}">{formatLabel(item.status)}</span>
							</span>
							<span>{formatLabel(item.category)}</span>
							<span>{item.officer_name}</span>
							<span>{item.complainant_name}</span>
							<span>{formatDateValue(item.created_at)}</span>
							<span>{item.assigned_to_name || 'Unassigned'}</span>
						</button>
					{/each}
				</div>
			{/if}
			<Pagination
				currentPage={page}
				totalItems={allFilteredComplaints.length}
				perPage={perPage}
				onPageChange={(p) => { page = p; }}
				onPerPageChange={(pp) => { perPage = pp; page = 1; }}
			/>
		</div>
	{/if}
</div>

<PersonSearchModal
	show={showInvestigatorSearch}
	title="Search Officers"
	searchQuery={investigatorSearchQuery}
	searchResults={searchService.state.results}
	onClose={() => {
		showInvestigatorSearch = false;
		investigatorSearchQuery = "";
	}}
	onSearch={handleInvestigatorSearch}
	onSelect={handleSelectInvestigator}
/>

<PersonSearchModal
	show={showOfficerSearchForEdit}
	title="Search Officer"
	searchQuery=""
	searchResults={searchService.state.results}
	onClose={() => {
		showOfficerSearchForEdit = false;
		searchService.clearResults();
	}}
	onSearch={handleOfficerSearchForEdit}
	onSelect={handleSelectOfficerForEdit}
/>

<style>
	/* ===== PAGE ===== */
	.ia-page {
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

	.pill-yellow {
		background: rgba(234, 179, 8, 0.08);
		color: rgba(250, 204, 21, 0.8);
		border: 1px solid rgba(234, 179, 8, 0.1);
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
		grid-template-columns: 1.2fr 0.8fr 1fr 1fr 1fr 0.8fr 1fr;
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
		grid-template-columns: 1.2fr 0.8fr 1fr 1fr 1fr 0.8fr 1fr;
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
	.assigned-name {
		color: rgb(var(--accent-text-rgb));
		font-size: 12px;
		font-weight: 600;
		margin: 0 0 6px 0;
	}
	.action-btn.danger {
		color: #ef4444;
		border-color: rgba(239, 68, 68, 0.3);
	}
	.action-btn.danger:hover {
		background: rgba(239, 68, 68, 0.1);
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

	/* ===== INLINE CONTROLS ===== */
	.inline-controls {
		display: flex;
		gap: 6px;
		align-items: center;
	}

	/* ===== EVIDENCE LINKS ===== */
	.evidence-links {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.evidence-link {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-size: 11px;
		text-decoration: none;
		transition: color 0.1s;
	}

	.evidence-link:hover {
		color: rgba(var(--accent-text-rgb), 0.9);
		text-decoration: underline;
	}

	/* ===== NOTES ===== */
	.note-input-row {
		display: flex;
		gap: 8px;
		align-items: flex-start;
		margin-bottom: 8px;
	}

	.note-input-row .form-textarea {
		flex: 1;
		background: rgba(255, 255, 255, 0.05);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 4px;
		color: rgba(255, 255, 255, 0.87);
		font-size: 11px;
		padding: 6px 8px;
		resize: vertical;
		min-height: 36px;
		font-family: inherit;
	}

	.note-input-row .form-textarea:focus {
		outline: none;
		border-color: rgba(var(--accent-rgb), 0.5);
	}

	.notes-list {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.note-item {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 4px;
		padding: 8px 10px;
	}

	.note-header {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-bottom: 4px;
	}

	.note-author {
		color: rgb(var(--accent-text-rgb));
		font-size: 10px;
		font-weight: 600;
	}

	.note-date {
		color: rgba(255, 255, 255, 0.3);
		font-size: 9px;
		flex: 1;
	}

	.note-content {
		color: rgba(255, 255, 255, 0.75);
		font-size: 11px;
		margin: 0;
		white-space: pre-wrap;
		line-height: 1.4;
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
