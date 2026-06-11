import { fetchNui } from "../utils/fetchNui";
import { NUI_EVENTS } from "../constants/nuiEvents";
import type {
	CourtHearing,
	HearingDetail,
	CreateHearingPayload,
	AttendeeRole,
} from "../interfaces/ICourt";

export interface CourtServiceState {
	hearings: CourtHearing[];
	isLoading: boolean;
	lastError: string | null;
	rangeFrom: string | null;
	rangeTo: string | null;
	categories: string[] | null;
}

function pad(n: number): string {
	return n < 10 ? `0${n}` : `${n}`;
}

/** Format a Date as a MySQL DATETIME string in local time (no timezone shift). */
export function toMysqlDateTime(d: Date): string {
	return (
		`${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ` +
		`${pad(d.getHours())}:${pad(d.getMinutes())}:00`
	);
}

/**
 * Coerce whatever the DB layer returns for a datetime into the canonical
 * "YYYY-MM-DD HH:MM:SS" string the UI expects. oxmysql may hand back a string,
 * an ISO string, a Date, or a numeric (ms) timestamp depending on config.
 */
export function normalizeScheduledAt(val: unknown): string {
	if (typeof val === "string") {
		const s = val.includes("T") ? val.replace("T", " ") : val;
		return s.slice(0, 19);
	}
	if (typeof val === "number") {
		return toMysqlDateTime(new Date(val));
	}
	if (val instanceof Date) {
		return toMysqlDateTime(val);
	}
	return "";
}

export function createCourtService() {
	let state = $state<CourtServiceState>({
		hearings: [],
		isLoading: false,
		lastError: null,
		rangeFrom: null,
		rangeTo: null,
		categories: null,
	});

	async function loadRange(from: string, to: string, categories?: string[] | null) {
		state.isLoading = true;
		state.lastError = null;
		state.rangeFrom = from;
		state.rangeTo = to;
		state.categories = categories ?? null;
		try {
			const response = await fetchNui<CourtHearing[]>(
				NUI_EVENTS.COURT.GET_HEARINGS,
				{ from, to, categories: categories ?? undefined },
				[],
			);
			state.hearings = Array.isArray(response)
				? response.map((h) => ({ ...h, scheduled_at: normalizeScheduledAt(h.scheduled_at) }))
				: [];
		} catch (error) {
			console.error("Failed to load hearings:", error);
			state.lastError = "Failed to load hearings";
			state.hearings = [];
		} finally {
			state.isLoading = false;
		}
	}

	/** Reload whatever range is currently loaded (after a mutation). */
	async function refresh() {
		if (state.rangeFrom && state.rangeTo) {
			await loadRange(state.rangeFrom, state.rangeTo, state.categories);
		}
	}

	async function getHearing(hearingId: number): Promise<HearingDetail | null> {
		try {
			const response = await fetchNui<{ success: boolean; data?: HearingDetail }>(
				NUI_EVENTS.COURT.GET_HEARING,
				{ hearingId },
				{ success: false },
			);
			return response.success && response.data
				? {
						...response.data,
						hearing: {
							...response.data.hearing,
							scheduled_at: normalizeScheduledAt(response.data.hearing.scheduled_at),
						},
					}
				: null;
		} catch (error) {
			console.error("Failed to load hearing:", error);
			return null;
		}
	}

	async function createHearing(payload: CreateHearingPayload) {
		state.lastError = null;
		try {
			const response = await fetchNui<{ success: boolean; hearingId?: number; error?: string }>(
				NUI_EVENTS.COURT.CREATE_HEARING,
				payload,
				{ success: false },
			);
			if (!response.success) state.lastError = response.error || "Failed to create hearing";
			else await refresh();
			return response;
		} catch (error) {
			console.error("Failed to create hearing:", error);
			state.lastError = "Failed to create hearing";
			return { success: false };
		}
	}

	async function updateHearing(hearingId: number, data: Record<string, unknown>) {
		try {
			const response = await fetchNui<{ success: boolean; error?: string }>(
				NUI_EVENTS.COURT.UPDATE_HEARING,
				{ hearingId, data },
				{ success: false },
			);
			if (response.success) await refresh();
			return response;
		} catch (error) {
			console.error("Failed to update hearing:", error);
			return { success: false };
		}
	}

	async function deleteHearing(hearingId: number) {
		try {
			const response = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.COURT.DELETE_HEARING,
				{ hearingId },
				{ success: false },
			);
			if (response.success) await refresh();
			return response.success;
		} catch (error) {
			console.error("Failed to delete hearing:", error);
			return false;
		}
	}

	async function addAttendee(
		hearingId: number,
		citizenid: string,
		display_name: string,
		role: AttendeeRole,
	) {
		try {
			const response = await fetchNui<{ success: boolean; id?: number }>(
				NUI_EVENTS.COURT.ADD_ATTENDEE,
				{ hearingId, citizenid, display_name, role },
				{ success: false },
			);
			return response;
		} catch (error) {
			console.error("Failed to add attendee:", error);
			return { success: false };
		}
	}

	async function removeAttendee(attendeeId: number) {
		try {
			const response = await fetchNui<{ success: boolean }>(
				NUI_EVENTS.COURT.REMOVE_ATTENDEE,
				{ attendeeId },
				{ success: false },
			);
			return response.success;
		} catch (error) {
			console.error("Failed to remove attendee:", error);
			return false;
		}
	}

	return {
		get state() {
			return state;
		},
		loadRange,
		refresh,
		getHearing,
		createHearing,
		updateHearing,
		deleteHearing,
		addAttendee,
		removeAttendee,
	};
}

export type CourtService = ReturnType<typeof createCourtService>;