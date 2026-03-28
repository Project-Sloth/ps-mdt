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

	type CourtCaseStatus = "pending" | "scheduled" | "in_trial" | "closed" | "dismissed";
	type CaseType = "criminal" | "civil" | "appeal" | "motion";

	interface CourtCase {
		id: number;
		case_number: string;
		title: string;
		case_type: CaseType;
		defendant_name: string;
		defendant_citizenid: string;
		status: CourtCaseStatus;
		hearing_date?: string;
		filed_date: string;
		presiding_judge?: string;
		presiding_judge_name?: string;
		prosecutor?: string;
		prosecutor_name?: string;
		defense_attorney?: string;
		defense_attorney_name?: string;
		linked_reports: number[];
		notes?: string;
		created_at: string;
		updated_at?: string;
	}

	interface CourtCaseDetail {
		court_case: CourtCase;
		notes: string;
		linked_reports: { id: number; title: string }[];
	}

	let cases = $state<CourtCase[]>([]);
	let selectedCase = $state<CourtCaseDetail | null>(null);
	let isLoading = $state(false);
	let searchQuery = $state("");
	let statusFilter = $state<string>("all");
	let page = $state(1);
	let perPage = $state(25);
	let showCreateModal = $state(false);

	let newCase = $state({
		title: "",
		case_type: "criminal" as CaseType,
		defendant_citizenid: "",
		defendant_name: "",
	});

	let showDefendantSearch = $state(false);
	let defendantSearchResults = $state<SearchResult[]>([]);

	// Party search state (for detail view)
	let partySearchTarget = $state<"judge" | "prosecutor" | "defense" | null>(null);
	let partySearchResults = $state<SearchResult[]>([]);

	// Editable detail fields
	let editingHearingDate = $state("");

	// New document modal
	let showNewDocModal = $state(false);
	let newDocData = $state({ title: "", type: "brief" as string, content: "" });

	async function handleDefendantSearch(query: string) {
		if (query.length < 2) { defendantSearchResults = []; return; }
		const results = await fetchNui<any[]>(NUI_EVENTS.CITIZEN.SEARCH_CITIZENS, { query }, []);
		defendantSearchResults = (results || []).map((c: any) => ({
			id: c.citizenid || c.id,
			fullName: c.fullName || c.firstname + " " + c.lastname,
			citizenid: c.citizenid || c.id,
			image: c.profileImage || c.image,
		}));
	}

	function handleDefendantSelect(person: SearchResult) {
		newCase.defendant_citizenid = person.citizenid || person.id;
		newCase.defendant_name = person.fullName;
		showDefendantSearch = false;
		defendantSearchResults = [];
	}

	async function handlePartySearch(query: string) {
		if (query.length < 2) { partySearchResults = []; return; }
		const results = await fetchNui<any[]>(NUI_EVENTS.CITIZEN.SEARCH_CITIZENS, { query }, []);
		partySearchResults = (results || []).map((c: any) => ({
			id: c.citizenid || c.id,
			fullName: c.fullName || c.firstname + " " + c.lastname,
			citizenid: c.citizenid || c.id,
			image: c.profileImage || c.image,
		}));
	}

	function handlePartySelect(person: SearchResult) {
		if (!selectedCase || !partySearchTarget) return;
		const nameFields: Record<string, [string, string]> = {
			judge: ["presiding_judge", "presiding_judge_name"],
			prosecutor: ["prosecutor", "prosecutor_name"],
			defense: ["defense_attorney", "defense_attorney_name"],
		};
		const [idField, nameField] = nameFields[partySearchTarget];
		handleUpdateCase({ [idField]: person.citizenid || person.id, [nameField]: person.fullName });
		partySearchTarget = null;
		partySearchResults = [];
	}

	function clearParty(target: "judge" | "prosecutor" | "defense") {
		const nameFields: Record<string, [string, string]> = {
			judge: ["presiding_judge", "presiding_judge_name"],
			prosecutor: ["prosecutor", "prosecutor_name"],
			defense: ["defense_attorney", "defense_attorney_name"],
		};
		const [idField, nameField] = nameFields[target];
		handleUpdateCase({ [idField]: "", [nameField]: "" });
	}

	async function handleCreateDocument() {
		if (!newDocData.title.trim() || !selectedCase) return;
		try {
			const result = await fetchNui<{ success: boolean; error?: string }>(
				NUI_EVENTS.DOJ.CREATE_LEGAL_DOCUMENT,
				{
					type: newDocData.type,
					title: newDocData.title.trim(),
					court_case_id: selectedCase.court_case.id,
					content: newDocData.content.trim(),
				},
				{ success: true },
			);
			if (result.success) {
				showNewDocModal = false;
				newDocData = { title: "", type: "brief", content: "" };
				globalNotifications.success("Legal document created");
			} else {
				globalNotifications.error(result.error || "Failed to create document");
			}
		} catch {
			globalNotifications.error("Failed to create document");
		}
	}

	function saveHearingDate() {
		if (!editingHearingDate) {
			handleUpdateCase({ hearing_date: null });
		} else {
			handleUpdateCase({ hearing_date: editingHearingDate });
		}
	}

	const statusOptions = ["all", "pending", "scheduled", "in_trial", "closed", "dismissed"];

	function getStatusPillClass(status: string): string {
		switch (status) {
			case "pending": return "pill-yellow";
			case "scheduled": return "pill-blue";
			case "in_trial": return "pill-orange";
			case "closed": return "pill-grey";
			case "dismissed": return "pill-red";
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

	let allFilteredCases = $derived.by(() => {
		let filtered = cases;
		if (statusFilter !== "all") {
			filtered = filtered.filter((c) => c.status === statusFilter);
		}
		const query = searchQuery.trim().toLowerCase();
		if (query) {
			filtered = filtered.filter((c) =>
				[c.case_number, c.title, c.defendant_name]
					.filter(Boolean)
					.some((val) => String(val).toLowerCase().includes(query)),
			);
		}
		return filtered;
	});

	let paginatedCases = $derived.by(() => {
		const start = (page - 1) * perPage;
		return allFilteredCases.slice(start, start + perPage);
	});

	let mounted = false;

	$effect(() => {
		searchQuery;
		statusFilter;
		page = 1;
		if (mounted && !isEnvBrowser()) loadCases();
	});

	onMount(async () => {
		if (isEnvBrowser()) {
			cases = [
				{ id: 1, case_number: "CC-2026-00001", title: "State v. Marcus Johnson", case_type: "criminal", defendant_name: "Marcus Johnson", defendant_citizenid: "ABC123", status: "scheduled", hearing_date: new Date(Date.now() + 7 * 86400000).toISOString(), filed_date: "2026-03-10T10:00:00Z", presiding_judge_name: "Hon. Patricia Wells", prosecutor_name: "ADA Sarah Chen", defense_attorney_name: "James Wright, Esq.", linked_reports: [1, 3], notes: "", created_at: "2026-03-10T10:00:00Z" },
				{ id: 2, case_number: "CC-2026-00002", title: "State v. David Chen", case_type: "criminal", defendant_name: "David Chen", defendant_citizenid: "DEF456", status: "pending", filed_date: "2026-03-15T14:00:00Z", presiding_judge_name: undefined, prosecutor_name: "ADA Mike Torres", defense_attorney_name: undefined, linked_reports: [7], notes: "", created_at: "2026-03-15T14:00:00Z" },
				{ id: 3, case_number: "CC-2026-00003", title: "Garcia v. City of Los Santos", case_type: "civil", defendant_name: "City of Los Santos", defendant_citizenid: "CITY01", status: "in_trial", hearing_date: new Date(Date.now() + 2 * 86400000).toISOString(), filed_date: "2026-02-20T09:00:00Z", presiding_judge_name: "Hon. Robert Kim", prosecutor_name: undefined, defense_attorney_name: "City Attorney Office", linked_reports: [], notes: "", created_at: "2026-02-20T09:00:00Z" },
				{ id: 4, case_number: "CC-2026-00004", title: "State v. Tony Ramirez", case_type: "criminal", defendant_name: "Tony Ramirez", defendant_citizenid: "GHI789", status: "closed", filed_date: "2026-01-05T08:00:00Z", presiding_judge_name: "Hon. Patricia Wells", prosecutor_name: "ADA Sarah Chen", defense_attorney_name: "Public Defender Office", linked_reports: [12], notes: "Plea deal accepted.", created_at: "2026-01-05T08:00:00Z" },
				{ id: 5, case_number: "CC-2026-00005", title: "State v. Lisa Park", case_type: "motion", defendant_name: "Lisa Park", defendant_citizenid: "JKL012", status: "dismissed", filed_date: "2026-03-01T11:00:00Z", presiding_judge_name: "Hon. Robert Kim", prosecutor_name: "ADA Mike Torres", defense_attorney_name: "Angela Davis, Esq.", linked_reports: [], notes: "Dismissed for lack of evidence.", created_at: "2026-03-01T11:00:00Z" },
			];
			mounted = true;
			return;
		}
		await loadCases();
		mounted = true;
	});

	async function loadCases() {
		isLoading = true;
		try {
			const data = await fetchNui<{ cases: CourtCase[] }>(
				NUI_EVENTS.DOJ.GET_COURT_CASES,
				{ page, status: statusFilter === "all" ? "" : statusFilter, search: searchQuery.trim() || "" },
				{ cases: [] },
			);
			cases = data.cases || [];
		} catch {
			globalNotifications.error("Failed to load court cases");
		}
		isLoading = false;
	}

	async function selectCase(id: number) {
		isLoading = true;
		try {
			const response = await fetchNui<any>(
				NUI_EVENTS.DOJ.GET_COURT_CASE,
				{ id },
				cases.find((c) => c.id === id) || null,
			);
			if (response) {
				selectedCase = {
					court_case: response,
					notes: response.notes || "",
					linked_reports: [],
				};
				editingHearingDate = response.hearing_date ? response.hearing_date.slice(0, 16) : "";
			} else {
				selectedCase = null;
			}
		} catch {
			globalNotifications.error("Failed to load court case details");
		}
		isLoading = false;
	}

	function goBack() {
		selectedCase = null;
		if (!isEnvBrowser()) loadCases();
	}

	async function handleCreateCase() {
		if (!newCase.title.trim()) return;
		isLoading = true;
		try {
			const result = await fetchNui<{ success: boolean; id?: number; error?: string }>(
				NUI_EVENTS.DOJ.CREATE_COURT_CASE,
				{
					title: newCase.title.trim(),
					case_type: newCase.case_type,
					defendant_citizenid: newCase.defendant_citizenid.trim(),
					defendant_name: newCase.defendant_name.trim(),
				},
				{ success: true, id: Math.floor(Math.random() * 1000) },
			);
			if (result.success) {
				showCreateModal = false;
				newCase = { title: "", case_type: "criminal", defendant_citizenid: "", defendant_name: "" };
				globalNotifications.success("Court case created");
				await loadCases();
			} else {
				globalNotifications.error(result.error || "Failed to create court case");
			}
		} catch {
			globalNotifications.error("Failed to create court case");
		}
		isLoading = false;
	}

	async function handleUpdateCase(update: Record<string, unknown>) {
		if (!selectedCase) return;
		try {
			await fetchNui(
				NUI_EVENTS.DOJ.UPDATE_COURT_CASE,
				{ id: selectedCase.court_case.id, payload: update },
				{ success: true },
			);
			await selectCase(selectedCase.court_case.id);
			globalNotifications.success("Court case updated");
		} catch {
			globalNotifications.error("Failed to update court case");
		}
	}
</script>

<div class="page">
	{#if selectedCase}
		<!-- DETAIL VIEW -->
		<div class="topbar">
			<button class="back-btn" onclick={goBack}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
				Back to Cases
			</button>
			<span class="topbar-case-number">{selectedCase.court_case.case_number}</span>
			<span class="pill {getStatusPillClass(selectedCase.court_case.status)}">{formatLabel(selectedCase.court_case.status)}</span>
		</div>

		<div class="detail-scroll">
			<div class="detail-layout">
				<div class="detail-main">
					<div class="section">
						<div class="section-title">Case Information</div>
						<h3 class="case-title">{selectedCase.court_case.title}</h3>
						<div class="field-row">
							<div class="field-group">
								<span class="field-label">Case Number</span>
								<span class="field-value">{selectedCase.court_case.case_number}</span>
							</div>
							<div class="field-group">
								<span class="field-label">Case Type</span>
								<span class="field-value">{formatLabel(selectedCase.court_case.case_type)}</span>
							</div>
							<div class="field-group">
								<span class="field-label">Status</span>
								<span class="pill {getStatusPillClass(selectedCase.court_case.status)}">{formatLabel(selectedCase.court_case.status)}</span>
							</div>
							<div class="field-group">
								<span class="field-label">Filed Date</span>
								<span class="field-value">{formatDateValue(selectedCase.court_case.filed_date)}</span>
							</div>
						</div>
					</div>

					<div class="section">
						<div class="section-title">Defendant</div>
						<div class="field-row">
							<div class="field-group">
								<span class="field-label">Name</span>
								<span class="field-value">{selectedCase.court_case.defendant_name || "-"}</span>
							</div>
							<div class="field-group">
								<span class="field-label">Citizen ID</span>
								<span class="field-value mono">{selectedCase.court_case.defendant_citizenid || "-"}</span>
							</div>
						</div>
					</div>

					<div class="section">
						<div class="section-title">Hearing</div>
						<div class="field-row">
							<div class="field-group" style="flex:1;">
								<span class="field-label">Hearing Date</span>
								<div class="inline-edit-row">
									<input type="datetime-local" class="form-input" bind:value={editingHearingDate} />
									<button class="save-field-btn" onclick={saveHearingDate}>Save</button>
								</div>
							</div>
						</div>
					</div>

					<div class="section">
						<div class="section-header-row">
							<span class="section-title">Documents</span>
							<button class="add-btn" onclick={() => { newDocData = { title: `${selectedCase.court_case.case_number} - `, type: "brief", content: "" }; showNewDocModal = true; }}>+ Add</button>
						</div>
					</div>

					{#if selectedCase.linked_reports.length > 0}
						<div class="section">
							<div class="section-title">Linked Reports</div>
							<div class="linked-items">
								{#each selectedCase.linked_reports as report}
									<span class="linked-chip">#{report.id} - {report.title}</span>
								{/each}
							</div>
						</div>
					{/if}
				</div>

				<div class="detail-side">
					<div class="section">
						<div class="section-title">Update Status</div>
						<select class="form-select" value={selectedCase.court_case.status} onchange={(e) => handleUpdateCase({ status: (e.target as HTMLSelectElement).value })}>
							{#each statusOptions.filter((s) => s !== "all") as opt}
								<option value={opt}>{formatLabel(opt)}</option>
							{/each}
						</select>
					</div>

					<div class="section">
						<div class="section-header-row">
							<span class="section-title">Judge</span>
							{#if selectedCase.court_case.presiding_judge_name}
								<button class="add-btn" onclick={() => clearParty("judge")}>x Remove</button>
							{:else}
								<button class="add-btn" onclick={() => (partySearchTarget = "judge")}>+ Add</button>
							{/if}
						</div>
						{#if selectedCase.court_case.presiding_judge_name}
							<span class="party-name">{selectedCase.court_case.presiding_judge_name}</span>
						{/if}
					</div>
					<div class="section">
						<div class="section-header-row">
							<span class="section-title">Prosecutor</span>
							{#if selectedCase.court_case.prosecutor_name}
								<button class="add-btn" onclick={() => clearParty("prosecutor")}>x Remove</button>
							{:else}
								<button class="add-btn" onclick={() => (partySearchTarget = "prosecutor")}>+ Add</button>
							{/if}
						</div>
						{#if selectedCase.court_case.prosecutor_name}
							<span class="party-name">{selectedCase.court_case.prosecutor_name}</span>
						{/if}
					</div>
					<div class="section">
						<div class="section-header-row">
							<span class="section-title">Defense</span>
							{#if selectedCase.court_case.defense_attorney_name}
								<button class="add-btn" onclick={() => clearParty("defense")}>x Remove</button>
							{:else}
								<button class="add-btn" onclick={() => (partySearchTarget = "defense")}>+ Add</button>
							{/if}
						</div>
						{#if selectedCase.court_case.defense_attorney_name}
							<span class="party-name">{selectedCase.court_case.defense_attorney_name}</span>
						{/if}
					</div>
				</div>
			</div>
		</div>
	{:else}
		<!-- LIST VIEW -->
		<div class="topbar">
			<div class="search-box">
				<input type="text" placeholder="Search cases..." bind:value={searchQuery} />
			</div>
			<div class="filter-pills">
				{#each statusOptions as opt}
					<button class="filter-pill" class:active={statusFilter === opt} onclick={() => (statusFilter = opt)}>
						{formatLabel(opt)}
					</button>
				{/each}
			</div>
			<div class="topbar-actions">
				<span class="result-count">{allFilteredCases.length} case{allFilteredCases.length !== 1 ? "s" : ""}</span>
				<button class="action-btn" onclick={loadCases} disabled={isLoading}>{isLoading ? "Loading..." : "Refresh"}</button>
				<button class="primary-btn" onclick={() => (showCreateModal = true)}>New Court Case</button>
			</div>
		</div>

		<div class="list-panel">
			{#if isLoading && cases.length === 0}
				<div class="center-state">
					<div class="loading-spinner"></div>
					<p>Loading court cases...</p>
				</div>
			{:else if allFilteredCases.length === 0}
				<div class="center-state">
					<h3>No Court Cases Found</h3>
					<p>{searchQuery ? "No cases match your search criteria." : "No court cases available."}</p>
				</div>
			{:else}
				<div class="table-header">
					<span>Case #</span>
					<span>Title</span>
					<span>Defendant</span>
					<span>Type</span>
					<span>Status</span>
					<span>Hearing</span>
					<span>Filed</span>
				</div>
				<div class="table-body">
					{#each paginatedCases as item}
						<button class="table-row" onclick={() => selectCase(item.id)}>
							<span class="row-case">{item.case_number}</span>
							<span class="row-title">{item.title}</span>
							<span>{item.defendant_name}</span>
							<span>{formatLabel(item.case_type)}</span>
							<span><span class="pill {getStatusPillClass(item.status)}">{formatLabel(item.status)}</span></span>
							<span>{formatDateValue(item.hearing_date)}</span>
							<span>{formatDateValue(item.filed_date)}</span>
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
				<span class="modal-title">New Court Case</span>
				<button class="modal-close" onclick={() => (showCreateModal = false)}>
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
				</button>
			</div>
			<div class="modal-body">
				<div class="form-group">
					<label class="form-label">Title</label>
					<input type="text" class="form-input" placeholder="e.g. State v. John Doe" bind:value={newCase.title} />
				</div>
				<div class="form-group">
					<label class="form-label">Case Type</label>
					<select class="form-select" bind:value={newCase.case_type}>
						<option value="criminal">Criminal</option>
						<option value="civil">Civil</option>
						<option value="appeal">Appeal</option>
						<option value="motion">Motion</option>
					</select>
				</div>
				<div class="form-group">
					<label class="form-label">Defendant</label>
					{#if newCase.defendant_citizenid}
						<div class="selected-citizen">
							<span class="citizen-name">{newCase.defendant_name}</span>
							<span class="citizen-id">({newCase.defendant_citizenid})</span>
							<button type="button" class="remove-citizen-btn" onclick={() => { newCase.defendant_citizenid = ""; newCase.defendant_name = ""; }}>x</button>
						</div>
					{:else}
						<button type="button" class="form-input search-citizen-btn" onclick={() => (showDefendantSearch = true)}>Search citizen...</button>
					{/if}
				</div>
				</div>
			<div class="modal-footer">
				<button class="back-btn" onclick={() => (showCreateModal = false)}>Cancel</button>
				<button class="primary-btn" disabled={!newCase.title.trim()} onclick={handleCreateCase}>Create Case</button>
			</div>
		</div>
	</div>
{/if}

<PersonSearchModal
	show={showDefendantSearch}
	title="Search Defendant"
	searchResults={defendantSearchResults}
	onClose={() => { showDefendantSearch = false; defendantSearchResults = []; }}
	onSearch={handleDefendantSearch}
	onSelect={handleDefendantSelect}
/>

<PersonSearchModal
	show={partySearchTarget !== null}
	title={partySearchTarget === "judge" ? "Search Judge" : partySearchTarget === "prosecutor" ? "Search Prosecutor" : "Search Defense Attorney"}
	searchResults={partySearchResults}
	onClose={() => { partySearchTarget = null; partySearchResults = []; }}
	onSearch={handlePartySearch}
	onSelect={handlePartySelect}
/>

{#if showNewDocModal}
<div class="modal-backdrop" onclick={() => (showNewDocModal = false)} role="presentation">
	<div class="modal" onclick={(e) => e.stopPropagation()} role="dialog">
		<div class="modal-header">
			<span class="modal-title">New Legal Document</span>
			<button class="modal-close" onclick={() => (showNewDocModal = false)}>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
			</button>
		</div>
		<div class="modal-body">
			<div class="form-group">
				<label class="form-label">Title</label>
				<input type="text" class="form-input" bind:value={newDocData.title} />
			</div>
			<div class="form-group">
				<label class="form-label">Type</label>
				<select class="form-select" bind:value={newDocData.type}>
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
				<label class="form-label">Content</label>
				<textarea class="form-textarea" rows="6" placeholder="Document content..." bind:value={newDocData.content}></textarea>
			</div>
		</div>
		<div class="modal-footer">
			<button class="back-btn" onclick={() => (showNewDocModal = false)}>Cancel</button>
			<button class="primary-btn" disabled={!newDocData.title.trim()} onclick={handleCreateDocument}>Create Document</button>
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
		grid-template-columns: 1.2fr 2fr 1.2fr 0.8fr 0.8fr 0.8fr 0.8fr;
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
		grid-template-columns: 1.2fr 2fr 1.2fr 0.8fr 0.8fr 0.8fr 0.8fr;
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

	.case-title {
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

	.linked-items {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.linked-chip {
		color: rgba(var(--accent-text-rgb), 0.7);
		font-size: 11px;
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
		width: 440px;
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

	.selected-citizen.compact {
		height: 28px;
		font-size: 11px;
	}

	.inline-edit-row {
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.inline-edit-row .form-input {
		flex: 1;
	}

	.section-header-row { display: flex; justify-content: space-between; align-items: center; }
	.section-header-row .section-title { margin-bottom: 0; }
	.add-btn { background: transparent; border: none; color: rgba(255,255,255,0.35); cursor: pointer; font-size: 10px; font-weight: 500; padding: 2px 6px; transition: color 0.1s; }
	.add-btn:hover { color: rgba(255,255,255,0.5); }

	.party-name {
		color: rgba(255, 255, 255, 0.75);
		font-size: 11px;
	}

	.save-field-btn {
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

	.save-field-btn:hover {
		background: rgba(var(--accent-rgb), 0.14);
	}
</style>
