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
	involved: {
		officers: Officer[];
		suspects: Suspect[];
		victims: Victim[];
	};
	evidence: Evidence[];
	charges: ReportCharge[];
	restrictions: string[];
	vehicles: ReportVehicle[];
}

export interface Officer {
	id: string;
	citizenid: string;
	fullName: string;
	badgeId: string;
	type: string;
	notes: string;
}

export interface Suspect {
	id: string;
	citizenid: string;
	fullName: string;
	notes: string;
	warrantActive?: boolean;
	profileImage?: string;
	fingerprint?: string;
}

export interface Victim {
	id: string;
	citizenid: string;
	fullName: string;
	type: string;
}

export interface Evidence {
	id: string;
	title: string;
	type: string;
	serial: string;
	notes: string;
	images: string[];
	caseId?: string;
}

export interface ReportVehicle {
	plate: string;
	vehicle_label: string;
	owner_name: string;
	owner_citizenid?: string;
}

export interface ReportCharge {
	id: string;
	citizenid: string;
	suspectName: string;
	charge: string;
	count: number;
	time: number;
	fine: number;
}

export interface SearchResult {
	id: string;
	fullName: string;
	badgeId?: string;
	citizenid?: string;
	rank?: string;
	image?: string;
	fingerprint?: string;
}
