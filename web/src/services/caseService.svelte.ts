import { fetchNui } from "../utils/fetchNui";
import { NUI_EVENTS } from "../constants/nuiEvents";
import type {
	CaseAttachment,
	CaseDetailResponse,
	CaseOfficerAssignment,
	CaseRecord,
	CasesResponse,
	EvidenceImage,
	EvidenceItem,
} from "../interfaces/ICase";

export interface CaseServiceState {
	cases: CaseRecord[];
	selectedCase: CaseDetailResponse | null;
	isLoading: boolean;
	lastError: string | null;
	page: number;
	hasMore: boolean;
}

export function createCaseService() {
	let state = $state<CaseServiceState>({
		cases: [],
		selectedCase: null,
		isLoading: false,
		lastError: null,
		page: 1,
		hasMore: true,
	});

	async function loadCases(page = 1, filters?: Record<string, unknown>) {
		state.isLoading = true;
		state.lastError = null;
		try {
			const response = await fetchNui<CasesResponse>(
				NUI_EVENTS.CASE.GET_CASES,
				{ page, filters },
				{ cases: [], hasMore: false },
			);

			if (page === 1) {
				state.cases = response.cases || [];
			} else {
				state.cases = [...state.cases, ...(response.cases || [])];
			}

			state.page = page;
			state.hasMore = Boolean(response.hasMore);
		} catch (error) {
			console.error("Failed to load cases:", error);
			state.lastError = "Failed to load cases";
		} finally {
			state.isLoading = false;
		}
	}

	async function getCase(caseId: number) {
		state.isLoading = true;
		state.lastError = null;
		try {
			const response = await fetchNui<{
				success: boolean;
				data?: CaseDetailResponse;
			}>(NUI_EVENTS.CASE.GET_CASE, { caseId });

			if (response.success && response.data) {
				state.selectedCase = response.data;
				return response.data;
			}
			throw new Error("Case not found");
		} catch (error) {
			console.error("Failed to load case:", error);
			state.lastError = "Failed to load case";
			return null;
		} finally {
			state.isLoading = false;
		}
	}

	async function getCaseEvidencePage(caseId: number, page = 1, limit = 5) {
		try {
			const response = await fetchNui<{
				success: boolean;
				data?: {
					items: EvidenceItem[];
					total: number;
					page: number;
					limit: number;
				};
			}>(NUI_EVENTS.CASE.GET_CASE_EVIDENCE_PAGE,
				{ caseId, page, limit },
				{ success: true, data: { items: [], total: 0, page, limit } },
			);
			return response;
		} catch (error) {
			console.error("Failed to load evidence page:", error);
			return { success: false };
		}
	}

	async function createCase(payload: {
		title: string;
		summary?: string;
		status?: string;
		priority?: string;
		department?: string;
	}) {
		state.isLoading = true;
		state.lastError = null;
		try {
			const response = await fetchNui<{
				success: boolean;
				caseId?: number;
			}>(NUI_EVENTS.CASE.CREATE_CASE, payload, { success: true });
			return response;
		} catch (error) {
			console.error("Failed to create case:", error);
			state.lastError = "Failed to create case";
			return { success: false };
		} finally {
			state.isLoading = false;
		}
	}

	async function linkReportToCase(reportId: number, caseId: number) {
		try {
			const response = await fetchNui<{ success: boolean; error?: string }>(
				NUI_EVENTS.CASE.LINK_REPORT_TO_CASE,
				{ reportId, caseId },
				{ success: true },
			);
			return response;
		} catch (error) {
			console.error("Failed to link report:", error);
			return { success: false, error: "Failed to link report" };
		}
	}

	async function unlinkReportFromCase(reportId: number, caseId: number) {
		try {
			const response = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CASE.UNLINK_REPORT_FROM_CASE,
				{ reportId, caseId },
				{ success: true },
			);
			return response.success;
		} catch (error) {
			console.error("Failed to unlink report:", error);
			return false;
		}
	}

	async function updateCase(
		caseId: number,
		payload: Record<string, unknown>,
	) {
		try {
			const response = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CASE.UPDATE_CASE,
				{ caseId, payload },
				{ success: true },
			);
			return response.success;
		} catch (error) {
			console.error("Failed to update case:", error);
			return false;
		}
	}

	async function deleteCase(caseId: number) {
		try {
			const response = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CASE.DELETE_CASE,
				{ caseId },
				{ success: true },
			);
			return response.success;
		} catch (error) {
			console.error("Failed to delete case:", error);
			return false;
		}
	}

	async function assignOfficer(
		caseId: number,
		citizenid: string,
		role: CaseOfficerAssignment["role"],
	) {
		try {
			const response = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CASE.ASSIGN_CASE_OFFICER,
				{ caseId, citizenid, role },
				{ success: true },
			);
			return response.success;
		} catch (error) {
			console.error("Failed to assign officer:", error);
			return false;
		}
	}

	async function removeOfficer(caseId: number, citizenid: string) {
		try {
			const response = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CASE.REMOVE_CASE_OFFICER,
				{ caseId, citizenid },
				{ success: true },
			);
			return response.success;
		} catch (error) {
			console.error("Failed to remove officer:", error);
			return false;
		}
	}

	async function addAttachment(caseId: number, attachment: CaseAttachment) {
		try {
			const response = await fetchNui<{ success: boolean; id?: number }>(
				NUI_EVENTS.CASE.ADD_CASE_ATTACHMENT,
				{ caseId, attachment },
				{ success: true },
			);
			return response;
		} catch (error) {
			console.error("Failed to add attachment:", error);
			return { success: false };
		}
	}

	async function getEvidenceCustody(evidenceId: number) {
		try {
			const response = await fetchNui<
				Array<{
					id: number;
					action: string;
					holder: string;
					location?: string;
					notes?: string;
					timestamp: string | number;
				}>
			>(NUI_EVENTS.CASE.GET_EVIDENCE_CUSTODY,
				{ evidenceId },
				[],
			);
			return response || [];
		} catch (error) {
			console.error("Failed to load evidence custody:", error);
			return [];
		}
	}

	async function addAttachmentUpload(
		caseId: number,
		attachment: {
			data: string;
			filename: string;
			contentType: string;
			label?: string;
			type?: CaseAttachment["type"];
		},
	) {
		try {
			const response = await fetchNui<{ success: boolean; id?: number }>(
				NUI_EVENTS.CASE.ADD_CASE_ATTACHMENT_UPLOAD,
				{ caseId, attachment },
				{ success: true },
			);
			return response;
		} catch (error) {
			console.error("Failed to upload attachment:", error);
			return { success: false };
		}
	}

	async function addEvidenceItem(
		caseId: number,
		evidence: Record<string, unknown>,
	) {
		try {
			const response = await fetchNui<{ success: boolean; id?: number }>(
				NUI_EVENTS.CASE.ADD_EVIDENCE_ITEM,
				{ caseId, evidence },
				{ success: true },
			);
			return response;
		} catch (error) {
			console.error("Failed to add evidence:", error);
			return { success: false };
		}
	}

	async function updateEvidenceItem(
		evidenceId: number,
		evidence: Record<string, unknown>,
	) {
		try {
			const response = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CASE.UPDATE_EVIDENCE_ITEM,
				{ evidenceId, evidence },
				{ success: true },
			);
			return response.success;
		} catch (error) {
			console.error("Failed to update evidence:", error);
			return false;
		}
	}

	async function transferEvidenceItem(
		evidenceId: number,
		toCitizenId: string,
		notes?: string,
	) {
		try {
			const response = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CASE.TRANSFER_EVIDENCE_ITEM,
				{ evidenceId, toCitizenId, notes },
				{ success: true },
			);
			return response.success;
		} catch (error) {
			console.error("Failed to transfer evidence:", error);
			return false;
		}
	}

	async function deleteEvidenceItem(evidenceId: number) {
		try {
			const response = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CASE.DELETE_EVIDENCE_ITEM,
				{ evidenceId },
				{ success: true },
			);
			return response.success;
		} catch (error) {
			console.error("Failed to delete evidence:", error);
			return false;
		}
	}

	async function removeAttachment(attachmentId: number) {
		try {
			const response = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CASE.REMOVE_CASE_ATTACHMENT,
				{ attachmentId },
				{ success: true },
			);
			return response.success;
		} catch (error) {
			console.error("Failed to remove attachment:", error);
			return false;
		}
	}

	async function addEvidenceImage(evidenceId: number, image: EvidenceImage) {
		try {
			const response = await fetchNui<{ success: boolean; id?: number }>(
				NUI_EVENTS.CASE.ADD_EVIDENCE_IMAGE,
				{ evidenceId, image },
				{ success: true },
			);
			return response;
		} catch (error) {
			console.error("Failed to add evidence image:", error);
			return { success: false };
		}
	}

	async function removeEvidenceImage(imageId: number) {
		try {
			const response = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CASE.REMOVE_EVIDENCE_IMAGE,
				{ imageId },
				{ success: true },
			);
			return response.success;
		} catch (error) {
			console.error("Failed to remove evidence image:", error);
			return false;
		}
	}

	async function getCaseAuditLogs(caseId: number, page = 1, limit = 10) {
		try {
			const response = await fetchNui<{
				items: Array<{
					id: number;
					action: string;
					category: string;
					actor: string;
					details?: string;
					timestamp: string | number;
				}>;
				total: number;
			}>(
				NUI_EVENTS.AUDIT.GET_AUDIT_LOGS_BY_CASE,
				{ caseId, page, limit },
				{ items: [], total: 0, page, limit },
			);
			return response || { items: [], total: 0 };
		} catch (error) {
			console.error("Failed to load audit logs:", error);
			return { items: [], total: 0 };
		}
	}

	async function addCaseNote(caseId: number, content: string) {
		try {
			const response = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CASE.ADD_CASE_NOTE,
				{ caseId, content },
				{ success: true },
			);
			return response.success;
		} catch (error) {
			console.error("Failed to add case note:", error);
			return false;
		}
	}

	async function deleteCaseNote(caseId: number, noteId: number) {
		try {
			const response = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.CASE.DELETE_CASE_NOTE,
				{ caseId, noteId },
				{ success: true },
			);
			return response.success;
		} catch (error) {
			console.error("Failed to delete case note:", error);
			return false;
		}
	}

	return {
		get state() {
			return state;
		},
		loadCases,
		getCase,
		getCaseEvidencePage,
		createCase,
		linkReportToCase,
		unlinkReportFromCase,
		updateCase,
		deleteCase,
		assignOfficer,
		removeOfficer,
		addAttachment,
		addAttachmentUpload,
		removeAttachment,
		addEvidenceItem,
		updateEvidenceItem,
		transferEvidenceItem,
		deleteEvidenceItem,
		addEvidenceImage,
		removeEvidenceImage,
		getEvidenceCustody,
		getCaseAuditLogs,
		addCaseNote,
		deleteCaseNote,
	};
}

export type CaseService = ReturnType<typeof createCaseService>;
