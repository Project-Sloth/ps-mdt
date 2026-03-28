<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { useNuiEvent } from "../utils/useNuiEvent";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { openReportInEditor } from "../stores/reportsStore";
	import type { createTabService } from "../services/tabService.svelte";
	import { globalNotifications } from "../services/notificationService.svelte";
	import { pendingBoloId, clearPendingBolo } from "../stores/navigationStore";
	import { get } from "svelte/store";
	import Pagination from "../components/Pagination.svelte";

	interface Bolo {
		id: number;
		reportId: string;
		reportName?: string;
		name: string;
		type: string;
		notes: string;
		status?: string;
		officer?: string;
		createdAt?: string;
	}

	let { tabService }: { tabService: ReturnType<typeof createTabService> } =
		$props();
	let bolos: Bolo[] = $state([]);
	let statusFilter = $state("active");
	let loading = $state(true);
	let showCreate = $state(false);
	let selectedBolo: Bolo | null = $state(null);
	let createForm = $state({
		name: "",
		type: "citizen",
		subjectId: "",
		reportId: "",
		notes: "",
	});

	onMount(async () => {
		if (isEnvBrowser()) {
			bolos = [
				{ id: 1, reportId: 'RPT-001', reportName: 'Armed Robbery - Vinewood', name: 'Marcus Johnson', type: 'citizen', notes: 'Wanted for armed robbery, considered dangerous. Last seen near Vinewood Blvd.', status: 'active', officer: 'Sgt. Miller', createdAt: '2026-03-15 14:30' },
				{ id: 2, reportId: 'RPT-003', reportName: 'Drive-By Shooting Investigation', name: 'Black Kuruma - UNK ???', type: 'vehicle', notes: 'Suspected in drive-by shooting downtown. Tinted windows, no front plate.', status: 'active', officer: 'Ofc. Rodriguez', createdAt: '2026-03-16 09:15' },
				{ id: 3, reportId: 'RPT-007', reportName: 'Missing Person - Williams', name: 'Sarah Williams', type: 'citizen', notes: 'Missing person - last seen at Del Perro Pier. Family reported concern.', status: 'active', officer: 'Det. Park', createdAt: '2026-03-17 11:00' },
				{ id: 4, reportId: 'RPT-012', reportName: 'Hit and Run Series', name: 'White Faggio - PLT 999', type: 'vehicle', notes: 'Used in multiple hit-and-run incidents near Vespucci Beach.', status: 'inactive', officer: 'Ofc. Smith', createdAt: '2026-03-10 16:45' },
				{ id: 5, reportId: 'RPT-015', reportName: 'Jewelry Store Robbery', name: 'David Chen', type: 'citizen', notes: 'Suspect in jewelry store robbery. May be armed.', status: 'resolved', officer: 'Lt. Davis', createdAt: '2026-03-08 08:20' },
			];
			loading = false;
			checkPendingBolo();
			return;
		}
		try {
			bolos = await fetchNui(NUI_EVENTS.CITIZEN.GET_BOLOS, { type: "all", status: "all" });
		} catch (error) {
			globalNotifications.error("Failed to fetch BOLOs");
			bolos = [];
		}
		loading = false;
		checkPendingBolo();
	});

	function checkPendingBolo() {
		const id = get(pendingBoloId);
		if (id !== null) {
			const bolo = bolos.find((b) => b.id === id);
			if (bolo) {
				selectedBolo = bolo;
				// If the bolo's status doesn't match current filter, switch to "all"
				if (statusFilter !== "all" && bolo.status !== statusFilter) {
					statusFilter = "all";
				}
			}
			clearPendingBolo();
		}
	}

	useNuiEvent<Bolo[]>(NUI_EVENTS.CITIZEN.UPDATE_BOLOS, (data) => {
		if (data) bolos = data;
	});

	let boloPage = $state(1);
	let boloPerPage = $state(20);

	let filteredBolos = $derived.by(() => {
		if (!statusFilter || statusFilter === "all") return bolos;
		return bolos.filter((bolo) => bolo.status === statusFilter);
	});

	let pagedBolos = $derived.by(() => {
		const start = (boloPage - 1) * boloPerPage;
		return filteredBolos.slice(start, start + boloPerPage);
	});

	// Reset page when filter changes
	$effect(() => {
		statusFilter;
		boloPage = 1;
	});

	function viewBolo(boloId: number) {
		selectedBolo = bolos.find((item) => item.id === boloId) ?? null;
	}

	async function resolveBolo(boloId: number) {
		try {
			const response = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.CITIZEN.UPDATE_BOLO_STATUS,
				{ id: boloId, status: "resolved" }
			);
			if (response?.success) {
				const bolo = bolos.find((b) => b.id === boloId);
				if (bolo) bolo.status = "resolved";
				bolos = [...bolos];
				if (selectedBolo?.id === boloId) selectedBolo.status = "resolved";
				globalNotifications.success("BOLO marked as resolved");
			} else {
				globalNotifications.error(response?.message || "Failed to resolve BOLO");
			}
		} catch {
			globalNotifications.error("Failed to resolve BOLO");
		}
	}

	async function deleteBolo(boloId: number) {
		try {
			const response = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.CITIZEN.DELETE_BOLO,
				{ id: boloId }
			);
			if (response?.success) {
				bolos = bolos.filter((b) => b.id !== boloId);
				selectedBolo = null;
				globalNotifications.success("BOLO deleted");
			} else {
				globalNotifications.error(response?.message || "Failed to delete BOLO");
			}
		} catch {
			globalNotifications.error("Failed to delete BOLO");
		}
	}

	function goToReport(reportId: string) {
		if (reportId && reportId !== "N/A") {
			openReportInEditor(String(reportId));
			const activeInstance = tabService.getActiveInstance();
			if (activeInstance) {
				tabService.setInstanceTab(activeInstance.id, "Reports");
			} else {
				tabService.setActiveTab("Reports");
			}
		}
	}

	function getStatusClass(status?: string) {
		switch (status) {
			case "active": return "status-active";
			case "inactive": return "status-inactive";
			case "resolved": return "status-resolved";
			default: return "";
		}
	}

	function getTypeLabel(type: string) {
		switch (type) {
			case "citizen": return "Citizen";
			case "vehicle": return "Vehicle";
			case "weapon": return "Weapon";
			case "property": return "Property";
			default: return "Other";
		}
	}

	function getTypeClass(type: string) {
		switch (type) {
			case "citizen": return "type-blue";
			case "vehicle": return "type-orange";
			case "weapon": return "type-red";
			default: return "";
		}
	}

	async function createBolo() {
		if (!createForm.name.trim()) return;
		if (isEnvBrowser()) {
			const newBolo: Bolo = {
				id: bolos.length + 1,
				reportId: createForm.reportId || "N/A",
				name: createForm.name.trim(),
				type: createForm.type,
				notes: createForm.notes.trim(),
				status: "active",
				officer: "You",
				createdAt: new Date().toISOString().slice(0, 16).replace("T", " "),
			};
			bolos = [newBolo, ...bolos];
			createForm = { name: "", type: "citizen", subjectId: "", reportId: "", notes: "" };
			showCreate = false;
			return;
		}
		const payload = {
			type: createForm.type,
			subjectId: createForm.subjectId.trim() || undefined,
			subjectName: createForm.name.trim(),
			reportId: createForm.reportId ? Number(createForm.reportId) : undefined,
			notes: createForm.notes.trim(),
		};
		const response = await fetchNui("createBolo" as any, payload);
		if (response?.success) {
			createForm = { name: "", type: "citizen", subjectId: "", reportId: "", notes: "" };
			showCreate = false;
			bolos = await fetchNui(NUI_EVENTS.CITIZEN.GET_BOLOS, { type: "all", status: "all" });
		}
	}
