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

	interface PPREntry {
		id: number;
		ppr_number: string;
		officer_name: string;
		officer_citizenid: string;
		author_name: string;
		author_citizenid?: string;
		category: string;
		title: string;
		description?: string;
		incident_date?: string;
		incident_location?: string;
		linked_report_id?: number;
		linked_case_id?: number;
		created_at: string;
		updated_at?: string;
	}

	interface PPRNote {
		id: number;
		content: string;
		author_name?: string;
		created_at?: string;
	}

	interface PPRDetail {
		entry: PPREntry;
		notes: PPRNote[];
	}

	let entries = $state<PPREntry[]>([]);
	let selectedEntry = $state<PPRDetail | null>(null);
	let loading = $state(false);
	let searchQuery = $state("");
	let categoryFilter = $state<string>("all");
	let page = $state(1);
	let perPage = $state(20);
	let noteContent = $state("");
	let noteSubmitting = $state(false);
	let showCreateForm = $state(false);

	// Create form state
	let newTitle = $state("");
	let newDescription = $state("");
	let newCategory = $state("positive");
	let newIncidentDate = $state("");
	let newIncidentLocation = $state("");
	let newLinkedReportId = $state<number | undefined>(undefined);
	let newLinkedCaseId = $state<number | undefined>(undefined);
	let newOfficerCitizenId = $state("");
	let newOfficerName = $state("");
	let isSubmitting = $state(false);

	// Edit state
	let editMode = $state(false);
	let editTitle = $state("");
	let editDescription = $state("");
	let editCategory = $state("");
	let editIncidentDate = $state("");
	let editIncidentLocation = $state("");

	// Officer search
	const searchService = createSearchService();
	let showOfficerSearch = $state(false);
	let officerSearchQuery = $state("");

	let canManage = $derived(authService?.hasPermission('ppr_manage') ?? false);
	let mounted = false;

	const categoryOptions = ["all", "positive", "coaching", "disciplinary"];

	onMount(async () => {
		if (isEnvBrowser()) {
			entries = [
				{ id: 1, ppr_number: 'PPR-2026-00001', officer_name: 'Ofc. Williams', officer_citizenid: 'ABC123', author_name: 'Sgt. Johnson', category: 'positive', title: 'Outstanding response to bank robbery', incident_date: '2026-03-20', created_at: '2026-03-20T10:00:00Z' },
				{ id: 2, ppr_number: 'PPR-2026-00002', officer_name: 'Ofc. Thompson', officer_citizenid: 'DEF456', author_name: 'Lt. Baker', category: 'coaching', title: 'Traffic stop procedure review', incident_date: '2026-03-18', created_at: '2026-03-18T14:30:00Z' },
				{ id: 3, ppr_number: 'PPR-2026-00003', officer_name: 'Ofc. Davis', officer_citizenid: 'GHI789', author_name: 'Sgt. Johnson', category: 'disciplinary', title: 'Failure to follow pursuit policy', incident_date: '2026-03-15', created_at: '2026-03-15T08:00:00Z' },
			];
			loading = false;
			mounted = true;
			return;
		}
		await loadEntries();
		mounted = true;
	});

	async function loadEntries() {
		loading = true;
		try {
			const data = await fetchNui<{ entries: PPREntry[]; hasMore?: boolean }>(
				NUI_EVENTS.PPR.GET_PPR_LIST,
				{ page, category: categoryFilter === 'all' ? '' : categoryFilter, search: searchQuery.trim() || '' },
				{ entries: [], hasMore: false }
			);
			entries = data.entries || [];
		} catch (e) {
			console.error('[PPR] loadEntries error:', e);
			globalNotifications.error("Failed to load PPR entries");
		}
		loading = false;
	}

	async function selectEntry(id: number) {
		loading = true;
		try {
			const response = await fetchNui<{ success: boolean; data?: PPRDetail }>(
				NUI_EVENTS.PPR.GET_PPR,
				{ id },
				{ success: true, data: { entry: entries.find(e => e.id === id)!, notes: [] } }
			);
			const detail = response?.data || { entry: entries.find(e => e.id === id)!, notes: [] };
			selectedEntry = detail;
			if (detail?.entry) {
				editTitle = detail.entry.title || "";
				editDescription = detail.entry.description || "";
				editCategory = detail.entry.category || "";
				editIncidentDate = detail.entry.incident_date || "";
				editIncidentLocation = detail.entry.incident_location || "";
			}
		} catch {
			globalNotifications.error("Failed to load PPR details");
		}
		loading = false;
	}

	function goBack() {
		selectedEntry = null;
		noteContent = "";
		editMode = false;
		if (!isEnvBrowser()) loadEntries();
	}

	function resetCreateForm() {
		newTitle = "";
		newDescription = "";
		newCategory = "positive";
		newIncidentDate = "";
		newIncidentLocation = "";
		newLinkedReportId = undefined;
		newLinkedCaseId = undefined;
		newOfficerCitizenId = "";
		newOfficerName = "";
	}

	async function handleCreatePPR() {
		if (!newTitle.trim() || !newOfficerCitizenId || !newCategory || isSubmitting) return;
		isSubmitting = true;
		try {
			const result = await fetchNui<{ success: boolean; error?: string }>(
				NUI_EVENTS.PPR.CREATE_PPR,
				{
					officer_citizenid: newOfficerCitizenId,
					officer_name: newOfficerName,
					category: newCategory,
					title: newTitle.trim(),
					description: newDescription.trim(),
					incident_date: newIncidentDate || undefined,
					incident_location: newIncidentLocation.trim() || undefined,
					linked_report_id: newLinkedReportId || undefined,
					linked_case_id: newLinkedCaseId || undefined,
				},
				{ success: true }
			);
			if (!result || result.success === false) {
				globalNotifications.error(result?.error || "Failed to create PPR entry");
				isSubmitting = false;
				return;
			}
			globalNotifications.success("PPR entry created");
			resetCreateForm();
			showCreateForm = false;
			if (!isEnvBrowser()) loadEntries();
		} catch {
			globalNotifications.error("Failed to create PPR entry");
		}
		isSubmitting = false;
	}

	async function handleUpdateEntry() {
		if (!selectedEntry || !canManage) return;
		try {
			const result = await fetchNui<{ success: boolean; error?: string }>(
				NUI_EVENTS.PPR.UPDATE_PPR,
				{
					id: selectedEntry.entry.id,
					title: editTitle.trim(),
					description: editDescription.trim(),
					category: editCategory,
					incident_date: editIncidentDate || undefined,
					incident_location: editIncidentLocation.trim() || undefined,
				},
				{ success: true }
			);
			if (!result || result.success === false) {
				globalNotifications.error(result?.error || "Failed to update PPR entry");
				return;
			}
			selectedEntry.entry.title = editTitle.trim();
			selectedEntry.entry.description = editDescription.trim();
			selectedEntry.entry.category = editCategory;
			selectedEntry.entry.incident_date = editIncidentDate;
			selectedEntry.entry.incident_location = editIncidentLocation.trim();
			editMode = false;
			globalNotifications.success("PPR entry updated");
		} catch {
			globalNotifications.error("Failed to update PPR entry");
		}
	}

	async function handleDeleteEntry() {
		if (!selectedEntry || !canManage) return;
		try {
			await fetchNui(NUI_EVENTS.PPR.DELETE_PPR, { id: selectedEntry.entry.id }, { success: true });
			globalNotifications.success("PPR entry deleted");
			goBack();
		} catch {
			globalNotifications.error("Failed to delete PPR entry");
		}
	}

	async function handleAddNote() {
		if (!selectedEntry || !noteContent.trim() || noteSubmitting) return;
		noteSubmitting = true;
		try {
			await fetchNui(NUI_EVENTS.PPR.ADD_PPR_NOTE, {
				pprId: selectedEntry.entry.id,
				content: noteContent.trim(),
			});
			noteContent = "";
			await selectEntry(selectedEntry.entry.id);
		} catch {
			globalNotifications.error("Failed to add note");
		}
		noteSubmitting = false;
	}

	async function handleDeleteNote(noteId: number) {
		if (!selectedEntry) return;
		try {
			await fetchNui(NUI_EVENTS.PPR.DELETE_PPR_NOTE, {
				pprId: selectedEntry.entry.id,
				noteId: noteId,
			});
			await selectEntry(selectedEntry.entry.id);
		} catch {
			globalNotifications.error("Failed to delete note");
		}
	}

	async function handleOfficerSearch(query: string) {
		officerSearchQuery = query;
		if (!query.trim()) {
			searchService.clearResults();
			return;
		}
		await searchService.searchOfficers(query);
	}

	function handleSelectOfficer(person: { citizenid?: string; id?: string; fullName?: string }) {
		newOfficerCitizenId = person.citizenid || person.id || '';
		newOfficerName = person.fullName || '';
		showOfficerSearch = false;
		searchService.clearResults();
		officerSearchQuery = "";
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

	function getCategoryPillClass(category: string): string {
		switch (category) {
			case 'positive': return 'pill-green';
			case 'coaching': return 'pill-orange';
			case 'disciplinary': return 'pill-red';
			default: return 'pill-grey';
		}
	}

	let allFilteredEntries = $derived.by(() => {
		let filtered = entries;
		if (categoryFilter !== 'all') {
			filtered = filtered.filter(e => e.category === categoryFilter);
		}
		const query = searchQuery.trim().toLowerCase();
		if (query) {
			filtered = filtered.filter(e =>
				[e.ppr_number, e.officer_name, e.author_name, e.category, e.title]
					.filter(Boolean)
					.some(val => String(val).toLowerCase().includes(query))
			);
		}
		return filtered;
	});

	let paginatedEntries = $derived.by(() => {
		const start = (page - 1) * perPage;
		return allFilteredEntries.slice(start, start + perPage);
	});

	$effect(() => {
		searchQuery;
		categoryFilter;
		page = 1;
		if (mounted && !isEnvBrowser()) loadEntries();
	});
</script>

<div class="ppr-page">
	{#if selectedEntry}
		<!-- ==================== DETAIL VIEW ==================== -->
		<div class="topbar">
			<button class="back-btn" onclick={goBack}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
				Back to PPR List
			</button>
			<span class="topbar-case-number">{selectedEntry.entry.ppr_number}</span>
			<span class="pill {getCategoryPillClass(selectedEntry.entry.category)}">{formatLabel(selectedEntry.entry.category)}</span>
		</div>

		<div class="detail-scroll">
			<div class="detail-layout">
				<!-- Left Column: Main Content -->
				<div class="detail-main">
					<div class="section">
						<div class="section-header">
							<div class="section-title" style="margin-bottom:0;">Incident Details</div>
							{#if canManage}
								<div class="inline-controls">
									{#if editMode}
										<button class="action-btn" onclick={handleUpdateEntry}>Save</button>
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
									<span class="field-label">Title</span>
									<input type="text" class="form-input" bind:value={editTitle} placeholder="Title" />
								</div>
								<div class="field-group">
									<span class="field-label">Category</span>
									<select class="form-select" bind:value={editCategory}>
										<option value="positive">Positive</option>
										<option value="coaching">Coaching</option>
										<option value="disciplinary">Disciplinary</option>
									</select>
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
							<div class="field-group" style="margin-top:8px;">
								<span class="field-label">Description</span>
								<textarea class="form-textarea" rows="4" bind:value={editDescription} placeholder="Description"></textarea>
							</div>
						{:else}
							<div class="field-row">
								<div class="field-group">
									<span class="field-label">Officer</span>
									<span class="field-value">{selectedEntry.entry.officer_name || '-'}</span>
								</div>
								<div class="field-group">
									<span class="field-label">Author</span>
									<span class="field-value">{selectedEntry.entry.author_name || '-'}</span>
								</div>
								<div class="field-group">
									<span class="field-label">Category</span>
									<span class="pill {getCategoryPillClass(selectedEntry.entry.category)}">{formatLabel(selectedEntry.entry.category)}</span>
								</div>
								<div class="field-group">
									<span class="field-label">Incident Date</span>
									<span class="field-value">{selectedEntry.entry.incident_date || '-'}</span>
								</div>
								<div class="field-group">
									<span class="field-label">Location</span>
									<span class="field-value">{selectedEntry.entry.incident_location || '-'}</span>
								</div>
							</div>
						{/if}
					</div>

					{#if !editMode}
						<div class="section">
							<div class="section-title">Title & Description</div>
							<p class="summary-text" style="font-weight:600;color:rgba(255,255,255,0.75);margin-bottom:4px;">{selectedEntry.entry.title}</p>
							<p class="summary-text">{selectedEntry.entry.description || 'No description provided.'}</p>
						</div>
					{/if}

					{#if selectedEntry.entry.linked_report_id || selectedEntry.entry.linked_case_id}
						<div class="section">
							<div class="section-title">Linked Records</div>
							<div class="field-row">
								{#if selectedEntry.entry.linked_report_id}
									<div class="field-group">
										<span class="field-label">Linked Report</span>
										<span class="field-value">Report #{selectedEntry.entry.linked_report_id}</span>
									</div>
								{/if}
								{#if selectedEntry.entry.linked_case_id}
									<div class="field-group">
										<span class="field-label">Linked Case</span>
										<span class="field-value">Case #{selectedEntry.entry.linked_case_id}</span>
									</div>
								{/if}
							</div>
						</div>
					{/if}
				</div>

				<!-- Right Column: Sidebar -->
				<div class="detail-side">
					{#if canManage}
						<div class="section">
							<div class="section-title">Actions</div>
							<div class="inline-controls">
								{#if !editMode}
									<button class="action-btn" onclick={() => { editMode = true; }}>Edit</button>
								{/if}
								<button class="action-btn danger" onclick={handleDeleteEntry}>Delete</button>
							</div>
						</div>
					{/if}

					<div class="section">
						<div class="section-title">Notes</div>
						{#if canManage}
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
						{/if}
						{#if selectedEntry.notes.length > 0}
							<div class="notes-list">
								{#each selectedEntry.notes as note}
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
	{:else if showCreateForm}
		<!-- ==================== CREATE FORM ==================== -->
		<div class="topbar">
			<button class="back-btn" onclick={() => { showCreateForm = false; resetCreateForm(); }}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
				Back to PPR List
			</button>
		</div>

		<div class="create-form">
			<h3>New Performance Review</h3>

			<div class="form-group">
				<span class="form-label">Officer</span>
				<button
					class="officer-search-trigger"
					class:placeholder={!newOfficerName}
					onclick={() => (showOfficerSearch = true)}
				>
					{newOfficerName || 'Click to search for an officer...'}
				</button>
			</div>

			<div class="form-row">
				<div class="form-group">
					<span class="form-label">Category</span>
					<select class="form-select" bind:value={newCategory}>
						<option value="positive">Positive</option>
						<option value="coaching">Coaching</option>
						<option value="disciplinary">Disciplinary</option>
					</select>
				</div>
				<div class="form-group">
					<span class="form-label">Incident Date</span>
					<input type="date" class="form-input" bind:value={newIncidentDate} />
				</div>
			</div>

			<div class="form-group">
				<span class="form-label">Title</span>
				<input type="text" class="form-input" bind:value={newTitle} placeholder="Enter title..." />
			</div>

			<div class="form-group">
				<span class="form-label">Description</span>
				<textarea class="form-textarea" rows="4" bind:value={newDescription} placeholder="Enter description..."></textarea>
			</div>

			<div class="form-group">
				<span class="form-label">Incident Location</span>
				<input type="text" class="form-input" bind:value={newIncidentLocation} placeholder="Enter location..." />
			</div>

			<div class="form-row">
				<div class="form-group">
					<span class="form-label">Linked Report # (optional)</span>
					<input type="number" class="form-input" bind:value={newLinkedReportId} placeholder="Report ID" />
				</div>
				<div class="form-group">
					<span class="form-label">Linked Case # (optional)</span>
					<input type="number" class="form-input" bind:value={newLinkedCaseId} placeholder="Case ID" />
				</div>
			</div>

			<div class="form-actions">
				<button class="action-btn" onclick={() => { showCreateForm = false; resetCreateForm(); }}>Cancel</button>
				<button class="primary-btn" onclick={handleCreatePPR} disabled={isSubmitting || !newTitle.trim() || !newOfficerCitizenId}>
					{isSubmitting ? 'Submitting...' : 'Submit'}
				</button>
			</div>
		</div>
	{:else}
		<!-- ==================== LIST VIEW ==================== -->
		<div class="topbar">
			<div class="filter-pills">
				{#each categoryOptions as opt}
					<button
						class="filter-pill"
						class:active={categoryFilter === opt}
						onclick={() => { categoryFilter = opt; }}
					>
						{opt === 'all' ? 'All' : formatLabel(opt)}
					</button>
				{/each}
			</div>
		</div>

		<div class="topbar">
			<div class="search-box">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.3)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
				<input type="text" placeholder="Search PPR entries..." bind:value={searchQuery} />
			</div>
			<div style="flex:1;"></div>
			{#if canManage}
				<button class="primary-btn" onclick={() => { showCreateForm = true; }}>
					<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
					New PPR
				</button>
			{/if}
			<button class="back-btn" onclick={loadEntries} disabled={loading}>
				<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/></svg>
				Refresh
			</button>
		</div>

		<div class="list-panel">
			{#if loading && entries.length === 0}
				<div class="center-state">
					<div class="loading-spinner"></div>
					<p>Loading PPR entries...</p>
				</div>
			{:else if paginatedEntries.length === 0}
				<div class="center-state">
					<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.2)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
					<h3>No PPR Entries Found</h3>
					<p>{searchQuery ? "No entries match your search criteria." : "No performance reviews have been created yet."}</p>
				</div>
			{:else}
				<div class="table-header">
					<span>#</span>
					<span>Officer</span>
					<span>Category</span>
					<span>Title</span>
					<span>Author</span>
					<span>Date</span>
				</div>
				<div class="table-body">
					{#each paginatedEntries as item}
						<button class="table-row" onclick={() => selectEntry(item.id)}>
							<span class="row-case">{item.ppr_number}</span>
							<span>{item.officer_name}</span>
							<span>
								<span class="pill {getCategoryPillClass(item.category)}">{formatLabel(item.category)}</span>
							</span>
							<span>{item.title}</span>
							<span>{item.author_name}</span>
							<span>{formatDateValue(item.created_at)}</span>
						</button>
					{/each}
				</div>
			{/if}
			<Pagination
				currentPage={page}
				totalItems={allFilteredEntries.length}
				perPage={perPage}
				onPageChange={(p) => { page = p; }}
				onPerPageChange={(pp) => { perPage = pp; page = 1; }}
			/>
		</div>
	{/if}
</div>

<PersonSearchModal
	show={showOfficerSearch}
	title="Search Officers"
	searchQuery={officerSearchQuery}
	searchResults={searchService.state.results}
	onClose={() => {
		showOfficerSearch = false;
		officerSearchQuery = "";
	}}
	onSearch={handleOfficerSearch}
	onSelect={handleSelectOfficer}
/>

<style>
	/* ===== PAGE ===== */
	.ppr-page {
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
		grid-template-columns: 1.2fr 1fr 0.8fr 1.5fr 1fr 0.8fr;
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
		grid-template-columns: 1.2fr 1fr 0.8fr 1.5fr 1fr 0.8fr;
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
