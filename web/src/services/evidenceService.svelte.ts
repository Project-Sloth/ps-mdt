import { fetchNui } from "../utils/fetchNui";
import { NUI_EVENTS } from "../constants/nuiEvents";
import type { Evidence } from "../interfaces/IReportEditor";
import { compressImage } from "./uploadService";

export interface EvidenceItem {
	id: number;
	case_id?: number;
	report_id?: number;
	title: string;
	type: string;
	serial?: string;
	notes?: string;
	location?: string;
	stash_id?: string;
	stored?: number | boolean;
	last_holder?: string | null;
	created_by?: string | null;
	created_at?: string;
	updated_at?: string;
	images?: Array<{
		id: number;
		url: string;
		label?: string;
		uploaded_by?: string;
		uploaded_at?: string;
	}>;
}

export interface EvidenceServiceState {
	uploading: boolean;
	lastError: string | null;
	uploadProgress: number;
}

export function createEvidenceService() {
	let state = $state<EvidenceServiceState>({
		uploading: false,
		lastError: null,
		uploadProgress: 0,
	});

	/**
	 * Upload an image for evidence
	 */
	async function uploadImage(
		file: File,
		evidenceId: string,
	): Promise<string> {
		state.uploading = true;
		state.lastError = null;
		state.uploadProgress = 0;

		try {
		const base64 = await compressImage(file);
		const response = await fetchNui(
			NUI_EVENTS.EVIDENCE.ADD_EVIDENCE_IMAGE,
			{
				evidenceId: Number(evidenceId),
				image: {
					data: base64,
					filename: file.name,
					contentType: file.type,
					label: "",
				},
			},
			{
				success: true,
				url: `evidence_${evidenceId}_${Date.now()}.jpg`,
			},
		);

		if (response.success) {
			state.uploadProgress = 100;
			return response.url || response.imageUrl;
		}
		throw new Error("Upload failed");
		} catch (error) {
			console.error("Failed to upload image:", error);
			state.lastError = "Failed to upload image";
			throw error;
		} finally {
			state.uploading = false;
			// Reset progress after a short delay
			setTimeout(() => {
				state.uploadProgress = 0;
			}, 1000);
		}
	}

	async function getEvidenceItems(page = 1, limit = 20, filters?: Record<string, unknown>) {
		return fetchNui<{ success: boolean; data?: { items: EvidenceItem[]; total: number; page: number; limit: number } }>(
			NUI_EVENTS.EVIDENCE.GET_EVIDENCE_ITEMS,
			{ page, limit, filters },
			{ success: true, data: { items: [], total: 0, page, limit } },
		);
	}

	async function searchEvidenceItems(query: string, page = 1, limit = 20) {
		return fetchNui<{ success: boolean; data?: { items: EvidenceItem[]; total: number; page: number; limit: number } }>(
			NUI_EVENTS.EVIDENCE.SEARCH_EVIDENCE_ITEMS,
			{ query, page, limit },
			{ success: true, data: { items: [], total: 0, page, limit } },
		);
	}

	async function addEvidenceItem(payload: Record<string, unknown>) {
		return fetchNui<{ success: boolean; id?: number }>(
			NUI_EVENTS.EVIDENCE.ADD_EVIDENCE_ITEM,
			payload,
			{ success: true },
		);
	}

	async function updateEvidenceItem(evidenceId: number, payload: Record<string, unknown>) {
		return fetchNui<{ success: boolean }>(
			NUI_EVENTS.EVIDENCE.UPDATE_EVIDENCE_ITEM,
			{ evidenceId, evidence: payload },
			{ success: true },
		);
	}

	async function deleteEvidenceItem(evidenceId: number) {
		return fetchNui<{ success: boolean }>(
			NUI_EVENTS.EVIDENCE.DELETE_EVIDENCE_ITEM,
			{ evidenceId },
			{ success: true },
		);
	}

	async function transferEvidenceItem(evidenceId: number, toCitizenId: string, notes?: string) {
		return fetchNui<{ success: boolean }>(
			NUI_EVENTS.EVIDENCE.TRANSFER_EVIDENCE_ITEM,
			{ evidenceId, toCitizenId, notes },
			{ success: true },
		);
	}

	async function getEvidenceCustody(evidenceId: number) {
		return fetchNui<
			Array<{
				id: number;
				action: string;
				holder: string;
				location?: string;
				notes?: string;
				timestamp: string | number;
			}>
		>(NUI_EVENTS.EVIDENCE.GET_EVIDENCE_CUSTODY, { evidenceId }, []);
	}

	async function addEvidenceImage(evidenceId: number, image: { url?: string; label?: string; data?: string; filename?: string; contentType?: string }) {
		return fetchNui<{ success: boolean; id?: number; url?: string }>(
			NUI_EVENTS.EVIDENCE.ADD_EVIDENCE_IMAGE,
			{ evidenceId, image },
			{ success: true },
		);
	}

	async function removeEvidenceImage(imageId: number) {
		return fetchNui<{ success: boolean }>(
			NUI_EVENTS.EVIDENCE.REMOVE_EVIDENCE_IMAGE,
			{ imageId },
			{ success: true },
		);
	}

	async function linkEvidenceToCase(
		evidenceId: number,
		caseId: number | string,
		reportId?: number,
	) {
		return fetchNui<{ success: boolean; error?: string }>(
			NUI_EVENTS.EVIDENCE.LINK_EVIDENCE_TO_CASE,
			{ evidenceId, caseId, reportId },
			{ success: true },
		);
	}

	async function linkEvidenceToReport(
		evidenceId: number,
		reportId: number,
	) {
		return fetchNui<{ success: boolean; error?: string }>(
			NUI_EVENTS.EVIDENCE.LINK_EVIDENCE_TO_REPORT,
			{ evidenceId, reportId },
			{ success: true },
		);
	}

	async function createCaseFromEvidence(
		evidenceId: number,
		reportId?: number,
	) {
		return fetchNui<{ success: boolean; caseId?: number; caseNumber?: string }>(
			NUI_EVENTS.EVIDENCE.CREATE_CASE_FROM_EVIDENCE,
			{ evidenceId, reportId },
			{ success: true },
		);
	}

	async function openEvidenceStash(stashId: string) {
		return fetchNui<{ success: boolean }>(
			NUI_EVENTS.EVIDENCE.OPEN_EVIDENCE_STASH,
			{ stashId },
			{ success: true },
		);
	}

	async function logEvidenceViewed(evidenceId: number) {
		return fetchNui<{ success: boolean }>(
			NUI_EVENTS.EVIDENCE.LOG_EVIDENCE_VIEWED,
			{ evidenceId },
			{ success: true },
		);
	}

	/**
	 * Create a new evidence item
	 */
	function createEvidence(
		title: string,
		type: string,
		serial: string = "",
		notes: string = "",
	): Evidence {
		return {
			id: generateEvidenceId(),
			title,
			type,
			serial,
			notes,
			images: [],
		};
	}

	/**
	 * Generate a unique evidence ID
	 */
	function generateEvidenceId(): string {
		return `EV-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
	}

	/**
	 * Add image to evidence item
	 */
	function addImageToEvidence(
		evidence: Evidence,
		imageUrl: string,
	): Evidence {
		return {
			...evidence,
			images: [...evidence.images, imageUrl],
		};
	}

	/**
	 * Remove image from evidence item
	 */
	function removeImageFromEvidence(
		evidence: Evidence,
		imageUrl: string,
	): Evidence {
		return {
			...evidence,
			images: evidence.images.filter((img) => img !== imageUrl),
		};
	}

	/**
	 * Validate file before upload
	 */
	function validateImageFile(file: File): { valid: boolean; error?: string } {
		const maxSize = 10 * 1024 * 1024; // 10MB
		const allowedTypes = [
			"image/jpeg",
			"image/png",
			"image/gif",
			"image/webp",
		];

		if (!allowedTypes.includes(file.type)) {
			return {
				valid: false,
				error: "Invalid file type. Please upload JPEG, PNG, GIF, or WebP images.",
			};
		}

		if (file.size > maxSize) {
			return {
				valid: false,
				error: "File size too large. Please upload images smaller than 10MB.",
			};
		}

		return { valid: true };
	}

	return {
		get state() {
			return state;
		},
		uploadImage,
		getEvidenceItems,
		searchEvidenceItems,
		addEvidenceItem,
		updateEvidenceItem,
		deleteEvidenceItem,
		transferEvidenceItem,
		getEvidenceCustody,
		addEvidenceImage,
		removeEvidenceImage,
		linkEvidenceToCase,
		linkEvidenceToReport,
		createCaseFromEvidence,
		openEvidenceStash,
		logEvidenceViewed,
		createEvidence,
		generateEvidenceId,
		addImageToEvidence,
		removeImageFromEvidence,
		validateImageFile,
	};
}

export type EvidenceService = ReturnType<typeof createEvidenceService>;