</script>

<div class="page">
	<!-- Top bar -->
	<div class="topbar">
		<div class="filters">
			{#each ["active", "inactive", "resolved", "all"] as f}
				<button class="filter-btn" class:active={statusFilter === f} onclick={() => (statusFilter = f)}>{f}</button>
			{/each}
		</div>
		<button class="new-btn" onclick={() => (showCreate = true)}>
			<svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/></svg>
			New BOLO
		</button>
	</div>

	<!-- List -->
	{#if loading}
		<div class="center-msg"><div class="spinner"></div><span>Loading BOLOs...</span></div>
	{:else if filteredBolos.length === 0}
		<div class="center-msg"><span>No BOLOs found.</span></div>
	{:else}
		<div class="bolo-list">
			{#each pagedBolos as bolo (bolo.id)}
				<button class="bolo-row" onclick={() => viewBolo(bolo.id)}>
					<div class="bolo-main">
						<div class="bolo-title-row">
							<span class="bolo-name">{bolo.name}</span>
							<span class="status-pill {getStatusClass(bolo.status)}">{bolo.status ?? "unknown"}</span>
							<span class="type-pill {getTypeClass(bolo.type)}">{getTypeLabel(bolo.type)}</span>
						</div>
						<div class="bolo-meta">
							<span class="meta-id">{bolo.reportId}</span>
							{#if bolo.officer}<span class="meta-dot"></span><span class="meta-text">{bolo.officer}</span>{/if}
							{#if bolo.createdAt}<span class="meta-dot"></span><span class="meta-text">{bolo.createdAt}</span>{/if}
						</div>
						{#if bolo.notes && bolo.notes.trim()}
							<div class="bolo-notes">{bolo.notes}</div>
						{/if}
					</div>
				</button>
			{/each}
		</div>
		<Pagination
			currentPage={boloPage}
			totalItems={filteredBolos.length}
			perPage={boloPerPage}
			perPageOptions={[10, 20, 50, 100]}
			onPageChange={(p) => { boloPage = p; }}
			onPerPageChange={(pp) => { boloPerPage = pp; boloPage = 1; }}
		/>
	{/if}
</div>

<!-- Detail Modal -->
{#if selectedBolo}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="modal-backdrop" onclick={(e) => { if (e.target === e.currentTarget) selectedBolo = null; }}>
		<div class="modal" role="dialog" aria-modal="true" tabindex="-1">
			<div class="modal-header">
				<h3>BOLO Details</h3>
				<button class="close-btn" aria-label="Close" onclick={() => (selectedBolo = null)}>
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
				</button>
			</div>
			<div class="modal-body">
				<div class="modal-top">
					<span class="modal-name">{selectedBolo.name}</span>
					<span class="status-pill {getStatusClass(selectedBolo.status)}">{selectedBolo.status ?? "unknown"}</span>
				</div>
				<div class="modal-grid">
					<div class="modal-field"><span class="field-label">Type</span><span class="field-value">{getTypeLabel(selectedBolo.type)}</span></div>
					<div class="modal-field"><span class="field-label">Report ID</span><span class="field-value">{selectedBolo.reportId}</span></div>
					{#if selectedBolo.reportName}<div class="modal-field"><span class="field-label">Report</span><span class="field-value">{selectedBolo.reportName}</span></div>{/if}
					{#if selectedBolo.officer}<div class="modal-field"><span class="field-label">Officer</span><span class="field-value">{selectedBolo.officer}</span></div>{/if}
					{#if selectedBolo.createdAt}<div class="modal-field"><span class="field-label">Created</span><span class="field-value">{selectedBolo.createdAt}</span></div>{/if}
				</div>
				{#if selectedBolo.notes && selectedBolo.notes.trim()}
					<div class="modal-notes">
						<span class="field-label">Notes</span>
						<p class="notes-body">{selectedBolo.notes}</p>
					</div>
				{/if}
			</div>
			<div class="modal-footer">
				<div class="modal-footer-left">
					{#if selectedBolo.status === 'active'}
						<button class="resolve-btn" onclick={() => { if (selectedBolo) resolveBolo(selectedBolo.id); }}>
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
							Resolve
						</button>
					{/if}
					<button class="delete-btn" onclick={() => { if (selectedBolo) deleteBolo(selectedBolo.id); }}>
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
						Delete
					</button>
				</div>
				<div class="modal-footer-right">
					{#if selectedBolo.reportId && selectedBolo.reportId !== "N/A"}
						<button class="action-btn" onclick={() => { if (selectedBolo) goToReport(selectedBolo.reportId); }}>View Report</button>
					{/if}
					<button class="cancel-btn" onclick={() => (selectedBolo = null)}>Close</button>
				</div>
			</div>
		</div>
	</div>
{/if}

<!-- Create Modal -->
{#if showCreate}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="modal-backdrop" onclick={(e) => { if (e.target === e.currentTarget) showCreate = false; }}>
		<div class="modal" role="dialog" aria-modal="true" tabindex="-1">
			<div class="modal-header">
				<h3>New BOLO</h3>
				<button class="close-btn" aria-label="Close" onclick={() => (showCreate = false)}>
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
				</button>
			</div>
			<div class="modal-body form-body">
				<div class="form-group"><span class="field-label">Name</span><input class="form-input" bind:value={createForm.name} placeholder="Subject name" /></div>
				<div class="form-group"><span class="field-label">Type</span>
					<select class="form-input form-select" bind:value={createForm.type}>
						<option value="citizen">Citizen</option>
						<option value="vehicle">Vehicle</option>
						<option value="weapon">Weapon</option>
						<option value="property">Property</option>
						<option value="other">Other</option>
					</select>
				</div>
				<div class="form-group"><span class="field-label">Subject ID</span><input class="form-input" bind:value={createForm.subjectId} placeholder="Citizen ID / Plate / Serial" /></div>
				<div class="form-group"><span class="field-label">Report ID</span><input class="form-input" bind:value={createForm.reportId} type="number" placeholder="Link to report" /></div>
				<div class="form-group form-full"><span class="field-label">Notes</span><textarea class="form-input" rows="4" bind:value={createForm.notes} placeholder="BOLO description and details..."></textarea></div>
			</div>
			<div class="modal-footer">
				<button class="cancel-btn" onclick={() => (showCreate = false)}>Cancel</button>
				<button class="primary-btn" onclick={createBolo}>Create BOLO</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.page { height: 100%; display: flex; flex-direction: column; background: var(--card-dark-bg); overflow: hidden; }

	/* Top bar */
	.topbar { display: flex; align-items: center; gap: 10px; padding: 0 16px; height: 42px; flex-shrink: 0; border-bottom: 1px solid rgba(255, 255, 255, 0.06); }
	.filters { display: flex; gap: 2px; }
	.filter-btn { background: transparent; border: none; border-radius: 0; padding: 4px 10px; color: rgba(255, 255, 255, 0.3); font-size: 10px; font-weight: 500; text-transform: capitalize; cursor: pointer; transition: all 0.1s; border-bottom: 2px solid transparent; }
	.filter-btn:hover { color: rgba(255, 255, 255, 0.6); }
	.filter-btn.active { color: rgba(96, 165, 250, 0.9); border-bottom-color: rgba(var(--accent-rgb), 0.5); }
	.new-btn { margin-left: auto; display: flex; align-items: center; gap: 5px; background: rgba(16, 185, 129, 0.06); color: rgba(52, 211, 153, 0.7); border: 1px solid rgba(16, 185, 129, 0.1); padding: 4px 10px; border-radius: 3px; font-size: 10px; font-weight: 500; cursor: pointer; transition: all 0.1s; }
	.new-btn:hover { background: rgba(16, 185, 129, 0.12); color: rgba(110, 231, 183, 0.9); }

	/* List */
	.bolo-list { flex: 1; overflow-y: auto; padding: 0; display: flex; flex-direction: column; gap: 0; scrollbar-width: thin; scrollbar-color: rgba(255, 255, 255, 0.06) transparent; }
	.bolo-list::-webkit-scrollbar { width: 4px; }
	.bolo-list::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	.bolo-row { display: flex; width: 100%; padding: 8px 16px; background: transparent; border: none; border-bottom: 1px solid rgba(255, 255, 255, 0.03); border-radius: 0; cursor: pointer; transition: background 0.1s; text-align: left; font: inherit; color: inherit; }
	.bolo-row:hover { background: rgba(255, 255, 255, 0.02); }

	.bolo-main { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 3px; }
	.bolo-title-row { display: flex; align-items: center; gap: 7px; flex-wrap: wrap; }
	.bolo-name { color: rgba(255, 255, 255, 0.85); font-size: 11px; font-weight: 600; }

	.status-pill { padding: 1px 6px; border-radius: 3px; font-size: 9px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.3px; }
	.status-active { background: rgba(239, 68, 68, 0.08); color: rgba(248, 113, 113, 0.8); border: 1px solid rgba(239, 68, 68, 0.1); }
	.status-inactive { background: rgba(245, 158, 11, 0.08); color: rgba(251, 191, 36, 0.8); border: 1px solid rgba(245, 158, 11, 0.1); }
	.status-resolved { background: rgba(16, 185, 129, 0.08); color: rgba(52, 211, 153, 0.8); border: 1px solid rgba(16, 185, 129, 0.1); }

	.type-pill { padding: 1px 6px; border-radius: 3px; font-size: 9px; font-weight: 500; background: rgba(255, 255, 255, 0.03); color: rgba(255, 255, 255, 0.3); border: 1px solid rgba(255, 255, 255, 0.04); }
	.type-blue { background: rgba(var(--accent-rgb), 0.06); color: rgba(96, 165, 250, 0.7); border-color: rgba(var(--accent-rgb), 0.08); }
	.type-orange { background: rgba(245, 158, 11, 0.06); color: rgba(251, 191, 36, 0.7); border-color: rgba(245, 158, 11, 0.08); }
	.type-red { background: rgba(239, 68, 68, 0.06); color: rgba(248, 113, 113, 0.7); border-color: rgba(239, 68, 68, 0.08); }

	.bolo-meta { display: flex; align-items: center; gap: 5px; font-size: 10px; }
	.meta-id { color: rgba(255, 255, 255, 0.35); font-family: monospace; font-size: 10px; }
	.meta-dot { width: 2px; height: 2px; border-radius: 50%; background: rgba(255, 255, 255, 0.1); flex-shrink: 0; }
	.meta-text { color: rgba(255, 255, 255, 0.2); }
	.bolo-notes { color: rgba(255, 255, 255, 0.3); font-size: 10px; line-height: 1.4; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-top: 1px; }

	.center-msg { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 10px; color: rgba(255, 255, 255, 0.35); font-size: 11px; }
	.spinner { width: 24px; height: 24px; border: 2px solid rgba(255, 255, 255, 0.06); border-top-color: rgba(96, 165, 250, 0.5); border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }

	/* Modal shared */
	.modal-backdrop { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.7); backdrop-filter: blur(4px); display: flex; align-items: center; justify-content: center; z-index: 999; }
	.modal { background: var(--card-dark-bg); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 6px; width: min(540px, 92vw); max-height: 85vh; overflow: hidden; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5); }
	.modal-header { display: flex; align-items: center; justify-content: space-between; padding: 10px 16px; border-bottom: 1px solid rgba(255, 255, 255, 0.06); }
	.modal-header h3 { margin: 0; font-size: 12px; font-weight: 600; color: rgba(255, 255, 255, 0.85); }
	.close-btn { display: flex; align-items: center; justify-content: center; background: transparent; color: rgba(255, 255, 255, 0.3); border: 1px solid rgba(255, 255, 255, 0.06); padding: 4px; border-radius: 3px; cursor: pointer; transition: all 0.1s; }
	.close-btn:hover { color: rgba(255, 255, 255, 0.7); border-color: rgba(255, 255, 255, 0.1); }

	.modal-body { padding: 14px 16px; overflow-y: auto; }
	.modal-top { display: flex; align-items: center; gap: 8px; margin-bottom: 12px; }
	.modal-name { color: rgba(255, 255, 255, 0.85); font-size: 14px; font-weight: 700; }
	.modal-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 12px; }
	.modal-field { display: flex; flex-direction: column; gap: 2px; }
	.field-label { color: rgba(255, 255, 255, 0.35); font-size: 9px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.6px; }
	.field-value { color: rgba(255, 255, 255, 0.7); font-size: 11px; font-weight: 500; }
	.modal-notes { background: transparent; border: none; border-top: 1px solid rgba(255, 255, 255, 0.04); border-radius: 0; padding: 10px 0 0; }
	.notes-body { margin: 4px 0 0; font-size: 11px; line-height: 1.5; color: rgba(255, 255, 255, 0.5); }

	.modal-footer { display: flex; justify-content: space-between; align-items: center; gap: 6px; padding: 10px 16px; border-top: 1px solid rgba(255, 255, 255, 0.06); }
	.modal-footer-left { display: flex; gap: 6px; }
	.modal-footer-right { display: flex; gap: 6px; }
	.resolve-btn { display: flex; align-items: center; gap: 4px; background: rgba(34, 197, 94, 0.06); color: rgba(74, 222, 128, 0.7); border: 1px solid rgba(34, 197, 94, 0.1); padding: 4px 10px; border-radius: 3px; font-size: 10px; font-weight: 500; cursor: pointer; transition: all 0.1s; }
	.resolve-btn:hover { background: rgba(34, 197, 94, 0.12); color: rgba(74, 222, 128, 0.9); }
	.delete-btn { display: flex; align-items: center; gap: 4px; background: transparent; color: rgba(248, 113, 113, 0.5); border: 1px solid rgba(239, 68, 68, 0.1); padding: 4px 10px; border-radius: 3px; font-size: 10px; font-weight: 500; cursor: pointer; transition: all 0.1s; }
	.delete-btn:hover { background: rgba(239, 68, 68, 0.08); color: rgba(252, 165, 165, 0.8); }
	.action-btn { background: rgba(var(--accent-rgb), 0.06); color: rgba(var(--accent-text-rgb), 0.7); border: 1px solid rgba(var(--accent-rgb), 0.1); padding: 4px 10px; border-radius: 3px; font-size: 10px; font-weight: 500; cursor: pointer; transition: all 0.1s; }
	.action-btn:hover { background: rgba(var(--accent-rgb), 0.12); color: rgba(var(--accent-text-rgb), 0.9); }
	.cancel-btn { background: transparent; color: rgba(255, 255, 255, 0.4); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 3px; padding: 4px 10px; font-size: 10px; font-weight: 500; cursor: pointer; transition: all 0.1s; }
	.cancel-btn:hover { color: rgba(255, 255, 255, 0.7); border-color: rgba(255, 255, 255, 0.1); }
	.primary-btn { background: rgba(16, 185, 129, 0.06); color: rgba(52, 211, 153, 0.7); border: 1px solid rgba(16, 185, 129, 0.1); border-radius: 3px; padding: 4px 12px; font-size: 10px; font-weight: 600; cursor: pointer; transition: all 0.1s; }
	.primary-btn:hover { background: rgba(16, 185, 129, 0.12); color: rgba(110, 231, 183, 0.9); }

	/* Form */
	.form-body { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
	.form-group { display: flex; flex-direction: column; gap: 3px; }
	.form-full { grid-column: 1 / -1; }
	.form-input { background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 3px; padding: 5px 8px; color: rgba(255, 255, 255, 0.8); font-size: 11px; transition: border-color 0.1s; font-family: inherit; }
	.form-input:focus { outline: none; border-color: rgba(255, 255, 255, 0.1); }
	.form-input::placeholder { color: rgba(255, 255, 255, 0.2); }
	.form-select { padding-right: 22px; font-size: 10px; }
	textarea.form-input { resize: vertical; min-height: 60px; }
</style>
