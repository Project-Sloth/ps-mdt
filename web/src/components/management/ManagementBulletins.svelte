<script lang="ts">
	import { onMount } from "svelte";
	import { fetchNui } from "../../utils/fetchNui";
	import { isEnvBrowser } from "../../utils/misc";
	import { NUI_EVENTS } from "../../constants/nuiEvents";

	// ── Types ──────────────────────────────────────────────────

	interface Bulletin {
		id?: number;
		content: string;
	}

	interface BulletinCategory {
		value: string;
		label: string;
		icon: string;
	}

	// ── MotD state ─────────────────────────────────────────────

	let bulletins: Bulletin[] = $state([]);
	let newTitle: string = $state("");
	let newContent: string = $state("");
	let isLoading = $state(false);
	let isSubmitting = $state(false);
	let statusMessage: { text: string; type: "success" | "error" } | null = $state(null);

	// ── Category state ─────────────────────────────────────────

	const DEFAULT_CATEGORIES: BulletinCategory[] = [
		{ value: 'announcement', label: 'Announcements', icon: 'campaign'     },
		{ value: 'operations',   label: 'Operations',    icon: 'local_police' },
		{ value: 'training',     label: 'Training',      icon: 'school'       },
		{ value: 'general',      label: 'General',       icon: 'forum'        },
	];

	let categories = $state<BulletinCategory[]>(DEFAULT_CATEGORIES.map(c => ({ ...c })));
	let categoriesLoading = $state(false);
	let categoriesSaving  = $state(false);

	// ── Shared helpers ─────────────────────────────────────────

	function showStatus(text: string, type: "success" | "error" = "success") {
		statusMessage = { text, type };
		setTimeout(() => { statusMessage = null; }, 3000);
	}

	// ── MotD logic ─────────────────────────────────────────────

	async function loadBulletins() {
		if (isEnvBrowser()) return;
		try {
			isLoading = true;
			const response = await fetchNui<Bulletin[]>(
				NUI_EVENTS.DASHBOARD.GET_BULLETINS,
				{},
				[],
			);
			bulletins = Array.isArray(response) ? response : [];
		} catch (error) {
			console.error("Failed to load bulletins:", error);
			bulletins = [];
		} finally {
			isLoading = false;
		}
	}

	function buildContent(): string {
		const title = newTitle.trim().toUpperCase();
		const body = newContent.trim();
		if (title && body) return `${title}: ${body}`;
		if (title) return title;
		return body;
	}

	function parseBulletin(content: string): { title: string; body: string } {
		const colonIdx = content.indexOf(":");
		if (colonIdx > 0 && colonIdx < 40) {
			return {
				title: content.slice(0, colonIdx).trim(),
				body: content.slice(colonIdx + 1).trim(),
			};
		}
		return { title: "", body: content };
	}

	async function handleSubmit() {
		if (!newContent.trim() && !newTitle.trim()) return;
		const fullContent = buildContent();
		if (!fullContent) return;
		if (isEnvBrowser()) {
			bulletins = [{ id: Date.now(), content: fullContent }, ...bulletins];
			newTitle = "";
			newContent = "";
			return;
		}
		try {
			isSubmitting = true;
			const result = await fetchNui<{ success: boolean; message?: string; id?: number }>(
				NUI_EVENTS.DASHBOARD.CREATE_BULLETIN,
				{ content: fullContent },
				{ success: false },
			);
			if (result && result.success) {
				showStatus("Bulletin posted");
				newTitle = "";
				newContent = "";
				await loadBulletins();
			} else {
				showStatus(result?.message || "Failed to post bulletin", "error");
			}
		} catch (error) {
			console.error("Failed to create bulletin:", error);
			showStatus("Failed to post bulletin", "error");
		} finally {
			isSubmitting = false;
		}
	}

	async function deleteBulletin(id: number | undefined) {
		if (!id) return;
		if (isEnvBrowser()) {
			bulletins = bulletins.filter((b) => b.id !== id);
			return;
		}
		try {
			const result = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.DASHBOARD.DELETE_BULLETIN,
				{ id },
				{ success: false },
			);
			if (result && result.success) {
				showStatus("Bulletin deleted");
				await loadBulletins();
			} else {
				showStatus(result?.message || "Failed to delete bulletin", "error");
			}
		} catch (error) {
			console.error("Failed to delete bulletin:", error);
			showStatus("Failed to delete bulletin", "error");
		}
	}

	// ── Category logic ─────────────────────────────────────────

	async function loadCategories() {
		if (isEnvBrowser()) return;
		try {
			categoriesLoading = true;
			const result = await fetchNui<BulletinCategory[]>(
				NUI_EVENTS.BULLETIN.GET_CATEGORIES,
				{},
				[],
			);
			if (Array.isArray(result) && result.length > 0) {
				categories = result;
			}
		} catch (error) {
			console.error("Failed to load categories:", error);
		} finally {
			categoriesLoading = false;
		}
	}

	async function saveCategories() {
		if (isEnvBrowser()) {
			showStatus("Categories saved");
			return;
		}
		try {
			categoriesSaving = true;
			const result = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.BULLETIN.SAVE_CATEGORIES,
				{ categories },
				{ success: false },
			);
			if (result?.success) {
				showStatus("Categories saved");
			} else {
				showStatus(result?.message || "Failed to save categories", "error");
			}
		} catch (error) {
			console.error("Failed to save categories:", error);
			showStatus("Failed to save categories", "error");
		} finally {
			categoriesSaving = false;
		}
	}

	function resetCategories() {
		categories = DEFAULT_CATEGORIES.map(c => ({ ...c }));
	}

	// ── Mount ──────────────────────────────────────────────────

	onMount(() => {
		if (isEnvBrowser()) {
			bulletins = [
				{ id: 1, content: "TRAINING: FTO certification renewal is due by end of month. Contact Lt. Park to schedule your assessment." },
				{ id: 2, content: "BOLO REMINDER: Black Kuruma from the Pacific Standard robbery is still outstanding. If spotted, do NOT engage alone." },
				{ id: 3, content: "Radio channel 3 is now reserved for tactical operations. Please update your radios before next shift." },
			];
			return;
		}
		loadBulletins();
		loadCategories();
	});
