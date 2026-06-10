<script lang="ts">
	import { onMount } from "svelte";
	import { createEvidenceService } from "../services/evidenceService.svelte";
	import { formatBytes, compressImage } from "../services/uploadService";
	import { isEnvBrowser } from "../utils/misc";
	import type { createTabService } from "../services/tabService.svelte";
	import type { MDTTab } from "../constants";
	import Pagination from "../components/Pagination.svelte";

	let { tabService }: { tabService?: ReturnType<typeof createTabService> } = $props();

	function navigateTo(tab: MDTTab) {
		if (!tabService) return;
		tabService.setActiveTab(tab);
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, tab);
		}
	}

	const evidenceService = createEvidenceService() as ReturnType<typeof createEvidenceService> & {
		getEvidenceItems: (...args: any[]) => Promise<any>;
		searchEvidenceItems: (...args: any[]) => Promise<any>;
		addEvidenceItem: (...args: any[]) => Promise<any>;
		updateEvidenceItem: (...args: any[]) => Promise<any>;
		deleteEvidenceItem: (...args: any[]) => Promise<any>;
		transferEvidenceItem: (...args: any[]) => Promise<any>;
		getEvidenceCustody: (...args: any[]) => Promise<any>;
		addEvidenceImage: (...args: any[]) => Promise<any>;
		removeEvidenceImage: (...args: any[]) => Promise<any>;
		linkEvidenceToCase: (...args: any[]) => Promise<any>;
		linkEvidenceToReport: (...args: any[]) => Promise<any>;
		createCaseFromEvidence: (...args: any[]) => Promise<any>;
		openEvidenceStash: (...args: any[]) => Promise<any>;
		logEvidenceViewed: (...args: any[]) => Promise<any>;
	};

	let searchQuery = $state("");
	let isLoading = $state(false);
	let showCreate = $state(false);
	let items = $state<any[]>([]);
	let total = $state(0);
	let page = $state(1);
	let limit = $state(20);

	let createForm = $state({
		caseId: "",
		reportId: "",
		title: "",
		type: "Physical",
		serial: "",
		description: "",
		location: "",
		stashId: "",
		stored: false,
		notes: "",
		plateNumber: "",
		quantity: "",
	});

	// Per-type field config: which fields to show and custom labels/placeholders
	const TYPE_FIELDS: Record<string, {
		serial?: boolean; serialLabel?: string; serialPlaceholder?: string;
		description?: boolean; descriptionPlaceholder?: string;
		stash?: boolean; stored?: boolean;
		plate?: boolean; quantity?: boolean;
	}> = {
		Physical:  { serial: true, description: true, descriptionPlaceholder: "What is it? (e.g. Knife, Clothing, Bag)", stash: true, stored: true },
		Digital:   { description: true, descriptionPlaceholder: "Type of digital evidence (e.g. Phone records, CCTV footage)" },
		Document:  { serial: true, serialLabel: "Document #", serialPlaceholder: "Document reference number", description: true, descriptionPlaceholder: "Document type (e.g. Bank statement, ID card)" },
		Weapon:    { serial: true, serialLabel: "Serial Number", serialPlaceholder: "Weapon serial number", stash: true, stored: true },
		Drug:      { description: true, descriptionPlaceholder: "Substance type (e.g. Cocaine, Marijuana)", quantity: true, stash: true, stored: true },
		Vehicle:   { plate: true, description: true, descriptionPlaceholder: "Vehicle description (e.g. Red Sultan RS)" },
		Other:     { serial: true, description: true, descriptionPlaceholder: "Describe the evidence", stash: true, stored: true },
	};

	let typeConfig = $derived(TYPE_FIELDS[createForm.type] || TYPE_FIELDS.Other);

	let selectedEvidenceId = $state<number | null>(null);
	let selectedEvidence = $state<any | null>(null);
	let custodyEntries = $state<any[]>([]);
	let transferCitizenId = $state("");
	let transferNotes = $state("");
	let evidenceImageFile = $state<File | null>(null);
	let evidenceImageLabel = $state("");
	let evidenceError = $state("");
	let isUploading = $state(false);
	let linkCaseId = $state("");
	let linkReportId = $state("");
	let statusMessage: { text: string; type: "success" | "error" } | null = $state(null);
	let lightboxUrl = $state<string | null>(null);
	let lightboxLabel = $state("");
	let createImageFiles = $state<File[]>([]);

	function showStatus(text: string, type: "success" | "error" = "success") {
		statusMessage = { text, type };
		setTimeout(() => { statusMessage = null; }, 3000);
	}

	const allowedEvidenceImageTypes = ["image/jpeg", "image/png", "image/webp"];

	function openLightbox(url: string, label: string) {
		lightboxUrl = url;
		lightboxLabel = label;
	}

	function closeLightbox() {
		lightboxUrl = null;
		lightboxLabel = "";
	}

	async function openStash(stashId: string) {
		if (!stashId) return;
		await evidenceService.openEvidenceStash(stashId);
	}

	async function loadEvidence(pageNumber = 1) {
		isLoading = true;
		try {
			if (searchQuery.trim()) {
				const response = await evidenceService.searchEvidenceItems(
					searchQuery.trim(),
					pageNumber,
					limit,
				);
				items = response.data?.items || [];
				total = response.data?.total || 0;
			} else {
				const response = await evidenceService.getEvidenceItems(
					pageNumber,
					limit,
				);
				items = response.data?.items || [];
				total = response.data?.total || 0;
			}
			page = pageNumber;
		} catch (error) {
			items = [];
			total = 0;
		} finally {
			isLoading = false;
		}
	}

	function resetCreateForm() {
		createForm = { caseId: "", reportId: "", title: "", type: "Physical", serial: "", description: "", location: "", stashId: "", stored: false, notes: "", plateNumber: "", quantity: "" };
		createImageFiles = [];
	}

	function buildNotes(): string {
		const parts: string[] = [];
		if (createForm.description.trim()) parts.push(createForm.description.trim());
		if (createForm.plateNumber.trim()) parts.push(`Plate: ${createForm.plateNumber.trim()}`);
		if (createForm.quantity.trim()) parts.push(`Qty: ${createForm.quantity.trim()}`);
		if (createForm.notes.trim()) parts.push(createForm.notes.trim());
		return parts.join(" | ");
	}

	async function handleCreateEvidence() {
		evidenceError = "";
		if (!createForm.title.trim()) {
			evidenceError = "Title is required.";
			return;
		}
		if (isEnvBrowser()) {
			const newItem = {
				id: items.length + 10,
				case_id: createForm.caseId ? Number(createForm.caseId) : null,
				title: createForm.title.trim(),
				type: createForm.type,
				serial: createForm.serial.trim() || `EVD-${String(items.length + 6).padStart(3, "0")}`,
				location: createForm.location.trim(),
				stash_id: createForm.stashId.trim(),
				stored: createForm.stored,
				notes: buildNotes(),
				created_at: new Date().toISOString(),
				updated_by: "You",
			};
			items = [newItem, ...items];
			total = items.length;
			showCreate = false;
			resetCreateForm();
			return;
		}
		const payload = {
			caseId: createForm.caseId ? Number(createForm.caseId) : undefined,
			reportId: createForm.reportId ? Number(createForm.reportId) : undefined,
			evidence: {
				title: createForm.title.trim(),
				type: createForm.type,
				serial: createForm.serial.trim() || (createForm.plateNumber.trim() ? createForm.plateNumber.trim() : ""),
				location: createForm.location.trim(),
				stashId: createForm.stashId.trim(),
				stored: createForm.stored,
				notes: buildNotes(),
			},
		};
		const stashToOpen = createForm.stashId.trim();
		const response = await evidenceService.addEvidenceItem(payload as any);
		if (response.success) {
			const newId = response.id || response.data?.id;
			if (newId && createImageFiles.length > 0) {
				for (const file of createImageFiles) {
					const base64 = await fileToBase64(file);
					await evidenceService.addEvidenceImage(newId, {
						data: base64,
						filename: file.name,
						contentType: file.type,
						label: file.name,
					});
				}
			}
			showCreate = false;
			resetCreateForm();
			await loadEvidence(1);
			if (stashToOpen) {
				await openStash(stashToOpen);
			}
		}
	}

	async function selectEvidence(item: any) {
		selectedEvidenceId = item.id;
		selectedEvidence = item;
		linkCaseId = item.case_id ? String(item.case_id) : "";
		linkReportId = item.report_id ? String(item.report_id) : "";
		// Log that this evidence was viewed (fire and forget, then refresh custody)
		evidenceService.logEvidenceViewed(item.id);
		custodyEntries = await evidenceService.getEvidenceCustody(item.id);
	}

	async function handleLinkEvidenceCase() {
		if (!selectedEvidenceId || !linkCaseId.trim()) {
			if (!linkCaseId.trim()) showStatus("Enter a Case ID or Case Number", "error");
			return;
		}
		try {
			// Pass raw string - server handles both numeric IDs and case numbers like "CASE-2026-003"
			const caseIdValue = /^\d+$/.test(linkCaseId.trim()) ? Number(linkCaseId.trim()) : linkCaseId.trim();
			const result = await evidenceService.linkEvidenceToCase(
				selectedEvidenceId,
				caseIdValue as any,
				selectedEvidence?.report_id ? Number(selectedEvidence.report_id) : undefined,
			);
			if (result?.success) {
				showStatus("Evidence linked to Case #" + linkCaseId.trim());
				await loadEvidence(page);
			} else {
				showStatus((result as any)?.error || "Failed to link evidence", "error");
			}
		} catch {
			showStatus("Failed to link evidence", "error");
		}
	}

	async function handleLinkEvidenceReport() {
		if (!selectedEvidenceId || !linkReportId.trim()) {
			if (!linkReportId.trim()) showStatus("Enter a Report ID", "error");
			return;
		}
		try {
			const reportIdNum = Number(linkReportId.trim());
			if (!reportIdNum) {
				showStatus("Report ID must be a number", "error");
				return;
			}
			const result = await evidenceService.linkEvidenceToReport(
				selectedEvidenceId,
				reportIdNum,
			);
			if (result?.success) {
				showStatus("Evidence linked to Report #" + linkReportId.trim());
				await loadEvidence(page);
			} else {
				showStatus((result as any)?.error || "Failed to link evidence to report", "error");
			}
		} catch {
			showStatus("Failed to link evidence to report", "error");
		}
	}

	async function handleCreateCaseFromEvidence() {
		if (!selectedEvidenceId) return;
		if (isEnvBrowser()) {
			const newCaseId = Math.floor(Math.random() * 900) + 100;
			const idx = items.findIndex((i) => i.id === selectedEvidenceId);
			if (idx !== -1) {
				items[idx] = { ...items[idx], case_id: newCaseId };
				items = [...items];
				selectedEvidence = items[idx];
				linkCaseId = String(newCaseId);
			}
			showStatus("Case #" + newCaseId + " created");
			return;
		}
		try {
			const response = await evidenceService.createCaseFromEvidence(
				selectedEvidenceId,
				selectedEvidence?.report_id ? Number(selectedEvidence.report_id) : undefined,
			);
			if (response?.success) {
				showStatus("Case #" + (response.caseId || "") + " created from evidence");
				linkCaseId = response.caseId ? String(response.caseId) : linkCaseId;
				await loadEvidence(page);
			} else {
				showStatus((response as any)?.error || "Failed to create case", "error");
			}
		} catch {
			showStatus("Failed to create case", "error");
		}
	}

	async function handleTransferEvidence() {
		if (!selectedEvidenceId || !transferCitizenId.trim()) return;
		await evidenceService.transferEvidenceItem(
			selectedEvidenceId,
			transferCitizenId.trim(),
			transferNotes.trim(),
		);
		custodyEntries = await evidenceService.getEvidenceCustody(
			selectedEvidenceId,
		);
		transferCitizenId = "";
		transferNotes = "";
	}

	let uploadSuccess = $state("");

	async function handleUploadEvidenceImage() {
		if (!selectedEvidenceId || !evidenceImageFile || isUploading) return;
		if (!allowedEvidenceImageTypes.includes(evidenceImageFile.type)) {
			evidenceError = "Unsupported image type.";
			return;
		}
		isUploading = true;
		if (isEnvBrowser()) {
			await new Promise((r) => setTimeout(r, 1000));
			uploadSuccess = `Uploaded: ${evidenceImageFile.name}`;
			evidenceImageFile = null;
			evidenceImageLabel = "";
			isUploading = false;
			setTimeout(() => { uploadSuccess = ""; }, 3000);
			return;
		}
		try {
			const base64 = await compressImage(evidenceImageFile);
			const result = await evidenceService.addEvidenceImage(selectedEvidenceId, {
				data: base64,
				filename: evidenceImageFile.name,
				contentType: evidenceImageFile.type,
				label: evidenceImageLabel.trim(),
			});
			if (result?.success && result.url) {
				if (selectedEvidence) {
					if (!selectedEvidence.images) selectedEvidence.images = [];
					selectedEvidence.images = [...selectedEvidence.images, {
						id: result.id || Date.now(),
						url: result.url,
						label: evidenceImageLabel.trim(),
					}];
				}
				uploadSuccess = `Uploaded: ${evidenceImageFile.name}`;
			} else {
				evidenceError = "Upload failed";
			}
		} catch {
			evidenceError = "Upload failed";
		}
		evidenceImageFile = null;
		evidenceImageLabel = "";
		isUploading = false;
		setTimeout(() => { uploadSuccess = ""; }, 3000);
	}

	async function handleRemoveImage(imageId: number) {
		if (!selectedEvidenceId) return;
		await evidenceService.removeEvidenceImage(imageId);
		if (selectedEvidence?.images) {
			selectedEvidence.images = selectedEvidence.images.filter((img: any) => img.id !== imageId);
		}
	}

	function formatStored(value: boolean | number | undefined) {
		return value ? "Stored" : "In Field";
	}

	onMount(async () => {
		if (isEnvBrowser()) {
			items = [
				{ id: 1, case_id: 101, title: 'Bloody Knife', type: 'Physical', serial: 'EVD-001', location: 'Vinewood Blvd Crime Scene', stash_id: 'LOCKER-A12', stored: true, notes: 'Found near victim, bagged and tagged', created_at: '2026-03-15T10:30:00Z', updated_by: 'Ofc. Smith' },
				{ id: 2, case_id: 101, title: 'Security Camera Footage', type: 'Digital', serial: 'EVD-002', location: 'Fleeca Bank - Hawick', stash_id: '', stored: false, notes: 'Footage from 03/14 showing suspect entering bank', created_at: '2026-03-15T11:00:00Z', updated_by: 'Det. Williams' },
				{ id: 3, case_id: 102, title: 'Shell Casings (x4)', type: 'Physical', serial: 'EVD-003', location: 'Route 68 Highway', stash_id: 'LOCKER-B03', stored: true, notes: '9mm casings recovered from scene', created_at: '2026-03-14T08:15:00Z', updated_by: 'Ofc. Johnson' },
				{ id: 4, case_id: 103, title: 'Suspect Phone Records', type: 'Digital', serial: 'EVD-004', location: 'LSPD Tech Lab', stash_id: 'DIGITAL-VAULT', stored: true, notes: 'Call logs subpoenaed from carrier', created_at: '2026-03-13T14:45:00Z', updated_by: 'Det. Chen' },
				{ id: 5, case_id: null, title: 'Damaged License Plate', type: 'Physical', serial: 'EVD-005', location: 'Del Perro Pier Parking', stash_id: '', stored: false, notes: 'Partial plate recovered from hit-and-run', created_at: '2026-03-12T16:20:00Z', updated_by: 'Ofc. Garcia' },
			];
			total = 5;
			return;
		}
		await loadEvidence(1);
	});
