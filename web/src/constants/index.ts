/** MDT tab definitions */
export const MDT_TABS = [
	{ name: "Dashboard", icon: "dashboard" },
	{ name: "Citizens", icon: "people" },
	{ name: "Reports", icon: "description" },
	{ name: "Cases", icon: "folder" },
	{ name: "Evidence", icon: "inventory_2" },
	{ name: "BOLOs", icon: "notification_important" },
	{ name: "Warrants", icon: "gavel" },
	{ name: "Vehicles", icon: "directions_car" },
	{ name: "Weapons", icon: "security" },
	{ name: "Charges", icon: "balance" },
	{ name: "Awards", icon: "emoji_events" },
	{ name: "Roster", icon: "group" },
	{ name: "Map", icon: "map" },
	{ name: "Cameras", icon: "videocam" },
	{ name: "Bodycams", icon: "video_camera_front" },
	{ name: "IA", icon: "shield" },
	{ name: "PPR", icon: "rate_review" },
	{ name: "FTO", icon: "school" },
	{ name: "SOP", icon: "menu_book" },
	{ name: "Court Cases", icon: "gavel" },
	{ name: "Warrant Review", icon: "policy" },
	{ name: "Court Orders", icon: "assignment_late" },
	{ name: "Legal Documents", icon: "article" },
	{ name: "Preferences", icon: "tune" },
	{ name: "Settings", icon: "admin_panel_settings" },
] as const;

/** Tabs available for EMS job type */
export const EMS_TABS: readonly (typeof MDT_TABS)[number]["name"][] = [
	"Dashboard",
	"Citizens",
	"Reports",
	"Roster",
	"Map",
	"Bodycams",
	"Preferences",
	"Settings",
] as const;

/** Get filtered tabs based on job type */
export const DOJ_TABS: readonly string[] = [
	"Dashboard",
	"Reports",
	"Court Cases",
	"Warrant Review",
	"Citizens",
	"Cases",
	"Evidence",
	"Court Orders",
	"Legal Documents",
	"Charges",
	"Settings",
] as const;

export function getTabsForJob(jobType: 'leo' | 'ems' | 'doj') {
	if (jobType === 'ems') {
		return MDT_TABS.filter(tab => (EMS_TABS as readonly string[]).includes(tab.name));
	}
	if (jobType === 'doj') {
		return MDT_TABS.filter(tab => (DOJ_TABS as readonly string[]).includes(tab.name));
	}
	return [...MDT_TABS];
}

/** Sidebar navigation groups */
export interface NavGroup {
	id: string;
	label?: string;
	icon?: string;
	tabs: readonly string[];
}

export const NAV_GROUPS: NavGroup[] = [
	{ id: "dashboard", tabs: ["Dashboard"] },
	{ id: "operations", label: "Operations", icon: "assignment", tabs: ["Reports", "Cases", "Evidence", "BOLOs", "Warrants"] },
	{ id: "records", label: "Records", icon: "folder_open", tabs: ["Citizens", "Vehicles", "Weapons", "Charges"] },
	{ id: "personnel", label: "Personnel", icon: "badge", tabs: ["Roster", "Awards", "IA", "PPR", "FTO", "SOP"] },
	{ id: "surveillance", label: "Surveillance", icon: "visibility", tabs: ["Map", "Cameras", "Bodycams"] },
	{ id: "bottom", tabs: ["Preferences", "Settings"] },
];

export const DOJ_NAV_GROUPS: NavGroup[] = [
	{ id: "dashboard", tabs: ["Dashboard"] },
	{ id: "court", label: "Court", icon: "account_balance", tabs: ["Court Cases", "Warrant Review", "Court Orders"] },
	{ id: "legal", label: "Legal", icon: "description", tabs: ["Legal Documents", "Charges"] },
	{ id: "records", label: "Records", icon: "folder_open", tabs: ["Reports", "Citizens", "Cases", "Evidence"] },
	{ id: "bottom", tabs: ["Settings"] },
];

/** Report types per job */
export const LEO_REPORT_TYPES = [
	"Incident Report",
	"Traffic Report",
	"Investigation Report",
	"Arrest Report",
	"Evidence Report",
] as const;

export const EMS_REPORT_TYPES = [
	"Medical Report",
	"Trauma Report",
	"Overdose Report",
	"Psychiatric Report",
	"Mass Casualty Report",
] as const;

export const DOJ_REPORT_TYPES = [
	"Court Filing",
	"Legal Brief",
	"Judicial Order",
	"Plea Agreement",
	"Sentencing Report",
] as const;

export function getReportTypesForJob(jobType: 'leo' | 'ems' | 'doj'): readonly string[] {
	if (jobType === 'ems') return EMS_REPORT_TYPES;
	if (jobType === 'doj') return DOJ_REPORT_TYPES;
	return LEO_REPORT_TYPES;
}

export type MDTTab = (typeof MDT_TABS)[number]["name"];