</script>

<div class="management-panel">
	{#if statusMessage}
		<div class="status-toast {statusMessage.type}">
			{statusMessage.text}
		</div>
	{/if}

	<!-- ═══════════════════════════════════════════════════════
	     Section 1: Message of the Day (MotD)
	════════════════════════════════════════════════════════ -->
	<div class="section">
		<div class="section-title-row">
			<span class="section-title">Message of the Day</span>
		</div>

		<div class="new-bulletin">
			<div class="bulletin-fields">
				<input
					class="bulletin-title-input"
					type="text"
					placeholder="Title (e.g. TRAINING, BOLO REMINDER)"
					bind:value={newTitle}
				/>
				<textarea
					class="bulletin-input"
					placeholder="Write a bulletin..."
					rows="2"
					bind:value={newContent}
				></textarea>
			</div>
			<button
				class="btn-post"
				onclick={handleSubmit}
				disabled={(!newContent.trim() && !newTitle.trim()) || isSubmitting}
			>
				{isSubmitting ? "Posting..." : "Post"}
			</button>
		</div>

		{#if isLoading}
			<div class="empty-state">
				<div class="loading-spinner"></div>
				<p>Loading bulletins...</p>
			</div>
		{:else}
			<div class="bulletins-list">
				{#each bulletins as bulletin (bulletin.id || bulletin.content)}
					{@const parsed = parseBulletin(bulletin.content)}
					<div class="bulletin-row">
						<div class="bulletin-body">
							{#if parsed.title && parsed.body}
								<span class="bulletin-title">{parsed.title}</span>
								<p class="bulletin-text">{parsed.body}</p>
							{:else}
								<p class="bulletin-text">{bulletin.content}</p>
							{/if}
						</div>
						{#if bulletin.id}
							<button
								class="delete-btn"
								onclick={() => deleteBulletin(bulletin.id)}
								aria-label="Delete bulletin"
							>
								<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
							</button>
						{/if}
					</div>
				{:else}
					<div class="empty-state">No bulletins posted.</div>
				{/each}
			</div>
		{/if}
	</div>

	<!-- ═══════════════════════════════════════════════════════
	     Section 2: Bulletin Board Categories
	════════════════════════════════════════════════════════ -->
	<div class="section">
		<div class="section-title-row">
			<span class="section-title">Bulletin Board Categories</span>
			<div class="section-actions">
				<button class="btn-reset" onclick={resetCategories} disabled={categoriesSaving}>
					Reset
				</button>
				<button class="btn-save-cats" onclick={saveCategories} disabled={categoriesSaving}>
					{categoriesSaving ? "Saving..." : "Save"}
				</button>
			</div>
		</div>

		<p class="section-hint">
			Customize the category labels and icons shown in the Bulletin Board sidebar.
			Use any <a href="https://fonts.google.com/icons" target="_blank" rel="noreferrer">Material Icon</a> name.
		</p>

		{#if categoriesLoading}
			<div class="empty-state" style="min-height: 80px;">
				<div class="loading-spinner"></div>
				<p>Loading categories...</p>
			</div>
		{:else}
			<div class="categories-list">
				{#each categories as cat}
					<div class="category-row">
						<!-- Live icon preview -->
						<div class="cat-icon-preview" title="Icon preview">
							<span class="material-icons">{cat.icon || 'help_outline'}</span>
						</div>

						<!-- Label input -->
						<div class="cat-field">
							<span class="cat-field-label">Label</span>
							<input
								class="cat-input"
								type="text"
								placeholder="Category label..."
								bind:value={cat.label}
								maxlength="32"
							/>
						</div>

						<!-- Icon input -->
						<div class="cat-field">
							<span class="cat-field-label">Icon name</span>
							<input
								class="cat-input cat-input-mono"
								type="text"
								placeholder="e.g. campaign, school, forum..."
								bind:value={cat.icon}
								maxlength="48"
							/>
						</div>

						<!-- Value badge (read-only, for reference) -->
						<div class="cat-value-badge">{cat.value}</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	/* ── Panel wrapper ────────────────────────────────────────── */
	.management-panel {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: transparent;
		overflow-y: auto;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.06) transparent;
	}

	/* ── Status toast ─────────────────────────────────────────── */
	.status-toast {
		padding: 6px 12px;
		font-size: 10px;
		font-weight: 500;
		flex-shrink: 0;
		margin: 8px 16px 0;
		border-radius: 3px;
	}

	.status-toast.success {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(110, 231, 183, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.status-toast.error {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(252, 165, 165, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	/* ── Sections ─────────────────────────────────────────────── */
	.section {
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		padding: 0 0 16px;
		flex-shrink: 0;
	}

	.section:last-child {
		border-bottom: none;
	}

	.section-title-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px 16px 8px;
		gap: 8px;
	}

	.section-title {
		font-size: 9px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.7px;
		color: rgba(255, 255, 255, 0.35);
	}

	.section-actions {
		display: flex;
		align-items: center;
		gap: 5px;
	}

	.section-hint {
		margin: 0 16px 10px;
		font-size: 10px;
		color: rgba(255, 255, 255, 0.3);
		line-height: 1.5;
	}

	.section-hint a {
		color: rgba(147, 197, 253, 0.6);
		text-decoration: none;
	}

	.section-hint a:hover {
		color: rgba(147, 197, 253, 0.9);
		text-decoration: underline;
	}

	/* ── MotD — new bulletin composer ─────────────────────────── */
	.new-bulletin {
		display: flex;
		gap: 10px;
		padding: 4px 16px 10px;
		align-items: flex-end;
	}

	.bulletin-fields {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 5px;
	}

	.bulletin-title-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.9);
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.bulletin-title-input:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.12);
	}

	.bulletin-title-input::placeholder {
		color: rgba(255, 255, 255, 0.35);
		font-weight: 400;
		text-transform: none;
		letter-spacing: 0;
	}

	.bulletin-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 6px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		font-family: inherit;
		resize: vertical;
		min-height: 32px;
	}

	.bulletin-input:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.12);
	}

	.bulletin-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.btn-post {
		background: rgba(var(--accent-rgb), 0.06);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		border-radius: 3px;
		padding: 5px 12px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
		flex-shrink: 0;
	}

	.btn-post:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.btn-post:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	/* ── MotD — bulletin list ──────────────────────────────────── */
	.bulletins-list {
		max-height: 220px;
		overflow-y: auto;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.06) transparent;
	}

	.bulletin-row {
		display: flex;
		align-items: flex-start;
		gap: 10px;
		padding: 8px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		transition: background 0.1s;
	}

	.bulletin-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.bulletin-row:last-child {
		border-bottom: none;
	}

	.bulletin-body {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 2px;
		min-width: 0;
	}

	.bulletin-title {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(255, 255, 255, 0.35);
	}

	.bulletin-text {
		color: rgba(255, 255, 255, 0.6);
		font-size: 11px;
		line-height: 1.5;
		margin: 0;
	}

	.delete-btn {
		background: none;
		border: none;
		color: rgba(255, 255, 255, 0.3);
		cursor: pointer;
		padding: 3px;
		border-radius: 3px;
		display: flex;
		align-items: center;
		flex-shrink: 0;
		transition: all 0.1s;
		opacity: 0;
	}

	.bulletin-row:hover .delete-btn {
		opacity: 1;
	}

	.delete-btn:hover {
		color: rgba(252, 165, 165, 0.8);
		background: rgba(239, 68, 68, 0.08);
	}

	/* ── Categories section buttons ──────────────────────────── */
	.btn-reset {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 3px 10px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-reset:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.6);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.btn-reset:disabled { opacity: 0.3; cursor: not-allowed; }

	.btn-save-cats {
		background: rgba(16, 185, 129, 0.06);
		border: 1px solid rgba(16, 185, 129, 0.1);
		border-radius: 3px;
		padding: 3px 12px;
		color: rgba(52, 211, 153, 0.7);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-save-cats:hover:not(:disabled) {
		background: rgba(16, 185, 129, 0.12);
		color: rgba(110, 231, 183, 0.9);
	}

	.btn-save-cats:disabled { opacity: 0.3; cursor: not-allowed; }

	/* ── Category rows ───────────────────────────────────────── */
	.categories-list {
		display: flex;
		flex-direction: column;
		gap: 0;
		padding: 0 16px;
	}

	.category-row {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 7px 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
	}

	.category-row:last-child {
		border-bottom: none;
	}

	/* Icon preview circle */
	.cat-icon-preview {
		width: 30px;
		height: 30px;
		border-radius: 50%;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.06);
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.cat-icon-preview .material-icons {
		font-size: 16px;
		color: rgba(255, 255, 255, 0.4);
	}

	/* Label / icon fields */
	.cat-field {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 2px;
		min-width: 0;
	}

	.cat-field-label {
		font-size: 8px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(255, 255, 255, 0.25);
	}

	.cat-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 7px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		font-family: inherit;
		outline: none;
		transition: border-color 0.1s;
		width: 100%;
	}

	.cat-input:focus {
		border-color: rgba(255, 255, 255, 0.12);
	}

	.cat-input::placeholder {
		color: rgba(255, 255, 255, 0.18);
	}

	.cat-input-mono {
		font-family: monospace;
		font-size: 10px;
		letter-spacing: 0.3px;
	}

	/* Read-only value badge */
	.cat-value-badge {
		font-size: 9px;
		font-family: monospace;
		color: rgba(255, 255, 255, 0.25);
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 3px;
		padding: 2px 6px;
		white-space: nowrap;
		flex-shrink: 0;
	}

	/* ── Shared empty / loading state ────────────────────────── */
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 80px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
	}

	.loading-spinner {
		width: 20px;
		height: 20px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left: 2px solid rgba(var(--accent-rgb), 0.5);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 8px;
	}

	@keyframes spin {
		0%   { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
</style>