</script>

<div class="evidence-page">
	<!-- Topbar -->
	<div class="topbar">
		<div class="search-box">
			<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
			<input
				type="text"
				placeholder="Search by title, serial, location, stash..."
				bind:value={searchQuery}
				onkeydown={(event) => {
					if (event.key === "Enter") loadEvidence(1);
				}}
			/>
		</div>
		<button class="action-btn" onclick={() => loadEvidence(1)}>
			Search
		</button>
		<button class="create-btn" onclick={() => {
			resetCreateForm();
			const nextNum = total + 1;
			createForm.serial = `EVD-${String(nextNum).padStart(3, "0")}`;
			createForm.stashId = `LOCKER-${String(nextNum).padStart(3, "0")}`;
			// Auto-populate Case ID from most recent case in evidence list
			const latestCaseId = items.reduce((max, item) => {
				const id = item.case_id ? Number(item.case_id) : 0;
				return id > max ? id : max;
			}, 0);
			if (latestCaseId > 0) createForm.caseId = String(latestCaseId);
			showCreate = true;
		}}>
			New Evidence
		</button>
	</div>

	<!-- Status Toast -->
	{#if statusMessage}
		<div class="status-toast {statusMessage.type}">
			{statusMessage.text}
		</div>
	{/if}

	<!-- Main 2-column grid -->
	<div class="main-grid">
		<!-- Evidence List (left) -->
		<div class="list-panel">
			{#if isLoading}
				<div class="empty-state">Loading evidence...</div>
			{:else if items.length === 0}
				<div class="empty-state">No evidence found.</div>
			{:else}
				<div class="table-header">
					<span class="col-title">Title</span>
					<span class="col-type">Type</span>
					<span class="col-serial">Serial</span>
					<span class="col-case">Case</span>
					<span class="col-report">Report</span>
					<span class="col-location">Location</span>
					<span class="col-stored">Status</span>
					<span class="col-date">Date</span>
				</div>
				{#each items as item}
					<button class="table-row" class:selected={selectedEvidenceId === item.id} onclick={() => selectEvidence(item)}>
						<span class="col-title">{item.title}</span>
						<span class="col-type"><span class="type-badge">{item.type}</span></span>
						<span class="col-serial">{item.serial || "---"}</span>
						<span class="col-case">
							{#if item.case_id}
								<!-- svelte-ignore a11y_click_events_have_key_events -->
								<span class="nav-link" role="button" tabindex="-1" onclick={(e) => { e.stopPropagation(); navigateTo("Cases"); }}>#{item.case_id}</span>
							{:else}
								---
							{/if}
						</span>
						<span class="col-report">
							{#if item.report_id}
								<!-- svelte-ignore a11y_click_events_have_key_events -->
								<span class="nav-link" role="button" tabindex="-1" onclick={(e) => { e.stopPropagation(); navigateTo("Reports"); }}>#{item.report_id}</span>
							{:else}
								---
							{/if}
						</span>
						<span class="col-location">{item.location || "---"}</span>
						<span class="col-stored"><span class="stored-dot" class:stored={item.stored}></span>{formatStored(item.stored)}</span>
						<span class="col-date">{item.created_at ? new Date(item.created_at).toLocaleDateString() : "---"}</span>
					</button>
				{/each}
			{/if}
			<Pagination
				currentPage={page}
				totalItems={total}
				perPage={limit}
				perPageOptions={[10, 20, 50, 100]}
				onPageChange={(p) => loadEvidence(p)}
				onPerPageChange={(pp) => { limit = pp; loadEvidence(1); }}
			/>
		</div>

		<!-- Detail Sidebar (right) -->
		<div class="detail-sidebar">
			{#if selectedEvidenceId}
				<!-- Custody Log -->
				<div class="section">
					<div class="section-title">Link Evidence</div>
					<div class="section-actions">
						<input
							class="form-input"
							placeholder="Case ID or CASE-2026-..."
							bind:value={linkCaseId}
						/>
						<button class="action-btn" onclick={handleLinkEvidenceCase}>
							Link to Case
						</button>
						<button class="action-btn" onclick={handleCreateCaseFromEvidence}>
							Create Case
						</button>
					</div>
					<div class="section-actions">
						<input
							class="form-input"
							placeholder="Report ID"
							bind:value={linkReportId}
						/>
						<button class="action-btn" onclick={handleLinkEvidenceReport}>
							Link to Report
						</button>
					</div>
					<div class="section-title" style="margin-top: 8px;">Custody Log</div>
					{#if custodyEntries.length === 0}
						<p class="muted-text">No custody updates yet.</p>
					{:else}
						<div class="custody-list">
							{#each custodyEntries as entry}
								<div class="custody-item">
									<span class="custody-action {entry.action}">{entry.action}</span>
									<span class="custody-detail">
										{#if entry.action === "viewed"}
											{entry.to_citizenid || "Unknown"}
										{:else if entry.action === "transferred"}
											{entry.from_citizenid || "?"} &rarr; {entry.to_citizenid || "?"}
										{:else}
											{entry.to_citizenid || entry.from_citizenid || ""}
										{/if}
									</span>
									<span class="custody-time">
										{entry.created_at ? new Date(entry.created_at).toLocaleString() : ""}
									</span>
									{#if entry.notes}
										<span class="custody-notes">{entry.notes}</span>
									{/if}
								</div>
							{/each}
						</div>
					{/if}
				</div>

				<!-- Transfer Evidence -->
				<div class="section">
					<div class="section-title">Transfer Evidence</div>
					<div class="transfer-row">
						<input class="form-input" placeholder="Citizen ID" bind:value={transferCitizenId} />
						<input class="form-input" placeholder="Transfer notes" bind:value={transferNotes} />
						<button class="action-btn" onclick={handleTransferEvidence}>
							Transfer
						</button>
					</div>
				</div>

				<!-- Upload Image -->
				<div class="section">
					<div class="section-title">Upload Evidence Image</div>
					<div class="upload-row">
						<input
							type="file"
							accept=".jpg,.jpeg,.png,.webp"
							class="file-input"
							onchange={(event) => {
								const input = event.target as HTMLInputElement;
								evidenceImageFile = input.files && input.files[0] ? input.files[0] : null;
							}}
						/>
						<input class="form-input" placeholder="Image label" bind:value={evidenceImageLabel} />
						<button class="create-btn" disabled={isUploading} onclick={handleUploadEvidenceImage}>
							{isUploading ? "Uploading..." : "Upload"}
						</button>
					</div>
					{#if isUploading}
						<p class="uploading-text">Uploading image, please wait...</p>
					{:else if evidenceImageFile}
						<p class="muted-text" style="margin-top:6px;">
							{evidenceImageFile.name} ({formatBytes(evidenceImageFile.size)})
						</p>
					{/if}
					{#if uploadSuccess}
						<p class="upload-success">{uploadSuccess}</p>
					{/if}
				</div>

				<!-- Open Stash -->
				{#if selectedEvidence?.stash_id}
					<div class="section">
						<div class="section-title">Evidence Stash</div>
						<div class="stash-row">
							<span class="stash-id">{selectedEvidence.stash_id}</span>
							<button class="action-btn" onclick={() => openStash(selectedEvidence.stash_id)}>
								<span class="material-icons" style="font-size:14px; margin-right:4px;">inventory_2</span>
								Open Stash
							</button>
						</div>
					</div>
				{/if}

				<!-- Uploaded Images -->
				{#if selectedEvidence?.images && selectedEvidence.images.length > 0}
					<div class="section">
						<div class="section-title">Evidence Images</div>
						<div class="image-gallery">
							{#each selectedEvidence.images as img}
								<div class="image-item">
									<button class="image-btn" onclick={() => openLightbox(img.url, img.label || 'Evidence')}>
										<img src={img.url} alt={img.label || 'Evidence'} class="evidence-thumb" />
									</button>
									<div class="image-info">
										<span class="image-label">{img.label || 'No label'}</span>
										<button class="remove-image-btn" onclick={() => handleRemoveImage(img.id)}>
											<span class="material-icons" style="font-size:14px;">close</span>
										</button>
									</div>
								</div>
							{/each}
						</div>
					</div>
				{/if}
			{:else}
				<div class="empty-detail">
					<svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" style="opacity:0.25; margin-bottom:10px;"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
					<p>Select an evidence item to view custody and uploads.</p>
				</div>
			{/if}
		</div>
	</div>
</div>

{#if showCreate}
	<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions a11y_no_noninteractive_element_interactions a11y_role_has_required_aria_props -->
	<div class="modal-backdrop" role="button" tabindex="-1" onclick={() => (showCreate = false)}>
		<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
		<div class="modal" role="dialog" aria-modal="true" onclick={(event) => event.stopPropagation()}>
			<div class="modal-header">
				<h3>New Evidence</h3>
				<button class="close-btn" onclick={() => (showCreate = false)}>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
				</button>
			</div>
			<div class="modal-body">
				<!-- Row 1: IDs + Title + Type -->
				<div class="form-grid form-grid-4">
					<div class="form-group">
						<span class="form-label">Case ID</span>
						<input bind:value={createForm.caseId} placeholder="Numeric or CASE-..." class="form-input" />
					</div>
					<div class="form-group">
						<span class="form-label">Report ID</span>
						<input bind:value={createForm.reportId} placeholder="Report ID" class="form-input" />
					</div>
					<div class="form-group">
						<span class="form-label">Title</span>
						<input bind:value={createForm.title} placeholder="Evidence title" class="form-input" />
					</div>
					<div class="form-group">
						<span class="form-label">Type</span>
						<select bind:value={createForm.type} class="form-input">
							<option value="Physical">Physical</option>
							<option value="Digital">Digital</option>
							<option value="Document">Document</option>
							<option value="Weapon">Weapon</option>
							<option value="Drug">Drug</option>
							<option value="Vehicle">Vehicle</option>
							<option value="Other">Other</option>
						</select>
					</div>
				</div>

				<!-- Row 2: Dynamic fields based on type -->
				<div class="form-grid">
					{#if typeConfig.description}
						<div class="form-group" style="grid-column: span 2;">
							<span class="form-label">Description</span>
							<input bind:value={createForm.description} placeholder={typeConfig.descriptionPlaceholder || "Describe the evidence"} class="form-input" />
						</div>
					{/if}
					{#if typeConfig.serial}
						<div class="form-group">
							<span class="form-label">{typeConfig.serialLabel || "Serial #"}</span>
							<input bind:value={createForm.serial} placeholder={typeConfig.serialPlaceholder || "Serial number"} class="form-input" />
						</div>
					{/if}
					{#if typeConfig.plate}
						<div class="form-group">
							<span class="form-label">Plate Number</span>
							<input bind:value={createForm.plateNumber} placeholder="License plate" class="form-input" />
						</div>
					{/if}
					{#if typeConfig.quantity}
						<div class="form-group">
							<span class="form-label">Quantity</span>
							<input bind:value={createForm.quantity} placeholder="Amount / weight" class="form-input" />
						</div>
					{/if}
				</div>

				<!-- Row 3: Location + conditional Stash -->
				<div class="form-grid">
					<div class="form-group" style={typeConfig.stash ? "" : "grid-column: span 3;"}>
						<span class="form-label">Location</span>
						<input bind:value={createForm.location} placeholder="Location found" class="form-input" />
					</div>
					{#if typeConfig.stash}
						<div class="form-group">
							<span class="form-label">Stash ID</span>
							<input bind:value={createForm.stashId} placeholder="LOCKER-001" class="form-input mono-input" />
						</div>
					{/if}
				</div>

				{#if typeConfig.stored}
					<label class="checkbox-label">
						<input type="checkbox" bind:checked={createForm.stored} />
						<span>Evidence is stored / secured</span>
					</label>
				{/if}
				<div class="form-group">
					<span class="form-label">Notes</span>
					<textarea rows="4" bind:value={createForm.notes} placeholder="Additional notes..." class="form-input"></textarea>
				</div>
				<div class="form-group">
					<span class="form-label">Attach Images</span>
					<input
						type="file"
						accept=".jpg,.jpeg,.png,.webp"
						multiple
						class="file-input"
						onchange={(event) => {
							const input = event.target as HTMLInputElement;
							if (input.files) {
								createImageFiles = [...createImageFiles, ...Array.from(input.files)];
							}
						}}
					/>
					{#if createImageFiles.length > 0}
						<div class="create-image-list">
							{#each createImageFiles as file, i}
								<div class="create-image-item">
									<span class="create-image-name">{file.name} ({formatBytes(file.size)})</span>
									<button class="remove-image-btn" onclick={() => { createImageFiles = createImageFiles.filter((_, idx) => idx !== i); }}>
										<span class="material-icons" style="font-size:14px;">close</span>
									</button>
								</div>
							{/each}
						</div>
					{/if}
				</div>
			</div>
			{#if evidenceError}
				<p class="error-text">{evidenceError}</p>
			{/if}
			<div class="modal-footer">
				<button class="cancel-btn" onclick={() => (showCreate = false)}>Cancel</button>
				<button class="save-btn" onclick={handleCreateEvidence}>Create Evidence</button>
			</div>
		</div>
	</div>
{/if}

{#if lightboxUrl}
	<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions a11y_no_noninteractive_element_interactions -->
	<div class="lightbox-overlay" onclick={closeLightbox} onkeydown={(e) => { if (e.key === 'Escape') closeLightbox(); }}>
		<div class="lightbox-content" onclick={(e) => e.stopPropagation()}>
			<div class="lightbox-header">
				<span class="lightbox-label">{lightboxLabel}</span>
				<button class="close-btn" onclick={closeLightbox}>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
				</button>
			</div>
			<img src={lightboxUrl} alt={lightboxLabel} class="lightbox-image" />
		</div>
	</div>
{/if}

<style>
	/* ── Page ── */
	.evidence-page {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
		overflow: hidden;
	}

	/* ── Topbar ── */
	.topbar {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 0 16px;
		height: 42px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.search-box {
		display: flex;
		align-items: center;
		gap: 8px;
		background: transparent;
		border: none;
		padding: 0;
		flex: 1;
		max-width: 400px;
		color: rgba(255, 255, 255, 0.2);
	}

	.search-box input {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.8);
		font-size: 12px;
		padding: 0;
		width: 100%;
		outline: none;
	}

	.search-box input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	/* ── Main Grid ── */
	.main-grid {
		display: grid;
		grid-template-columns: 2fr 1fr;
		gap: 0;
		flex: 1;
		min-height: 0;
	}

	/* ── List Panel ── */
	.list-panel {
		background: transparent;
		border: none;
		border-right: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.table-header {
		display: grid;
		grid-template-columns: 2fr 0.7fr 1fr 0.6fr 0.6fr 1.3fr 0.9fr 0.9fr;
		gap: 8px;
		padding: 8px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.35);
		flex-shrink: 0;
	}

	.table-row {
		display: grid;
		grid-template-columns: 2fr 0.7fr 1fr 0.6fr 0.6fr 1.3fr 0.9fr 0.9fr;
		gap: 8px;
		padding: 7px 16px;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		background: transparent;
		color: rgba(255, 255, 255, 0.85);
		font-size: 11px;
		text-align: left;
		cursor: pointer;
		transition: background 0.1s;
		align-items: center;
		width: 100%;
	}

	.table-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.table-row.selected {
		background: rgba(var(--accent-rgb), 0.04);
		border-left: 2px solid rgba(var(--accent-rgb), 0.4);
	}

	.table-row .col-title {
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.table-row .col-location {
		color: rgba(255, 255, 255, 0.35);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.table-row .col-serial,
	.table-row .col-case,
	.table-row .col-report,
	.table-row .col-date {
		color: rgba(255, 255, 255, 0.35);
	}

	.nav-link {
		color: rgba(var(--accent-rgb), 0.6);
		cursor: pointer;
		transition: all 0.1s;
	}

	.nav-link:hover {
		color: rgba(var(--accent-rgb), 0.9);
		text-decoration: underline;
	}

	.type-badge {
		display: inline-block;
		font-size: 9px;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: rgba(255, 255, 255, 0.35);
		border: 1px solid rgba(255, 255, 255, 0.06);
		padding: 1px 5px;
		border-radius: 3px;
		background: rgba(255, 255, 255, 0.02);
	}

	.col-stored {
		display: flex;
		align-items: center;
		gap: 5px;
		font-size: 10px;
		color: rgba(255, 255, 255, 0.35);
	}

	.stored-dot {
		width: 5px;
		height: 5px;
		border-radius: 50%;
		background: rgba(239, 68, 68, 0.5);
		flex-shrink: 0;
	}

	.stored-dot.stored {
		background: rgba(16, 185, 129, 0.6);
	}

	.empty-state {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 40px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
		flex: 1;
	}

	/* ── Detail Sidebar ── */
	.detail-sidebar {
		display: flex;
		flex-direction: column;
		gap: 0;
		overflow-y: auto;
	}

	.section {
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 0;
		padding: 12px 16px;
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
		margin-bottom: 8px;
	}

	.section-actions {
		display: flex;
		gap: 6px;
		align-items: center;
		flex-wrap: wrap;
		margin-bottom: 8px;
	}

	.section-actions .form-input {
		flex: 1;
		min-width: 70px;
	}

	.empty-detail {
		background: transparent;
		border: none;
		border-radius: 0;
		padding: 40px 16px;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		text-align: center;
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
		flex: 1;
	}

	.empty-detail p {
		margin: 0;
	}

	/* ── Custody ── */
	.custody-list {
		display: flex;
		flex-direction: column;
		gap: 0;
	}

	.custody-item {
		display: grid;
		grid-template-columns: 70px 1fr auto;
		gap: 4px 6px;
		font-size: 10px;
		padding: 5px 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		align-items: center;
	}

	.custody-action {
		color: rgba(255, 255, 255, 0.5);
		font-weight: 600;
		text-transform: uppercase;
		font-size: 9px;
		letter-spacing: 0.5px;
	}

	.custody-action.viewed { color: rgba(var(--accent-rgb), 0.6); }
	.custody-action.collected { color: rgba(16, 185, 129, 0.6); }
	.custody-action.transferred { color: rgba(251, 191, 36, 0.6); }

	.custody-detail {
		color: rgba(255, 255, 255, 0.4);
		font-family: monospace;
		font-size: 10px;
	}

	.custody-time {
		color: rgba(255, 255, 255, 0.2);
		font-size: 9px;
		white-space: nowrap;
	}

	.custody-notes {
		grid-column: 1 / -1;
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	/* ── Transfer / Upload Rows ── */
	.transfer-row {
		display: flex;
		gap: 6px;
		align-items: center;
		flex-wrap: wrap;
	}

	.transfer-row .form-input {
		flex: 1;
		min-width: 80px;
	}

	.upload-row {
		display: flex;
		gap: 6px;
		align-items: center;
		flex-wrap: wrap;
	}

	.upload-row .form-input {
		flex: 1;
		min-width: 80px;
	}

	.file-input {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.35);
		max-width: 170px;
	}

	.file-input::file-selector-button {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 3px 8px;
		color: rgba(255, 255, 255, 0.5);
		font-size: 10px;
		cursor: pointer;
		margin-right: 6px;
	}

	.muted-text {
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
		margin: 0;
	}

	.upload-success {
		color: rgba(110, 231, 183, 0.8);
		font-size: 10px;
		margin: 4px 0 0 0;
	}

	.uploading-text {
		color: rgba(251, 191, 36, 0.8);
		font-size: 10px;
		margin: 4px 0 0 0;
		animation: pulse-text 1.5s ease-in-out infinite;
	}

	@keyframes pulse-text {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.5; }
	}

	.create-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.image-gallery {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
		gap: 6px;
	}

	.image-item {
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 3px;
		overflow: hidden;
	}

	.evidence-thumb {
		width: 100%;
		height: 70px;
		object-fit: cover;
		display: block;
		cursor: pointer;
	}

	.image-info {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 3px 5px;
	}

	.image-label {
		font-size: 9px;
		color: rgba(255, 255, 255, 0.4);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		flex: 1;
	}

	.remove-image-btn {
		background: none;
		border: none;
		color: rgba(255, 255, 255, 0.2);
		cursor: pointer;
		padding: 2px;
		display: flex;
		align-items: center;
		transition: color 0.1s;
	}

	.remove-image-btn:hover {
		color: rgba(239, 68, 68, 0.7);
	}

	.image-btn {
		background: none;
		border: none;
		padding: 0;
		cursor: pointer;
		display: block;
		width: 100%;
	}

	/* ── Stash ── */
	.stash-row {
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.stash-id {
		font-size: 11px;
		font-family: monospace;
		color: rgba(255, 255, 255, 0.5);
		background: rgba(255, 255, 255, 0.02);
		padding: 4px 8px;
		border-radius: 3px;
		border: 1px solid rgba(255, 255, 255, 0.04);
		flex: 1;
	}

	/* ── Lightbox ── */
	.lightbox-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.88);
		backdrop-filter: blur(8px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 200;
	}

	.lightbox-content {
		max-width: 90vw;
		max-height: 90vh;
		display: flex;
		flex-direction: column;
		background: var(--card-dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 6px;
		overflow: hidden;
	}

	.lightbox-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 8px 12px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.lightbox-label {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.6);
		font-weight: 500;
	}

	.lightbox-image {
		max-width: 85vw;
		max-height: 80vh;
		object-fit: contain;
		display: block;
	}

	/* ── Create Modal Image List ── */
	.create-image-list {
		display: flex;
		flex-direction: column;
		gap: 2px;
		margin-top: 4px;
	}

	.create-image-item {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 3px 6px;
		background: transparent;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		border-radius: 0;
	}

	.create-image-name {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.5);
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		flex: 1;
	}

	/* ── Buttons ── */
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
		white-space: nowrap;
	}

	.action-btn:hover {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.create-btn {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		background: rgba(16, 185, 129, 0.06);
		color: rgba(52, 211, 153, 0.7);
		border: 1px solid rgba(16, 185, 129, 0.1);
		padding: 4px 10px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
		white-space: nowrap;
	}

	.create-btn:hover {
		background: rgba(16, 185, 129, 0.12);
		color: rgba(110, 231, 183, 0.9);
	}

	/* ── Form Inputs ── */
	.form-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		outline: none;
		transition: border-color 0.1s;
	}

	.form-input:focus {
		border-color: rgba(255, 255, 255, 0.1);
	}

	.form-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	textarea.form-input {
		resize: vertical;
		min-height: 60px;
		font-family: inherit;
	}

	/* ── Status Toast ── */
	.status-toast {
		padding: 5px 12px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		flex-shrink: 0;
		margin: 0 16px;
	}

	.status-toast.success {
		background: rgba(16, 185, 129, 0.06);
		color: rgba(110, 231, 183, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.status-toast.error {
		background: rgba(239, 68, 68, 0.06);
		color: rgba(252, 165, 165, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	/* ── Modal ── */
	.modal-backdrop {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.7);
		backdrop-filter: blur(4px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 100;
	}

	.modal {
		background: var(--card-dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 6px;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
		width: 100%;
		max-width: 700px;
		display: flex;
		flex-direction: column;
	}

	.modal-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 10px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.modal-header h3 {
		margin: 0;
		font-size: 13px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}

	.close-btn {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px;
		color: rgba(255, 255, 255, 0.3);
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.1s;
	}

	.close-btn:hover {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.modal-body {
		padding: 14px 16px;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.form-grid {
		display: grid;
		grid-template-columns: 1fr 1fr 1fr;
		gap: 8px;
	}

	.form-grid-4 {
		grid-template-columns: 1fr 1fr 2fr 1fr;
	}

	.mono-input {
		font-family: monospace;
		letter-spacing: 0.5px;
	}

	.form-group {
		display: flex;
		flex-direction: column;
		gap: 3px;
	}

	.form-label {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(255, 255, 255, 0.35);
	}

	.checkbox-label {
		display: flex;
		flex-direction: row;
		align-items: center;
		gap: 6px;
		cursor: pointer;
		font-size: 11px;
		color: rgba(255, 255, 255, 0.5);
	}

	.checkbox-label input[type="checkbox"] {
		accent-color: rgba(52, 211, 153, 0.8);
		width: 13px;
		height: 13px;
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 8px;
		padding: 10px 16px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}

	.cancel-btn {
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

	.cancel-btn:hover {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.save-btn {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		background: rgba(16, 185, 129, 0.06);
		color: rgba(52, 211, 153, 0.7);
		border: 1px solid rgba(16, 185, 129, 0.1);
		padding: 4px 12px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.save-btn:hover {
		background: rgba(16, 185, 129, 0.12);
		color: rgba(110, 231, 183, 0.9);
	}

	.error-text {
		color: rgba(252, 165, 165, 0.8);
		font-size: 10px;
		padding: 0 16px;
		margin: 0;
	}

	/* ── Scrollbar ── */
	.detail-sidebar::-webkit-scrollbar {
		width: 4px;
	}

	.detail-sidebar::-webkit-scrollbar-track {
		background: transparent;
	}

	.detail-sidebar::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	/* ── Responsive ── */
	@media (max-width: 1024px) {
		.main-grid {
			grid-template-columns: 1fr;
		}

		.list-panel {
			border-right: none;
			border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		}

		.topbar {
			flex-wrap: wrap;
		}

		.search-box {
			max-width: 100%;
		}
	}
</style>
