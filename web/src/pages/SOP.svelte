<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import type { AuthService } from "../services/authService.svelte";

	interface SOPSection {
		id: number;
		title: string;
		content: string;
		sort_order: number;
	}

	interface SOPCategory {
		id: number;
		title: string;
		icon: string;
		sort_order: number;
		sections: SOPSection[];
	}

	let { authService }: { authService?: AuthService } = $props();

	interface SOPSettings {
		mission_statement?: string;
		introduction?: string;
		version?: number;
	}

	let categories = $state<SOPCategory[]>([]);
	let sopSettings = $state<SOPSettings>({});
	let selectedCategoryId = $state<number | null>(null);
	let searchQuery = $state("");
	let loading = $state(true);

	let selectedCategory = $derived(categories.find(c => c.id === selectedCategoryId) || null);

	let filteredCategories = $derived(() => {
		if (!searchQuery.trim()) return categories;
		const q = searchQuery.toLowerCase();
		return categories.map(cat => ({
			...cat,
			sections: cat.sections.filter(s =>
				s.title.toLowerCase().includes(q) || s.content.toLowerCase().includes(q)
			)
		})).filter(cat =>
			cat.title.toLowerCase().includes(q) || cat.sections.length > 0
		);
	});

	onMount(async () => {
		await Promise.all([loadCategories(), loadSettings()]);
	});

	async function loadSettings() {
		try {
			const result = await fetchNui<SOPSettings>(NUI_EVENTS.SOP.GET_SOP_SETTINGS, {}, {});
			sopSettings = result || {};
		} catch { sopSettings = {}; }
	}

	async function loadCategories() {
		loading = true;
		try {
			const result = await fetchNui<SOPCategory[]>(
				NUI_EVENTS.SOP.GET_SOP_CATEGORIES,
				{},
				[],
			);
			categories = result || [];
			if (categories.length > 0 && !selectedCategoryId) {
				selectedCategoryId = categories[0].id;
			}
		} catch {
			categories = [];
		} finally {
			loading = false;
		}
	}
</script>

