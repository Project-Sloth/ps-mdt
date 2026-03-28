<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../../utils/fetchNui";
	import { isEnvBrowser } from "../../utils/misc";
	import { NUI_EVENTS } from "../../constants/nuiEvents";
	import { globalNotifications } from "../../services/notificationService.svelte";
	import type { createTabService } from "../../services/tabService.svelte";
	import type { AuthService } from "../../services/authService.svelte";

	interface Props {
		tabService: ReturnType<typeof createTabService>;
		authService: AuthService;
	}

	let { tabService, authService }: Props = $props();

	type DocType = "brief" | "motion" | "ruling" | "opinion" | "plea_deal" | "sentencing" | "other";
	type DocStatus = "draft" | "filed" | "approved" | "rejected";

	interface LegalDocument {
		id: number;
		title: string;
		type: DocType;
		status: DocStatus;
		content: string;
		author_name: string;
		author_citizenid: string;
		linked_court_case_id?: number;
		linked_court_case_number?: string;
		created_at: string;
		updated_at?: string;
	}

	let documents = $state<LegalDocument[]>([]);
	let selectedDocument = $state<LegalDocument | null>(null);
	let isLoading = $state(false);
	let searchQuery = $state("");
	let typeFilter = $state<string>("all");
	let statusFilter = $state<string>("all");
	let showCreateModal = $state(false);
	let editContent = $state("");

	let newDoc = $state({
		type: "brief" as DocType,
		title: "",
		linked_court_case_id: "",
		content: "",
	});

	const typeOptions: { value: string; label: string }[] = [
		{ value: "all", label: "All Types" },
		{ value: "brief", label: "Brief" },
		{ value: "motion", label: "Motion" },
		{ value: "ruling", label: "Ruling" },
		{ value: "opinion", label: "Opinion" },
		{ value: "plea_deal", label: "Plea Deal" },
		{ value: "sentencing", label: "Sentencing" },
		{ value: "other", label: "Other" },
	];

	const statusOptions = ["all", "draft", "filed", "approved", "rejected"];

	function getStatusPillClass(status: string): string {
		switch (status) {
			case "draft": return "pill-grey";
			case "filed": return "pill-blue";
			case "approved": return "pill-green";
			case "rejected": return "pill-red";
			default: return "pill-grey";
		}
	}

	function getTypePillClass(type: string): string {
		switch (type) {
			case "brief": return "pill-blue";
			case "motion": return "pill-orange";
			case "ruling": return "pill-green";
			case "opinion": return "pill-yellow";
			case "plea_deal": return "pill-yellow";
			case "sentencing": return "pill-red";
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

	let allFilteredDocs = $derived.by(() => {
		let filtered = documents;
		if (statusFilter !== "all") {
			filtered = filtered.filter((d) => d.status === statusFilter);
		}
		if (typeFilter !== "all") {
			filtered = filtered.filter((d) => d.type === typeFilter);
		}
		const query = searchQuery.trim().toLowerCase();
		if (query) {
			filtered = filtered.filter((d) =>
				[d.title, d.author_name, d.type, d.linked_court_case_number]
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
		if (mounted && !isEnvBrowser()) loadDocuments();
	});

	onMount(async () => {
		if (isEnvBrowser()) {
			documents = [
				{ id: 1, title: "Prosecution Brief - State v. Johnson", type: "brief", status: "filed", content: "This brief outlines the prosecution's case against Marcus Johnson for armed robbery...", author_name: "ADA Sarah Chen", author_citizenid: "PROS01", linked_court_case_id: 1, linked_court_case_number: "CC-2026-00001", created_at: "2026-03-12T10:00:00Z" },
				{ id: 2, title: "Motion to Dismiss - State v. Park", type: "motion", status: "approved", content: "Defense moves to dismiss all charges due to insufficient evidence...", author_name: "Angela Davis, Esq.", author_citizenid: "DEF01", linked_court_case_id: 5, linked_court_case_number: "CC-2026-00005", created_at: "2026-03-05T14:00:00Z" },
				{ id: 3, title: "Ruling on Motion to Suppress", type: "ruling", status: "approved", content: "The court rules that evidence obtained during the search is admissible...", author_name: "Hon. Patricia Wells", author_citizenid: "JUD01", linked_court_case_id: 1, linked_court_case_number: "CC-2026-00001", created_at: "2026-03-15T09:00:00Z" },
				{ id: 4, title: "Plea Agreement - State v. Ramirez", type: "plea_deal", status: "filed", content: "Defendant agrees to plead guilty to reduced charges in exchange for...", author_name: "ADA Mike Torres", author_citizenid: "PROS02", linked_court_case_id: 4, linked_court_case_number: "CC-2026-00004", created_at: "2026-03-08T11:00:00Z" },
				{ id: 5, title: "Sentencing Memorandum - Chen", type: "sentencing", status: "draft", content: "The prosecution recommends the following sentence...", author_name: "ADA Sarah Chen", author_citizenid: "PROS01", linked_court_case_id: 2, linked_court_case_number: "CC-2026-00002", created_at: "2026-03-18T16:00:00Z" },
				{ id: 6, title: "Judicial Opinion on Bail Reform", type: "opinion", status: "draft", content: "This opinion addresses the recent changes to bail conditions...", author_name: "Hon. Robert Kim", author_citizenid: "JUD02", created_at: "2026-03-20T08:00:00Z" },
			];
			mounted = true;
			return;
		}
		await loadDocuments();
		mounted = true;
	});

	async function loadDocuments() {
		isLoading = true;
		try {
			const data = await fetchNui<{ documents: LegalDocument[] }>(
				NUI_EVENTS.DOJ.GET_LEGAL_DOCUMENTS,
				{ status: statusFilter === "all" ? "" : statusFilter, type: typeFilter === "all" ? "" : typeFilter, search: searchQuery.trim() || "" },
				{ documents: [] },
			);
			documents = data.documents || [];
		} catch {
			globalNotifications.error("Failed to load legal documents");
		}
		isLoading = false;
	}

	async function selectDocument(id: number) {
		isLoading = true;
		try {
			const response = await fetchNui<{ success: boolean; data?: LegalDocument }>(
				NUI_EVENTS.DOJ.GET_LEGAL_DOCUMENT,
				{ id },
				{ success: true, data: documents.find((d) => d.id === id) },
			);
			selectedDocument = response?.data || documents.find((d) => d.id === id) || null;
			editContent = selectedDocument?.content || "";
		} catch {
			globalNotifications.error("Failed to load document");
		}
		isLoading = false;
	}

	function goBack() {
		selectedDocument = null;
		editContent = "";
		if (!isEnvBrowser()) loadDocuments();
	}

	async function handleCreateDocument() {
		if (!newDoc.title.trim()) return;
		isLoading = true;
		try {
			const result = await fetchNui<{ success: boolean; id?: number; error?: string }>(
				NUI_EVENTS.DOJ.CREATE_LEGAL_DOCUMENT,
				{
					type: newDoc.type,
					title: newDoc.title.trim(),
					linked_court_case_id: newDoc.linked_court_case_id ? Number(newDoc.linked_court_case_id) : undefined,
					content: newDoc.content.trim(),
				},
				{ success: true, id: Math.floor(Math.random() * 1000) },
			);
			if (result.success) {
				showCreateModal = false;
				newDoc = { type: "brief", title: "", linked_court_case_id: "", content: "" };
				globalNotifications.success("Legal document created");
				await loadDocuments();
			} else {
				globalNotifications.error(result.error || "Failed to create document");
			}
		} catch {
			globalNotifications.error("Failed to create document");
		}
		isLoading = false;
	}

	async function handleSaveContent() {
		if (!selectedDocument) return;
		try {
			await fetchNui(
				NUI_EVENTS.DOJ.UPDATE_LEGAL_DOCUMENT,
				{ id: selectedDocument.id, content: editContent },
				{ success: true },
			);
			selectedDocument.content = editContent;
			globalNotifications.success("Document saved");
		} catch {
			globalNotifications.error("Failed to save document");
		}
	}

	async function handleUpdateStatus(newStatus: DocStatus) {
		if (!selectedDocument) return;
		try {
			await fetchNui(
				NUI_EVENTS.DOJ.UPDATE_LEGAL_DOCUMENT,
				{ id: selectedDocument.id, status: newStatus },
				{ success: true },
			);
			selectedDocument.status = newStatus;
			globalNotifications.success("Status updated");
		} catch {
			globalNotifications.error("Failed to update status");
		}
	}

	async function handleDeleteDocument() {
		if (!selectedDocument) return;
		try {
			const result = await fetchNui<{ success: boolean; error?: string }>(
				NUI_EVENTS.DOJ.DELETE_LEGAL_DOCUMENT,
				{ id: selectedDocument.id },
				{ success: true },
			);
			if (result.success) {
				globalNotifications.success("Document deleted");
				goBack();
				await loadDocuments();
			} else {
				globalNotifications.error(result.error || "Failed to delete document");
			}
		} catch {
			globalNotifications.error("Failed to delete document");
		}
	}
</script>

<div class="page">
	{#if selectedDocument}
		<!-- DETAIL / EDITOR VIEW -->
		<div class="topbar">
			<button class="back-btn" onclick={goBack}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
				Back to Documents
			</button>
			<span class="pill {getTypePillClass(selectedDocument.type)}">{formatLabel(selectedDocument.type)}</span>
			<span class="pill {getStatusPillClass(selectedDocument.status)}">{formatLabel(selectedDocument.status)}</span>
			<div class="topbar-actions">
				<button class="action-btn" onclick={handleSaveContent} disabled={isLoading}>Save</button>
			</div>
		</div>

		<div class="detail-scroll">
			<div class="detail-layout">
				<div class="detail-main">
					<div class="section">
						<div class="section-title">Document Information</div>
						<h3 class="doc-title">{selectedDocument.title}</h3>
						<div class="field-row">
							<div class="field-group">
								<span class="field-label">Author</span>
								<span class="field-value">{selectedDocument.author_name}</span>
							</div>
							<div class="field-group">
								<span class="field-label">Created</span>
								<span class="field-value">{formatDateValue(selectedDocument.created_at)}</span>
							</div>
							{#if selectedDocument.linked_court_case_number}
								<div class="field-group">
									<span class="field-label">Court Case</span>
									<span class="field-value link">{selectedDocument.linked_court_case_number}</span>
								</div>
							{/if}
						</div>
					</div>

					<div class="section editor-section">
						<div class="section-title">Content</div>
						<textarea class="editor-textarea" bind:value={editContent} placeholder="Document content..."></textarea>
					</div>
				</div>

				<div class="detail-side">
					<div class="section">
						<div class="section-title">Status</div>
						<select class="form-select" value={selectedDocument.status} onchange={(e) => handleUpdateStatus((e.target as HTMLSelectElement).value as DocStatus)}>
							<option value="draft">Draft</option>
							<option value="filed">Filed</option>
							<option value="approved">Approved</option>
							<option value="rejected">Rejected</option>
						</select>
					</div>

					<div class="section">
						<div class="section-title">Actions</div>
						<button class="danger-btn" onclick={handleDeleteDocument} disabled={isLoading}>
							Delete Document
						</button>
					</div>
				</div>
			</div>
		</div>
	{:else}
		<!-- LIST VIEW -->
		<div class="topbar">
			<div class="search-box">
				<input type="text" placeholder="Search documents..." bind:value={searchQuery} />
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
				<span class="result-count">{allFilteredDocs.length} document{allFilteredDocs.length !== 1 ? "s" : ""}</span>
				<button class="action-btn" onclick={loadDocuments} disabled={isLoading}>{isLoading ? "Loading..." : "Refresh"}</button>
				<button class="primary-btn" onclick={() => (showCreateModal = true)}>New Document</button>
			</div>
		</div>

		<div class="list-panel">
			{#if isLoading && documents.length === 0}
				<div class="center-state">
					<div class="loading-spinner"></div>
					<p>Loading legal documents...</p>
				</div>
			{:else if allFilteredDocs.length === 0}
				<div class="center-state">
					<h3>No Legal Documents Found</h3>
					<p>{searchQuery ? "No documents match your search criteria." : "No legal documents available."}</p>
				</div>
			{:else}
				<div class="table-header">
					<span>Title</span>
					<span>Type</span>
					<span>Status</span>
					<span>Author</span>
					<span>Court Case</span>
					<span>Date</span>
				</div>
				<div class="table-body">
					{#each allFilteredDocs as item}
						<button class="table-row" onclick={() => selectDocument(item.id)}>
							<span class="row-title">{item.title}</span>
							<span><span class="pill {getTypePillClass(item.type)}">{formatLabel(item.type)}</span></span>
							<span><span class="pill {getStatusPillClass(item.status)}">{formatLabel(item.status)}</span></span>
							<span>{item.author_name}</span>
							<span class="row-case">{item.linked_court_case_number || "-"}</span>
							<span>{formatDateValue(item.created_at)}</span>
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
				<span class="modal-title">New Legal Document</span>
				<button class="modal-close" onclick={() => (showCreateModal = false)}>
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
				</button>
			</div>
			<div class="modal-body">
				<div class="form-group">
					<label class="form-label">Type</label>
					<select class="form-select" bind:value={newDoc.type}>
						<option value="brief">Brief</option>
						<option value="motion">Motion</option>
						<option value="ruling">Ruling</option>
						<option value="opinion">Opinion</option>
						<option value="plea_deal">Plea Deal</option>
						<option value="sentencing">Sentencing</option>
						<option value="other">Other</option>
					</select>
				</div>
				<div class="form-group">
					<label class="form-label">Title</label>
					<input type="text" class="form-input" placeholder="Document title..." bind:value={newDoc.title} />
				</div>
				<div class="form-group">
					<label class="form-label">Link to Court Case (optional, ID)</label>
					<input type="text" class="form-input" placeholder="Court case ID" bind:value={newDoc.linked_court_case_id} />
				</div>
				<div class="form-group">
					<label class="form-label">Content</label>
					<textarea class="form-textarea" style="min-height: 120px;" placeholder="Document content..." bind:value={newDoc.content}></textarea>
				</div>
			</div>
			<div class="modal-footer">
				<button class="back-btn" onclick={() => (showCreateModal = false)}>Cancel</button>
				<button class="primary-btn" disabled={!newDoc.title.trim()} onclick={handleCreateDocument}>Create Document</button>
			</div>
		</div>
	</div>
{/if}

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
		background: rgba(var(--accent-rgb), 0.06);
		color: rgba(var(--accent-text-rgb), 0.7);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		border-radius: 3px;
		padding: 4px 10px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.action-btn:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
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
		grid-template-columns: 2.5fr 0.8fr 0.7fr 1fr 1fr 0.8fr;
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
		grid-template-columns: 2.5fr 0.8fr 0.7fr 1fr 1fr 0.8fr;
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

	.row-title {
		color: rgba(255, 255, 255, 0.75) !important;
		font-weight: 500;
	}

	.row-case {
		color: rgba(96, 165, 250, 0.7) !important;
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

	.editor-section {
		flex: 1;
	}

	.section-title {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		margin-bottom: 2px;
	}

	.doc-title {
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

	.field-value.link {
		color: rgba(96, 165, 250, 0.7);
		font-weight: 500;
	}

	.editor-textarea {
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 4px;
		padding: 10px 12px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 12px;
		font-family: inherit;
		line-height: 1.6;
		outline: none;
		resize: vertical;
		width: 100%;
		box-sizing: border-box;
		min-height: 300px;
	}

	.editor-textarea:focus {
		border-color: rgba(var(--accent-rgb), 0.3);
	}

	.editor-textarea::placeholder {
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
</style>
