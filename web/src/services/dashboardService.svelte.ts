import { useNuiEvent } from "../utils/useNuiEvent";
import { fetchNui } from "../utils/fetchNui";
import { debugError } from "../utils/debug";
import { isEnvBrowser } from "../utils/misc";
import { NUI_EVENTS } from "../constants/nuiEvents";
import type { DashboardData } from "../interfaces/IDashboard";

export function createDashboardService() {
	// State initialization with default values
	const defaultState = {
		jobInfo: { rank: "Loading...", payRate: "$0/hr" },
		reportsInfo: { totalThisWeek: 0, changeFromLastWeek: 0 },
		weeklyTimeData: [] as Array<{ day: string; hours: number }>,
		activeWarrants: [] as DashboardData["activeWarrants"],
		recentReports: [] as DashboardData["recentReports"],
		activeBolos: [] as DashboardData["activeBolos"],
		bulletins: [
			{ id: 1, content: "Loading..." },
		] as DashboardData["bulletins"],
		activeUnits: { count: 0 },
		recentDispatches: [] as DashboardData["recentDispatches"],
		usageMetrics: {
			totals: {
				reports: 0,
				arrests: 0,
				activeWarrants: 0,
			},
			windows: {
				reportsLast7: 0,
				reportsLast30: 0,
				arrestsLast7: 0,
				arrestsLast30: 0,
			},
		},
	};

	// State variables
	let jobInfo = $state(defaultState.jobInfo);
	let reportsInfo = $state(defaultState.reportsInfo);
	let weeklyTimeData = $state(defaultState.weeklyTimeData);
	let activeWarrants = $state(defaultState.activeWarrants);
	let recentReports = $state(defaultState.recentReports);
	let recentReportsPage = $state(1);
	let recentReportsHasMore = $state(true);
	const recentReportsPageSize = 10;
	let activeBolos = $state(defaultState.activeBolos);
	let bulletins = $state(defaultState.bulletins);
	let activeUnits = $state(defaultState.activeUnits);
	let recentDispatches = $state(defaultState.recentDispatches);
	let usageMetrics = $state(defaultState.usageMetrics);

	// Derived state
	let currentBulletinIndex = $state(0);
	let bulletinCarouselInterval: ReturnType<typeof setInterval> | null =
		$state(null);
	let progressUpdateInterval: ReturnType<typeof setInterval> | null =
		$state(null);
	let carouselProgress = $state(0);
	let bulletinStartTime = $state(Date.now());
	const CAROUSEL_DURATION = 5000;

	let bulletinContent = $derived(
		bulletins && bulletins.length > 0
			? bulletins[currentBulletinIndex]?.content || "Loading bulletins..."
			: "Loading bulletins...",
	);

	// Carousel functions
	function updateProgress() {
		const elapsed = Date.now() - bulletinStartTime;
		carouselProgress = Math.min(elapsed / CAROUSEL_DURATION, 1);
	}

	function resetProgress() {
		bulletinStartTime = Date.now();
		carouselProgress = 0;
	}

	function nextBulletin() {
		if (bulletins && bulletins.length > 1) {
			currentBulletinIndex =
				(currentBulletinIndex + 1) % bulletins.length;
			resetProgress();
		}
	}

	function prevBulletin() {
		if (bulletins && bulletins.length > 1) {
			currentBulletinIndex =
				currentBulletinIndex === 0
					? bulletins.length - 1
					: currentBulletinIndex - 1;
			resetProgress();
		}
	}

	function goToBulletin(index: number) {
		if (bulletins && index >= 0 && index < bulletins.length) {
			currentBulletinIndex = index;
			resetProgress();
		}
	}

	function startCarouselTimer() {
		if (bulletinCarouselInterval) {
			clearInterval(bulletinCarouselInterval);
		}
		if (progressUpdateInterval) {
			clearInterval(progressUpdateInterval);
		}

		if (bulletins && bulletins.length > 1) {
			resetProgress();
			bulletinCarouselInterval = setInterval(
				nextBulletin,
				CAROUSEL_DURATION,
			);
			progressUpdateInterval = setInterval(updateProgress, 50);
		}
	}

	function stopCarouselTimer() {
		if (bulletinCarouselInterval) {
			clearInterval(bulletinCarouselInterval);
			bulletinCarouselInterval = null;
		}
		if (progressUpdateInterval) {
			clearInterval(progressUpdateInterval);
			progressUpdateInterval = null;
		}
		carouselProgress = 0;
	}

	// Auto-start carousel when bulletins are loaded/updated
	function checkAndStartCarousel() {
		if (
			bulletins &&
			bulletins.length > 1 &&
			bulletins[0].content !== "Loading..."
		) {
			startCarouselTimer();
		}
	}

	// Setup event listeners
	function setupEventListeners() {
		useNuiEvent<DashboardData["jobData"]>(
			NUI_EVENTS.DASHBOARD.UPDATE_JOB_DATA,
			(data) => {
				jobInfo = data || jobInfo;
			},
		);

		useNuiEvent<DashboardData["reportStatistics"]>(
			NUI_EVENTS.DASHBOARD.UPDATE_REPORT_STATISTICS,
			(data) => {
				reportsInfo = data || reportsInfo;
			},
		);

		useNuiEvent<DashboardData["timeStatistics"]>(
			NUI_EVENTS.DASHBOARD.UPDATE_TIME_STATISTICS,
			(data) => {
				weeklyTimeData = data || weeklyTimeData;
			},
		);

		useNuiEvent<DashboardData["activeWarrants"]>(
			NUI_EVENTS.DASHBOARD.UPDATE_ACTIVE_WARRANTS,
			(data) => {
				activeWarrants = Array.isArray(data) ? data : activeWarrants;
			},
		);

		useNuiEvent<DashboardData["bulletins"]>(
			NUI_EVENTS.DASHBOARD.UPDATE_BULLETINS,
			(data) => {
				if (data) {
					bulletins = data;
					checkAndStartCarousel();
				}
			},
		);

		useNuiEvent<DashboardData["recentReports"]>(
			NUI_EVENTS.DASHBOARD.UPDATE_RECENT_REPORTS,
			(data) => {
				recentReports = data || recentReports;
			},
		);

		useNuiEvent<DashboardData["activeBolos"]>(
			NUI_EVENTS.DASHBOARD.UPDATE_ACTIVE_BOLOS,
			(data) => {
				activeBolos = data || activeBolos;
			},
		);

		useNuiEvent<DashboardData["activeUnits"]>(
			NUI_EVENTS.DASHBOARD.UPDATE_ACTIVE_UNITS,
			(data) => {
				activeUnits = data || activeUnits;
			},
		);

		useNuiEvent<DashboardData["recentDispatches"]>(
			NUI_EVENTS.DASHBOARD.UPDATE_RECENT_DISPATCHES,
			(data) => {
				recentDispatches = data || recentDispatches;
			},
		);

		useNuiEvent<DashboardData["usageMetrics"]>(
			NUI_EVENTS.DASHBOARD.UPDATE_USAGE_METRICS,
			(data) => {
				usageMetrics = data || usageMetrics;
			},
		);
	}

	// Load initial data
	async function loadInitialData() {
		// Single aggregated round-trip for the whole dashboard. Previously this
		// fired ~9 separate NUI callbacks (one per widget) on open — each a
		// server round-trip + cb() serialisation the client had to process,
		// which was the bulk of the on-open ps-mdt spike. Now it's one call.
		type DashboardPayload = {
			jobData?: typeof jobInfo;
			reportStatistics?: typeof reportsInfo;
			timeStatistics?: typeof weeklyTimeData;
			activeWarrants?: typeof activeWarrants;
			bulletins?: typeof bulletins;
			activeBolos?: typeof activeBolos;
			activeUnits?: typeof activeUnits;
			recentDispatches?: typeof recentDispatches;
			usageMetrics?: typeof usageMetrics;
		};

		try {
			const data = await fetchNui<DashboardPayload>(
				NUI_EVENTS.DASHBOARD.GET_DASHBOARD,
				{},
				{},
			);

			if (data && typeof data === "object") {
				jobInfo = data.jobData || jobInfo;
				reportsInfo = data.reportStatistics || reportsInfo;
				weeklyTimeData = data.timeStatistics || weeklyTimeData;
				activeWarrants = Array.isArray(data.activeWarrants)
					? data.activeWarrants
					: activeWarrants;
				if (data.bulletins) {
					bulletins = data.bulletins;
					checkAndStartCarousel();
				}
				activeBolos = data.activeBolos || activeBolos;
				activeUnits = data.activeUnits || activeUnits;
				recentDispatches = data.recentDispatches || recentDispatches;
				usageMetrics = data.usageMetrics || usageMetrics;
			}
		} catch (error) {
			debugError("Failed to fetch dashboard data:", error);
		}

		await loadRecentReports(1, true);
	}

	async function loadRecentReports(page = 1, reset = false) {
		try {
			const payload = { page, limit: recentReportsPageSize };
			const response = await fetchNui(
				NUI_EVENTS.DASHBOARD.GET_RECENT_REPORTS,
				payload,
				[],
			);
			const items = Array.isArray(response) ? response : [];
			recentReports = reset ? items : [...recentReports, ...items];
			recentReportsPage = page;
			recentReportsHasMore = items.length >= recentReportsPageSize;
		} catch (error) {
			debugError("Failed to fetch recent reports:", error);
		}
	}

	async function loadMoreRecentReports() {
		if (!recentReportsHasMore) return;
		await loadRecentReports(recentReportsPage + 1);
	}

	// Cleanup all intervals and resources
	function destroy() {
		stopCarouselTimer();
	}

	// Initialize the service
	async function initialize() {
		// Clean up any existing intervals before re-initializing
		stopCarouselTimer();

		if (isEnvBrowser()) {
			const now = Date.now();
			jobInfo = { rank: "Sergeant", payRate: "$450/hr" };
			reportsInfo = { totalThisWeek: 12, changeFromLastWeek: 3 };
			weeklyTimeData = [
				{ day: "Mon", hours: 6.5 },
				{ day: "Tue", hours: 8.0 },
				{ day: "Wed", hours: 4.5 },
				{ day: "Thu", hours: 7.0 },
				{ day: "Fri", hours: 9.0 },
				{ day: "Sat", hours: 3.0 },
				{ day: "Sun", hours: 0 },
			];
			activeWarrants = [
				{ id: 1, name: "Marcus Johnson", expiryDate: new Date(now + 7 * 86400000).toISOString() } as any,
				{ id: 2, name: "James Miller", expiryDate: new Date(now + 3 * 86400000).toISOString() } as any,
			];
			recentReports = [
				{ id: "1", reportId: "RPT-001", title: "Armed Robbery at Fleeca Bank", author: "Ofc. Smith", type: "Incident", datecreated: now - 86400000, dateupdated: now - 3600000 } as any,
				{ id: "2", reportId: "RPT-002", title: "Traffic Stop - Suspended License", author: "Ofc. Johnson", type: "Citation", datecreated: now - 172800000, dateupdated: now - 86400000 } as any,
				{ id: "3", reportId: "RPT-003", title: "Drive-by Shooting on Vinewood Blvd", author: "Det. Williams", type: "Incident", datecreated: now - 259200000, dateupdated: now - 172800000 } as any,
			];
			activeBolos = [
				{ id: 1, reportId: "RPT-001", name: "Marcus Johnson", type: "citizen", notes: "Wanted for armed robbery" } as any,
				{ id: 2, reportId: "RPT-003", name: "Black Kuruma", type: "vehicle", notes: "Suspected in drive-by shooting" } as any,
			];
			bulletins = [
				{ id: 1, content: "Shift briefing at 0800 - mandatory attendance for all patrol units." },
				{ id: 2, content: "New body camera policy in effect starting Monday. See Sgt. Garcia for details." },
				{ id: 3, content: "Overtime available this weekend for anyone willing to cover the Vespucci patrol zone." },
			];
			activeUnits = { count: 8 };
			recentDispatches = [
				{ id: "D-001", title: "10-31 - Robbery in Progress", location: "Fleeca Bank, Hawick Ave", priority: 1, time: now - 300000, units: ["401", "405"] } as any,
				{ id: "D-002", title: "10-50 - Vehicle Accident", location: "Route 68 & Senora Way", priority: 3, time: now - 1800000, units: ["455"] } as any,
				{ id: "D-003", title: "10-15 - Disturbance", location: "Vespucci Beach Boardwalk", priority: 2, time: now - 3600000, units: ["496", "431"] } as any,
			];
			usageMetrics = {
				totals: { reports: 247, arrests: 89, activeWarrants: 4 },
				windows: { reportsLast7: 12, reportsLast30: 47, arrestsLast7: 5, arrestsLast30: 18 },
			};
			return;
		}
		setupEventListeners();
		await loadInitialData();
	}

	// Public API - getters for reactive state
	return {
		// State getters
		get jobInfo() {
			return jobInfo;
		},
		get reportsInfo() {
			return reportsInfo;
		},
		get weeklyTimeData() {
			return weeklyTimeData;
		},
		get activeWarrants() {
			return activeWarrants;
		},
		get recentReports() {
			return recentReports;
		},
		get recentReportsHasMore() {
			return recentReportsHasMore;
		},
		get activeBolos() {
			return activeBolos;
		},
		get bulletins() {
			return bulletins;
		},
		get bulletinContent() {
			return bulletinContent;
		},
		get activeUnits() {
			return activeUnits;
		},
		get recentDispatches() {
			return recentDispatches;
		},
		get usageMetrics() {
			return usageMetrics;
		},

		// Carousel state
		get currentBulletinIndex() {
			return currentBulletinIndex;
		},
		get carouselProgress() {
			return carouselProgress;
		},

		// Methods
		initialize,
		destroy,
		loadInitialData,
		loadMoreRecentReports,

		// Carousel methods
		nextBulletin,
		prevBulletin,
		goToBulletin,
		startCarouselTimer,
		stopCarouselTimer,
		checkAndStartCarousel,

		// State setters (if needed for external updates)
		setRecentDispatches: (data: DashboardData["recentDispatches"]) => {
			recentDispatches = data;
		},
	};
}

export type DashboardService = ReturnType<typeof createDashboardService>;