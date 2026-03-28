<script lang="ts">
	import { onMount, onDestroy, untrack } from "svelte";
	import type { Report, SearchResult, ReportVehicle } from "../interfaces/IReportEditor";
	import type { Charge } from "../interfaces/ICharges";

	// Import components
	import ReportEditorHeader from "../components/ReportEditorHeader.svelte";
	import ReportMetadata from "../components/report-editor/ReportMetadata.svelte";
	import TagsManager from "../components/report-editor/TagsManager.svelte";
	import OfficersManager from "../components/report-editor/OfficersManager.svelte";
	import SuspectsManager from "../components/report-editor/SuspectsManager.svelte";
	import VictimsManager from "../components/report-editor/VictimsManager.svelte";
	import EvidenceManager from "../components/report-editor/EvidenceManager.svelte";
	import ChargesManager from "../components/report-editor/ChargesManager.svelte";
	import VehiclesManager from "../components/report-editor/VehiclesManager.svelte";
	import ReportTextEditor from "../components/report-editor/ReportTextEditor.svelte";
	import PersonSearchModal from "../components/report-editor/PersonSearchModal.svelte";
	import ImageUploadModal from "../components/report-editor/ImageUploadModal.svelte";

	// Import services
	import { createReportService } from "../services/reportService.svelte";
	import { createSearchService } from "../services/searchService.svelte";
	import { createEvidenceService } from "../services/evidenceService.svelte";
	import { createCaseService } from "../services/caseService.svelte";
	import { createTagService } from "../services/tagService.svelte";
	import { createReportEditorUIService } from "../services/reportEditorUIService.svelte";
	import { createReportEditorHandlers } from "@/handlers/reportEditorHandlers";
	import type { createInstanceStateService } from "../services/instanceStateService.svelte";
	import { usePersistence } from "../hooks/usePersistence.svelte";
	import type { ReportPageData } from "../schemas/persistenceSchema";
	import { fetchNui } from "../utils/fetchNui";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { globalNotifications } from "../services/notificationService.svelte";
	import { compressImage } from "../services/uploadService";
	import { createCollabService, type CollabEditor } from "../services/collabService.svelte";
	import CollabPresenceBar from "../components/report-editor/CollabPresenceBar.svelte";

	import type { createTabService } from "../services/tabService.svelte";
	import { getReportTypesForJob, type MDTTab } from "../constants";

	import type { JobType } from "../interfaces/IUser";

	const {
		reportId,
		onClose,
		instanceStateService,
		tabService,
		jobType = 'leo',
	}: {
		reportId: string | null;
		onClose: () => void;
		instanceStateService: ReturnType<typeof createInstanceStateService>;
		tabService?: ReturnType<typeof createTabService>;
		jobType?: JobType;
	} = $props();

	const isEMS = $derived(jobType === 'ems');

	function navigateTo(tab: MDTTab) {
		if (!tabService) return;
		tabService.setActiveTab(tab);
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, tab);
		}
	}

	// Initialize services
	const reportService = createReportService();
	const searchService = createSearchService();
	const evidenceService = createEvidenceService() as ReturnType<
		typeof createEvidenceService
	> & {
		linkEvidenceToCase: (
			evidenceId: number,
			caseId: number,
			reportId?: number,
		) => Promise<{ success: boolean }>;
		createCaseFromEvidence: (
			evidenceId: number,
			reportId?: number,
		) => Promise<{ success: boolean; caseId?: number }>;
	};
	const caseService = createCaseService();
	const tagService = createTagService();
	const reportEditorUI = createReportEditorUIService();

	// Initialize collaboration service
	const collabService = createCollabService();
	let collabEditors = $state<CollabEditor[]>([]);
	let collabJoined = $state(false);

	// Initialize persistence hook
	const persistence = usePersistence(instanceStateService, "report-page");

	const defaultReportType = getReportTypesForJob(jobType)[0] || "Incident Report";
	let report: Report = $state({ ...reportService.createEmptyReport(), type: defaultReportType });
	let penalCodes = $state<Charge[]>([]);
	let reductionOffers = $state<number[]>([]);
	let isPersistenceEnabled = $state(true); // Control whether persistence is active
	let isSaving = $state(false); // Flag to track save state

	// Bench warrant modal state
	let benchWarrantModal = $state<{ open: boolean; suspect: Report["involved"]["suspects"][number] | null; reason: string; submitting: boolean }>({
		open: false,
		suspect: null,
		reason: '',
		submitting: false,
	});

	// Teleport action: moves node to document.body to escape zoom container
	function teleport(node: HTMLElement) {
		document.body.appendChild(node);
		return {
			destroy() {
				if (node.parentNode) node.parentNode.removeChild(node);
			}
		};
	}
	function showStatus(text: string, type: "success" | "error" | "info" = "success") {
		globalNotifications.notify(text, type);
	}

	interface ServerTemplate {
		id: number;
		name: string;
		type: string;
		content: string;
	}

	let reportTemplates: ServerTemplate[] = $state([]);
	let showTemplateMenu = $state(false);

	async function loadReportTemplates() {
		try {
			const response = await fetchNui<ServerTemplate[]>(
				NUI_EVENTS.SETTINGS.GET_REPORT_TEMPLATES,
				{ jobType },
				[],
			);
			if (Array.isArray(response)) {
				reportTemplates = response;
			}
		} catch (error) {
			console.error("Failed to load report templates:", error);
		}
	}

	function getTemplatesForType(type: string): ServerTemplate[] {
		return reportTemplates.filter((t) => t.type === type);
	}

	function insertTemplate() {
		const matching = getTemplatesForType(report.type);
		if (matching.length === 0) {
			showStatus("No templates configured for this report type", "error");
			return;
		}
		if (matching.length === 1) {
			handlers.handleContentUpdate(matching[0].content);
			showStatus(`Template "${matching[0].name}" inserted`);
			return;
		}
		// Multiple templates - show picker
		showTemplateMenu = !showTemplateMenu;
	}

	function selectTemplate(template: ServerTemplate) {
		handlers.handleContentUpdate(template.content);
		showStatus(`Template "${template.name}" inserted`);
		showTemplateMenu = false;
	}

	// Create a promise for loading report data
	let reportPromise = $state<Promise<Report>>();

	onMount(() => {
		// Create the loading promise
		reportPromise = initializeReportData();
		loadPenalCodes();
		loadJailFinesConfig();
		loadReportTemplates();

		// Setup collaboration listeners and callbacks
		collabService.setupListeners();
		collabService.onEditorsChanged((editors) => {
			// Detect joins and leaves by comparing old vs new
			const oldNames = new Set(collabEditors.map(e => e.name));
			const newNames = new Set(editors.map(e => e.name));
			for (const editor of editors) {
				if (!oldNames.has(editor.name)) {
					showStatus(`${editor.name} joined the report`, "info");
				}
			}
			for (const old of collabEditors) {
				if (!newNames.has(old.name)) {
					showStatus(`${old.name} left the report`, "info");
				}
			}
			collabEditors = editors;
		});
		collabService.onRemoteDataUpdate((dataType, data) => {
			lastSentStructuredData[dataType] = JSON.stringify(data);
			if (dataType === 'title') report.title = data;
			else if (dataType === 'type') report.type = data;
			else if (dataType === 'officers') report.involved.officers = data;
			else if (dataType === 'suspects') report.involved.suspects = data;
			else if (dataType === 'victims') report.involved.victims = data;
			else if (dataType === 'evidence') report.evidence = data;
			else if (dataType === 'charges') report.charges = data;
			else if (dataType === 'vehicles') report.vehicles = data;
			else if (dataType === 'tags') report.tags = data;
		});

		// Join collab session if editing an existing report
		if (reportId) {
			collabService.joinSession(reportId).then((sessionState) => {
				if (sessionState.lastStructuredData) {
					const sd = sessionState.lastStructuredData;
					if (sd.title) report.title = sd.title;
					if (sd.officers) report.involved.officers = sd.officers;
					if (sd.suspects) report.involved.suspects = sd.suspects;
					if (sd.victims) report.involved.victims = sd.victims;
					if (sd.evidence) report.evidence = sd.evidence;
					if (sd.charges) report.charges = sd.charges;
					if (sd.vehicles) report.vehicles = sd.vehicles;
					if (sd.tags) report.tags = sd.tags;
				}
				collabJoined = true;
			});
		} else {
			collabJoined = true;
		}
	});

	onDestroy(() => {
		// Leave collab session
		collabService.leaveSession();

		// Only save current report data to persistence when component is destroyed and persistence is enabled
		if (isPersistenceEnabled && !isSaving) {
			saveCurrentData();
		}
	});

	// Strip large data URLs from evidence images before persisting to avoid storage bloat
	function stripDataUrlsFromReport(r: Report): Report {
		return {
			...r,
			evidence: r.evidence.map((e) => ({
				...e,
				images: e.images.filter((img) => !img.startsWith("data:")),
			})),
		};
	}

	function buildPersistenceData(): ReportPageData {
		return {
			report: stripDataUrlsFromReport(report),
			tags: tagService.state.availableTags.map((t) => t.name),
			searchQuery: reportEditorUI.state.searchQuery,
			activeFilters: [],
			uiState: {
				showTagDropdown: reportEditorUI.state.showTagDropdown,
				showOfficerSearch: reportEditorUI.state.showOfficerSearch,
				showSuspectSearch: reportEditorUI.state.showSuspectSearch,
				showVictimSearch: reportEditorUI.state.showVictimSearch,
				selectedEvidenceId: reportEditorUI.state.selectedEvidenceId,
			},
		};
	}

	// Auto-save when report data changes (only when persistence is enabled and not saving)
	$effect(() => {
		// Track only the triggers we care about
		const _report = report;
		const _initialized = persistence.isInitialized;
		const _enabled = isPersistenceEnabled;
		const _saving = isSaving;

		if (_initialized && _report && _enabled && !_saving) {
			// Build and save without tracking reactive reads inside
			untrack(() => {
				persistence.debouncedSave(buildPersistenceData());
			});
		}
	});

	// Sync content on local editor typing only (not on remote updates)
	// Sync structured data to collab - debounced with diff check to prevent echo loops
	let structuredDataSyncTimer: ReturnType<typeof setTimeout> | null = null;
	let lastSentStructuredData: Record<string, string> = {};
	let structuredDataReady = $state(false);

	// Delay structured data sync to avoid initial load echo
	$effect(() => {
		if (collabService.isActive && !structuredDataReady) {
			const timer = setTimeout(() => { structuredDataReady = true; }, 1000);
			return () => clearTimeout(timer);
		}
	});

	function scheduleStructuredDataSync() {
		if (!structuredDataReady || !collabService.isActive) return;
		if (structuredDataSyncTimer) clearTimeout(structuredDataSyncTimer);
		structuredDataSyncTimer = setTimeout(() => {
			if (!collabService.isActive) return;
			const fields: Record<string, any> = {
				title: report.title,
				officers: report.involved.officers,
				suspects: report.involved.suspects,
				victims: report.involved.victims,
				evidence: report.evidence,
				charges: report.charges,
				vehicles: report.vehicles,
				tags: report.tags,
			};
			for (const [key, value] of Object.entries(fields)) {
				const serialized = JSON.stringify(value);
				if (lastSentStructuredData[key] !== serialized) {
					lastSentStructuredData[key] = serialized;
					collabService.syncData(key, value);
				}
			}
		}, 1000);
	}

	// Single $effect for all structured data - fires on any change, debounced
	$effect(() => {
		const _ = [report.title, report.involved.officers, report.involved.suspects,
			report.involved.victims, report.evidence, report.charges, report.vehicles, report.tags];
		if (structuredDataReady && collabService.isActive) {
			untrack(() => scheduleStructuredDataSync());
		}
	});

	// Watch for instance changes and reload data
	$effect(() => {
		if (persistence.hasInstanceChanged && persistence.isInitialized) {
			loadPersistedData();
		}
	});

	function loadPersistedData(): void {
		// Don't load persisted data if persistence is disabled or we're saving
		if (!isPersistenceEnabled || isSaving) {
			return;
		}

		const persistedData = persistence.loadPersistedData();

		if (persistedData) {
			// Load the persisted report data
			if (persistedData.report) {
				// Only restore persisted data when:
				// - Editing a specific report AND the persisted data matches that report
				// - Creating a new report AND the persisted data is also a new (unsaved) report
				const persistedId = persistedData.report.reportId;
				const isNewReport = !reportId;
				const persistedIsNew = !persistedId;
				const idsMatch = reportId && persistedId === reportId;

				if (idsMatch || (isNewReport && persistedIsNew)) {
					report = persistedData.report;
				}
			}

			// Load the UI state
			if (persistedData.uiState) {
				reportEditorUI.state.showTagDropdown =
					persistedData.uiState.showTagDropdown;
				reportEditorUI.state.showOfficerSearch =
					persistedData.uiState.showOfficerSearch;
				reportEditorUI.state.showSuspectSearch =
					persistedData.uiState.showSuspectSearch;
				reportEditorUI.state.showVictimSearch =
					persistedData.uiState.showVictimSearch;
				reportEditorUI.state.selectedEvidenceId =
					persistedData.uiState.selectedEvidenceId;
			}

			// Load available tags if persisted (convert string[] back to TagInfo[])
			if (persistedData.tags && persistedData.tags.length > 0 && tagService.state.availableTags.length === 0) {
				tagService.state.availableTags = persistedData.tags.map((t) => ({
					name: t,
					color: "#6b7280",
				}));
			}
		}
	}

	function saveCurrentData(): void {
		// Don't save if persistence is disabled or we're saving
		if (!isPersistenceEnabled || isSaving) {
			return;
		}

		persistence.saveData(buildPersistenceData());
	}

	async function initializeReportData(): Promise<Report> {
		// Reset persistence state for new initialization
		isPersistenceEnabled = true;
		isSaving = false;

		// Load available tags
		await tagService.loadAvailableTags();

		// Initialize report
		const initializedReport =
			await reportService.initializeReport(reportId);
		report = initializedReport;

		// Load persisted data for this instance after base initialization
		loadPersistedData();

		// Mark persistence as initialized so effects can start working
		persistence.initialize();

		return initializedReport;
	}

	// Create handlers
	const handlers = createReportEditorHandlers(
		() => report,
		(newReport) => {
			report = newReport;
		},
		reportService,
		tagService,
		reportEditorUI,
	);

	async function issueWarrant(suspect: Report["involved"]["suspects"][number]) {
		if (!suspect.citizenid) return;
		if (!report.reportId) {
			showStatus("Save the report before issuing warrants", "error");
			return;
		}
		try {
			await reportService.issueWarrant(report.reportId, suspect.citizenid);
			handlers.handleUpdateSuspect({
				...suspect,
				warrantActive: true,
			});
			await fetchNui(NUI_EVENTS.DASHBOARD.GET_ACTIVE_WARRANTS);
			showStatus(`Warrant issued for ${suspect.fullName}`);
		} catch (error: any) {
			showStatus(error?.message || `Failed to issue warrant for ${suspect.fullName}`, "error");
		}
	}

	async function closeWarrant(suspect: Report["involved"]["suspects"][number]) {
		if (!suspect.citizenid) return;
		if (!report.reportId) {
			showStatus("Save the report before closing warrants", "error");
			return;
		}
		try {
			await reportService.closeWarrant(report.reportId, suspect.citizenid);
			handlers.handleUpdateSuspect({
				...suspect,
				warrantActive: false,
			});
			await fetchNui(NUI_EVENTS.DASHBOARD.GET_ACTIVE_WARRANTS);
			showStatus(`Warrant closed for ${suspect.fullName}`);
		} catch (error: any) {
			showStatus(error?.message || `Failed to close warrant for ${suspect.fullName}`, "error");
		}
	}

	// Functions that interact with services
	async function handleSearch() {
		if (!reportEditorUI.state.searchQuery.trim()) {
			searchService.clearResults();
			return;
		}

		try {
			if (reportEditorUI.state.activeSearch === "officers") {
				await searchService.searchOfficers(
					reportEditorUI.state.searchQuery,
				);
			} else if (
				reportEditorUI.state.activeSearch === "suspects" ||
				reportEditorUI.state.activeSearch === "victims"
			) {
				await searchService.searchPlayers(
					reportEditorUI.state.searchQuery,
				);
			}
		} catch {
			showStatus("Search failed", "error");
		}
	}

	async function handleSendToJail(citizenid: string, months: number) {
		try {
			const result = await reportService.sendToJail(citizenid, months);
			showStatus(result.message || `Sent to jail for ${months} months`);
		} catch {
			showStatus("Failed to send to jail", "error");
		}
	}

	async function handleGiveCitation(citizenid: string, fine: number) {
		try {
			const result = await reportService.giveCitation(citizenid, fine, report.reportId);
			showStatus(result.message || `Citation issued: $${fine.toLocaleString()}`);
		} catch {
			showStatus("Failed to issue citation", "error");
		}
	}

	async function loadPenalCodes() {
		try {
			penalCodes = await reportService.getCharges();
		} catch {
			showStatus("Failed to load penal codes", "error");
		}
	}

	async function loadJailFinesConfig() {
		try {
			const config = await fetchNui<{ reductionOffers?: number[]; maxFineAmount?: number }>(
				NUI_EVENTS.SETTINGS.GET_JAIL_FINES_CONFIG,
				{},
				{ reductionOffers: [10, 25, 50], maxFineAmount: 100000 },
			);
			if (config && Array.isArray(config.reductionOffers)) {
				reductionOffers = config.reductionOffers;
			}
		} catch {
			// Non-critical - reduction buttons just won't show
		}
	}

	async function issueBolo(suspect: Report["involved"]["suspects"][number]) {
		if (!suspect.citizenid) return;
		if (!report.reportId) {
			showStatus("Save the report before issuing a BOLO", "error");
			return;
		}
		try {
			const payload = {
				type: "citizen" as const,
				subjectId: suspect.citizenid,
				subjectName: suspect.fullName,
				reportId: report.reportId ? Number(report.reportId) : undefined,
				notes: `BOLO issued from report ${report.reportId || "(unsaved)"}. ${report.title || ""}`.trim(),
			};
			const response = await fetchNui(NUI_EVENTS.CITIZEN.CREATE_BOLO, payload);
			if (response?.success) {
				showStatus(`BOLO issued for ${suspect.fullName}`);
			} else {
				showStatus(response?.message || "Failed to issue BOLO", "error");
			}
		} catch {
			showStatus("Failed to issue BOLO", "error");
		}
	}

	function openBenchWarrantModal(suspect: Report["involved"]["suspects"][number]) {
		if (!suspect.citizenid) return;
		if (!report.reportId) {
			showStatus("Save the report before requesting a bench warrant", "error");
			return;
		}
		benchWarrantModal = { open: true, suspect, reason: '', submitting: false };
	}

	async function submitBenchWarrant() {
		const suspect = benchWarrantModal.suspect;
		if (!suspect || !suspect.citizenid || !report.reportId) return;

		const reason = benchWarrantModal.reason.trim();
		if (!reason) {
			showStatus("A reason is required for bench warrant requests", "error");
			return;
		}

		benchWarrantModal.submitting = true;
		try {
			const suspectCharges = report.charges
				.filter((c) => c.citizenid === suspect.citizenid)
				.map((c) => c.charge || c.title || 'Unknown Charge');

			const payload = {
				citizenid: suspect.citizenid,
				citizen_name: suspect.fullName,
				charges: JSON.stringify(suspectCharges),
				reason,
				linked_report_id: report.reportId ? Number(report.reportId) : null,
			};

			const response = await fetchNui(NUI_EVENTS.DOJ.CREATE_WARRANT_REQUEST, payload);
			if (response?.success) {
				showStatus(`Bench warrant request submitted for ${suspect.fullName}`);
				benchWarrantModal = { open: false, suspect: null, reason: '', submitting: false };
			} else {
				showStatus(response?.error || "Failed to submit bench warrant request", "error");
			}
		} catch {
			showStatus("Failed to submit bench warrant request", "error");
		} finally {
			benchWarrantModal.submitting = false;
		}
	}

	function closeBenchWarrantModal() {
		benchWarrantModal = { open: false, suspect: null, reason: '', submitting: false };
	}

	async function issueVehicleBolo(vehicle: ReportVehicle) {
		if (!vehicle.plate) return;
		if (!report.reportId) {
			showStatus("Save the report before issuing a BOLO", "error");
			return;
		}
		try {
			const payload = {
				type: "vehicle" as const,
				subjectId: vehicle.plate,
				subjectName: `${vehicle.plate} - ${vehicle.vehicle_label || "Unknown Vehicle"}`,
				reportId: report.reportId ? Number(report.reportId) : undefined,
				notes: `Vehicle BOLO issued from report ${report.reportId || "(unsaved)"}. ${report.title || ""}. Owner: ${vehicle.owner_name || "Unknown"}.`.trim(),
			};
			const response = await fetchNui(NUI_EVENTS.CITIZEN.CREATE_BOLO, payload);
			if (response?.success) {
				showStatus(`Vehicle BOLO issued for ${vehicle.plate}`);
			} else {
				showStatus(response?.message || "Failed to issue vehicle BOLO", "error");
			}
		} catch {
			showStatus("Failed to issue vehicle BOLO", "error");
		}
	}

	async function triggerSuspectMugshot(suspect: Report["involved"]["suspects"][number]) {
		if (!suspect.citizenid) return;
		try {
			const result = await fetchNui<{ success: boolean; message?: string; imageUrl?: string }>(
				NUI_EVENTS.CITIZEN.TRIGGER_SUSPECT_MUGSHOT,
				{ citizenid: suspect.citizenid },
				{ success: true, message: "Mugshot captured", imageUrl: "" },
			);
			if (result.success) {
				if (result.imageUrl) {
					const suspectIndex = report.involved.suspects.findIndex(
						(s) => s.citizenid === suspect.citizenid,
					);
					if (suspectIndex !== -1) {
						report.involved.suspects[suspectIndex] = {
							...report.involved.suspects[suspectIndex],
							profileImage: result.imageUrl,
						};
						report = { ...report };
					}
				}
				showStatus(result.message || `Mugshot captured for ${suspect.fullName}`);
			} else {
				showStatus(result.message || "Failed to capture mugshot", "error");
			}
		} catch {
			showStatus("Failed to capture mugshot", "error");
		}
	}

	async function addSuspectFingerprint(suspect: Report["involved"]["suspects"][number]) {
		if (!suspect.citizenid) return;
		try {
			const result = await fetchNui<{ success: boolean; message?: string; fingerprint?: string }>(
				NUI_EVENTS.CITIZEN.ADD_SUSPECT_FINGERPRINT,
				{ citizenid: suspect.citizenid },
				{ success: true, message: "Fingerprint scan initiated", fingerprint: "AB-1234-5678" },
			);
			if (result.success && result.fingerprint) {
				// Fingerprint already on file
				const suspectIndex = report.involved.suspects.findIndex(
					(s) => s.citizenid === suspect.citizenid,
				);
				if (suspectIndex !== -1) {
					report.involved.suspects[suspectIndex] = {
						...report.involved.suspects[suspectIndex],
						fingerprint: result.fingerprint,
					};
					report = { ...report };
				}
				showStatus(`Fingerprint on file for ${suspect.fullName}: ${result.fingerprint}`);
			} else if (result.success) {
				// Scan was triggered on the suspect
				showStatus(`Fingerprint scan initiated on ${suspect.fullName}`, "info");
			} else {
				showStatus(result.message || "Failed to get fingerprint", "error");
			}
		} catch {
			showStatus("Failed to get fingerprint", "error");
		}
	}

	// Hidden file input ref for suspect photo upload
	let photoUploadInput: HTMLInputElement | undefined = $state();
	let photoUploadCitizenId: string = $state("");
	let isUploadingPhoto: boolean = $state(false);
	let isUploadingEvidence: boolean = $state(false);

	function openPhotoUpload(suspect: Report["involved"]["suspects"][number]) {
		if (!suspect.citizenid) return;
		photoUploadCitizenId = suspect.citizenid;
		photoUploadInput?.click();
	}

	async function handlePhotoUpload(event: Event) {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (!file || !photoUploadCitizenId || isUploadingPhoto) return;

		isUploadingPhoto = true;
		showStatus("Uploading photo...");

		try {
			const base64 = await compressImage(file);

			const result = await fetchNui<{ success: boolean; message?: string; imageUrl?: string }>(
				NUI_EVENTS.CITIZEN.UPLOAD_SUSPECT_PHOTO,
				{ citizenid: photoUploadCitizenId, image: base64 },
				{ success: true, message: "Photo uploaded", imageUrl: base64 },
			);

			if (result.success) {
				// Update suspect's profileImage in report so warning disappears
				const suspectIndex = report.involved.suspects.findIndex(
					(s) => s.citizenid === photoUploadCitizenId,
				);
				if (suspectIndex !== -1) {
					report.involved.suspects[suspectIndex] = {
						...report.involved.suspects[suspectIndex],
						profileImage: result.imageUrl || base64,
					};
					report = { ...report };
				}
				showStatus(result.message || "Photo uploaded successfully");
			} else {
				showStatus(result.message || "Failed to upload photo", "error");
			}
		} catch {
			showStatus("Failed to upload photo", "error");
		} finally {
			isUploadingPhoto = false;
		}

		// Reset input so same file can be selected again
		input.value = "";
	}

	async function uploadImageHandler(file: File, evidenceId: string) {
		if (isUploadingEvidence) return;
		isUploadingEvidence = true;

		try {
			const numericId = Number(evidenceId);
			if (numericId && !isNaN(numericId)) {
				// Evidence already saved to DB - upload directly
				const imageUrl = await evidenceService.uploadImage(file, evidenceId);
				const evidenceIndex = report.evidence.findIndex((e) => e.id === evidenceId);
				if (evidenceIndex !== -1) {
					report.evidence[evidenceIndex] = evidenceService.addImageToEvidence(
						report.evidence[evidenceIndex],
						imageUrl,
					);
				}
			} else {
				// Evidence is in-memory (not yet saved) - compress and store as data URL
				const dataUrl = await compressImage(file);
				const evidenceIndex = report.evidence.findIndex((e) => e.id === evidenceId);
				if (evidenceIndex !== -1) {
					report.evidence[evidenceIndex] = evidenceService.addImageToEvidence(
						report.evidence[evidenceIndex],
						dataUrl,
					);
				}
			}
			reportEditorUI.closeImageUpload();
		} catch (error: any) {
			showStatus(error?.message || "Failed to upload image", "error");
		} finally {
			isUploadingEvidence = false;
		}
	}

	async function linkEvidenceToCase(evidenceId: string, caseId: string) {
		const numericEvidenceId = Number(evidenceId);
		const numericCaseId = Number(caseId);
		if (!numericEvidenceId || !numericCaseId || !report.reportId) return;
		const response = await evidenceService.linkEvidenceToCase(
			numericEvidenceId,
			numericCaseId,
			Number(report.reportId),
		);
		if (response?.success) {
			const evidenceIndex = report.evidence.findIndex(
				(item) => item.id === evidenceId,
			);
			if (evidenceIndex !== -1) {
				report.evidence[evidenceIndex] = {
					...report.evidence[evidenceIndex],
					caseId: String(numericCaseId),
				} as any;
			}
		}
	}

	async function createCaseForEvidence(evidenceId: string) {
		const numericEvidenceId = Number(evidenceId);
		if (!numericEvidenceId || !report.reportId) return;
		const response = await evidenceService.createCaseFromEvidence(
			numericEvidenceId,
			Number(report.reportId),
		);
		if (response?.success && response.caseId) {
			await linkEvidenceToCase(evidenceId, String(response.caseId));
		}
	}

	function cancelHandler() {
		// Clear persisted data so the next "New Report" starts fresh
		isPersistenceEnabled = false;
		persistence.cancelDebouncedSave();
		persistence.clearPersistedData();
		persistence.forceRemoveData();
		onClose();
	}

	async function saveReportHandler() {
		// Validate tags before saving
		if (!report.tags || report.tags.length === 0) {
			showStatus("At least one tag is required before saving", "error");
			return;
		}

		try {
			// Set saving flag to completely disable all persistence operations
			isSaving = true;

			// Also disable persistence and cancel any pending saves
			isPersistenceEnabled = false;
			persistence.cancelDebouncedSave();

			await reportService.saveReport(report);

			// Clear persisted data
			persistence.clearPersistedData();
			persistence.forceRemoveData();

			// Reset the form data
			report = reportService.createEmptyReport();

			// Reset UI state
			reportEditorUI.state.searchQuery = "";
			reportEditorUI.state.showTagDropdown = false;
			reportEditorUI.state.showOfficerSearch = false;
			reportEditorUI.state.showSuspectSearch = false;
			reportEditorUI.state.showVictimSearch = false;
			reportEditorUI.state.selectedEvidenceId = "";

			// Close the editor (this will destroy the component)
			onClose();
		} catch (error: any) {
			const msg = error?.message || "Failed to save report";
			showStatus(msg, "error");
			// Reset flags if save failed
			isSaving = false;
			isPersistenceEnabled = true;
		}
	}

	async function deleteReportHandler() {
		if (!report.reportId) return;
		try {
			isSaving = true;
			isPersistenceEnabled = false;
			persistence.cancelDebouncedSave();

			const success = await reportService.deleteReport(report.reportId);
			if (success) {
				persistence.clearPersistedData();
				persistence.forceRemoveData();
				report = reportService.createEmptyReport();
				onClose();
			} else {
				showStatus("Failed to delete report", "error");
				isSaving = false;
				isPersistenceEnabled = true;
			}
		} catch (error: any) {
			showStatus(error?.message || "Failed to delete report", "error");
			isSaving = false;
			isPersistenceEnabled = true;
		}
	}

