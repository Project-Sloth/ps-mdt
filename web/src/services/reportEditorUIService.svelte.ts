export interface ReportEditorUIState {
	// Modal states
	showTagDropdown: boolean;
	showOfficerSearch: boolean;
	showSuspectSearch: boolean;
	showVictimSearch: boolean;
	showImageUpload: boolean;

	// Search states
	activeSearch: string;
	searchQuery: string;

	// Other UI states
	selectedEvidenceId: string;
}

export function createReportEditorUIService() {
	let state = $state<ReportEditorUIState>({
		showTagDropdown: false,
		showOfficerSearch: false,
		showSuspectSearch: false,
		showVictimSearch: false,
		showImageUpload: false,
		activeSearch: "",
		searchQuery: "",
		selectedEvidenceId: "",
	});

	// ===== TAG DROPDOWN =====
	function openTagDropdown(): void {
		state.showTagDropdown = true;
	}

	function closeTagDropdown(): void {
		state.showTagDropdown = false;
	}

	function toggleTagDropdown(): void {
		state.showTagDropdown = !state.showTagDropdown;
	}

	// ===== OFFICER SEARCH =====
	function openOfficerSearch(): void {
		state.showOfficerSearch = true;
		state.activeSearch = "officers";
		state.searchQuery = "";
	}

	function closeOfficerSearch(): void {
		state.showOfficerSearch = false;
		state.activeSearch = "";
		state.searchQuery = "";
	}

	// ===== SUSPECT SEARCH =====
	function openSuspectSearch(): void {
		state.showSuspectSearch = true;
		state.activeSearch = "suspects";
		state.searchQuery = "";
	}

	function closeSuspectSearch(): void {
		state.showSuspectSearch = false;
		state.activeSearch = "";
		state.searchQuery = "";
	}

	// ===== VICTIM SEARCH =====
	function openVictimSearch(): void {
		state.showVictimSearch = true;
		state.activeSearch = "victims";
		state.searchQuery = "";
	}

	function closeVictimSearch(): void {
		state.showVictimSearch = false;
		state.activeSearch = "";
		state.searchQuery = "";
	}

	// ===== IMAGE UPLOAD =====
	function openImageUpload(evidenceId: string): void {
		state.selectedEvidenceId = evidenceId;
		state.showImageUpload = true;
	}

	function closeImageUpload(): void {
		state.showImageUpload = false;
		state.selectedEvidenceId = "";
	}

	// ===== SEARCH QUERY =====
	function setSearchQuery(query: string): void {
		state.searchQuery = query;
	}

	function clearSearch(): void {
		state.searchQuery = "";
		state.activeSearch = "";
	}

	// ===== UTILITY FUNCTIONS =====
	function closeAllModals(): void {
		state.showTagDropdown = false;
		state.showOfficerSearch = false;
		state.showSuspectSearch = false;
		state.showVictimSearch = false;
		state.showImageUpload = false;
		state.activeSearch = "";
		state.searchQuery = "";
		state.selectedEvidenceId = "";
	}

	function handleClickOutside(event: MouseEvent): void {
		const target = event.target as HTMLElement;
		if (!target.closest(".dropdown-container")) {
			closeTagDropdown();
		}
	}

	return {
		get state() {
			return state;
		},
		// Tag dropdown
		openTagDropdown,
		closeTagDropdown,
		toggleTagDropdown,
		// Officer search
		openOfficerSearch,
		closeOfficerSearch,
		// Suspect search
		openSuspectSearch,
		closeSuspectSearch,
		// Victim search
		openVictimSearch,
		closeVictimSearch,
		// Image upload
		openImageUpload,
		closeImageUpload,
		// Search
		setSearchQuery,
		clearSearch,
		// Utilities
		closeAllModals,
		handleClickOutside,
	};
}

export type ReportEditorUIService = ReturnType<
	typeof createReportEditorUIService
>;
