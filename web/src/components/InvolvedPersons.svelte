<script lang="ts">
	import { VICTIM_TYPES, OFFICER_TYPES } from "../constants";
	import type { Report } from "../interfaces/IReportEditor";

	export let report: Report;
	export let onRemoveSuspect: (index: number) => void;
	export let onRemoveVictim: (index: number) => void;
	export let onRemoveOfficer: (index: number) => void;

	let showSuspectSearch = false;
	let showVictimSearch = false;
	let showOfficerSearch = false;

	function toggleSuspectSearch() {
		showSuspectSearch = !showSuspectSearch;
		if (showSuspectSearch) {
			showVictimSearch = false;
			showOfficerSearch = false;
		}
	}

	function toggleVictimSearch() {
		showVictimSearch = !showVictimSearch;
		if (showVictimSearch) {
			showSuspectSearch = false;
			showOfficerSearch = false;
		}
	}

	function toggleOfficerSearch() {
		showOfficerSearch = !showOfficerSearch;
		if (showOfficerSearch) {
			showSuspectSearch = false;
			showVictimSearch = false;
		}
	}
</script>

<section class="involved-persons" aria-label="Involved persons">
	<h3 class="section-title">Involved Persons</h3>

	<!-- Suspects Section -->
	<div class="person-section">
		<div class="person-header">
			<h4 class="person-title">
				Suspects ({report.involved.suspects.length})
			</h4>
			<button
				type="button"
				on:click={toggleSuspectSearch}
				class="add-person-btn"
				aria-expanded={showSuspectSearch}
				aria-controls="suspect-search"
			>
				{showSuspectSearch ? "Cancel" : "Add Suspect"}
			</button>
		</div>

		{#if showSuspectSearch}
			<div
				id="suspect-search"
				class="search-container"
				role="region"
				aria-label="Add suspect"
			>
				<!-- Search component would go here -->
				<p class="search-placeholder">Suspect search interface</p>
			</div>
		{/if}

		{#if report.involved.suspects.length > 0}
			<div class="persons-list" role="list" aria-label="Suspects">
				{#each report.involved.suspects as suspect, index}
					<div class="person-item" role="listitem">
						<div class="person-info">
							<div class="person-name">{suspect.fullName}</div>
							<div class="person-details">
								Notes: {suspect.notes}
							</div>
						</div>
						<button
							type="button"
							on:click={() => onRemoveSuspect(index)}
							class="remove-person-btn"
							aria-label="Remove suspect {suspect.fullName}"
						>
							Remove
						</button>
					</div>
				{/each}
			</div>
		{:else}
			<p class="no-persons">No suspects added</p>
		{/if}
	</div>

	<!-- Victims Section -->
	<div class="person-section">
		<div class="person-header">
			<h4 class="person-title">
				Victims ({report.involved.victims.length})
			</h4>
			<button
				type="button"
				on:click={toggleVictimSearch}
				class="add-person-btn"
				aria-expanded={showVictimSearch}
				aria-controls="victim-search"
			>
				{showVictimSearch ? "Cancel" : "Add Victim"}
			</button>
		</div>

		{#if showVictimSearch}
			<div
				id="victim-search"
				class="search-container"
				role="region"
				aria-label="Add victim"
			>
				<!-- Search component would go here -->
				<p class="search-placeholder">Victim search interface</p>
			</div>
		{/if}

		{#if report.involved.victims.length > 0}
			<div class="persons-list" role="list" aria-label="Victims">
				{#each report.involved.victims as victim, index}
					<div class="person-item" role="listitem">
						<div class="person-info">
							<div class="person-name">{victim.fullName}</div>
							<div class="person-details">
								Type: {victim.type}
							</div>
						</div>
						<button
							type="button"
							on:click={() => onRemoveVictim(index)}
							class="remove-person-btn"
							aria-label="Remove victim {victim.fullName}"
						>
							Remove
						</button>
					</div>
				{/each}
			</div>
		{:else}
			<p class="no-persons">No victims added</p>
		{/if}
	</div>

	<!-- Officers Section -->
	<div class="person-section">
		<div class="person-header">
			<h4 class="person-title">
				Officers ({report.involved.officers.length})
			</h4>
			<button
				type="button"
				on:click={toggleOfficerSearch}
				class="add-person-btn"
				aria-expanded={showOfficerSearch}
				aria-controls="officer-search"
			>
				{showOfficerSearch ? "Cancel" : "Add Officer"}
			</button>
		</div>

		{#if showOfficerSearch}
			<div
				id="officer-search"
				class="search-container"
				role="region"
				aria-label="Add officer"
			>
				<!-- Search component would go here -->
				<p class="search-placeholder">Officer search interface</p>
			</div>
		{/if}

		{#if report.involved.officers.length > 0}
			<div class="persons-list" role="list" aria-label="Officers">
				{#each report.involved.officers as officer, index}
					<div class="person-item" role="listitem">
						<div class="person-info">
							<div class="person-name">{officer.fullName}</div>
							<div class="person-details">
								Type: {officer.type} | Badge: {officer.badgeId}
							</div>
						</div>
						<button
							type="button"
							on:click={() => onRemoveOfficer(index)}
							class="remove-person-btn"
							aria-label="Remove officer {officer.fullName}"
						>
							Remove
						</button>
					</div>
				{/each}
			</div>
		{:else}
			<p class="no-persons">No officers added</p>
		{/if}
	</div>
</section>

<style>
	.involved-persons {
		padding: 1rem;
		background: var(--surface-elevated);
		border-radius: 0.5rem;
		margin-bottom: 1rem;
	}

	.section-title {
		font-size: 1.25rem;
		font-weight: 600;
		color: var(--text-primary);
		margin: 0 0 1.5rem 0;
	}

	.person-section {
		margin-bottom: 2rem;
	}

	.person-section:last-child {
		margin-bottom: 0;
	}

	.person-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
		gap: 1rem;
	}

	.person-title {
		font-size: 1rem;
		font-weight: 600;
		color: var(--text-primary);
		margin: 0;
	}

	.add-person-btn {
		padding: 0.5rem 1rem;
		background: var(--primary-color);
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.add-person-btn:hover {
		background: var(--primary-dark);
	}

	.search-container {
		padding: 1rem;
		background: var(--surface-color);
		border: 1px solid var(--border-color);
		border-radius: 0.375rem;
		margin-bottom: 1rem;
	}

	.search-placeholder {
		color: var(--text-secondary);
		font-style: italic;
		margin: 0;
		text-align: center;
		padding: 2rem;
	}

	.persons-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.person-item {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		padding: 0.75rem;
		background: var(--surface-color);
		border: 1px solid var(--border-color);
		border-radius: 0.375rem;
		gap: 1rem;
	}

	.person-info {
		flex: 1;
		min-width: 0;
	}

	.person-name {
		font-weight: 600;
		color: var(--text-primary);
		margin-bottom: 0.25rem;
	}

	.person-details {
		font-size: 0.875rem;
		color: var(--text-secondary);
		word-wrap: break-word;
	}

	.remove-person-btn {
		padding: 0.375rem 0.75rem;
		background: var(--danger-color);
		color: white;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.75rem;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.2s;
		flex-shrink: 0;
	}

	.remove-person-btn:hover {
		background: var(--danger-dark);
	}

	.no-persons {
		color: var(--text-secondary);
		font-style: italic;
		margin: 0;
		padding: 1rem;
		text-align: center;
		background: var(--surface-color);
		border: 1px dashed var(--border-color);
		border-radius: 0.375rem;
	}
</style>
