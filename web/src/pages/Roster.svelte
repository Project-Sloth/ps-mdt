<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { useNuiEvent } from "../utils/useNuiEvent";
	import { debugData } from "../utils/debugData";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { globalNotifications } from "../services/notificationService.svelte";
	import type { AuthService } from "../services/authService.svelte";

	let { authService, tabService }: { authService?: AuthService; tabService?: any } = $props();

	interface Officer {
		id: string;
		callsign: string;
		firstName: string;
		lastName: string;
		rank: string;
		department?: string;
		status: "On Duty" | "Off Duty";
		certifications: string[];
		badgeNumber: string;
		citizenid?: string;
		radioChannel?: number;
	}

	interface ActiveUnit {
		id: string;
		badgeNumber: string;
		firstName: string;
		lastName: string;
		callsign: string;
	}

	interface OfficerTag {
		id: number;
		name: string;
		color: string;
	}

	interface JobGrade {
		grade: number;
		name: string;
		isBoss: boolean;
	}

	let officers = $state<Officer[]>([]);
	let activeUnits = $state<ActiveUnit[]>([]);
	let isLoading = $state(false);
	let searchQuery = $state("");
	let sortColumn = $state<string>("");
	let sortDirection = $state<"asc" | "desc">("asc");

	// Certification modal state
	let selectedOfficer = $state<Officer | null>(null);
	let availableTags = $state<OfficerTag[]>([]);
	let selectedCerts = $state<string[]>([]);
	let isSavingCerts = $state(false);
	let showCertModal = $state(false);

	// Boss panel state
	let showBossPanel = $state(false);
	let bossPanelTab = $state<"rank" | "callsign" | "certs" | "ppr" | "fto" | "ia_history">("rank");
	let iaHistory = $state<Array<{ id: number; complaint_number: string; category: string; status: string; created_at: string }>>([]);
	let iaHistoryLoading = $state(false);
	let pprHistory = $state<Array<{ id: number; ppr_number: string; category: string; title: string; author_name: string; incident_date?: string; created_at: string }>>([]);
	let pprHistoryLoading = $state(false);
	let ftoHistory = $state<Array<{ id: number; fto_number: string; status: string; trainer_name: string; trainee_name: string; phase_name?: string; start_date?: string; dor_count?: number; latest_rating?: number; created_at: string }>>([]);
	let ftoHistoryLoading = $state(false);
	let jobGrades = $state<JobGrade[]>([]);
	let selectedGrade = $state<number | null>(null);
	let editCallsign = $state("");
	let isSavingBoss = $state(false);
	let showFireConfirm = $state(false);

	let canManageCerts = $derived(authService?.hasPermission("roster_manage_certifications") ?? false);
	let canManageOfficers = $derived(authService?.hasPermission("roster_manage_officers") ?? false);
	let canOpenPanel = $derived(canManageCerts || canManageOfficers);

	let filteredOfficers = $derived.by(() => {
		const query = searchQuery.trim().toLowerCase();
		let filtered = !query
			? officers
			: officers.filter(({ callsign, firstName, lastName, rank }) =>
					[callsign, firstName, lastName, rank].some((val) =>
						val.toLowerCase().includes(query),
					),
				);

		if (sortColumn) {
			filtered = [...filtered].sort((a, b) => {
				let aVal: string | number = "";
				let bVal: string | number = "";

				switch (sortColumn) {
					case "name":
						aVal = `${a.firstName} ${a.lastName}`;
						bVal = `${b.firstName} ${b.lastName}`;
						break;
					case "callsign":
						aVal = a.callsign;
						bVal = b.callsign;
						break;
					case "rank":
						aVal = a.rank;
						bVal = b.rank;
						break;
					case "status":
						aVal = a.status;
						bVal = b.status;
						break;
				}

				if (typeof aVal === "string" && typeof bVal === "string") {
					const result = aVal.localeCompare(bVal);
					return sortDirection === "asc" ? result : -result;
				}
				return 0;
			});
		}

		return filtered;
	});

	onMount(() => {
		if (isEnvBrowser()) {
			officers = [
				{
					id: "1",
					callsign: "401",
					firstName: "John",
					lastName: "Smith",
					rank: "Chief of Police",
					department: "lspd",
					status: "On Duty",
					certifications: ["FTO", "SWAT", "Interceptor"],
					badgeNumber: "1001",
					citizenid: "ABC12345",
					radioChannel: 1,
				},
				{
					id: "2",
					callsign: "455",
					firstName: "Jane",
					lastName: "Doe",
					rank: "Lieutenant",
					department: "lspd",
					status: "On Duty",
					certifications: ["Air Certified", "FTO"],
					badgeNumber: "1002",
					citizenid: "DEF67890",
					radioChannel: 1,
				},
				{
					id: "3",
					callsign: "474",
					firstName: "Mike",
					lastName: "Johnson",
					rank: "Sergeant",
					department: "bcso",
					status: "Off Duty",
					certifications: ["SWAT"],
					badgeNumber: "1003",
					citizenid: "GHI11111",
					radioChannel: 0,
				},
				{
					id: "4",
					callsign: "402",
					firstName: "Sarah",
					lastName: "Wilson",
					rank: "Officer",
					department: "lspd",
					status: "On Duty",
					certifications: [],
					badgeNumber: "1004",
					citizenid: "JKL22222",
					radioChannel: 2,
				},
				{
					id: "5",
					callsign: "472",
					firstName: "David",
					lastName: "Brown",
					rank: "Detective",
					department: "sahp",
					status: "Off Duty",
					certifications: ["FTO"],
					badgeNumber: "1005",
					citizenid: "MNO33333",
					radioChannel: 0,
				},
			];

			activeUnits = [
				{ id: "1", badgeNumber: "1001", firstName: "John", lastName: "Smith", callsign: "401" },
				{ id: "2", badgeNumber: "1002", firstName: "Jane", lastName: "Doe", callsign: "455" },
				{ id: "4", badgeNumber: "1004", firstName: "Sarah", lastName: "Wilson", callsign: "402" },
			];

			availableTags = [
				{ id: 1, name: "SWAT", color: "#3b82f6" },
				{ id: 2, name: "FTO", color: "#10b981" },
				{ id: 3, name: "Detective", color: "#8b5cf6" },
				{ id: 4, name: "K9 Certified", color: "#06b6d4" },
				{ id: 5, name: "Air Certified", color: "#ec4899" },
				{ id: 6, name: "Command", color: "#ef4444" },
			];
		} else {
			loadRoster();
			loadOfficerTags();
		}
	});

	useNuiEvent<Officer[]>(NUI_EVENTS.ROSTER.GET_ROSTER, (data: Officer[]) => {
		officers = Array.isArray(data) ? data : [];
	});

	useNuiEvent<ActiveUnit[]>(
		NUI_EVENTS.ROSTER.GET_ACTIVE_UNITS,
		(data: ActiveUnit[]) => {
			activeUnits = Array.isArray(data) ? data : [];
		},
	);

	async function loadRoster() {
		try {
			isLoading = true;
			const response = await fetchNui(NUI_EVENTS.ROSTER.GET_ROSTER);
			officers = Array.isArray(response.roster) ? response.roster : [];
			activeUnits = Array.isArray(response.activeUnits)
				? response.activeUnits
				: [];
		} catch (error) {
			globalNotifications.error("Failed to load roster");
			officers = [];
		} finally {
			isLoading = false;
		}
	}

	async function loadOfficerTags() {
		if (isEnvBrowser()) return;
		try {
			const tags = await fetchNui(NUI_EVENTS.ROSTER.GET_OFFICER_TAGS);
			availableTags = Array.isArray(tags) ? tags : [];
		} catch {
			availableTags = [];
		}
	}

	async function loadJobGrades(department: string) {
		if (isEnvBrowser()) {
			// Dev mock: derive grades from the officer mock data ranks
			const uniqueRanks = [...new Set(officers.map((o) => o.rank))];
			jobGrades = uniqueRanks.map((name, i) => ({
				grade: i,
				name,
				isBoss: i === uniqueRanks.length - 1,
			}));
			return;
		}
		try {
			const grades = await fetchNui<JobGrade[]>(NUI_EVENTS.ROSTER.GET_JOB_GRADES, { job: department });
			jobGrades = Array.isArray(grades) ? grades : [];
		} catch {
			jobGrades = [];
		}
	}

	function handleSort(column: string) {
		if (sortColumn === column) {
			sortDirection = sortDirection === "asc" ? "desc" : "asc";
		} else {
			sortColumn = column;
			sortDirection = "asc";
		}
	}

	function getSortIndicator(column: string): string {
		if (sortColumn !== column) return "";
		return sortDirection === "asc" ? " ↑" : " ↓";
	}

	function refreshData() {
		if (!isEnvBrowser()) {
			loadRoster();
		}
	}

	async function openOfficerPanel(officer: Officer) {
		if (!canOpenPanel) return;

		selectedOfficer = officer;
		selectedCerts = [...(officer.certifications || [])];
		editCallsign = officer.callsign || "";
		selectedGrade = null;
		showFireConfirm = false;

		if (canManageOfficers) {
			// Open boss panel with all tabs
			bossPanelTab = "rank";
			await Promise.all([
				loadOfficerTags(),
				loadJobGrades(officer.department || "police"),
			]);
			showBossPanel = true;
		} else {
			// Fall back to cert-only modal
			await loadOfficerTags();
			showCertModal = true;
		}
	}

	function closeBossPanel() {
		showBossPanel = false;
		showFireConfirm = false;
		selectedOfficer = null;
		selectedCerts = [];
		editCallsign = "";
		selectedGrade = null;
		jobGrades = [];
	}

	function closeCertModal() {
		showCertModal = false;
		selectedOfficer = null;
		selectedCerts = [];
	}

	function toggleCert(tagName: string) {
		if (selectedCerts.includes(tagName)) {
			selectedCerts = selectedCerts.filter((c) => c !== tagName);
		} else {
			selectedCerts = [...selectedCerts, tagName];
		}
	}

	async function saveCertifications() {
		if (!selectedOfficer?.citizenid) return;
		isSavingCerts = true;
		try {
			const response = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.ROSTER.UPDATE_OFFICER_CERTIFICATIONS,
				{
					citizenid: selectedOfficer.citizenid,
					certifications: selectedCerts,
				},
			);
			if (response?.success) {
				const idx = officers.findIndex((o) => o.citizenid === selectedOfficer!.citizenid);
				if (idx !== -1) {
					officers[idx].certifications = [...selectedCerts];
				}
				globalNotifications.success(`Updated certifications for ${selectedOfficer.firstName} ${selectedOfficer.lastName}`);
				if (showBossPanel) {
					// Stay on boss panel, just show success
				} else {
					closeCertModal();
				}
			} else {
				globalNotifications.error(response?.message || "Failed to update certifications");
			}
		} catch {
			globalNotifications.error("Failed to update certifications");
		} finally {
			isSavingCerts = false;
		}
	}

	async function promoteOfficer() {
		if (!selectedOfficer?.citizenid || selectedGrade === null) return;
		isSavingBoss = true;
		try {
			const response = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.ROSTER.PROMOTE_OFFICER,
				{
					citizenid: selectedOfficer.citizenid,
					job: selectedOfficer.department || "police",
					grade: selectedGrade,
				},
			);
			if (response?.success) {
				const gradeName = jobGrades.find((g) => g.grade === selectedGrade)?.name || `Grade ${selectedGrade}`;
				const idx = officers.findIndex((o) => o.citizenid === selectedOfficer!.citizenid);
				if (idx !== -1) {
					officers[idx].rank = gradeName;
				}
				globalNotifications.success(response.message || `Rank updated to ${gradeName}`);
			} else {
				globalNotifications.error(response?.message || "Failed to update rank");
			}
		} catch {
			globalNotifications.error("Failed to update rank");
		} finally {
			isSavingBoss = false;
		}
	}

	async function fireOfficer() {
		if (!selectedOfficer?.citizenid) return;
		isSavingBoss = true;
		try {
			const response = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.ROSTER.FIRE_OFFICER,
				{ citizenid: selectedOfficer.citizenid },
			);
			if (response?.success) {
				officers = officers.filter((o) => o.citizenid !== selectedOfficer!.citizenid);
				globalNotifications.success(response.message || "Officer has been terminated");
				closeBossPanel();
			} else {
				globalNotifications.error(response?.message || "Failed to terminate officer");
			}
		} catch {
			globalNotifications.error("Failed to terminate officer");
		} finally {
			isSavingBoss = false;
			showFireConfirm = false;
		}
	}

	async function loadIAHistory() {
		if (!selectedOfficer) return;
		iaHistoryLoading = true;
		try {
			const officerName = `${selectedOfficer.firstName} ${selectedOfficer.lastName}`;
			const result = await fetchNui<Array<{ id: number; complaint_number: string; category: string; status: string; created_at: string }>>(
				NUI_EVENTS.IA.GET_IA_HISTORY_FOR_OFFICER,
				{ officerName },
				[]
			);
			iaHistory = Array.isArray(result) ? result : [];
		} catch {
			iaHistory = [];
		}
		iaHistoryLoading = false;
	}

	function formatIAStatus(status: string): string {
		return status.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
	}

	function getIAStatusClass(status: string): string {
		switch (status) {
			case 'open': return 'pill-blue';
			case 'under_review': return 'pill-orange';
			case 'investigated': return 'pill-yellow';
			case 'sustained': return 'pill-red';
			case 'exonerated': return 'pill-green';
			default: return 'pill-gray';
		}
	}

	async function loadOfficerPPR() {
		if (!selectedOfficer?.citizenid) return;
		pprHistoryLoading = true;
		try {
			const result = await fetchNui<Array<{ id: number; ppr_number: string; category: string; title: string; author_name: string; incident_date?: string; created_at: string }>>(
				NUI_EVENTS.PPR.GET_OFFICER_PPR_HISTORY,
				{ officerCitizenId: selectedOfficer.citizenid },
				[]
			);
			pprHistory = Array.isArray(result) ? result : [];
		} catch {
			pprHistory = [];
		}
		pprHistoryLoading = false;
	}

	async function loadOfficerFTO() {
		if (!selectedOfficer?.citizenid) return;
		ftoHistoryLoading = true;
		try {
			const result = await fetchNui<Array<any>>(
				NUI_EVENTS.FTO.GET_OFFICER_FTO_HISTORY,
				{ officerCitizenId: selectedOfficer.citizenid },
				[]
			);
			ftoHistory = Array.isArray(result) ? result : [];
		} catch {
			ftoHistory = [];
		}
		ftoHistoryLoading = false;
	}

	function getFTOStatusClass(status: string): string {
		switch (status) {
			case 'active': return 'status-active';
			case 'completed': return 'status-completed';
			case 'failed': return 'status-failed';
			case 'suspended': return 'status-suspended';
			default: return '';
		}
	}

	function getPPRCategoryClass(category: string): string {
		switch (category) {
			case 'positive': return 'pill-green';
			case 'coaching': return 'pill-orange';
			case 'disciplinary': return 'pill-red';
			default: return 'pill-gray';
		}
	}

	function formatPPRCategory(category: string): string {
		return category.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
	}

	function formatDateShort(dateStr: string): string {
		if (!dateStr) return '';
		try {
			const d = new Date(dateStr);
			return `${String(d.getMonth() + 1).padStart(2, '0')}/${String(d.getDate()).padStart(2, '0')}/${d.getFullYear()}`;
		} catch { return dateStr; }
	}

	async function saveCallsign() {
		if (!selectedOfficer?.citizenid || !editCallsign.trim()) return;
		isSavingBoss = true;
		try {
			const response = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.ROSTER.UPDATE_CALLSIGN,
				{
					citizenid: selectedOfficer.citizenid,
					callsign: editCallsign.trim(),
				},
			);
			if (response?.success) {
				const idx = officers.findIndex((o) => o.citizenid === selectedOfficer!.citizenid);
				if (idx !== -1) {
					officers[idx].callsign = editCallsign.trim();
					officers[idx].badgeNumber = editCallsign.trim();
				}
				globalNotifications.success(response.message || `Callsign updated to ${editCallsign.trim()}`);
			} else {
				globalNotifications.error(response?.message || "Failed to update callsign");
			}
		} catch {
			globalNotifications.error("Failed to update callsign");
		} finally {
			isSavingBoss = false;
		}
	}

	function getTagColor(certName: string): string {
		const tag = availableTags.find((t) => t.name === certName);
		return tag?.color || "#6b7280";
	}
