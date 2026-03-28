export interface Report {
	id?: string;
	title: string;
	reportId: string;
	officer: string;
	type: string;
	created: number;
	lastUpdated: number;
	content: string;
	tags: string[];
	involved: ReportInvolved;
	evidence: Evidence[];
	restrictions: string[];
	tag?: string;
}

export interface ReportInvolved {
	officers: Officer[];
	suspects: Suspect[];
	victims: Victim[];
}

export interface Officer {
	id: string;
	fullName: string;
	badgeId: string;
	type: string;
	notes: string;
}

export interface Suspect {
	id: string;
	notes: string;
}

export interface Victim {
	id: string;
	type: string;
}

export interface Evidence {
	id: string;
	title: string;
	type: string;
	serial: string;
	notes: string;
	caseId?: string;
}

export interface ReportsResponse {
	reports: Report[];
	hasMore: boolean;
}

export interface GenerateReportIdResponse {
	reportId: string;
}
