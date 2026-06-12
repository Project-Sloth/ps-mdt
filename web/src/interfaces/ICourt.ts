// Court / calendar domain types.
//
// The calendar covers four event categories (court hearings, trainings,
// meetings and other events). "Hearing" is used as the generic record name
// for historical reasons even for non-court events.

export type EventCategory = "court" | "training" | "meeting" | "other";

export type HearingType =
	| "arraignment"
	| "trial"
	| "sentencing"
	| "appeal"
	| "motion"
	| "hearing"
	| "other";

export type HearingStatus =
	| "scheduled"
	| "in_session"
	| "completed"
	| "adjourned"
	| "cancelled";

export type AttendeeRole =
	| "prosecutor"
	| "defense"
	| "officer"
	| "witness"
	| "judge"
	| "trainee"
	| "instructor"
	| "attendee";

/** A single calendar event (hearing / training / meeting / other). */
export interface CourtHearing {
	id: number;
	title: string;
	category: EventCategory;
	hearing_type: HearingType;
	scheduled_at: string; // "YYYY-MM-DD HH:MM:SS"
	duration_minutes?: number;
	location?: string | null;
	judge_cid?: string | null;
	judge_name?: string | null;
	case_id?: number | null;
	case_number?: string | null;
	case_title?: string | null;
	warrant_reportid?: number | null;
	defendant_cid?: string | null;
	defendant_name?: string | null;
	status: HearingStatus;
	notes?: string | null;
	created_by?: string | null;
	created_by_name?: string | null;
}

/** A person attached to an event. */
export interface CourtAttendee {
	id: number;
	citizenid: string;
	display_name?: string | null;
	role: AttendeeRole;
	notified_at?: string | null;
}

/** A hearing plus its attendees, as returned by getHearing. */
export interface HearingDetail {
	hearing: CourtHearing;
	attendees: CourtAttendee[];
}

/** Attendee payload accepted when creating/bulk-adding. */
export interface AttendeeInput {
	citizenid: string;
	display_name?: string;
	role: AttendeeRole;
}

/** Payload for creating a new event. */
export interface CreateHearingPayload {
	title: string;
	category: EventCategory;
	hearing_type: HearingType;
	scheduled_at: string;
	duration_minutes: number;
	location: string | null;
	judge_name: string | null;
	case_id: number | null;
	defendant_cid: string | null;
	defendant_name: string | null;
	status: HearingStatus;
	notes: string | null;
	attendees?: AttendeeInput[];
}

// ── Quick-add attendee groups ───────────────────────────────────────────────

/** A configured quick-add group (e.g. "All Officers", "Rookies"). */
export interface AttendeeGroup {
	id: string;
	label: string;
	role: AttendeeRole;
}

/** Result of resolving a group's members on the server. */
export interface GroupMembersResult {
	success: boolean;
	members: AttendeeInput[];
	role: AttendeeRole;
	error?: string;
}