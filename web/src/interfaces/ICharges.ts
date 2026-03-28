export interface Charge {
	code?: string;
	label: string;
	description: string;
	time: number;
	fine?: number;
	type: "felony" | "misdemeanor" | "infraction";
	category: string;
}

export interface GroupedCharges {
	felony: Record<string, Charge[]>;
	misdemeanor: Record<string, Charge[]>;
	infraction: Record<string, Charge[]>;
}
