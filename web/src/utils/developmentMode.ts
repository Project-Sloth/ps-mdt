import { debugData } from "../utils/debugData";
import { isEnvBrowser } from "../utils/misc";
import { NUI_EVENTS } from "../constants/nuiEvents";
import { MOCK_AUTH_DATA } from "../services/authService.svelte";

/** Sets up development mode mock data and debug utilities */
export function setupDevelopmentMode(): void {
	if (!isEnvBrowser()) {
		return;
	}

	// Setup mock authentication data for browser testing
	debugData([
		{
			action: NUI_EVENTS.AUTH.UPDATE_AUTH,
			data: MOCK_AUTH_DATA,
		},
	]);

	debugData([
		{
			action: NUI_EVENTS.DASHBOARD.UPDATE_JOB_DATA,
			data: {
				rank: "Officer",
				payRate: "$300/hr",
			},
		},
	]);

	debugData([
		{
			action: NUI_EVENTS.DASHBOARD.UPDATE_REPORT_STATISTICS,
			data: {
				totalThisWeek: 47,
				changeFromLastWeek: 12,
			},
		},
	]);

	debugData([
		{
			action: NUI_EVENTS.DASHBOARD.UPDATE_TIME_STATISTICS,
			data: [
				{ day: "Mon", hours: 8.5 },
				{ day: "Tue", hours: 7.2 },
				{ day: "Wed", hours: 9.1 },
				{ day: "Thu", hours: 8.0 },
				{ day: "Fri", hours: 6.5 },
				{ day: "Sat", hours: 4.2 },
				{ day: "Sun", hours: 0 },
			],
		},
	]);

	debugData([
		{
			action: NUI_EVENTS.DASHBOARD.UPDATE_ACTIVE_WARRANTS,
			data: [
				{
					reportid: 1234,
					name: "John Smith",
					felonies: 2,
					misdemeanors: 1,
					infractions: 0,
				},
				{
					reportid: 5678,
					name: "Jane Doe",
					felonies: 0,
					misdemeanors: 3,
					infractions: 2,
				},
			],
		},
	]);

	debugData([
		{
			action: NUI_EVENTS.DASHBOARD.UPDATE_BULLETINS,
			data: [
				{
					id: 1,
					content:
						"All units be advised: increased gang activity in Davis area. Exercise caution when responding to calls in the vicinity.",
				},
				{
					id: 2,
					content:
						"BOLO: Blue sedan, license plate 8SAM123, suspect armed and dangerous. Last seen heading north on Grove Street.",
				},
			],
		},
	]);

	debugData([
		{
			action: NUI_EVENTS.DASHBOARD.UPDATE_RECENT_REPORTS,
			data: [
				{
					id: 1,
					title: "Traffic Stop - Speeding Violation",
					author: "Officer Smith",
					datecreated: "2024-01-15 14:30:00",
					contentplaintext:
						"Routine traffic stop resulted in speeding citation. Driver was cooperative and no further action required.",
				},
				{
					id: 2,
					title: "Domestic Disturbance Call",
					author: "Officer Johnson",
					datecreated: "2024-01-15 13:45:00",
					contentplaintext:
						"Responded to domestic disturbance. Situation de-escalated, no arrests made. Parties advised to seek counseling.",
				},
			],
		},
	]);

	debugData([
		{
			action: NUI_EVENTS.DASHBOARD.UPDATE_ACTIVE_UNITS,
			data: {
				count: 28,
			},
		},
	]);

	debugData([
		{
			action: NUI_EVENTS.DASHBOARD.UPDATE_RECENT_DISPATCHES,
			data: [
				{
					id: "DISP001",
					message: "Armed Robbery in Progress",
					street: "Legion Square",
					time: Date.now() - 300000, // 5 minutes ago
					priority: 1,
					units: [
						{
							metadata: { callsign: "1A-01" },
							charinfo: {
								firstname: "John",
								lastname: "Smith",
							},
							citizenid: "ABC123",
						},
						{
							metadata: { callsign: "1A-02" },
							charinfo: {
								firstname: "Jane",
								lastname: "Doe",
							},
							citizenid: "DEF456",
						},
					],
				},
				{
					id: "DISP002",
					message: "Traffic Accident with Injuries",
					street: "Vinewood Hills Blvd",
					time: Date.now() - 600000, // 10 minutes ago
					priority: 2,
					units: [
						{
							metadata: { callsign: "1A-03" },
							charinfo: {
								firstname: "Mike",
								lastname: "Johnson",
							},
							citizenid: "GHI789",
						},
					],
				},
				{
					id: "DISP003",
					message: "Noise Complaint",
					street: "Mirror Park Drive",
					time: Date.now() - 900000, // 15 minutes ago
					priority: 3,
					units: [
						{
							metadata: { callsign: "1A-04" },
							charinfo: {
								firstname: "Sarah",
								lastname: "Williams",
							},
							citizenid: "JKL012",
						},
					],
				},
			],
		},
	]);

	debugData([
		{
			action: NUI_EVENTS.REPORT.UPDATE_REPORTS,
			data: {
				reports: [
					{
						id: "1",
						title: "Armed Robbery at Fleeca Bank Downtown",
						reportId: "RP-2024-001",
						author: "J. Smith",
						type: "Incident Report",
						datecreated: Date.now() - 7200000,
						dateupdated: Date.now() - 3600000,
						tag: "Active Investigation",
					},
					{
						id: "2",
						title: "Traffic Stop - Speeding",
						reportId: "RP-2024-002",
						author: "A. Johnson",
						type: "Traffic Report",
						datecreated: Date.now() - 14400000,
						dateupdated: Date.now() - 1800000,
						tag: "Follow-up",
					},
					{
						id: "3",
						title: "Suspicious Activity - Vinewood",
						reportId: "RP-2024-003",
						author: "M. Brown",
						type: "Arrest Report",
						datecreated: Date.now() - 10800000,
						dateupdated: Date.now() - 600000,
						tag: "Street Crimes",
					},
					{
						id: "4",
						title: "Domestic Disturbance - Grove Street",
						reportId: "RP-2024-004",
						author: "L. Garcia",
						type: "Warrant",
						datecreated: Date.now() - 21600000,
						dateupdated: Date.now() - 1200000,
						tag: "Under Review",
					},
					{
						id: "5",
						title: "Burglary - Legion Square",
						reportId: "RP-2024-005",
						author: "K. Lee",
						type: "Incident Report",
						datecreated: Date.now() - 43200000,
						dateupdated: Date.now() - 300000,
						tag: "Closed",
					},
				],
			},
		},
	]);
}

