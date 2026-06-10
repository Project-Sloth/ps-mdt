export const MANAGEMENT_TABS = [
	"Activity",
	"Bulletins",
	"Permissions",
] as const;

export interface PermissionCategory {
	key: string;
	label: string;
	icon: string;
	permissions: { key: string; label: string; description: string }[];
}

export const PERMISSION_CATEGORIES: PermissionCategory[] = [
	{
		key: "citizens",
		label: "Citizens",
		icon: "people",
		permissions: [
			{ key: "citizens_search", label: "Search Citizens", description: "Search and view citizen profiles" },
			{ key: "citizens_edit_licenses", label: "Edit Licenses", description: "Issue, revoke, and manage citizen licenses" },
		],
	},
	{
		key: "reports",
		label: "Reports",
		icon: "description",
		permissions: [
			{ key: "reports_view", label: "View Reports", description: "View and search reports" },
			{ key: "reports_create", label: "Create Reports", description: "Create and edit reports" },
			{ key: "reports_delete", label: "Delete Reports", description: "Delete reports from the system" },
		],
	},
	{
		key: "cases",
		label: "Cases",
		icon: "folder",
		permissions: [
			{ key: "cases_view", label: "View Cases", description: "View and search cases" },
			{ key: "cases_create", label: "Create Cases", description: "Create new cases" },
			{ key: "cases_edit", label: "Edit Cases", description: "Edit case details and assignments" },
			{ key: "cases_delete", label: "Delete Cases", description: "Delete cases from the system" },
		],
	},
	{
		key: "evidence",
		label: "Evidence",
		icon: "inventory_2",
		permissions: [
			{ key: "evidence_view", label: "View Evidence", description: "View and search evidence" },
			{ key: "evidence_create", label: "Create Evidence", description: "Create new evidence entries" },
			{ key: "evidence_transfer", label: "Transfer Custody", description: "Transfer evidence between officers" },
			{ key: "evidence_upload", label: "Upload Images", description: "Upload images to evidence" },
		],
	},
	{
		key: "bolos",
		label: "BOLOs",
		icon: "notification_important",
		permissions: [
			{ key: "bolos_view", label: "View BOLOs", description: "View active BOLOs and details" },
			{ key: "bolos_create", label: "Create BOLOs", description: "Create new BOLOs" },
		],
	},
	{
		key: "warrants",
		label: "Warrants",
		icon: "gavel",
		permissions: [
			{ key: "warrants_view", label: "View Warrants", description: "View active warrants" },
			{ key: "warrants_issue", label: "Issue Warrants", description: "Issue warrants on suspects" },
			{ key: "warrants_close", label: "Close Warrants", description: "Close active warrants" },
		],
	},
	{
		key: "vehicles",
		label: "Vehicles",
		icon: "directions_car",
		permissions: [
			{ key: "vehicles_search", label: "Search Vehicles", description: "Search and view vehicle records" },
			{ key: "vehicles_edit_dmv", label: "Edit DMV Status", description: "Update points, status, and notes" },
		],
	},
	{
		key: "weapons",
		label: "Weapons",
		icon: "security",
		permissions: [
			{ key: "weapons_search", label: "Search Weapons", description: "Search and view weapon records" },
		],
	},
	{
		key: "charges",
		label: "Charges",
		icon: "balance",
		permissions: [
			{ key: "charges_view", label: "View Charges", description: "View penal code charges" },
			{ key: "charges_edit", label: "Edit Charges", description: "Edit fine amounts and jail time" },
		],
	},
	{
		key: "roster",
		label: "Roster",
		icon: "group",
		permissions: [
			{ key: "roster_manage_certifications", label: "Manage Certifications", description: "Add or remove officer certifications" },
			{ key: "roster_manage_officers", label: "Manage Officers", description: "Promote, demote, fire officers and edit callsigns" },
		],
	},
	{
		key: "ppr",
		label: "Performance Reviews",
		icon: "rate_review",
		permissions: [
			{ key: "ppr_view", label: "View PPR", description: "View performance planning and review entries for all officers" },
			{ key: "ppr_manage", label: "Manage PPR", description: "Create, edit, and delete performance reviews" },
		],
	},
	{
		key: "fto",
		label: "Field Training",
		icon: "school",
		permissions: [
			{ key: "fto_view", label: "View FTO", description: "View all field training assignments and daily observation reports" },
			{ key: "fto_manage", label: "Manage FTO", description: "Create assignments, write DORs, and manage training phases" },
		],
	},
	{
		key: "cameras",
		label: "Cameras & Bodycams",
		icon: "videocam",
		permissions: [
			{ key: "cameras_view", label: "View Cameras", description: "Access security camera feeds" },
			{ key: "bodycams_view", label: "View Bodycams", description: "Access officer bodycam footage" },
		],
	},
	{
		key: "dispatch",
		label: "Dispatch",
		icon: "cell_tower",
		permissions: [
			{ key: "dispatch_attach", label: "Attach to Calls", description: "Attach or detach from dispatch calls" },
			{ key: "dispatch_route", label: "Route to Calls", description: "Set GPS route to dispatch calls" },
		],
	},
	{
		key: "ia",
		label: "Internal Affairs",
		icon: "shield",
		permissions: [
			{ key: "ia_view", label: "View IA Complaints", description: "View internal affairs complaints and investigations" },
			{ key: "ia_manage", label: "Manage IA Complaints", description: "Update status, assign investigators, and add notes to complaints" },
		],
	},
	{
		key: "sop",
		label: "Standard Operating Procedures",
		icon: "menu_book",
		permissions: [
			{ key: "sop_view", label: "View SOP", description: "View standard operating procedures" },
			{ key: "sop_manage", label: "Manage SOP", description: "Create, edit, and publish standard operating procedures" },
		],
	},
	{
		key: "management",
		label: "Management",
		icon: "admin_panel_settings",
		permissions: [
			{ key: "management_permissions", label: "Manage Permissions", description: "Edit role permissions" },
			{ key: "management_bulletins", label: "Manage Bulletins", description: "Create and delete bulletins" },
			{ key: "management_activity", label: "View Activity Log", description: "View audit activity log" },
			{ key: "management_tags", label: "Manage Tags", description: "Create and delete profile tags" },
			{ key: "management_tracking", label: "Manage Tracking", description: "Configure audit tracking settings" },
			{ key: "management_settings", label: "Manage Settings", description: "Configure jail/fines, templates, awards, and licenses" },
		],
	},
];

