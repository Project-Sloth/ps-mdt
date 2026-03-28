interface jobData {
	rank: string;
	payRate: string;
}
interface reportStatistics {
	totalThisWeek: number;
	changeFromLastWeek: number;
}
interface timeStatistic {
	day: string;
	hours: number;
}
interface Warrant {
	reportid: number;
	name: string;
	charges: Array<string>;
	felonies: number;
	misdemeanors: number;
	infractions: number;
	expirydate: number;
}
interface Bulletin {
	id: number;
	content: string;
}
interface Bolo {
	id: number;
	reportId: string;
	name: string;
	type: string;
	notes: string;
}
interface Report {
	id: number;
	title: string;
	type: string;
	contentyjs: Uint8Array;
	contentplaintext: string;
	author: string;
	datecreated: number;
	dateupdated: number;
}

interface ActiveUnits {
	count: number;
}
export interface DispatchUnit {
	citizenid: string;
	charinfo: {
		firstname: string;
		lastname: string;
	};
	job: {
		name: string;
		type: string;
		label: string;
	};
	metadata: {
		callsign: string;
	};
}
interface Dispatch {
	id: string;
	message: string;
	code: string;
	codename: string;
	icon: string;
	priority: number;
	coords: Array<number>;
	gender: string;
	street: string;
	callsign?: string;
	name?: string;
	jobs: Array<string>;
	units: DispatchUnit[];
	time: number;
}
export interface DashboardData {
	jobData: jobData;
	reportStatistics: reportStatistics;
	timeStatistics: timeStatistic[];
	activeWarrants: Warrant[];
	recentReports: Report[];
	activeBolos: Bolo[];
	bulletins: Bulletin[];
	activeUnits: ActiveUnits;
	recentDispatches: Dispatch[];
	usageMetrics: {
		totals: {
			reports: number;
			arrests: number;
			activeWarrants: number;
		};
		windows: {
			reportsLast7: number;
			reportsLast30: number;
			arrestsLast7: number;
			arrestsLast30: number;
		};
	};
}
