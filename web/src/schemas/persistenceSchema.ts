import type { Report } from "@/interfaces/IReportEditor";

// Base persistence data structures for each page type
export interface ReportPageData {
	report: Report;
	tags: string[];
	searchQuery: string;
	activeFilters: string[];
	uiState: {
		showTagDropdown: boolean;
		showOfficerSearch: boolean;
		showSuspectSearch: boolean;
		showVictimSearch: boolean;
		selectedEvidenceId: string;
	};
}

export interface CitizensPageData {
	searchQuery: string;
	filters: {
		hasWarrants: boolean;
		jobType: string;
		flags: string[];
	};
	selectedCitizen: string | null;
	viewMode: "grid" | "list";
}

export interface ChargesPageData {
	searchQuery: string;
	collapsedSections: {
		felony: boolean;
		misdemeanor: boolean;
		infraction: boolean;
	};
	filters: {
		category: string[];
		type: string[];
	};
}

export interface VehiclesPageData {
	searchQuery: string;
	filters: {
		make: string[];
		model: string[];
		color: string[];
	};
	selectedVehicle: string | null;
}

export interface WeaponsPageData {
	searchQuery: string;
	filters: {
		type: string[];
		serial: string;
	};
	selectedWeapon: string | null;
}

export interface RosterPageData {
	searchQuery: string;
	filters: {
		department: string[];
		rank: string[];
		status: string[];
	};
	viewMode: "active" | "all";
}

export interface DashboardPageData {
	selectedTimeRange: string;
	expandedSections: string[];
	pinnedReports: string[];
}

export interface CasesPageData {
	searchQuery: string;
	selectedCaseId: number | null;
	filters: {
		status: string[];
		priority: string[];
		department: string[];
	};
}

// Main persistence schema - now simplified since data is stored in instance.data
export interface PersistenceSchema {
	// Global shared data (still uses localStorage directly)
	"global:recent-tags": string[];
	"global:user-preferences": {
		theme: string;
		notifications: boolean;
		autoSave: boolean;
	};
}
