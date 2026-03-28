import { fetchNui } from "../utils/fetchNui";
import { NUI_EVENTS } from "../constants/nuiEvents";
import type {
	Report,
	Officer,
	Suspect,
	Victim,
	Evidence,
	ReportCharge,
	ReportVehicle,
	SearchResult,
} from "../interfaces/IReportEditor";

export interface ReportServiceState {
	reports: Map<string, Report>;
	isLoading: boolean;
	isSaving: boolean;
	lastError: string | null;
}

export function createReportService() {
	let state = $state<ReportServiceState>({
		reports: new Map(),
		isLoading: false,
		isSaving: false,
		lastError: null,
	});

	/**
	 * Generate a new unique report ID
	 */
	async function generateReportId(): Promise<string> {
		try {
			const response = await fetchNui(
				NUI_EVENTS.REPORT.GENERATE_REPORT_ID,
				{},
			);
			if (response && response.reportId) {
				return response.reportId;
			}
			return "";
		} catch (error) {
			console.error("Failed to generate report ID:", error);
			return "";
		}
	}

	/**
	 * Load a report by ID
	 */
	async function loadReport(id: string): Promise<Report> {
		state.isLoading = true;
		state.lastError = null;

		try {
			const response = await fetchNui(
				NUI_EVENTS.REPORT.GET_REPORT,
				{ reportId: id },
			);

			const report = normalizeReportResponse(response, id);
			state.reports.set(id, report);
			return report;
		} catch (error) {
			console.error("Failed to load report:", error);
			state.lastError = "Failed to load report";
			return {
				...createEmptyReport(),
				reportId: id,
			};
		} finally {
			state.isLoading = false;
		}
	}

	/**
	 * Save a report
	 */
	async function saveReport(report: Report): Promise<void> {
		state.isSaving = true;
		state.lastError = null;

		try {
			const reportToSave = {
				...report,
				id: report.id ?? report.reportId,
			};
			const response = await fetchNui<{ success: boolean; message?: string; error?: string; reportId?: string }>(
				NUI_EVENTS.REPORT.SAVE_REPORT,
				reportToSave,
			);

			if (response?.success) {
				if (response.reportId) {
					report.reportId = String(response.reportId);
				}
				state.reports.set(report.reportId, report);
			} else {
				const msg = response?.message || response?.error || "Save operation failed";
				throw new Error(msg);
			}
		} catch (error) {
			state.lastError = error instanceof Error ? error.message : "Failed to save report";
			throw error;
		} finally {
			state.isSaving = false;
		}
	}

	async function deleteReport(reportId: string): Promise<boolean> {
		try {
			const response = await fetchNui(
				NUI_EVENTS.REPORT.DELETE_REPORT,
				{ reportId },
				{ success: false },
			);
			if (response?.success) {
				state.reports.delete(reportId);
				return true;
			}
			return false;
		} catch (error) {
			console.error("Failed to delete report:", error);
			return false;
		}
	}

	async function getReportAnalytics(filters?: {
		startDate?: string;
		endDate?: string;
		author?: string;
	}): Promise<{ incidents: number; arrests: number; warrants: number }> {
		const response = await fetchNui(
			NUI_EVENTS.REPORT.GET_REPORT_ANALYTICS,
			{ filters },
		);
		if (response && response.success && response.data) {
			return response.data;
		}
		return { incidents: 0, arrests: 0, warrants: 0 };
	}

	async function issueWarrant(reportId: string, citizenid: string): Promise<void> {
		try {
			const result = await fetchNui<{ success: boolean; error?: string }>(
				NUI_EVENTS.WARRANT.ISSUE_WARRANT,
				{ reportId, citizenid },
			);
			if (!result?.success) {
				throw new Error(result?.error || "Failed to issue warrant");
			}
		} catch (error) {
			console.error("Failed to issue warrant:", error);
			throw error;
		}
	}

	async function closeWarrant(reportId: string, citizenid: string): Promise<void> {
		try {
			const result = await fetchNui<{ success: boolean; error?: string }>(
				NUI_EVENTS.WARRANT.CLOSE_WARRANT,
				{ reportId, citizenid },
			);
			if (!result?.success) {
				throw new Error(result?.error || "Failed to close warrant");
			}
		} catch (error) {
			console.error("Failed to close warrant:", error);
			throw error;
		}
	}

	async function sendToJail(citizenId: string, sentence: number): Promise<{ success: boolean; message?: string }> {
		return fetchNui<{ success: boolean; message?: string }>(
			NUI_EVENTS.SENTENCING.SEND_TO_JAIL,
			{ citizenId, sentence },
			{ success: true, message: `Sent to jail for ${sentence} months` },
		);
	}

	async function giveCitation(citizenId: string, fine: number, reportId?: string): Promise<{ success: boolean; message?: string }> {
		return fetchNui<{ success: boolean; message?: string }>(
			NUI_EVENTS.SENTENCING.GIVE_CITATION,
			{ citizenId, fine, reportId },
			{ success: true, message: "Citation given" },
		);
	}

	async function getCharges(): Promise<any[]> {
		const response = await fetchNui<any>(
			NUI_EVENTS.CHARGE.GET_CHARGES,
			{},
			[],
		);
		// Server returns array directly, not wrapped in { success, data }
		if (Array.isArray(response)) return response;
		if (response?.data && Array.isArray(response.data)) return response.data;
		return [];
	}

	function normalizeReportResponse(
		response: any,
		fallbackId: string,
	): Report {
		if (response && response.success && response.data) {
			return mapServerReport(response.data, fallbackId);
		}
		if (response && response.data) {
			return mapServerReport(response.data, fallbackId);
		}
		return mapServerReport(response, fallbackId);
	}

	function mapServerReport(raw: any, fallbackId: string): Report {
		const reportId = String(raw?.reportId ?? raw?.id ?? fallbackId ?? "");
		const tags = normalizeTags(raw?.tags);
		const involved = normalizeInvolved(raw?.involved);
		const evidence = normalizeEvidence(raw?.evidence);
		const charges = normalizeCharges(raw?.charges);

		return {
			id: raw?.id ? String(raw.id) : reportId,
			reportId,
			title: raw?.title ?? "",
			officer: raw?.authorplaintext ?? raw?.author ?? "",
			type: raw?.type ?? "Incident Report",
			created: Number(raw?.datecreated ?? raw?.created ?? Date.now()),
			lastUpdated: Number(
				raw?.dateupdated ?? raw?.lastUpdated ?? Date.now(),
			),
			content:
				raw?.content ??
				raw?.contentplaintext ??
				(raw?.contentyjs && parseJsonString(raw.contentyjs)) ??
				"",
			tags,
			involved,
			evidence,
			charges,
			restrictions: normalizeRestrictions(raw?.restrictions),
			vehicles: (() => {
				try {
					const v = typeof raw?.vehicles === "string" ? JSON.parse(raw.vehicles) : raw?.vehicles;
					return Array.isArray(v) ? v : [];
				} catch { return []; }
			})(),
		};
	}

	function normalizeTags(tags: any): string[] {
		const parsed = parseJsonString(tags);
		const list = Array.isArray(parsed)
			? parsed
			: Array.isArray(tags)
				? tags
				: [];
		return list
			.map((tag) => (typeof tag === "string" ? tag : tag?.tag))
			.filter(Boolean);
	}

	function normalizeInvolved(involved: any): Report["involved"] {
		const parsed = parseJsonString(involved);
		const list = Array.isArray(parsed)
			? parsed
			: Array.isArray(involved)
				? involved
				: [];
		const normalized = {
			officers: [],
			suspects: [],
			victims: [],
		} as Report["involved"];

		for (const entry of list) {
			const type = (entry?.type || "").toLowerCase();
			if (type === "officer") {
				normalized.officers.push({
					id: crypto.randomUUID(),
					citizenid: entry?.citizenid || "",
					fullName: entry?.name || entry?.fullname || "Unknown",
					badgeId: entry?.badgeId || "",
					type: entry?.type || "Officer",
					notes: entry?.notes || "",
				});
			} else if (type === "victim") {
				normalized.victims.push({
					id: entry?.citizenid || crypto.randomUUID(),
					citizenid: entry?.citizenid || "",
					fullName: entry?.name || entry?.fullname || "Unknown",
					type: entry?.type || "Victim",
				});
			} else {
				normalized.suspects.push({
					id: entry?.citizenid || crypto.randomUUID(),
					citizenid: entry?.citizenid || "",
					fullName: entry?.name || entry?.fullname || "Unknown",
					notes: entry?.notes || "",
					warrantActive: entry?.warrantActive || false,
					profileImage: entry?.image || undefined,
				});
			}
		}

		return normalized;
	}

	function normalizeEvidence(evidence: any): Report["evidence"] {
		const parsed = parseJsonString(evidence);
		const list = Array.isArray(parsed)
			? parsed
			: Array.isArray(evidence)
				? evidence
				: [];
		return list.map((entry, index) => ({
			id: entry?.id || `${index}`,
			title: entry?.title || entry?.type || "Evidence",
			type: entry?.type || "",
			serial: entry?.serial || entry?.content || "",
			notes: entry?.note || entry?.notes || "",
			caseId: (entry?.caseId || entry?.case_id) ? String(entry.caseId || entry.case_id) : undefined,
			images: entry?.images || (entry?.content ? [entry.content] : []),
		}));
	}

	function normalizeCharges(charges: any): ReportCharge[] {
		const parsed = parseJsonString(charges);
		const list = Array.isArray(parsed) ? parsed : Array.isArray(charges) ? charges : [];
		return list.filter(Boolean).map((c: any) => ({
			id: c.id || `CHG-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
			citizenid: c.citizenid || "",
			suspectName: c.suspectName || c.suspect_name || "",
			charge: c.charge || c.label || "",
			count: Number(c.count) || 1,
			time: Number(c.time) || 0,
			fine: Number(c.fine) || 0,
		}));
	}

	function normalizeRestrictions(restrictions: any): string[] {
		const parsed = parseJsonString(restrictions);
		const list = Array.isArray(parsed)
			? parsed
			: Array.isArray(restrictions)
				? restrictions
				: [];
		return list
			.map((item) => (typeof item === "string" ? item : item?.identifier))
			.filter(Boolean);
	}

	function parseJsonString(value: any): any {
		if (typeof value !== "string") {
			return value;
		}
		try {
			return JSON.parse(value);
		} catch {
			return value;
		}
	}

	/**
	 * Create an empty report template
	 */
	function createEmptyReport(): Report {
		return {
			title: "",
			reportId: "",
			officer: "",
			type: "Incident Report",
			created: Date.now(),
			lastUpdated: Date.now(),
			content: "",
			tags: [],
			involved: {
				officers: [],
				suspects: [],
				victims: [],
			},
			evidence: [],
			charges: [],
			restrictions: [],
			vehicles: [],
		};
	}

	/**
	 * Get a cached report or fetch it if not cached
	 */
	async function getReport(id: string): Promise<Report> {
		const cached = state.reports.get(id);
		if (cached) {
			return cached;
		}
		return await loadReport(id);
	}

	/**
	 * Update a report in the cache
	 */
	function updateReportInCache(report: Report): void {
		state.reports.set(report.reportId, report);
	}

	/**
	 * Initialize a report - either load existing or create new
	 */
	async function initializeReport(reportId: string | null): Promise<Report> {
		if (reportId) {
			// Load existing report
			try {
				return await loadReport(reportId);
			} catch (error) {
				console.error("Failed to load report:", error);
				throw error;
			}
		} else {
			// Create new report with generated ID
			const newReport = createEmptyReport();
			return newReport;
		}
	}

	// ===== REPORT DATA MANIPULATION FUNCTIONS =====

	/**
	 * Generic helper to update an item in an array by ID
	 */
	function updateItemInArray<T extends { id: string }>(
		array: T[],
		updatedItem: T,
	): void {
		const index = array.findIndex((item) => item.id === updatedItem.id);
		if (index !== -1) array[index] = updatedItem;
	}

	/**
	 * Add an officer to a report
	 */
	function addOfficer(report: Report, officer: SearchResult): Report {
		const newOfficer: Officer = {
			id: crypto.randomUUID(),
			citizenid: officer.citizenid || officer.id || "",
			fullName: officer.fullName,
			badgeId: officer.badgeId || "",
			type: "Assisting",
			notes: "",
		};

		return {
			...report,
			involved: {
				...report.involved,
				officers: [...report.involved.officers, newOfficer],
			},
		};
	}

	/**
	 * Remove an officer from a report
	 */
	function removeOfficer(report: Report, officerId: string): Report {
		return {
			...report,
			involved: {
				...report.involved,
				officers: report.involved.officers.filter(
					(o) => o.id !== officerId,
				),
			},
		};
	}

	/**
	 * Add a suspect to a report
	 */
	function addSuspect(report: Report, suspect: SearchResult): Report {
			const newSuspect: Suspect = {
				id: crypto.randomUUID(),
				citizenid: suspect.citizenid || "",
				fullName: suspect.fullName,
				notes: "",
				warrantActive: false,
				profileImage: suspect.image || undefined,
				fingerprint: suspect.fingerprint || undefined,
			};

		return {
			...report,
			involved: {
				...report.involved,
				suspects: [...report.involved.suspects, newSuspect],
			},
		};
	}

	/**
	 * Remove a suspect from a report
	 */
	function removeSuspect(report: Report, suspectId: string): Report {
		return {
			...report,
			involved: {
				...report.involved,
				suspects: report.involved.suspects.filter(
					(s) => s.id !== suspectId,
				),
			},
		};
	}

	/**
	 * Add a victim to a report
	 */
	function addVictim(report: Report, victim: SearchResult): Report {
		const newVictim: Victim = {
			id: crypto.randomUUID(),
			citizenid: victim.citizenid || "",
			fullName: victim.fullName,
			type: "Primary",
		};

		return {
			...report,
			involved: {
				...report.involved,
				victims: [...report.involved.victims, newVictim],
			},
		};
	}

	/**
	 * Remove a victim from a report
	 */
	function removeVictim(report: Report, victimId: string): Report {
		return {
			...report,
			involved: {
				...report.involved,
				victims: report.involved.victims.filter(
					(v) => v.id !== victimId,
				),
			},
		};
	}

	/**
	 * Add evidence to a report
	 */
	function addEvidence(report: Report): Report {
		const newEvidence: Evidence = {
			id: crypto.randomUUID(),
			title: "",
			type: "Physical",
			serial: "",
			notes: "",
			images: [],
		};

		return {
			...report,
			evidence: [...report.evidence, newEvidence],
		};
	}

	/**
	 * Remove evidence from a report
	 */
	function removeEvidence(report: Report, evidenceId: string): Report {
		return {
			...report,
			evidence: report.evidence.filter((e) => e.id !== evidenceId),
		};
	}

	/**
	 * Remove an image from evidence
	 */
	function removeImageFromEvidence(
		report: Report,
		evidenceId: string,
		imageIndex: number,
	): Report {
		return {
			...report,
			evidence: report.evidence.map((evidence) => {
				if (evidence.id === evidenceId) {
					return {
						...evidence,
						images: evidence.images.filter(
							(_, i) => i !== imageIndex,
						),
					};
				}
				return evidence;
			}),
		};
	}

	/**
	 * Add a vehicle to a report
	 */
	function addVehicle(report: Report, vehicle: ReportVehicle): Report {
		const exists = report.vehicles.some(v => v.plate === vehicle.plate);
		if (exists) return report;
		return { ...report, vehicles: [...report.vehicles, vehicle] };
	}

	/**
	 * Remove a vehicle from a report
	 */
	function removeVehicle(report: Report, plate: string): Report {
		return { ...report, vehicles: report.vehicles.filter(v => v.plate !== plate) };
	}

	// ===== UTILITY FUNCTIONS =====

	/**
	 * Format a timestamp to date string
	 */
	function formatDate(timestamp: number): string {
		return new Date(timestamp).toLocaleDateString("en-US", {
			month: "2-digit",
			day: "2-digit",
			year: "numeric",
		});
	}

	/**
	 * Format a timestamp to time string
	 */
	function formatTime(timestamp: number): string {
		return new Date(timestamp).toLocaleTimeString("en-US", {
			hour: "2-digit",
			minute: "2-digit",
			hour12: false,
		});
	}

	return {
		get state() {
			return state;
		},
		generateReportId,
		loadReport,
		saveReport,
		deleteReport,
		issueWarrant,
		closeWarrant,
		sendToJail,
		giveCitation,
		getCharges,
		getReportAnalytics,
		createEmptyReport,
		getReport,
		updateReportInCache,
		initializeReport,
		// Report manipulation functions
		addOfficer,
		removeOfficer,
		addSuspect,
		removeSuspect,
		addVictim,
		removeVictim,
		addEvidence,
		removeEvidence,
		removeImageFromEvidence,
		addVehicle,
		removeVehicle,
		// Generic helper
		updateItemInArray,
		// Utility functions
		formatDate,
		formatTime,
	};
}

export type ReportService = ReturnType<typeof createReportService>;