/** Sets up Report Editor mock data */
export function setupReportEditorMockData(): void {
	if (!isEnvBrowser()) {
		return;
	}

	debugData(
		[
			{
				action: "getReport",
				data: {
					id: "1",
					title: "Armed Robbery Investigation",
					reportId: "RP-2024-001",
					officer: "J. Smith",
					type: "Investigation Report",
					created: Date.now() - 7200000,
					lastUpdated: Date.now() - 3600000,
					content:
						"<p>Initial response to armed robbery at Fleeca Bank Downtown...</p>",
					tags: ["Active Investigation", "High Priority"],
					involved: {
						officers: [
							{
								id: "1",
								fullName: "John Smith",
								badgeId: "1001",
								type: "Primary",
								notes: "Lead investigator",
							},
						],
						suspects: [
							{
								id: "1",
								citizenid: "ABC12345",
								fullName: "Robert Wilson",
								notes: "Armed with handgun, approximately 6ft tall",
							},
						],
						victims: [
							{
								id: "1",
								citizenid: "DEF67890",
								fullName: "Sarah Connor",
								type: "Primary",
							},
						],
					},
					evidence: [
						{
							id: "1",
							title: "Security Camera Footage",
							type: "Digital",
							serial: "CAM-001",
							notes: "Shows suspect entering bank",
							images: [
								"evidence_1_camera.jpg",
								"evidence_1_suspect.jpg",
							],
						},
					],
					restrictions: ["Confidential", "Detective Access Only"],
				},
			},
		],
		200,
	);
}