export const TAB_VISIBILITY_KEYS = [
	{ tabName: "Reports", key: "tab_hidden_reports", label: "Reports" },
	{ tabName: "Cases", key: "tab_hidden_cases", label: "Cases" },
	{ tabName: "Evidence", key: "tab_hidden_evidence", label: "Evidence" },
	{ tabName: "BOLOs", key: "tab_hidden_bolos", label: "BOLOs" },
	{ tabName: "Warrants", key: "tab_hidden_warrants", label: "Warrants" },
	{ tabName: "Citizens", key: "tab_hidden_citizens", label: "Citizens" },
	{ tabName: "Vehicles", key: "tab_hidden_vehicles", label: "Vehicles" },
	{ tabName: "Weapons", key: "tab_hidden_weapons", label: "Weapons" },
	{ tabName: "Charges", key: "tab_hidden_charges", label: "Charges" },
	{ tabName: "Awards", key: "tab_hidden_awards", label: "Awards" },
	{ tabName: "Roster", key: "tab_hidden_roster", label: "Roster" },
	{ tabName: "Map", key: "tab_hidden_map", label: "Map" },
	{ tabName: "Cameras", key: "tab_hidden_cameras", label: "Cameras" },
	{ tabName: "Bodycams", key: "tab_hidden_bodycams", label: "Bodycams" },
	{ tabName: "IA", key: "tab_hidden_ia", label: "Internal Affairs" },
	{ tabName: "PPR", key: "tab_hidden_ppr", label: "PPR" },
	{ tabName: "FTO", key: "tab_hidden_fto", label: "Field Training" },
	{ tabName: "SOP", key: "tab_hidden_sop", label: "SOP" },
];

/** Flat list of all permission keys */
export const ALL_PERMISSION_KEYS = [
	...PERMISSION_CATEGORIES.flatMap((cat) => cat.permissions.map((p) => p.key)),
	...TAB_VISIBILITY_KEYS.map((t) => t.key),
];
