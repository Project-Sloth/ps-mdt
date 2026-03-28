<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../../utils/fetchNui";
	import { NUI_EVENTS } from "../../constants/nuiEvents";
	import { createEditorService } from "../../services/editorService.svelte";
	import type { AuthService } from "../../services/authService.svelte";

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

	interface SOPSettings {
		job?: string;
		mission_statement?: string;
		introduction?: string;
		version?: number;
		updated_by?: string;
		updated_at?: string;
	}

	let { authService }: { authService?: AuthService } = $props();

	// State
	let activeTab = $state<"mission" | "intro" | "categories" | "publish">("categories");
	let categories = $state<SOPCategory[]>([]);
	let settings = $state<SOPSettings>({});
	let loading = $state(true);
	let statusMsg = $state("");

	// Category editing
	let selectedCategoryId = $state<number | null>(null);
	let newCategoryTitle = $state("");
	let newCategoryIcon = $state("description");
	let editingCategoryId = $state<number | null>(null);
	let editCategoryTitle = $state("");
	let editCategoryIcon = $state("");

	// Section editing
	let editingSectionId = $state<number | null>(null);
	let newSectionTitle = $state("");
	let editSectionTitle = $state("");
	let sectionContent = $state("");

	// Mission editor
	let missionEditorEl = $state<HTMLElement | null>(null);
	let missionEditorService = createEditorService();
	let missionInitialized = $state(false);

	// Intro editor
	let introEditorEl = $state<HTMLElement | null>(null);
	let introEditorService = createEditorService();
	let introInitialized = $state(false);

	// Section editor
	let sectionEditorEl = $state<HTMLElement | null>(null);
	let sectionEditorService = createEditorService();
	let sectionInitialized = $state(false);

	// Publish
	let publishing = $state(false);
	let confirmPublish = $state(false);

	let selectedCategory = $derived(categories.find(c => c.id === selectedCategoryId) || null);

	onMount(async () => {
		await Promise.all([loadCategories(), loadSettings()]);
	});

	// Initialize mission editor when tab switches
	$effect(() => {
		if (activeTab === "mission" && missionEditorEl && !missionInitialized) {
			missionEditorService.initializeEditor(
				missionEditorEl,
				settings.mission_statement || "",
				(content) => { settings.mission_statement = content; }
			);
			missionInitialized = true;
		}
	});

	// Initialize intro editor when tab switches
	$effect(() => {
		if (activeTab === "intro" && introEditorEl && !introInitialized) {
			introEditorService.initializeEditor(
				introEditorEl,
				settings.introduction || "",
				(content) => { settings.introduction = content; }
			);
			introInitialized = true;
		}
	});

	// Initialize section editor when editing a section
	$effect(() => {
		if (editingSectionId && sectionEditorEl && !sectionInitialized) {
			const section = selectedCategory?.sections.find(s => s.id === editingSectionId);
			sectionEditorService.initializeEditor(
				sectionEditorEl,
				section?.content || "",
				(content) => { sectionContent = content; }
			);
			sectionInitialized = true;
		}
	});

	async function loadCategories() {
		loading = true;
		try {
			const result = await fetchNui<SOPCategory[]>(NUI_EVENTS.SOP.GET_SOP_CATEGORIES, {}, []);
			categories = result || [];
		} catch { categories = []; }
		finally { loading = false; }
	}

	async function loadSettings() {
		try {
			const result = await fetchNui<SOPSettings>(NUI_EVENTS.SOP.GET_SOP_SETTINGS, {}, {});
			settings = result || {};
		} catch { settings = {}; }
	}

	// ---- Category CRUD ----

	async function createCategory() {
		if (!newCategoryTitle.trim()) return;
		const result = await fetchNui<{ success: boolean; id?: number }>(
			NUI_EVENTS.SOP.CREATE_SOP_CATEGORY,
			{ title: newCategoryTitle.trim(), icon: newCategoryIcon || "description" },
			{ success: true, id: 1 }
		);
		if (result?.success) {
			newCategoryTitle = "";
			newCategoryIcon = "description";
			await loadCategories();
			showStatus("Category created");
		}
	}

	async function saveCategory() {
		if (!editingCategoryId || !editCategoryTitle.trim()) return;
		const result = await fetchNui<{ success: boolean }>(
			NUI_EVENTS.SOP.UPDATE_SOP_CATEGORY,
			{ id: editingCategoryId, title: editCategoryTitle.trim(), icon: editCategoryIcon },
			{ success: true }
		);
		if (result?.success) {
			editingCategoryId = null;
			await loadCategories();
			showStatus("Category updated");
		}
	}

	async function deleteCategory(id: number) {
		const result = await fetchNui<{ success: boolean }>(
			NUI_EVENTS.SOP.DELETE_SOP_CATEGORY,
			{ id },
			{ success: true }
		);
		if (result?.success) {
			if (selectedCategoryId === id) selectedCategoryId = null;
			await loadCategories();
			showStatus("Category deleted");
		}
	}

	function startEditCategory(cat: SOPCategory) {
		editingCategoryId = cat.id;
		editCategoryTitle = cat.title;
		editCategoryIcon = cat.icon;
	}

	// ---- Section CRUD ----

	async function createSection() {
		if (!selectedCategoryId || !newSectionTitle.trim()) return;
		const result = await fetchNui<{ success: boolean; id?: number }>(
			NUI_EVENTS.SOP.CREATE_SOP_SECTION,
			{ category_id: selectedCategoryId, title: newSectionTitle.trim(), content: "" },
			{ success: true, id: 1 }
		);
		if (result?.success) {
			newSectionTitle = "";
			await loadCategories();
			showStatus("Section created");
		}
	}

	function startEditSection(section: SOPSection) {
		editingSectionId = section.id;
		editSectionTitle = section.title;
		sectionContent = section.content;
		sectionInitialized = false;
	}

	async function saveSection() {
		if (!editingSectionId) return;
		const result = await fetchNui<{ success: boolean }>(
			NUI_EVENTS.SOP.UPDATE_SOP_SECTION,
			{ id: editingSectionId, title: editSectionTitle.trim(), content: sectionContent },
			{ success: true }
		);
		if (result?.success) {
			sectionEditorService.destroyEditor();
			sectionInitialized = false;
			editingSectionId = null;
			await loadCategories();
			showStatus("Section saved");
		}
	}

	function cancelEditSection() {
		sectionEditorService.destroyEditor();
		sectionInitialized = false;
		editingSectionId = null;
	}

	async function deleteSection(id: number) {
		const result = await fetchNui<{ success: boolean }>(
			NUI_EVENTS.SOP.DELETE_SOP_SECTION,
			{ id },
			{ success: true }
		);
		if (result?.success) {
			if (editingSectionId === id) cancelEditSection();
			await loadCategories();
			showStatus("Section deleted");
		}
	}

	// ---- Mission Statement ----

	async function saveMission() {
		const content = missionEditorService.getContent();
		const result = await fetchNui<{ success: boolean }>(
			NUI_EVENTS.SOP.UPDATE_SOP_MISSION,
			{ mission_statement: content },
			{ success: true }
		);
		if (result?.success) {
			showStatus("Mission statement saved");
		}
	}

	// ---- Intro ----

	async function saveIntro() {
		const content = introEditorService.getContent();
		const result = await fetchNui<{ success: boolean }>(
			NUI_EVENTS.SOP.UPDATE_SOP_INTRO,
			{ introduction: content },
			{ success: true }
		);
		if (result?.success) {
			showStatus("Introduction saved");
		}
	}

	// ---- Publish ----

	async function publishSOP() {
		publishing = true;
		try {
			const result = await fetchNui<{ success: boolean; version?: number }>(
				NUI_EVENTS.SOP.PUBLISH_SOP,
				{},
				{ success: true, version: (settings.version || 0) + 1 }
			);
			if (result?.success) {
				settings.version = result.version;
				confirmPublish = false;
				showStatus(`SOP published - Version ${result.version}`);
			}
		} finally { publishing = false; }
	}

	function showStatus(msg: string) {
		statusMsg = msg;
		setTimeout(() => { if (statusMsg === msg) statusMsg = ""; }, 3000);
	}

	const ICON_OPTIONS = [
		"description", "gavel", "security", "local_police", "directions_car",
		"health_and_safety", "handshake", "groups", "policy", "emergency",
		"report", "assignment", "verified", "shield", "military_tech",
		"support_agent", "inventory_2", "badge", "school", "sports_martial_arts"
	];
