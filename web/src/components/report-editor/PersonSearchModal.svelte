<script lang="ts">
	import type { SearchResult } from "../../interfaces/IReportEditor";

	interface Props {
		show: boolean;
		title: string;
		searchResults: SearchResult[];
		onClose: () => void;
		onSearch: (query: string) => void;
		onSelect: (person: SearchResult) => void;
	}

	let {
		show,
		title,
		searchResults,
		onClose,
		onSearch,
		onSelect,
	}: Props = $props();

	let localQuery = $state("");
	let inputRef: HTMLInputElement | undefined = $state();
	let prevShow = false;

	// Only focus when modal first opens
	$effect(() => {
		const currentShow = show;
		if (currentShow && !prevShow) {
			localQuery = "";
			// Use requestAnimationFrame to avoid Svelte's render cycle
			requestAnimationFrame(() => {
				inputRef?.focus();
			});
		}
		prevShow = currentShow;
	});

	function handleInput() {
		onSearch(localQuery);
	}

	function handleSelect(person: SearchResult) {
		onSelect(person);
	}

	function handleOverlayClick(event: MouseEvent) {
		if (event.target === event.currentTarget) {
			onClose();
		}
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === "Escape") {
			onClose();
		}
	}
</script>

{#if show}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		class="popup-overlay"
		onclick={handleOverlayClick}
		onkeydown={handleKeydown}
	>
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div class="popup" role="dialog" aria-modal="true" onclick={(e) => e.stopPropagation()}>
			<div class="popup-header">
				<span class="popup-title">{title}</span>
				<button class="popup-close" onclick={onClose}>x</button>
			</div>
			<div class="popup-content">
				<input
					bind:this={inputRef}
					type="text"
					placeholder="Search by name or ID..."
					bind:value={localQuery}
					oninput={handleInput}
					class="search-input"
				/>
				<div class="search-results">
					{#each searchResults as person}
						<button
							class="search-result-item"
							onclick={() => handleSelect(person)}
						>
							<div class="result-info">
								<span class="result-name"
									>{person.fullName}</span
								>
								<span class="result-details">
									{#if person.badgeId}
										Badge: {person.badgeId} | {person.rank}
									{:else if person.citizenid}
										ID: {person.citizenid}
									{/if}
								</span>
							</div>
						</button>
					{/each}
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	.popup-overlay {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
		background: rgba(0, 0, 0, 0.6);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 2000;
	}

	.popup {
		background: var(--card-dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 6px;
		width: 90%;
		max-width: 400px;
		max-height: 70vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
	}

	.popup-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 10px 14px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.popup-title {
		font-size: 13px;
		font-weight: 500;
		color: rgba(255, 255, 255, 0.9);
	}

	.popup-close {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.5);
		font-size: 14px;
		cursor: pointer;
		padding: 0;
		width: 20px;
		height: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.popup-close:hover {
		color: rgba(255, 255, 255, 0.7);
	}

	.popup-content {
		padding: 12px 14px;
		overflow-y: auto;
		flex: 1;
	}

	.search-input {
		width: 100%;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 4px;
		padding: 7px 10px;
		color: rgba(255, 255, 255, 0.9);
		font-size: 11px;
		margin-bottom: 10px;
	}

	.search-input:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.1);
	}

	.search-input::placeholder {
		color: rgba(255, 255, 255, 0.35);
	}

	.search-results {
		max-height: 260px;
		overflow-y: auto;
	}

	.search-result-item {
		width: 100%;
		text-align: left;
		padding: 7px 10px;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		border-radius: 0;
		margin-bottom: 0;
		cursor: pointer;
		background: transparent;
		transition: background 0.1s;
	}

	.search-result-item:hover {
		background: rgba(255, 255, 255, 0.03);
	}

	.search-result-item:last-child {
		border-bottom: none;
	}

	.result-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.result-name {
		font-weight: 500;
		color: rgba(255, 255, 255, 0.9);
		font-size: 12px;
	}

	.result-details {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.5);
	}

	.search-results::-webkit-scrollbar {
		width: 4px;
	}

	.search-results::-webkit-scrollbar-track {
		background: transparent;
	}

	.search-results::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	.search-results::-webkit-scrollbar-thumb:hover {
		background: rgba(255, 255, 255, 0.1);
	}
</style>