</script>

<div class="roster-page">
	<div class="topbar">
		<input
			type="text"
			placeholder="Search by callsign, name or rank..."
			bind:value={searchQuery}
			class="search-input"
		/>
		<div class="topbar-right">
			<span class="result-count">{filteredOfficers.length} officer{filteredOfficers.length !== 1 ? "s" : ""}</span>
			<button class="btn-secondary" onclick={refreshData} disabled={isLoading}>
				{isLoading ? "Loading..." : "Refresh"}
			</button>
		</div>
	</div>

	<div class="content-area">
		<div class="list-panel">
			<div class="table-header">
				<button class="col-header sortable" onclick={() => handleSort("status")}>Status{getSortIndicator("status")}</button>
				<button class="col-header sortable" onclick={() => handleSort("callsign")}>Call Sign{getSortIndicator("callsign")}</button>
				<button class="col-header sortable" onclick={() => handleSort("name")}>Name{getSortIndicator("name")}</button>
				<span class="col-header">Radio Ch.</span>
				<button class="col-header sortable" onclick={() => handleSort("rank")}>Rank{getSortIndicator("rank")}</button>
				<span class="col-header">Dept</span>
				<span class="col-header">Certifications</span>
			</div>

			<div class="table-body">
				{#if isLoading}
					<div class="empty-state">
						<div class="loading-spinner"></div>
						<p>Loading roster...</p>
					</div>
				{:else if filteredOfficers.length === 0}
					<div class="empty-state">
						<p class="empty-title">No Officers Found</p>
						<p class="empty-sub">
							{searchQuery
								? "No officers match your search criteria."
								: "No officers are currently in the roster."}
						</p>
					</div>
				{:else}
					{#each filteredOfficers as officer (officer.id)}
						<div
							class="table-row"
							class:clickable={canOpenPanel}
							onclick={() => openOfficerPanel(officer)}
						>
							<span class="cell-status">
								<span class="status-pill" class:on-duty={officer.status === "On Duty"} class:off-duty={officer.status === "Off Duty"}>
									{officer.status}
								</span>
							</span>
							<span class="cell-callsign">{officer.callsign}</span>
							<span class="cell-name">{officer.firstName} {officer.lastName}</span>
							<span class="cell-radio">
								{#if officer.radioChannel && officer.radioChannel > 0}
									<span class="radio-badge">{officer.radioChannel}</span>
								{:else}
									<span class="cell-muted">-</span>
								{/if}
							</span>
							<span class="cell-rank">{officer.rank}</span>
							<span class="cell-dept">{officer.department || "-"}</span>
							<span class="cell-certs">
								{#if officer.certifications.length > 0}
									{#each officer.certifications as cert}
										<span class="cert-tag" style="border-color: {getTagColor(cert)}40; color: {getTagColor(cert)}">{cert}</span>
									{/each}
								{:else}
									<span class="cell-muted">-</span>
								{/if}
							</span>
						</div>
					{/each}
				{/if}
			</div>
		</div>

		<div class="units-panel">
			<div class="units-header">
				<span class="units-label">Active Units</span>
				<span class="units-count">{activeUnits.length}</span>
			</div>

			{#if activeUnits.length === 0}
				<div class="units-empty">No units active</div>
			{:else}
				<div class="units-list">
					{#each activeUnits as unit (unit.id)}
						<div class="unit-row">
							<span class="unit-callsign">{unit.callsign}</span>
							<span class="unit-name">{unit.firstName.charAt(0)}. {unit.lastName}</span>
						</div>
					{/each}
				</div>
			{/if}
		</div>
	</div>
</div>

<!-- Certification Modal (for users without boss panel access) -->
{#if showCertModal && selectedOfficer}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="modal-overlay" onclick={closeCertModal}>
		<div class="modal-container" onclick={(e) => e.stopPropagation()}>
			<div class="modal-header">
				<div class="modal-title-area">
					<span class="modal-title">Manage Certifications</span>
					<span class="modal-subtitle">{selectedOfficer.firstName} {selectedOfficer.lastName} - {selectedOfficer.callsign}</span>
				</div>
				<button class="modal-close" onclick={closeCertModal}>
					<span class="material-icons">close</span>
				</button>
			</div>

			<div class="modal-body">
				{#if availableTags.length === 0}
					<div class="no-tags">
						<span class="material-icons no-tags-icon">label_off</span>
						<p>No certifications available.</p>
						<p class="no-tags-hint">Create officer tags in Management &gt; Tags</p>
					</div>
				{:else}
					<div class="cert-grid">
						{#each availableTags as tag (tag.id)}
							<button
								class="cert-option"
								class:selected={selectedCerts.includes(tag.name)}
								onclick={() => toggleCert(tag.name)}
								style="--tag-color: {tag.color}"
							>
								<span class="cert-check">
									{#if selectedCerts.includes(tag.name)}
										<span class="material-icons">check_circle</span>
									{:else}
										<span class="material-icons">radio_button_unchecked</span>
									{/if}
								</span>
								<span class="cert-color-dot" style="background: {tag.color}"></span>
								<span class="cert-label">{tag.name}</span>
							</button>
						{/each}
					</div>
				{/if}
			</div>

			<div class="modal-footer">
				<button class="btn-cancel" onclick={closeCertModal}>Cancel</button>
				<button
					class="btn-save"
					onclick={saveCertifications}
					disabled={isSavingCerts || availableTags.length === 0}
				>
					{isSavingCerts ? "Saving..." : "Save"}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Boss Panel Modal -->
{#if showBossPanel && selectedOfficer}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="modal-overlay" onclick={closeBossPanel}>
		<div class="boss-panel" onclick={(e) => e.stopPropagation()}>
			<div class="modal-header">
				<div class="modal-title-area">
					<span class="modal-title">Officer Management</span>
					<span class="modal-subtitle">{selectedOfficer.firstName} {selectedOfficer.lastName} &bull; {selectedOfficer.callsign} &bull; {selectedOfficer.rank}</span>
				</div>
				<button class="modal-close" onclick={closeBossPanel}>
					<span class="material-icons">close</span>
				</button>
			</div>

			<div class="boss-tabs">
				<button class="boss-tab" class:active={bossPanelTab === "rank"} onclick={() => { bossPanelTab = "rank"; showFireConfirm = false; }}>
					<span class="material-icons boss-tab-icon">military_tech</span>
					Rank
				</button>
				<button class="boss-tab" class:active={bossPanelTab === "callsign"} onclick={() => { bossPanelTab = "callsign"; showFireConfirm = false; }}>
					<span class="material-icons boss-tab-icon">badge</span>
					Callsign
				</button>
				{#if canManageCerts}
					<button class="boss-tab" class:active={bossPanelTab === "certs"} onclick={() => { bossPanelTab = "certs"; showFireConfirm = false; }}>
						<span class="material-icons boss-tab-icon">verified</span>
						Certifications
					</button>
				{/if}
				<button class="boss-tab" class:active={bossPanelTab === "ppr"} onclick={() => { bossPanelTab = "ppr"; showFireConfirm = false; loadOfficerPPR(); }}>
					<span class="material-icons boss-tab-icon">rate_review</span>
					PPR
				</button>
				<button class="boss-tab" class:active={bossPanelTab === "fto"} onclick={() => { bossPanelTab = "fto"; showFireConfirm = false; loadOfficerFTO(); }}>
					<span class="material-icons boss-tab-icon">school</span>
					FTO
				</button>
				<button class="boss-tab" class:active={bossPanelTab === "ia_history"} onclick={() => { bossPanelTab = "ia_history"; showFireConfirm = false; loadIAHistory(); }}>
					<span class="material-icons boss-tab-icon">shield</span>
					IA History
				</button>
			</div>

			<div class="boss-body">
				{#if bossPanelTab === "rank"}
					<div class="boss-section">
						<label class="boss-label">Change Rank</label>
						<p class="boss-hint">Select a new rank for this officer. Officer must be online.</p>
						<div class="grade-grid">
							{#if jobGrades.length === 0}
								<div class="no-tags">
									<p>No grades available for this department.</p>
								</div>
							{:else}
								{#each jobGrades as grade (grade.grade)}
									<button
										class="grade-option"
										class:selected={selectedGrade === grade.grade}
										class:current={grade.name === selectedOfficer.rank}
										class:is-boss={grade.isBoss}
										onclick={() => selectedGrade = grade.grade}
									>
										<span class="grade-number">{grade.grade}</span>
										<span class="grade-name">{grade.name}</span>
										{#if grade.name === selectedOfficer.rank}
											<span class="grade-current">Current</span>
										{/if}
										{#if grade.isBoss}
											<span class="grade-boss-badge">Boss</span>
										{/if}
									</button>
								{/each}
							{/if}
						</div>
					</div>

					<div class="boss-divider"></div>

					<div class="boss-section">
						<label class="boss-label boss-label-danger">Terminate Officer</label>
						<p class="boss-hint">Remove this officer from the department. This sets their job to unemployed.</p>
						{#if !showFireConfirm}
							<button class="btn-fire" onclick={() => showFireConfirm = true}>
								<span class="material-icons">person_remove</span>
								Terminate Officer
							</button>
						{:else}
							<div class="fire-confirm">
								<p class="fire-warning">Are you sure you want to terminate <strong>{selectedOfficer.firstName} {selectedOfficer.lastName}</strong>?</p>
								<div class="fire-actions">
									<button class="btn-cancel" onclick={() => showFireConfirm = false}>Cancel</button>
									<button class="btn-fire-confirm" onclick={fireOfficer} disabled={isSavingBoss}>
										{isSavingBoss ? "Processing..." : "Confirm Termination"}
									</button>
								</div>
							</div>
						{/if}
					</div>

				{:else if bossPanelTab === "callsign"}
					<div class="boss-section">
						<label class="boss-label">Edit Callsign</label>
						<p class="boss-hint">Update this officer's callsign/badge number. Officer must be online.</p>
						<div class="callsign-input-row">
							<input
								type="text"
								class="callsign-input"
								bind:value={editCallsign}
								placeholder="Enter callsign..."
								maxlength="10"
							/>
						</div>
					</div>

				{:else if bossPanelTab === "certs"}
					<div class="boss-section">
						<label class="boss-label">Manage Certifications</label>
						{#if availableTags.length === 0}
							<div class="no-tags">
								<span class="material-icons no-tags-icon">label_off</span>
								<p>No certifications available.</p>
								<p class="no-tags-hint">Create officer tags in Management &gt; Tags</p>
							</div>
						{:else}
							<div class="cert-grid">
								{#each availableTags as tag (tag.id)}
									<button
										class="cert-option"
										class:selected={selectedCerts.includes(tag.name)}
										onclick={() => toggleCert(tag.name)}
										style="--tag-color: {tag.color}"
									>
										<span class="cert-check">
											{#if selectedCerts.includes(tag.name)}
												<span class="material-icons">check_circle</span>
											{:else}
												<span class="material-icons">radio_button_unchecked</span>
											{/if}
										</span>
										<span class="cert-color-dot" style="background: {tag.color}"></span>
										<span class="cert-label">{tag.name}</span>
									</button>
								{/each}
							</div>
						{/if}
					</div>

				{:else if bossPanelTab === "ppr"}
					<div class="boss-section">
						<label class="boss-label">Performance Reviews</label>
						<p class="boss-hint">Performance planning and review entries for this officer.</p>
						{#if pprHistoryLoading}
							<p class="boss-hint">Loading...</p>
						{:else if pprHistory.length === 0}
							<div class="no-tags">
								<span class="material-icons no-tags-icon">rate_review</span>
								<p>No PPR entries found for this officer.</p>
							</div>
						{:else}
							<div class="ia-history-list">
								{#each pprHistory as ppr}
									<div class="ia-history-item">
										<div class="ia-history-info">
											<span class="ia-history-number">{ppr.ppr_number}</span>
											<span class="ia-pill {getPPRCategoryClass(ppr.category)}">{formatPPRCategory(ppr.category)}</span>
										</div>
										<div class="ia-history-meta">
											<span style="flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;">{ppr.title}</span>
											<span class="ia-history-date">{formatDateShort(ppr.created_at)}</span>
										</div>
										<div class="ia-history-meta">
											<span style="color: rgba(255,255,255,0.35); font-size: 9px;">By {ppr.author_name}</span>
										</div>
									</div>
								{/each}
							</div>
						{/if}
					</div>

				{:else if bossPanelTab === "fto"}
					<div class="boss-section">
						<label class="boss-label">Field Training History</label>
						<p class="boss-hint">FTO training assignments for this officer.</p>
						{#if ftoHistoryLoading}
							<p class="boss-hint">Loading...</p>
						{:else if ftoHistory.length === 0}
							<div class="no-tags">
								<span class="material-icons no-tags-icon">school</span>
								<p>No FTO records found for this officer.</p>
							</div>
						{:else}
							<div class="ia-history-list">
								{#each ftoHistory as record}
									<div class="ia-history-item">
										<div class="ia-history-info">
											<span class="ia-history-number">{record.fto_number}</span>
											<span class="ia-pill {getFTOStatusClass(record.status)}">{record.status.toUpperCase()}</span>
										</div>
										<div class="ia-history-meta">
											<span style="flex:1;">
												{record.trainee_name === selectedOfficer?.name ? 'Trainer' : 'Trainee'}:
												{record.trainee_name === selectedOfficer?.name ? record.trainer_name : record.trainee_name}
											</span>
											{#if record.phase_name}
												<span style="color: rgba(255,255,255,0.5); font-size: 9px;">{record.phase_name}</span>
											{/if}
										</div>
										<div class="ia-history-meta">
											{#if record.dor_count}
												<span style="color: rgba(255,255,255,0.35); font-size: 9px;">{record.dor_count} DOR{record.dor_count !== 1 ? 's' : ''}</span>
											{/if}
											{#if record.latest_rating}
												<span style="color: rgba(255,255,255,0.5); font-size: 9px;">Rating: {record.latest_rating}/5</span>
											{/if}
											<span class="ia-history-date">{record.start_date || formatDateShort(record.created_at)}</span>
										</div>
									</div>
								{/each}
							</div>
						{/if}
					</div>

				{:else if bossPanelTab === "ia_history"}
					<div class="boss-section">
						<label class="boss-label">IA Complaint History</label>
						<p class="boss-hint">Internal affairs complaints involving this officer.</p>
						{#if iaHistoryLoading}
							<p class="boss-hint">Loading...</p>
						{:else if iaHistory.length === 0}
							<div class="no-tags">
								<span class="material-icons no-tags-icon">verified_user</span>
								<p>No IA complaints found for this officer.</p>
							</div>
						{:else}
							<div class="ia-history-list">
								{#each iaHistory as complaint}
									<div class="ia-history-item">
										<div class="ia-history-info">
											<span class="ia-history-number">{complaint.complaint_number}</span>
											<span class="ia-pill {getIAStatusClass(complaint.status)}">{formatIAStatus(complaint.status)}</span>
										</div>
										<div class="ia-history-meta">
											<span>{formatIAStatus(complaint.category)}</span>
											<span class="ia-history-date">{complaint.created_at ? new Date(complaint.created_at).toLocaleDateString() : '-'}</span>
										</div>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				{/if}
			</div>

			<div class="modal-footer">
				<button class="btn-cancel" onclick={closeBossPanel}>Close</button>
				{#if bossPanelTab === "rank" && selectedGrade !== null}
					<button
						class="btn-save"
						onclick={promoteOfficer}
						disabled={isSavingBoss}
					>
						{isSavingBoss ? "Saving..." : "Update Rank"}
					</button>
				{:else if bossPanelTab === "callsign"}
					<button
						class="btn-save"
						onclick={saveCallsign}
						disabled={isSavingBoss || !editCallsign.trim()}
					>
						{isSavingBoss ? "Saving..." : "Save Callsign"}
					</button>
				{:else if bossPanelTab === "certs"}
					<button
						class="btn-save"
						onclick={saveCertifications}
						disabled={isSavingCerts || availableTags.length === 0}
					>
						{isSavingCerts ? "Saving..." : "Save Certifications"}
					</button>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	.roster-page {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
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

	.search-input {
		flex: 1;
		max-width: 360px;
		background: transparent;
		border: none;
		padding: 0;
		color: rgba(255, 255, 255, 0.8);
		font-size: 12px;
	}

	.search-input:focus {
		outline: none;
	}

	.search-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.topbar-right {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-left: auto;
	}

	.result-count {
		color: rgba(255, 255, 255, 0.2);
		font-size: 10px;
	}

	.btn-secondary {
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

	.btn-secondary:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.btn-secondary:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.content-area {
		display: grid;
		grid-template-columns: 1fr 180px;
		gap: 0;
		flex: 1;
		min-height: 0;
		overflow: hidden;
	}

	.list-panel {
		background: transparent;
		border: none;
		border-radius: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		border-right: 1px solid rgba(255, 255, 255, 0.06);
	}

	.table-header {
		display: grid;
		grid-template-columns: 80px 70px 1.2fr 70px 1fr 0.8fr 1.5fr;
		gap: 8px;
		padding: 8px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.col-header {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.35);
		background: none;
		border: none;
		padding: 0;
		text-align: left;
		cursor: default;
	}

	.col-header.sortable {
		cursor: pointer;
	}

	.col-header.sortable:hover {
		color: rgba(255, 255, 255, 0.5);
	}

	.table-body {
		flex: 1;
		overflow-y: auto;
	}

	.table-row {
		display: grid;
		grid-template-columns: 80px 70px 1.2fr 70px 1fr 0.8fr 1.5fr;
		gap: 8px;
		padding: 7px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		font-size: 11px;
		align-items: center;
		transition: background 0.1s;
	}

	.table-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.table-row.clickable {
		cursor: pointer;
	}

	.table-row.clickable:hover {
		background: rgba(255, 255, 255, 0.03);
	}

	.table-row:last-child {
		border-bottom: none;
	}

	.cell-callsign {
		font-family: monospace;
		font-size: 10px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-weight: 500;
	}

	.cell-name {
		font-weight: 500;
		font-size: 11px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.cell-rank {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.cell-dept {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.cell-radio {
		font-size: 10px;
	}

	.radio-badge {
		display: inline-block;
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
		font-family: monospace;
		background: rgba(var(--accent-rgb), 0.08);
		color: rgba(var(--accent-text-rgb), 0.7);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
	}

	.cell-muted {
		color: rgba(255, 255, 255, 0.1);
	}

	.status-pill {
		display: inline-block;
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.status-pill.on-duty {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(110, 231, 183, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.status-pill.off-duty {
		background: rgba(255, 255, 255, 0.03);
		color: rgba(255, 255, 255, 0.3);
		border: 1px solid rgba(255, 255, 255, 0.05);
	}

	.cell-certs {
		display: flex;
		flex-wrap: wrap;
		gap: 3px;
	}

	.cert-tag {
		padding: 1px 5px;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 3px;
		font-size: 9px;
	}

	/* Active Units Sidebar */
	.units-panel {
		background: transparent;
		border: none;
		border-radius: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.units-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 14px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.units-label {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.35);
	}

	.units-count {
		font-size: 10px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.35);
		background: rgba(255, 255, 255, 0.03);
		padding: 1px 6px;
		border-radius: 3px;
	}

	.units-list {
		flex: 1;
		overflow-y: auto;
	}

	.unit-row {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 6px 14px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		font-size: 11px;
	}

	.unit-row:last-child {
		border-bottom: none;
	}

	.unit-callsign {
		font-family: monospace;
		font-size: 10px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-weight: 500;
		min-width: 28px;
	}

	.unit-name {
		color: rgba(255, 255, 255, 0.5);
		font-size: 11px;
	}

	.units-empty {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 80px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	/* States */
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 200px;
		text-align: center;
		color: rgba(255, 255, 255, 0.35);
	}

	.empty-title {
		font-size: 14px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.4);
		margin: 0 0 4px;
	}

	.empty-sub {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.35);
		margin: 0;
	}

	.loading-spinner {
		width: 24px;
		height: 24px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left: 2px solid rgba(var(--accent-rgb), 0.5);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 10px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	/* Scrollbars */
	.table-body::-webkit-scrollbar,
	.units-list::-webkit-scrollbar {
		width: 4px;
	}

	.table-body::-webkit-scrollbar-track,
	.units-list::-webkit-scrollbar-track {
		background: transparent;
	}

	.table-body::-webkit-scrollbar-thumb,
	.units-list::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	/* Certification Modal */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: rgba(0, 0, 0, 0.6);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.modal-container {
		background: var(--card-dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 6px;
		width: 400px;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.modal-title-area {
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.modal-title {
		font-size: 12px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}

	.modal-subtitle {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.3);
	}

	.modal-close {
		background: none;
		border: none;
		color: rgba(255, 255, 255, 0.3);
		cursor: pointer;
		padding: 4px;
		border-radius: 3px;
		transition: all 0.1s;
		display: flex;
		align-items: center;
	}

	.modal-close:hover {
		color: rgba(255, 255, 255, 0.7);
		background: rgba(255, 255, 255, 0.04);
	}

	.modal-close .material-icons {
		font-size: 16px;
	}

	.modal-body {
		padding: 12px 16px;
		overflow-y: auto;
		flex: 1;
	}

	.no-tags {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 24px 0;
		color: rgba(255, 255, 255, 0.3);
		text-align: center;
	}

	.no-tags-icon {
		font-size: 28px;
		margin-bottom: 8px;
		color: rgba(255, 255, 255, 0.1);
	}

	.no-tags p {
		margin: 0;
		font-size: 11px;
	}

	.no-tags-hint {
		font-size: 10px !important;
		color: rgba(255, 255, 255, 0.2) !important;
		margin-top: 4px !important;
	}

	.cert-grid {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.cert-option {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 7px 10px;
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 3px;
		cursor: pointer;
		transition: all 0.1s;
		color: rgba(255, 255, 255, 0.6);
		font-size: 11px;
	}

	.cert-option:hover {
		background: rgba(255, 255, 255, 0.03);
		border-color: rgba(255, 255, 255, 0.08);
	}

	.cert-option.selected {
		background: color-mix(in srgb, var(--tag-color) 6%, transparent);
		border-color: color-mix(in srgb, var(--tag-color) 20%, transparent);
		color: rgba(255, 255, 255, 0.85);
	}

	.cert-check {
		display: flex;
		align-items: center;
		flex-shrink: 0;
	}

	.cert-check .material-icons {
		font-size: 16px;
		color: rgba(255, 255, 255, 0.15);
	}

	.cert-option.selected .cert-check .material-icons {
		color: var(--tag-color);
	}

	.cert-color-dot {
		width: 6px;
		height: 6px;
		border-radius: 50%;
		flex-shrink: 0;
	}

	.cert-label {
		font-weight: 500;
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 6px;
		padding: 10px 16px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}

	.btn-cancel {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 12px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-cancel:hover {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.btn-save {
		background: rgba(var(--accent-rgb), 0.06);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		border-radius: 3px;
		padding: 5px 16px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-save:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.btn-save:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	/* Boss Panel */
	.boss-panel {
		background: var(--card-dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 6px;
		width: 560px;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
	}

	.boss-tabs {
		display: flex;
		gap: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		padding: 0 16px;
	}

	.boss-tab {
		display: flex;
		align-items: center;
		gap: 5px;
		padding: 8px 12px;
		background: none;
		border: none;
		border-bottom: 2px solid transparent;
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
		text-transform: uppercase;
		letter-spacing: 0.3px;
		white-space: nowrap;
	}

	.boss-tab:hover {
		color: rgba(255, 255, 255, 0.6);
	}

	.boss-tab.active {
		color: rgba(var(--accent-text-rgb), 0.85);
		border-bottom-color: rgba(var(--accent-rgb), 0.5);
	}

	.boss-tab-icon {
		font-size: 14px;
	}

	.boss-body {
		padding: 14px 16px;
		overflow-y: auto;
		flex: 1;
	}

	.boss-section {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.boss-label {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.7);
	}

	.boss-label-danger {
		color: rgba(239, 68, 68, 0.8);
	}

	.boss-hint {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.25);
		margin: 0 0 6px;
		line-height: 1.4;
	}

	.boss-divider {
		height: 1px;
		background: rgba(255, 255, 255, 0.06);
		margin: 14px 0;
	}

	/* Grade Grid */
	.grade-grid {
		display: flex;
		flex-direction: column;
		gap: 3px;
	}

	.grade-option {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 7px 10px;
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 3px;
		cursor: pointer;
		transition: all 0.1s;
		color: rgba(255, 255, 255, 0.6);
		font-size: 11px;
		text-align: left;
	}

	.grade-option:hover {
		background: rgba(255, 255, 255, 0.03);
		border-color: rgba(255, 255, 255, 0.08);
	}

	.grade-option.selected {
		background: rgba(var(--accent-rgb), 0.08);
		border-color: rgba(var(--accent-rgb), 0.2);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.grade-option.current {
		border-color: rgba(16, 185, 129, 0.15);
	}

	.grade-number {
		font-family: monospace;
		font-size: 9px;
		color: rgba(255, 255, 255, 0.2);
		min-width: 16px;
		text-align: center;
	}

	.grade-option.selected .grade-number {
		color: rgba(var(--accent-text-rgb), 0.5);
	}

	.grade-name {
		font-weight: 500;
		flex: 1;
	}

	.grade-current {
		font-size: 8px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(16, 185, 129, 0.7);
		font-weight: 600;
	}

	.grade-boss-badge {
		font-size: 8px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(251, 191, 36, 0.7);
		font-weight: 600;
		background: rgba(251, 191, 36, 0.08);
		padding: 1px 5px;
		border-radius: 2px;
	}

	/* Callsign Input */
	.callsign-input-row {
		display: flex;
		gap: 8px;
	}

	.callsign-input {
		flex: 1;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 3px;
		padding: 7px 10px;
		color: rgba(255, 255, 255, 0.85);
		font-size: 12px;
		font-family: monospace;
	}

	.callsign-input:focus {
		outline: none;
		border-color: rgba(var(--accent-rgb), 0.3);
	}

	.callsign-input::placeholder {
		color: rgba(255, 255, 255, 0.15);
	}

	/* Fire Button */
	.btn-fire {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 6px 14px;
		background: rgba(239, 68, 68, 0.06);
		border: 1px solid rgba(239, 68, 68, 0.12);
		border-radius: 3px;
		color: rgba(239, 68, 68, 0.7);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
		width: fit-content;
	}

	.btn-fire .material-icons {
		font-size: 14px;
	}

	.btn-fire:hover {
		background: rgba(239, 68, 68, 0.12);
		color: rgba(239, 68, 68, 0.9);
		border-color: rgba(239, 68, 68, 0.2);
	}

	.fire-confirm {
		background: rgba(239, 68, 68, 0.04);
		border: 1px solid rgba(239, 68, 68, 0.1);
		border-radius: 4px;
		padding: 10px 12px;
	}

	.fire-warning {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.6);
		margin: 0 0 10px;
		line-height: 1.4;
	}

	.fire-warning strong {
		color: rgba(255, 255, 255, 0.85);
	}

	.fire-actions {
		display: flex;
		gap: 6px;
		justify-content: flex-end;
	}

	.btn-fire-confirm {
		background: rgba(239, 68, 68, 0.15);
		border: 1px solid rgba(239, 68, 68, 0.25);
		border-radius: 3px;
		padding: 4px 12px;
		color: rgba(239, 68, 68, 0.9);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-fire-confirm:hover:not(:disabled) {
		background: rgba(239, 68, 68, 0.25);
	}

	.btn-fire-confirm:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.ia-history-list {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.ia-history-item {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 6px;
		padding: 8px 10px;
	}
	.ia-history-info {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-bottom: 3px;
	}
	.ia-history-number {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.87);
	}
	.ia-history-meta {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 10px;
		color: rgba(255, 255, 255, 0.4);
	}
	.ia-history-date {
		margin-left: auto;
	}
	.ia-pill {
		font-size: 9px;
		padding: 1px 6px;
		border-radius: 3px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}
	.pill-blue { background: rgba(59, 130, 246, 0.2); color: rgb(147, 197, 253); }
	.pill-orange { background: rgba(245, 158, 11, 0.2); color: rgb(253, 224, 71); }
	.pill-yellow { background: rgba(234, 179, 8, 0.2); color: rgb(253, 224, 71); }
	.pill-red { background: rgba(239, 68, 68, 0.2); color: rgb(252, 165, 165); }
	.pill-green { background: rgba(16, 185, 129, 0.2); color: rgb(167, 243, 208); }
	.pill-gray { background: rgba(107, 114, 128, 0.2); color: rgb(156, 163, 175); }
	.status-active { background: rgba(59, 130, 246, 0.2); color: rgb(147, 197, 253); }
	.status-completed { background: rgba(16, 185, 129, 0.2); color: rgb(167, 243, 208); }
	.status-failed { background: rgba(239, 68, 68, 0.2); color: rgb(252, 165, 165); }
	.status-suspended { background: rgba(245, 158, 11, 0.2); color: rgb(253, 224, 71); }
</style>