</script>

<div class="mgmt-sop">
	{#if statusMsg}
		<div class="status-toast">{statusMsg}</div>
	{/if}

	<div class="sop-tabs">
		<button class="sop-tab" class:active={activeTab === "mission"} onclick={() => activeTab = "mission"}>
			<span class="material-icons">flag</span> Mission Statement
		</button>
		<button class="sop-tab" class:active={activeTab === "categories"} onclick={() => activeTab = "categories"}>
			<span class="material-icons">folder</span> Categories & Sections
		</button>
		<button class="sop-tab" class:active={activeTab === "intro"} onclick={() => activeTab = "intro"}>
			<span class="material-icons">article</span> Introduction
		</button>
		<button class="sop-tab" class:active={activeTab === "publish"} onclick={() => activeTab = "publish"}>
			<span class="material-icons">publish</span> Publish
		</button>
	</div>

	<div class="sop-tab-content">
		{#if activeTab === "mission"}
			<div class="intro-tab">
				<p class="intro-desc">The mission statement is displayed at the top of the SOP page and in the agreement overlay. Define your department's mission, values, and M.O.S. requirements.</p>
				<div class="editor-container" bind:this={missionEditorEl}></div>
				<div class="editor-actions">
					<button class="btn-save" onclick={saveMission}>
						<span class="material-icons">save</span> Save Mission Statement
					</button>
				</div>
			</div>

		{:else if activeTab === "categories"}
			<div class="categories-layout">
				<!-- Category List -->
				<div class="cat-panel">
					<div class="panel-header">
						<h3>Categories</h3>
					</div>
					<div class="cat-list">
						{#each categories as cat}
							{#if editingCategoryId === cat.id}
								<div class="cat-edit-row">
									<input type="text" bind:value={editCategoryTitle} placeholder="Category title" class="input-sm" />
									<select bind:value={editCategoryIcon} class="icon-select">
										{#each ICON_OPTIONS as icon}
											<option value={icon}>{icon}</option>
										{/each}
									</select>
									<button class="btn-icon-sm" onclick={saveCategory} title="Save">
										<span class="material-icons">check</span>
									</button>
									<button class="btn-icon-sm cancel" onclick={() => editingCategoryId = null} title="Cancel">
										<span class="material-icons">close</span>
									</button>
								</div>
							{:else}
								<div
									class="cat-row"
									role="button"
									tabindex="0"
									class:active={selectedCategoryId === cat.id}
									onclick={() => { selectedCategoryId = cat.id; editingSectionId = null; cancelEditSection(); }}
								>
									<span class="material-icons cat-row-icon">{cat.icon || 'description'}</span>
									<span class="cat-row-title">{cat.title}</span>
									<span class="cat-row-count">{cat.sections.length}</span>
									<button class="btn-icon-xs" onclick={(e) => { e.stopPropagation(); startEditCategory(cat); }} title="Edit">
										<span class="material-icons">edit</span>
									</button>
									<button class="btn-icon-xs danger" onclick={(e) => { e.stopPropagation(); deleteCategory(cat.id); }} title="Delete">
										<span class="material-icons">delete</span>
									</button>
								</div>
							{/if}
						{/each}
					</div>
					<div class="add-row">
						<input type="text" bind:value={newCategoryTitle} placeholder="New category..." class="input-sm" onkeydown={(e) => e.key === 'Enter' && createCategory()} />
						<select bind:value={newCategoryIcon} class="icon-select">
							{#each ICON_OPTIONS as icon}
								<option value={icon}>{icon}</option>
							{/each}
						</select>
						<button class="btn-add" onclick={createCategory} disabled={!newCategoryTitle.trim()}>
							<span class="material-icons">add</span>
						</button>
					</div>
				</div>

				<!-- Sections Panel -->
				<div class="sec-panel">
					{#if !selectedCategory}
						<div class="panel-empty">
							<span class="material-icons">arrow_back</span>
							<p>Select a category to manage its sections</p>
						</div>
					{:else}
						<div class="panel-header">
							<h3>
								<span class="material-icons">{selectedCategory.icon || 'description'}</span>
								{selectedCategory.title}
							</h3>
						</div>

						{#if editingSectionId}
							<!-- Section Editor -->
							<div class="section-editor">
								<input type="text" bind:value={editSectionTitle} placeholder="Section title" class="input-full" />
								<div class="editor-container" bind:this={sectionEditorEl}></div>
								<div class="editor-actions">
									<button class="btn-save" onclick={saveSection}>
										<span class="material-icons">check</span> Save Section
									</button>
									<button class="btn-cancel" onclick={cancelEditSection}>
										<span class="material-icons">close</span> Cancel
									</button>
								</div>
							</div>
						{:else}
							<div class="sec-list">
								{#each selectedCategory.sections as section, i}
									<div class="sec-row">
										<span class="sec-num">{i + 1}.</span>
										<span class="sec-title">{section.title}</span>
										<button class="btn-icon-xs" onclick={() => startEditSection(section)} title="Edit">
											<span class="material-icons">edit</span>
										</button>
										<button class="btn-icon-xs danger" onclick={() => deleteSection(section.id)} title="Delete">
											<span class="material-icons">delete</span>
										</button>
									</div>
								{/each}
								{#if selectedCategory.sections.length === 0}
									<div class="sec-empty">No sections yet. Add one below.</div>
								{/if}
							</div>
							<div class="add-row">
								<input type="text" bind:value={newSectionTitle} placeholder="New section title..." class="input-sm" onkeydown={(e) => e.key === 'Enter' && createSection()} />
								<button class="btn-add" onclick={createSection} disabled={!newSectionTitle.trim()}>
									<span class="material-icons">add</span>
								</button>
							</div>
						{/if}
					{/if}
				</div>
			</div>

		{:else if activeTab === "intro"}
			<div class="intro-tab">
				<p class="intro-desc">This introduction is shown to officers when they are required to acknowledge the SOP. Use it to summarize key policies and expectations.</p>
				<div class="editor-container" bind:this={introEditorEl}></div>
				<div class="editor-actions">
					<button class="btn-save" onclick={saveIntro}>
						<span class="material-icons">save</span> Save Introduction
					</button>
				</div>
			</div>

		{:else if activeTab === "publish"}
			<div class="publish-tab">
				<div class="publish-card">
					<span class="material-icons publish-icon">publish</span>
					<h3>Publish SOP</h3>
					<p class="publish-version">Current Version: <strong>{settings.version || 'Not published'}</strong></p>
					{#if settings.updated_by}
						<p class="publish-meta">Last published by {settings.updated_by}</p>
					{/if}
					<p class="publish-warning">
						Publishing will increment the SOP version and <strong>require all officers to re-acknowledge</strong> the SOP before they can access the MDT.
					</p>
					{#if !confirmPublish}
						<button class="btn-publish" onclick={() => confirmPublish = true}>
							<span class="material-icons">publish</span> Publish New Version
						</button>
					{:else}
						<div class="confirm-box">
							<p>Are you sure? All officers will be required to re-acknowledge.</p>
							<div class="confirm-actions">
								<button class="btn-confirm" onclick={publishSOP} disabled={publishing}>
									{#if publishing}Publishing...{:else}Yes, Publish{/if}
								</button>
								<button class="btn-cancel-sm" onclick={() => confirmPublish = false}>Cancel</button>
							</div>
						</div>
					{/if}
				</div>
			</div>
		{/if}
	</div>
</div>

<style>
	.mgmt-sop {
		height: 100%;
		display: flex;
		flex-direction: column;
		position: relative;
	}

	.status-toast {
		position: absolute;
		top: 12px;
		right: 12px;
		background: rgba(34, 197, 94, 0.15);
		color: rgba(34, 197, 94, 0.9);
		border: 1px solid rgba(34, 197, 94, 0.25);
		padding: 8px 16px;
		border-radius: 6px;
		font-size: 12px;
		z-index: 10;
		animation: fadeInOut 3s ease forwards;
	}

	@keyframes fadeInOut {
		0% { opacity: 0; transform: translateY(-8px); }
		10% { opacity: 1; transform: translateY(0); }
		80% { opacity: 1; }
		100% { opacity: 0; }
	}

	/* Tabs */
	.sop-tabs {
		display: flex;
		gap: 4px;
		padding: 12px 16px 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
	}

	.sop-tab {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 8px 16px;
		background: transparent;
		border: none;
		border-bottom: 2px solid transparent;
		color: rgba(255, 255, 255, 0.5);
		font-size: 12px;
		cursor: pointer;
		transition: all 0.15s;
	}

	.sop-tab .material-icons { font-size: 16px; }

	.sop-tab:hover { color: rgba(255, 255, 255, 0.7); }

	.sop-tab.active {
		color: var(--accent-text);
		border-bottom-color: var(--accent-60);
	}

	.sop-tab-content {
		flex: 1;
		overflow-y: auto;
		padding: 16px;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.08) transparent;
	}

	/* Categories Layout */
	.categories-layout {
		display: flex;
		gap: 16px;
		height: 100%;
		min-height: 300px;
	}

	.cat-panel {
		width: 300px;
		min-width: 260px;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 8px;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.sec-panel {
		flex: 1;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 8px;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.panel-header {
		padding: 12px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
	}

	.panel-header h3 {
		font-size: 13px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.8);
		margin: 0;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.panel-header h3 .material-icons {
		font-size: 16px;
		color: var(--accent-60);
	}

	.panel-empty {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 8px;
		color: rgba(255, 255, 255, 0.3);
		font-size: 12px;
	}

	.panel-empty .material-icons {
		font-size: 28px;
	}

	/* Category List */
	.cat-list {
		flex: 1;
		overflow-y: auto;
		padding: 4px;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.08) transparent;
	}

	.cat-row {
		width: 100%;
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 10px;
		background: transparent;
		border: 1px solid transparent;
		border-radius: 6px;
		cursor: pointer;
		text-align: left;
		transition: all 0.12s;
		margin-bottom: 2px;
	}

	.cat-row:hover { background: rgba(255, 255, 255, 0.03); }

	.cat-row.active {
		background: var(--accent-10);
		border-color: var(--accent-15);
	}

	.cat-row-icon {
		font-size: 16px;
		color: rgba(255, 255, 255, 0.4);
	}

	.cat-row.active .cat-row-icon {
		color: var(--accent-60);
	}

	.cat-row-title {
		flex: 1;
		font-size: 12px;
		color: rgba(255, 255, 255, 0.8);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.cat-row-count {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.3);
		background: rgba(255, 255, 255, 0.06);
		padding: 1px 6px;
		border-radius: 8px;
	}

	.cat-edit-row {
		display: flex;
		align-items: center;
		gap: 4px;
		padding: 6px;
	}

	/* Section List */
	.sec-list {
		flex: 1;
		overflow-y: auto;
		padding: 8px;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.08) transparent;
	}

	.sec-row {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 12px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.sec-num {
		font-size: 12px;
		font-weight: 600;
		color: var(--accent-60);
		min-width: 20px;
	}

	.sec-title {
		flex: 1;
		font-size: 12px;
		color: rgba(255, 255, 255, 0.8);
	}

	.sec-empty {
		padding: 24px;
		text-align: center;
		color: rgba(255, 255, 255, 0.3);
		font-size: 12px;
	}

	/* Section Editor */
	.section-editor {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 12px;
		padding: 12px;
		overflow: hidden;
	}

	/* Inputs */
	.input-sm {
		flex: 1;
		padding: 6px 10px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 4px;
		color: rgba(255, 255, 255, 0.9);
		font-size: 12px;
		outline: none;
	}

	.input-sm:focus { border-color: var(--accent-35); }

	.input-full {
		width: 100%;
		padding: 8px 12px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 6px;
		color: rgba(255, 255, 255, 0.9);
		font-size: 13px;
		outline: none;
		flex-shrink: 0;
	}

	.input-full:focus { border-color: var(--accent-35); }

	.icon-select {
		width: 100px;
		padding: 6px 8px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 4px;
		color: rgba(255, 255, 255, 0.9);
		font-size: 11px;
		outline: none;
	}

	/* Buttons */
	.btn-icon-sm, .btn-icon-xs {
		display: flex;
		align-items: center;
		justify-content: center;
		background: transparent;
		border: none;
		cursor: pointer;
		border-radius: 4px;
		transition: all 0.12s;
	}

	.btn-icon-sm {
		padding: 4px;
		color: rgba(34, 197, 94, 0.7);
	}

	.btn-icon-sm .material-icons { font-size: 16px; }

	.btn-icon-sm.cancel { color: rgba(239, 68, 68, 0.7); }

	.btn-icon-sm:hover { background: rgba(255, 255, 255, 0.06); }

	.btn-icon-xs {
		padding: 2px;
		color: rgba(255, 255, 255, 0.3);
		opacity: 0;
		transition: opacity 0.12s;
	}

	.btn-icon-xs .material-icons { font-size: 14px; }

	.btn-icon-xs.danger:hover { color: rgba(239, 68, 68, 0.8); }

	.btn-icon-xs:hover { color: rgba(255, 255, 255, 0.7); }

	.cat-row:hover .btn-icon-xs,
	.sec-row:hover .btn-icon-xs { opacity: 1; }

	.add-row {
		display: flex;
		gap: 6px;
		padding: 8px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
	}

	.btn-add {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 6px;
		background: var(--accent-15);
		border: 1px solid var(--accent-20);
		border-radius: 4px;
		color: var(--accent-text);
		cursor: pointer;
		transition: all 0.12s;
	}

	.btn-add .material-icons { font-size: 16px; }

	.btn-add:hover:not(:disabled) { background: var(--accent-25); }
	.btn-add:disabled { opacity: 0.4; cursor: not-allowed; }

	/* Editor Container */
	.editor-container {
		flex: 1;
		min-height: 200px;
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 6px;
		overflow-y: auto;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.08) transparent;
	}

	.editor-container :global(.tiptap) {
		padding: 12px 16px;
		min-height: 180px;
		color: rgba(255, 255, 255, 0.85);
		font-size: 13px;
		line-height: 1.6;
		outline: none;
	}

	.editor-container :global(.tiptap p.is-editor-empty:first-child::before) {
		content: 'Start writing...';
		color: rgba(255, 255, 255, 0.25);
		float: left;
		pointer-events: none;
		height: 0;
	}

	.editor-actions {
		display: flex;
		gap: 8px;
		flex-shrink: 0;
	}

	.btn-save, .btn-cancel {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 8px 16px;
		border-radius: 6px;
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
		border: none;
		transition: all 0.12s;
	}

	.btn-save {
		background: var(--accent-15);
		color: var(--accent-text);
		border: 1px solid var(--accent-20);
	}

	.btn-save:hover { background: var(--accent-25); }

	.btn-save .material-icons,
	.btn-cancel .material-icons { font-size: 15px; }

	.btn-cancel {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.6);
		border: 1px solid rgba(255, 255, 255, 0.08);
	}

	.btn-cancel:hover { background: rgba(255, 255, 255, 0.08); }

	/* Intro Tab */
	.intro-tab {
		display: flex;
		flex-direction: column;
		gap: 12px;
		height: 100%;
	}

	.intro-desc {
		font-size: 12px;
		color: rgba(255, 255, 255, 0.45);
		margin: 0;
		line-height: 1.5;
	}

	/* Publish Tab */
	.publish-tab {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100%;
	}

	.publish-card {
		text-align: center;
		max-width: 400px;
		padding: 32px;
	}

	.publish-icon {
		font-size: 48px;
		color: var(--accent-50);
		margin-bottom: 12px;
	}

	.publish-card h3 {
		font-size: 18px;
		color: rgba(255, 255, 255, 0.9);
		margin: 0 0 12px;
	}

	.publish-version {
		font-size: 14px;
		color: rgba(255, 255, 255, 0.6);
		margin: 0 0 4px;
	}

	.publish-meta {
		font-size: 12px;
		color: rgba(255, 255, 255, 0.35);
		margin: 0 0 16px;
	}

	.publish-warning {
		font-size: 12px;
		color: rgba(234, 179, 8, 0.7);
		background: rgba(234, 179, 8, 0.06);
		border: 1px solid rgba(234, 179, 8, 0.15);
		border-radius: 6px;
		padding: 10px 14px;
		margin: 0 0 20px;
		line-height: 1.5;
	}

	.btn-publish {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 10px 24px;
		background: var(--accent-15);
		color: var(--accent-text);
		border: 1px solid var(--accent-20);
		border-radius: 8px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
	}

	.btn-publish:hover { background: var(--accent-25); }

	.btn-publish .material-icons { font-size: 18px; }

	.confirm-box {
		background: rgba(239, 68, 68, 0.06);
		border: 1px solid rgba(239, 68, 68, 0.15);
		border-radius: 8px;
		padding: 16px;
	}

	.confirm-box p {
		font-size: 13px;
		color: rgba(255, 255, 255, 0.7);
		margin: 0 0 12px;
	}

	.confirm-actions {
		display: flex;
		justify-content: center;
		gap: 8px;
	}

	.btn-confirm {
		padding: 8px 20px;
		background: rgba(239, 68, 68, 0.15);
		color: rgba(239, 68, 68, 0.9);
		border: 1px solid rgba(239, 68, 68, 0.25);
		border-radius: 6px;
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
	}

	.btn-confirm:hover { background: rgba(239, 68, 68, 0.25); }
	.btn-confirm:disabled { opacity: 0.5; cursor: not-allowed; }

	.btn-cancel-sm {
		padding: 8px 20px;
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.5);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 6px;
		font-size: 12px;
		cursor: pointer;
	}

	.btn-cancel-sm:hover { background: rgba(255, 255, 255, 0.08); }
</style>
