import { fetchNui } from "../utils/fetchNui";
import { NUI_EVENTS } from "../constants/nuiEvents";
import type { SearchResult } from "../interfaces/IReportEditor";

export interface SearchServiceState {
	results: SearchResult[];
	isSearching: boolean;
	lastQuery: string;
	lastError: string | null;
}

export function createSearchService() {
	let state = $state<SearchServiceState>({
		results: [],
		isSearching: false,
		lastQuery: "",
		lastError: null,
	});

	/**
	 * Search for officers by query
	 */
	async function searchOfficers(query: string): Promise<SearchResult[]> {
		if (!query.trim()) {
			state.results = [];
			return [];
		}

		state.isSearching = true;
		state.lastQuery = query;
		state.lastError = null;

		try {
			const response = await fetchNui(
				NUI_EVENTS.REPORT.SEARCH_OFFICERS,
				{ query },
			);

			const results = response as unknown as SearchResult[];
			state.results = results;
			return results;
		} catch (error) {
			console.error("Failed to search officers:", error);
			state.lastError = "Failed to search officers";
			state.results = [];
			return [];
		} finally {
			state.isSearching = false;
		}
	}

	/**
	 * Search for players by query
	 */
	async function searchPlayers(query: string): Promise<SearchResult[]> {
		if (!query.trim()) {
			state.results = [];
			return [];
		}

		state.isSearching = true;
		state.lastQuery = query;
		state.lastError = null;

		try {
			const response = await fetchNui(
				NUI_EVENTS.REPORT.SEARCH_PLAYERS,
				{ query },
			);

			const results = response as unknown as SearchResult[];
			state.results = results;
			return results;
		} catch (error) {
			console.error("Failed to search players:", error);
			state.lastError = "Failed to search players";
			state.results = [];
			return [];
		} finally {
			state.isSearching = false;
		}
	}

	/**
	 * Clear search results
	 */
	function clearResults(): void {
		state.results = [];
		state.lastQuery = "";
		state.lastError = null;
	}

	/**
	 * Get cached results for the last query
	 */
	function getResults(): SearchResult[] {
		return state.results;
	}

	return {
		get state() {
			return state;
		},
		searchOfficers,
		searchPlayers,
		clearResults,
		getResults,
	};
}

export type SearchService = ReturnType<typeof createSearchService>;