/** Component identifiers for tab routing */
export type ComponentId =
	| "dashboard"
	| "citizens"
	| "bolos"
	| "vehicles"
	| "weapons"
	| "cases"
	| "evidence"
	| "reports"
	| "warrants"
	| "charges"
	| "awards"
	| "roster"
	| "map"
	| "cameras"
	| "bodycams"
	| "ia"
	| "ppr"
	| "fto"
	| "sop"
	| "court_cases"
	| "warrant_review"
	| "court_orders"
	| "legal_documents"
	| "management"
	| "settings";

/** Tab name to component ID mapping */
export const TAB_TO_COMPONENT_MAP: Record<MDTTab, ComponentId> = {
	Dashboard: "dashboard",
	Citizens: "citizens",
	BOLOs: "bolos",
	Vehicles: "vehicles",
	Weapons: "weapons",
	Cases: "cases",
	Evidence: "evidence",
	Reports: "reports",
	Warrants: "warrants",
	Charges: "charges",
	Awards: "awards",
	Roster: "roster",
	Map: "map",
	Cameras: "cameras",
	Bodycams: "bodycams",
	IA: "ia",
	PPR: "ppr",
	FTO: "fto",
	SOP: "sop",
	"Court Cases": "court_cases",
	"Warrant Review": "warrant_review",
	"Court Orders": "court_orders",
	"Legal Documents": "legal_documents",
	Settings: "management",
	Preferences: "settings",
} as const;

export const DEFAULT_TIME = "16:20";
export const DEFAULT_DATE = "03.15.2024";

/** App version and branding per job type */
export const APP_INFO = {
	leo: {
		version: "LSPD MDT System v2.0",
		title: "Los Santos Police Department",
		subtitle: "Mobile Data Terminal",
		footerSubtext: "Authorized Personnel Only",
		icon: "local_police",
	},
	ems: {
		version: "EMS MDT System v1.0",
		title: "Emergency Medical Services",
		subtitle: "Medical Data Terminal",
		footerSubtext: "Authorized Personnel Only",
		icon: "local_hospital",
	},
	doj: {
		version: "DOJ Terminal v1.0",
		title: "Department of Justice",
		subtitle: "Court Management System",
		footerSubtext: "Authorized Legal Personnel Only",
		icon: "account_balance",
	},
} as const;

export const TIME_FORMAT_OPTIONS: Intl.DateTimeFormatOptions = {
	hour12: false,
	hour: "2-digit",
	minute: "2-digit",
} as const;

export const DATE_FORMAT_OPTIONS: Intl.DateTimeFormatOptions = {
	month: "2-digit",
	day: "2-digit",
	year: "numeric",
} as const;

/** UI timing constants (ms) */
export const TIMING = {
	timeUpdateInterval: 1000,
	topBarOpacityDelay: 100,
	offDutyLoadingDuration: 2000,
} as const;

/** Component ID to display name mapping */
export const COMPONENT_DISPLAY_NAMES: Record<ComponentId, string> = {
	dashboard: "Dashboard",
	citizens: "Citizens",
	bolos: "BOLOs",
	vehicles: "Vehicles",
	weapons: "Weapons",
	cases: "Cases",
	evidence: "Evidence",
	reports: "Reports",
	warrants: "Warrants",
	charges: "Charges",
	awards: "Awards",
	roster: "Roster",
	map: "Map",
	cameras: "Cameras",
	bodycams: "Bodycams",
	ia: "Internal Affairs",
	ppr: "Performance Reviews",
	fto: "Field Training",
	sop: "Standard Operating Procedures",
	court_cases: "Court Cases",
	warrant_review: "Warrant Review",
	court_orders: "Court Orders",
	legal_documents: "Legal Documents",
	management: "Settings",
	settings: "Preferences",
} as const;

/** Components that render placeholder content */
export const PLACEHOLDER_COMPONENTS: readonly ComponentId[] = [] as const;

export const REPORT_TYPES = [
	"Incident Report",
	"Traffic Report",
	"Investigation Report",
	"Arrest Report",
	"Evidence Report",
] as const;

export const EVIDENCE_TYPES = [
	"Physical",
	"Digital",
	"Document",
	"Weapon",
	"Drug",
	"Vehicle",
	"Other",
] as const;

export const VICTIM_TYPES = [
	"Primary",
	"Secondary",
	"Witness",
	"Complainant",
] as const;

export const OFFICER_TYPES = {
	PRIMARY: "Primary",
	ASSISTING: "Assisting",
	SUPERVISOR: "Supervisor",
	DETECTIVE: "Detective",
} as const;

/** Priority level color mapping */
export const PRIORITY_COLORS: Record<string, string> = {
	"1": "#ef4444",
	Major: "#ef4444",
	"2": "#f59e0b",
	Moderate: "#f59e0b",
	"3": "#10b981",
	Minor: "#10b981",
	default: "#6b7280",
} as const;

export type ReportType = (typeof REPORT_TYPES)[number];
export type EvidenceType = (typeof EVIDENCE_TYPES)[number];
export type VictimType = (typeof VICTIM_TYPES)[number];
export type OfficerType = (typeof OFFICER_TYPES)[keyof typeof OFFICER_TYPES];
