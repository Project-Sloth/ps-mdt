export type CaseStatus = "open" | "in_progress" | "closed";
export type CasePriority = "low" | "medium" | "high";

export interface CaseRecord {
	id: number;
	case_number: string;
	title: string;
	summary?: string;
	status: CaseStatus;
	priority: CasePriority;
	assigned_department?: string;
	created_by: string;
	created_by_name?: string;
	created_at: string | number;
	updated_at: string | number;
	primary_officer_name?: string;
	primary_officer_callsign?: string;
}

export interface CaseOfficerAssignment {
	citizenid: string;
	role: "primary" | "assisting" | "supervisor";
	assigned_by?: string;
	assigned_at?: string | number;
	fullname?: string;
	callsign?: string;
	badge_number?: string;
	rank?: string;
	department?: string;
}

export interface CaseAttachment {
	id: number;
	type: "photo" | "document" | "other";
	url: string;
	label?: string;
	uploaded_by?: string;
	uploaded_at?: string | number;
}

export interface EvidenceImage {
	id: number;
	url: string;
	label?: string;
	uploaded_by?: string;
	uploaded_at?: string | number;
	data?: string;
	filename?: string;
	contentType?: string;
}

export interface EvidenceItem {
	id: number;
	report_id?: number;
	case_id?: number;
	title: string;
	type: string;
	serial?: string;
	notes?: string;
	location?: string;
	stash_id?: string;
	stored: number | boolean;
	last_holder?: string;
	created_by?: string;
	created_at?: string | number;
	updated_at?: string | number;
	images?: EvidenceImage[];
}

export interface CaseNote {
	id: number;
	content: string;
	author_name?: string;
	created_at?: string | number;
}

export interface CaseDetailResponse {
	case: CaseRecord;
	officers: CaseOfficerAssignment[];
	attachments: CaseAttachment[];
	evidence: EvidenceItem[];
	reports?: Array<{
		id: number;
		title: string;
		type: string;
		datecreated?: string | number;
	}>;
	notes?: CaseNote[];
}

export interface CasesResponse {
	cases: CaseRecord[];
	hasMore: boolean;
}