<div class="sop-page">
	<div class="sop-sidebar">
		<div class="sidebar-header">
			<span class="material-icons header-icon">menu_book</span>
			<h2>Standard Operating Procedures</h2>
		</div>

		<div class="search-box">
			<span class="material-icons search-icon">search</span>
			<input
				type="text"
				placeholder="Search SOPs..."
				bind:value={searchQuery}
			/>
		</div>

		<div class="category-list">
			{#if loading}
				<div class="loading-state">
					<div class="spinner"></div>
					<span>Loading...</span>
				</div>
			{:else if filteredCategories().length === 0}
				<div class="empty-state">
					<span class="material-icons">info</span>
					<span>No SOPs found</span>
				</div>
			{:else}
				{#each filteredCategories() as category}
					<button
						class="category-item"
						class:active={selectedCategoryId === category.id}
						onclick={() => selectedCategoryId = category.id}
					>
						<span class="material-icons cat-icon">{category.icon || 'description'}</span>
						<div class="cat-info">
							<span class="cat-title">{category.title}</span>
							<span class="cat-count">{category.sections.length} section{category.sections.length !== 1 ? 's' : ''}</span>
						</div>
					</button>
				{/each}
			{/if}
		</div>
	</div>

	<div class="sop-content">
		{#if sopSettings.mission_statement}
			<div class="mission-banner">
				<div class="mission-header">
					<span class="material-icons mission-icon">flag</span>
					<h3>Mission Statement</h3>
				</div>
				<div class="mission-body prose">
					{@html sopSettings.mission_statement}
				</div>
			</div>
		{/if}
		{#if loading}
			<div class="content-empty">
				<div class="spinner"></div>
				<span>Loading SOPs...</span>
			</div>
		{:else if !selectedCategory}
			<div class="content-empty">
				<span class="material-icons empty-icon">menu_book</span>
				<h3>Select a Category</h3>
				<p>Choose an SOP category from the sidebar to view its contents.</p>
			</div>
		{:else if selectedCategory.sections.length === 0}
			<div class="content-empty">
				<span class="material-icons empty-icon">article</span>
				<h3>{selectedCategory.title}</h3>
				<p>No sections have been added to this category yet.</p>
			</div>
		{:else}
			<div class="content-header">
				<span class="material-icons">{selectedCategory.icon || 'description'}</span>
				<h2>{selectedCategory.title}</h2>
			</div>
			<div class="sections-list">
				{#each selectedCategory.sections as section, i}
					<div class="section-card">
						<div class="section-header">
							<span class="section-number">{i + 1}.</span>
							<h3 class="section-title">{section.title}</h3>
						</div>
						<div class="section-content prose">
							{@html section.content}
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.sop-page {
		display: flex;
		height: 100%;
		overflow: hidden;
	}

	/* Mission Banner */
	.mission-banner {
		background: linear-gradient(135deg, rgba(var(--accent-rgb, 59, 130, 246), 0.06), rgba(var(--accent-rgb, 59, 130, 246), 0.02));
		border: 1px solid rgba(var(--accent-rgb, 59, 130, 246), 0.12);
		border-radius: 10px;
		margin-bottom: 20px;
		overflow: hidden;
	}

	.mission-header {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px 20px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		background: rgba(255, 255, 255, 0.02);
	}

	.mission-icon {
		font-size: 18px;
		color: var(--accent-70);
	}

	.mission-header h3 {
		font-size: 13px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.9);
		margin: 0;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.mission-body {
		padding: 14px 20px;
		color: rgba(255, 255, 255, 0.75);
		font-size: 12.5px;
		line-height: 1.7;
	}

	.mission-body :global(p) { margin: 4px 0; }
	.mission-body :global(strong) { color: rgba(255, 255, 255, 0.95); }
	.mission-body :global(ul), .mission-body :global(ol) { padding-left: 18px; margin: 4px 0; }
	.mission-body :global(li) { margin: 2px 0; }

	/* Sidebar */
	.sop-sidebar {
		width: 280px;
		min-width: 280px;
		border-right: 1px solid rgba(255, 255, 255, 0.06);
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.sidebar-header {
		padding: 20px 20px 16px;
		display: flex;
		align-items: center;
		gap: 10px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
	}

	.header-icon {
		font-size: 22px;
		color: var(--accent-70);
	}

	.sidebar-header h2 {
		font-size: 14px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.9);
		margin: 0;
	}

	.search-box {
		padding: 12px 16px;
		position: relative;
		flex-shrink: 0;
	}

	.search-icon {
		position: absolute;
		left: 26px;
		top: 50%;
		transform: translateY(-50%);
		font-size: 16px;
		color: rgba(255, 255, 255, 0.3);
	}

	.search-box input {
		width: 100%;
		padding: 8px 12px 8px 34px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 6px;
		color: rgba(255, 255, 255, 0.9);
		font-size: 12px;
		outline: none;
		transition: border-color 0.15s;
	}

	.search-box input:focus {
		border-color: var(--accent-35);
	}

	.search-box input::placeholder {
		color: rgba(255, 255, 255, 0.3);
	}

	.category-list {
		flex: 1;
		overflow-y: auto;
		padding: 4px 8px;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.08) transparent;
	}

	.category-item {
		width: 100%;
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 10px 12px;
		border: 1px solid transparent;
		background: transparent;
		border-radius: 6px;
		cursor: pointer;
		text-align: left;
		transition: all 0.15s;
		margin-bottom: 2px;
		outline: none;
	}

	.category-item:hover:not(.active) {
		background: rgba(255, 255, 255, 0.04);
	}

	.category-item.active {
		background: var(--accent-10);
		border-color: var(--accent-15);
	}

	.cat-icon {
		font-size: 18px;
		color: rgba(255, 255, 255, 0.4);
		flex-shrink: 0;
	}

	.category-item.active .cat-icon {
		color: var(--accent-70);
	}

	.cat-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
		min-width: 0;
	}

	.cat-title {
		font-size: 12px;
		font-weight: 500;
		color: rgba(255, 255, 255, 0.8);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.cat-count {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.35);
	}

	/* Main Content */
	.sop-content {
		flex: 1;
		overflow-y: auto;
		padding: 24px 32px;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.08) transparent;
	}

	.content-header {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 24px;
		padding-bottom: 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.content-header .material-icons {
		font-size: 24px;
		color: var(--accent-70);
	}

	.content-header h2 {
		font-size: 18px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.95);
		margin: 0;
	}

	.content-empty {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 100%;
		gap: 8px;
		color: rgba(255, 255, 255, 0.4);
		text-align: center;
	}

	.empty-icon {
		font-size: 48px;
		color: rgba(255, 255, 255, 0.15);
		margin-bottom: 8px;
	}

	.content-empty h3 {
		font-size: 16px;
		color: rgba(255, 255, 255, 0.6);
		margin: 0;
	}

	.content-empty p {
		font-size: 13px;
		color: rgba(255, 255, 255, 0.35);
		margin: 0;
	}

	/* Sections */
	.sections-list {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.section-card {
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 10px;
		overflow: hidden;
	}

	.section-header {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 14px 20px;
		background: rgba(255, 255, 255, 0.02);
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.section-number {
		font-size: 13px;
		font-weight: 700;
		color: var(--accent-60);
		min-width: 20px;
	}

	.section-title {
		font-size: 14px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.9);
		margin: 0;
	}

	.section-content {
		padding: 16px 20px;
		color: rgba(255, 255, 255, 0.75);
		font-size: 13px;
		line-height: 1.7;
	}

	.section-content :global(h1),
	.section-content :global(h2),
	.section-content :global(h3) {
		color: rgba(255, 255, 255, 0.9);
		margin: 12px 0 6px;
	}

	.section-content :global(h1) { font-size: 16px; }
	.section-content :global(h2) { font-size: 15px; }
	.section-content :global(h3) { font-size: 14px; }

	.section-content :global(p) {
		margin: 6px 0;
	}

	.section-content :global(ul),
	.section-content :global(ol) {
		padding-left: 20px;
		margin: 6px 0;
	}

	.section-content :global(li) {
		margin: 3px 0;
	}

	.section-content :global(strong) {
		color: rgba(255, 255, 255, 0.95);
	}

	/* Loading & Empty */
	.loading-state,
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		padding: 32px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 12px;
	}

	.spinner {
		width: 24px;
		height: 24px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left-color: var(--accent-60);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
</style>
