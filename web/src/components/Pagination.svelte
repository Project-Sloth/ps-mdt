<script lang="ts">
	interface Props {
		currentPage: number;
		totalItems: number;
		perPage: number;
		perPageOptions?: number[];
		onPageChange: (page: number) => void;
		onPerPageChange?: (perPage: number) => void;
	}

	let {
		currentPage,
		totalItems,
		perPage,
		perPageOptions = [10, 25, 50, 100],
		onPageChange,
		onPerPageChange,
	}: Props = $props();

	let totalPages = $derived(Math.max(1, Math.ceil(totalItems / perPage)));
	let rangeStart = $derived(totalItems > 0 ? (currentPage - 1) * perPage + 1 : 0);
	let rangeEnd = $derived(Math.min(currentPage * perPage, totalItems));

	let visiblePages = $derived.by(() => {
		const pages: number[] = [];
		const maxVisible = 5;
		let start = Math.max(1, currentPage - Math.floor(maxVisible / 2));
		let end = start + maxVisible - 1;
		if (end > totalPages) {
			end = totalPages;
			start = Math.max(1, end - maxVisible + 1);
		}
		for (let i = start; i <= end; i++) pages.push(i);
		return pages;
	});

	let dropdownOpen = $state(false);

	function goToPage(page: number) {
		if (page < 1 || page > totalPages || page === currentPage) return;
		onPageChange(page);
	}

	function selectPerPage(value: number) {
		dropdownOpen = false;
		if (onPerPageChange) onPerPageChange(value);
	}

	function toggleDropdown() {
		dropdownOpen = !dropdownOpen;
	}

	function handleClickOutside(e: MouseEvent) {
		const target = e.target as HTMLElement;
		if (!target.closest('.per-page-dropdown')) {
			dropdownOpen = false;
		}
	}
</script>

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="pagination-bar" onclick={handleClickOutside}>
	<div class="pagination-left">
		<span class="range-label">
			{#if totalItems > 0}
				{rangeStart}–{rangeEnd} of {totalItems}
			{:else}
				0 entries
			{/if}
		</span>
		{#if onPerPageChange}
			<div class="per-page-dropdown">
				<button class="per-page-trigger" onclick={toggleDropdown}>
					{perPage} / page
					<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
						<polyline points={dropdownOpen ? "18 15 12 9 6 15" : "6 9 12 15 18 9"}/>
					</svg>
				</button>
				{#if dropdownOpen}
					<div class="per-page-menu">
						{#each perPageOptions as opt}
							<button
								class="per-page-option"
								class:active={opt === perPage}
								onclick={() => selectPerPage(opt)}
							>{opt} / page</button>
						{/each}
					</div>
				{/if}
			</div>
		{/if}
	</div>

	{#if totalPages > 1}
		<div class="pagination-center">
			<button class="page-btn" disabled={currentPage <= 1} onclick={() => goToPage(1)} title="First page">
				<span class="material-icons" style="font-size:14px">first_page</span>
			</button>
			<button class="page-btn" disabled={currentPage <= 1} onclick={() => goToPage(currentPage - 1)} title="Previous page">
				<span class="material-icons" style="font-size:14px">chevron_left</span>
			</button>

			{#each visiblePages as p}
				<button
					class="page-num"
					class:active={p === currentPage}
					onclick={() => goToPage(p)}
				>{p}</button>
			{/each}

			<button class="page-btn" disabled={currentPage >= totalPages} onclick={() => goToPage(currentPage + 1)} title="Next page">
				<span class="material-icons" style="font-size:14px">chevron_right</span>
			</button>
			<button class="page-btn" disabled={currentPage >= totalPages} onclick={() => goToPage(totalPages)} title="Last page">
				<span class="material-icons" style="font-size:14px">last_page</span>
			</button>
		</div>
	{/if}
</div>

<style>
	.pagination-bar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 14px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
	}

	.pagination-left {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.range-label {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.4);
		white-space: nowrap;
	}

	/* ── Custom Per-Page Dropdown ── */
	.per-page-dropdown {
		position: relative;
	}

	.per-page-trigger {
		display: flex;
		align-items: center;
		gap: 5px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 6px;
		color: rgba(255, 255, 255, 0.55);
		font-size: 11px;
		padding: 4px 8px;
		cursor: pointer;
		transition: all 0.15s ease;
	}

	.per-page-trigger:hover {
		background: rgba(255, 255, 255, 0.07);
		color: rgba(255, 255, 255, 0.8);
		border-color: rgba(255, 255, 255, 0.12);
	}

	.per-page-menu {
		position: absolute;
		bottom: calc(100% + 4px);
		left: 0;
		background: var(--secondary-bg);
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 8px;
		padding: 4px;
		min-width: 100px;
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
		z-index: 50;
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.per-page-option {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.6);
		font-size: 11px;
		padding: 6px 10px;
		border-radius: 5px;
		cursor: pointer;
		text-align: left;
		transition: all 0.1s ease;
	}

	.per-page-option:hover {
		background: rgba(255, 255, 255, 0.08);
		color: rgba(255, 255, 255, 0.9);
	}

	.per-page-option.active {
		background: rgba(var(--accent-rgb), 0.15);
		color: #93c5fd;
		font-weight: 600;
	}

	/* ── Page Buttons ── */
	.pagination-center {
		display: flex;
		align-items: center;
		gap: 4px;
	}

	.page-btn {
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.5);
		border-radius: 6px;
		padding: 4px 6px;
		cursor: pointer;
		display: flex;
		align-items: center;
		transition: all 0.15s ease;
	}

	.page-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.08);
		color: rgba(255, 255, 255, 0.9);
	}

	.page-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.page-num {
		background: transparent;
		border: 1px solid transparent;
		color: rgba(255, 255, 255, 0.45);
		border-radius: 6px;
		padding: 3px 9px;
		font-size: 11px;
		cursor: pointer;
		transition: all 0.15s ease;
	}

	.page-num:hover {
		background: rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.8);
	}

	.page-num.active {
		background: rgba(var(--accent-rgb), 0.15);
		border-color: rgba(var(--accent-rgb), 0.3);
		color: #93c5fd;
		font-weight: 600;
	}
</style>