</script>

<svelte:window on:click={reportEditorUI.handleClickOutside} />

<div class="report-editor">
	<ReportEditorHeader
		{reportId}
		onClose={cancelHandler}
		onSave={saveReportHandler}
		onDelete={deleteReportHandler}
		isSaving={reportService.state.isSaving}
		isLoading={!reportPromise}
		{collabEditors}
		myColor={collabService.myColor}
		myName={collabService.myName}
		collabActive={collabService.isActive}
	/>

	{#await reportPromise}
		<div class="loading-state">
			<div class="loading-spinner"></div>
			<p>Loading report...</p>
		</div>
	{:then}
		<div class="editor-content">
			<div class="left-column">
				<ReportMetadata
					title={report.title}
					reportId={report.reportId}
					officer={report.officer}
					type={report.type}
					created={report.created}
					lastUpdated={report.lastUpdated}
					onTitleChange={handlers.handleTitleChange}
					onTypeChange={handlers.handleTypeChange}
					onInsertTemplate={insertTemplate}
					onSelectTemplate={selectTemplate}
					availableTemplates={reportTemplates}
					{showTemplateMenu}
					{jobType}
				/>

				<div class="left-panel">
					{#if collabJoined}
					<ReportTextEditor
						content={report.content}
						onUpdate={handlers.handleContentUpdate}
						ydoc={collabService.ydoc}
						collabActive={collabService.isActive}
					/>
				{:else}
					<div style="padding: 16px; color: rgba(255,255,255,0.4); font-size: 13px;">
						Connecting to collaborative session...
					</div>
				{/if}
				</div>
			</div>

			<div class="right-panel">
				<TagsManager
					tags={report.tags}
					availableTags={tagService.state.availableTags}
					onAddTag={handlers.handleAddTag}
					onRemoveTag={handlers.handleRemoveTag}
					getTagColor={tagService.getTagColor}
				/>

				<OfficersManager
					officers={report.involved.officers}
					onAdd={handlers.handleAddOfficer}
					onRemove={handlers.handleRemoveOfficer}
					onUpdate={handlers.handleUpdateOfficer}
					title={isEMS ? "EMS" : "Officers"}
				/>

			{#if !isEMS}
			<SuspectsManager
				suspects={report.involved.suspects}
				onAdd={handlers.handleAddSuspect}
				onRemove={handlers.handleRemoveSuspect}
				onUpdate={handlers.handleUpdateSuspect}
				onIssueWarrant={issueWarrant}
				onCloseWarrant={closeWarrant}
				onIssueBenchWarrant={jobType === 'leo' ? openBenchWarrantModal : undefined}
				onIssueBolo={issueBolo}
				onTakeMugshot={triggerSuspectMugshot}
				onUploadPhoto={openPhotoUpload}
				onAddFingerprint={addSuspectFingerprint}
			/>
			{/if}

				<VictimsManager
					victims={report.involved.victims}
					onAdd={handlers.handleAddVictim}
					onRemove={handlers.handleRemoveVictim}
					onUpdate={handlers.handleUpdateVictim}
					title={isEMS ? "Patients" : "Victims"}
				/>

			{#if !isEMS}
			<ChargesManager
				charges={report.charges}
				suspects={report.involved.suspects}
				{penalCodes}
				{reductionOffers}
				onAddCharge={handlers.handleAddCharge}
				onRemoveCharge={handlers.handleRemoveCharge}
				onUpdateCharge={handlers.handleUpdateCharge}
				onSendToJail={handleSendToJail}
				onGiveCitation={handleGiveCitation}
			/>

			<VehiclesManager
				vehicles={report.vehicles}
				onAdd={(vehicle) => { report = reportService.addVehicle(report, vehicle); }}
				onRemove={(plate) => { report = reportService.removeVehicle(report, plate); }}
				onIssueBolo={issueVehicleBolo}
			/>

				<EvidenceManager
					evidence={report.evidence}
					onAddEvidence={handlers.handleAddEvidence}
					onRemoveEvidence={handlers.handleRemoveEvidence}
					onUpdateEvidence={handlers.handleUpdateEvidence}
					onOpenImageUpload={(evidenceId) =>
						reportEditorUI.openImageUpload(evidenceId)}
					onRemoveImage={(evidenceId, imageIndex) => {
						report = reportService.removeImageFromEvidence(
							report,
							evidenceId,
							imageIndex,
						);
					}}
					onLinkEvidenceCase={linkEvidenceToCase}
					onCreateCaseFromEvidence={createCaseForEvidence}
					onNavigateToCases={tabService ? () => navigateTo("Cases") : undefined}
					onNavigateToEvidence={tabService ? () => navigateTo("Evidence") : undefined}
				/>
			{/if}
			</div>
		</div>
	{:catch error}
		<div class="error-state">
			<p>Failed to load report: {error.message}</p>
			<button class="btn btn-primary" onclick={() => location.reload()}>
				Retry
			</button>
		</div>
	{/await}
</div>

<!-- Officer/EMS Search Modal -->
<PersonSearchModal
	show={reportEditorUI.state.showOfficerSearch}
	title={isEMS ? "Search EMS" : "Search Officers"}
	searchResults={searchService.state.results}
	onSearch={(query: string) => {
		reportEditorUI.state.searchQuery = query;
		reportEditorUI.state.activeSearch = "officers";
		handleSearch();
	}}
	onSelect={handlers.selectOfficer}
	onClose={() => reportEditorUI.closeOfficerSearch()}
/>

<!-- Suspect Search Modal -->
<PersonSearchModal
	show={reportEditorUI.state.showSuspectSearch}
	title="Search Suspects"
	searchResults={searchService.state.results}
	onSearch={(query: string) => {
		reportEditorUI.state.searchQuery = query;
		reportEditorUI.state.activeSearch = "suspects";
		handleSearch();
	}}
	onSelect={handlers.selectSuspect}
	onClose={() => reportEditorUI.closeSuspectSearch()}
/>

<!-- Victim/Patient Search Modal -->
<PersonSearchModal
	show={reportEditorUI.state.showVictimSearch}
	title={isEMS ? "Search Patients" : "Search Victims"}
	searchResults={searchService.state.results}
	onSearch={(query: string) => {
		reportEditorUI.state.searchQuery = query;
		reportEditorUI.state.activeSearch = "victims";
		handleSearch();
	}}
	onSelect={handlers.selectVictim}
	onClose={() => reportEditorUI.closeVictimSearch()}
/>

<ImageUploadModal
	show={reportEditorUI.state.showImageUpload}
	uploading={isUploadingEvidence}
	onUpload={(file: File) => {
		if (reportEditorUI.state.selectedEvidenceId) {
			uploadImageHandler(file, reportEditorUI.state.selectedEvidenceId);
		}
	}}
	onClose={() => reportEditorUI.closeImageUpload()}
/>

<!-- Hidden file input for suspect photo upload -->
<input
	type="file"
	accept="image/*"
	style="display:none"
	bind:this={photoUploadInput}
	onchange={handlePhotoUpload}
/>

{#if benchWarrantModal.open}
<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="bw-modal-overlay" use:teleport onclick={closeBenchWarrantModal}>
	<div class="bw-modal" onclick={(e) => e.stopPropagation()} role="dialog" aria-label="Issue Bench Warrant">
		<div class="bw-modal-header">
			<span class="bw-modal-title">Issue Bench Warrant</span>
			<button class="bw-modal-close" onclick={closeBenchWarrantModal} type="button">&times;</button>
		</div>
		<div class="bw-modal-body">
			<div class="bw-field">
				<label class="bw-label">Suspect</label>
				<div class="bw-value">{benchWarrantModal.suspect?.fullName} ({benchWarrantModal.suspect?.citizenid})</div>
			</div>
			<div class="bw-field">
				<label class="bw-label">Linked Report</label>
				<div class="bw-value">#{report.reportId}</div>
			</div>
			<div class="bw-field">
				<label class="bw-label">Charges</label>
				<div class="bw-charges">
					{#each report.charges.filter(c => c.citizenid === benchWarrantModal.suspect?.citizenid) as charge}
						<span class="bw-charge-chip">{charge.charge || charge.title || 'Unknown'} {charge.count > 1 ? `x${charge.count}` : ''}</span>
					{:else}
						<span class="bw-no-charges">No charges for this suspect</span>
					{/each}
				</div>
			</div>
			<div class="bw-field">
				<label class="bw-label" for="bw-reason">Reason / Justification <span class="bw-required">*</span></label>
				<textarea
					id="bw-reason"
					class="bw-textarea"
					bind:value={benchWarrantModal.reason}
					placeholder="Provide justification for this bench warrant request..."
					rows="4"
				></textarea>
			</div>
		</div>
		<div class="bw-modal-footer">
			<button class="bw-btn bw-btn-cancel" onclick={closeBenchWarrantModal} type="button" disabled={benchWarrantModal.submitting}>Cancel</button>
			<button class="bw-btn bw-btn-submit" onclick={submitBenchWarrant} type="button" disabled={benchWarrantModal.submitting || !benchWarrantModal.reason.trim()}>
				{benchWarrantModal.submitting ? 'Submitting...' : 'Submit Request'}
			</button>
		</div>
	</div>
</div>
{/if}

<style>
	.report-editor {
		display: grid;
		grid-template-rows: auto 1fr;
		height: 100%;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
		overflow: hidden;
		position: relative;
	}

	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		text-align: center;
		color: rgba(255, 255, 255, 0.3);
		font-size: 12px;
	}

	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		text-align: center;
		padding: 2rem;
		gap: 1rem;
	}

	.error-state p {
		color: #ef4444;
		margin: 0;
		font-size: 12px;
	}

	.loading-spinner {
		width: 20px;
		height: 20px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left: 2px solid rgba(255, 255, 255, 0.25);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 10px;
	}

	.editor-content {
		display: grid;
		grid-template-columns: 2fr 1fr;
		gap: 0;
		min-height: 0;
		overflow: hidden;
	}

	.left-column {
		display: grid;
		grid-template-rows: auto auto 1fr;
		gap: 0;
		min-height: 0;
		border-right: 1px solid rgba(255, 255, 255, 0.06);
	}

	.left-panel {
		display: flex;
		flex-direction: column;
		background: transparent;
		border: none;
		border-radius: 0;
		padding: 0;
		min-height: 0;
		overflow: hidden;
	}

	.right-panel {
		background: transparent;
		border: none;
		border-radius: 0;
		padding: 14px 16px;
		overflow-y: auto;
		min-height: 0;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	@media (max-width: 1024px) {
		.editor-content {
			grid-template-columns: 1fr;
		}

		.left-column {
			border-right: none;
			border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		}
	}

	.right-panel::-webkit-scrollbar {
		width: 3px;
	}

	.right-panel::-webkit-scrollbar-track {
		background: transparent;
	}

	.right-panel::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	.right-panel::-webkit-scrollbar-thumb:hover {
		background: rgba(255, 255, 255, 0.1);
	}

	/* Bench Warrant Modal */
	:global(.bw-modal-overlay) {
		position: fixed;
		inset: 0;
		background: none;
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 9999;
		animation: bwFadeIn 0.15s ease-out;
	}

	:global(.bw-modal) {
		background: #1a1d23;
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 12px;
		width: 440px;
		max-width: 90%;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
		animation: bwSlideIn 0.15s ease-out;
	}

	:global(.bw-modal-header) {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 16px 20px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	:global(.bw-modal-title) {
		font-size: 14px;
		font-weight: 600;
		color: rgba(252, 129, 129, 0.95);
	}

	:global(.bw-modal-close) {
		background: none;
		border: none;
		color: rgba(255, 255, 255, 0.4);
		font-size: 20px;
		cursor: pointer;
		padding: 0 4px;
		line-height: 1;
	}

	:global(.bw-modal-close:hover) {
		color: rgba(255, 255, 255, 0.8);
	}

	:global(.bw-modal-body) {
		padding: 16px 20px;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 14px;
	}

	:global(.bw-field) {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	:global(.bw-label) {
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(255, 255, 255, 0.4);
	}

	:global(.bw-required) {
		color: rgba(239, 68, 68, 0.8);
	}

	:global(.bw-value) {
		font-size: 12px;
		color: rgba(255, 255, 255, 0.75);
	}

	:global(.bw-charges) {
		display: flex;
		flex-wrap: wrap;
		gap: 4px;
	}

	:global(.bw-charge-chip) {
		padding: 2px 8px;
		background: rgba(255, 255, 255, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 4px;
		font-size: 11px;
		color: rgba(255, 255, 255, 0.65);
	}

	:global(.bw-no-charges) {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.3);
		font-style: italic;
	}

	:global(.bw-textarea) {
		width: 100%;
		min-height: 80px;
		padding: 10px 12px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 6px;
		color: rgba(255, 255, 255, 0.9);
		font-size: 12px;
		font-family: inherit;
		resize: vertical;
		outline: none;
		transition: border-color 0.15s;
	}

	:global(.bw-textarea:focus) {
		border-color: rgba(239, 68, 68, 0.4);
	}

	:global(.bw-textarea::placeholder) {
		color: rgba(255, 255, 255, 0.2);
	}

	:global(.bw-modal-footer) {
		display: flex;
		justify-content: flex-end;
		gap: 8px;
		padding: 12px 20px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}

	:global(.bw-btn) {
		padding: 8px 16px;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
		border: 1px solid transparent;
		transition: all 0.15s;
	}

	:global(.bw-btn:disabled) {
		opacity: 0.4;
		cursor: default;
	}

	:global(.bw-btn-cancel) {
		background: rgba(255, 255, 255, 0.04);
		border-color: rgba(255, 255, 255, 0.08);
		color: rgba(255, 255, 255, 0.6);
	}

	:global(.bw-btn-cancel:hover:not(:disabled)) {
		background: rgba(255, 255, 255, 0.08);
	}

	:global(.bw-btn-submit) {
		background: rgba(239, 68, 68, 0.15);
		border-color: rgba(239, 68, 68, 0.3);
		color: rgba(252, 129, 129, 0.95);
	}

	:global(.bw-btn-submit:hover:not(:disabled)) {
		background: rgba(239, 68, 68, 0.25);
	}

	@keyframes bwFadeIn {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	@keyframes bwSlideIn {
		from { opacity: 0; transform: translateY(-8px); }
		to { opacity: 1; transform: translateY(0); }
	}
</style>
