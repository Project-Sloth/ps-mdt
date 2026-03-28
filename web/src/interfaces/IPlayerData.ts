export interface PlayerData {
	citizenid: string;
	job: {
		name: string;
		label: string;
		type?: string;
		grade: {
			name: string;
			level: number;
		};
		onduty: boolean;
		isboss: boolean;
		payment?: number;
	};
	charinfo: {
		firstname: string;
		lastname: string;
	};
	metadata?: {
		callsign?: string;
		licences?: {
			driver?: boolean;
		};
	};
}
