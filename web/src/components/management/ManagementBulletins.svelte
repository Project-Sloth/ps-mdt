<script lang="ts">
	import { onMount, onDestroy } from "svelte";
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
		color: string;
		sort_order?: number;
		is_default?: boolean;
	}

	// ── NUI callback names (hardcoded to avoid missing-key issues) ──
	// These must match RegisterNUICallback names in client.lua exactly.
	const CB = {
		GET_BULLETINS:      (NUI_EVENTS.DASHBOARD as any)?.GET_BULLETINS      ?? 'getBulletins',
		CREATE_BULLETIN:    (NUI_EVENTS.DASHBOARD as any)?.CREATE_BULLETIN    ?? 'createBulletin',
		DELETE_BULLETIN:    (NUI_EVENTS.DASHBOARD as any)?.DELETE_BULLETIN    ?? 'deleteBulletin',
		GET_CATEGORIES:     'getBulletinCategories',
		ADD_CATEGORY:       'addBulletinCategory',
		UPDATE_CATEGORY:    'updateBulletinCategory',
		REMOVE_CATEGORY:    'removeBulletinCategory',
		REORDER_CATEGORIES: 'reorderBulletinCategories',
	} as const;

	// ── MotD state ─────────────────────────────────────────────

	let bulletins: Bulletin[] = $state([]);
	let newTitle              = $state('');
	let newContent            = $state('');
	let isLoading             = $state(false);
	let isSubmitting          = $state(false);
	let statusMessage: { text: string; type: 'success' | 'error' } | null = $state(null);

	// ── Category state ─────────────────────────────────────────

	const DEFAULT_CATEGORIES: BulletinCategory[] = [
		{ value: 'announcement', label: 'Announcements', icon: 'campaign',     color: '#3B82F6', is_default: true },
		{ value: 'operations',   label: 'Operations',    icon: 'local_police', color: '#8B5CF6', is_default: true },
		{ value: 'training',     label: 'Training',      icon: 'school',       color: '#10B981', is_default: true },
		{ value: 'general',      label: 'General',       icon: 'forum',        color: '#6B7280', is_default: true },
	];

	const ICON_SUGGESTIONS = [
		'campaign','local_police','school','forum','push_pin','gavel',
		'shield','directions_car','emergency','radio','groups','assignment',
		'inventory','badge','security','warning','star','notifications',
		'flag','location_on','map','schedule','lock','vpn_key',
		'help_center','feedback','event','rule','checklist','handshake',
	];

	let categories      = $state<BulletinCategory[]>(DEFAULT_CATEGORIES.map(c => ({ ...c })));
	let categoriesLoading = $state(false);
	let newCatLabel     = $state('');
	let newCatIcon      = $state('label');
	let newCatColor     = $state('#6B7280');
	let addingCat       = $state(false);
	let showAddForm     = $state(false);
	let showIconPicker  = $state<string | null>(null);
	let savingCat       = $state<string | null>(null);
	let removingCat     = $state<string | null>(null);

	// ── Mouse-drag reorder (Map.svelte pattern – no HTML5 draggable) ──

	type DragState = { idx: number; label: string; x: number; y: number; active: boolean };

	let drag        = $state<DragState | null>(null);
	let dragOverIdx = $state<number | null>(null);
	let isDragging  = $state(false);
	let ghostEl: HTMLDivElement | null = null;

	function createGhost(label: string, x: number, y: number) {
		removeGhost();
		ghostEl = document.createElement('div');
		ghostEl.className = 'cat-drag-ghost';
		ghostEl.textContent = label;
		ghostEl.style.left = `${x + 14}px`;
		ghostEl.style.top  = `${y - 18}px`;
		document.body.appendChild(ghostEl);
	}
	function moveGhost(x: number, y: number) {
		if (!ghostEl) return;
		ghostEl.style.left = `${x + 14}px`;
		ghostEl.style.top  = `${y - 18}px`;
	}
	function removeGhost() { ghostEl?.remove(); ghostEl = null; }

	function getRowIdxFromPoint(x: number, y: number): number | null {
		const els = document.elementsFromPoint(x, y);
		for (const el of els) {
			const row = (el as HTMLElement).closest('[data-cat-idx]') as HTMLElement | null;
			if (row) return Number(row.dataset.catIdx);
		}
		return null;
	}

	function onHandleMouseDown(e: MouseEvent, idx: number) {
		if (e.button !== 0) return;
		e.preventDefault();
		drag = { idx, label: categories[idx].label, x: e.clientX, y: e.clientY, active: false };
	}

	function onGlobalMouseMove(e: MouseEvent) {
		if (!drag) return;
		if (!drag.active) {
			const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
			if (Math.sqrt(dx*dx + dy*dy) < 5) return;
			drag.active = true;
			isDragging  = true;
			createGhost(drag.label, e.clientX, e.clientY);
		}
		moveGhost(e.clientX, e.clientY);

		const toIdx = getRowIdxFromPoint(e.clientX, e.clientY);
		if (toIdx !== null && toIdx !== drag.idx) {
			// Reorder live so data-cat-idx attributes stay in sync
			const arr = [...categories];
			const [moved] = arr.splice(drag.idx, 1);
			arr.splice(toIdx, 0, moved);
			categories  = arr;
			drag.idx    = toIdx;   // track new position
			dragOverIdx = toIdx;
		} else {
			dragOverIdx = toIdx !== drag.idx ? toIdx : null;
		}
	}

	async function onGlobalMouseUp(e: MouseEvent) {
		if (!drag) return;
		if (drag.active && !isEnvBrowser()) {
			// categories array is already in final order from live moves above
			// Send as flat array directly — client.lua unwraps data.order and passes it straight to ps.callback
			const order = categories.map((c, i) => ({ value: c.value, sort_order: i + 1 }));
			await fetchNui(CB.REORDER_CATEGORIES, { order }, {});
		}
		removeGhost();
		drag = null; isDragging = false; dragOverIdx = null;
	}

	// ── Lifecycle ──────────────────────────────────────────────

	onMount(() => {
		window.addEventListener('mousemove', onGlobalMouseMove);
		window.addEventListener('mouseup',   onGlobalMouseUp);
		if (isEnvBrowser()) {
			bulletins = [
				{ id: 1, content: 'TRAINING: FTO certification renewal is due by end of month.' },
				{ id: 2, content: 'BOLO REMINDER: Black Kuruma from Pacific Standard is still outstanding.' },
				{ id: 3, content: 'Radio channel 3 is now reserved for tactical operations.' },
			];
			return;
		}
		loadBulletins();
		loadCategories();
	});

	onDestroy(() => {
		window.removeEventListener('mousemove', onGlobalMouseMove);
		window.removeEventListener('mouseup',   onGlobalMouseUp);
		removeGhost();
	});

	// ── Helpers ────────────────────────────────────────────────

	function showStatus(text: string, type: 'success' | 'error' = 'success') {
		statusMessage = { text, type };
		setTimeout(() => { statusMessage = null; }, 3000);
	}

	function slugify(str: string): string {
		return str.toLowerCase().trim().replace(/\s+/g,'_').replace(/[^a-z0-9_]/g,'').slice(0, 48);
	}

	// ── MotD ───────────────────────────────────────────────────

	async function loadBulletins() {
		try {
			isLoading = true;
			const res = await fetchNui<Bulletin[]>(CB.GET_BULLETINS, {}, []);
			bulletins = Array.isArray(res) ? res : [];
		} catch { bulletins = []; }
		finally   { isLoading = false; }
	}

	function buildContent(): string {
		const title = newTitle.trim().toUpperCase();
		const body  = newContent.trim();
		if (title && body) return `${title}: ${body}`;
		return title || body;
	}

	function parseBulletin(content: string): { title: string; body: string } {
		const idx = content.indexOf(':');
		if (idx > 0 && idx < 40) return { title: content.slice(0, idx).trim(), body: content.slice(idx + 1).trim() };
		return { title: '', body: content };
	}

	async function handleSubmit() {
		const fullContent = buildContent();
		if (!fullContent) return;
		if (isEnvBrowser()) {
			bulletins = [{ id: Date.now(), content: fullContent }, ...bulletins];
			newTitle = ''; newContent = ''; return;
		}
		try {
			isSubmitting = true;
			const result = await fetchNui<{ success: boolean; message?: string }>(
				CB.CREATE_BULLETIN, { content: fullContent }, { success: false }
			);
			if (result?.success) { showStatus('Bulletin posted'); newTitle = ''; newContent = ''; await loadBulletins(); }
			else showStatus(result?.message || 'Failed to post bulletin', 'error');
		} finally { isSubmitting = false; }
	}

	async function deleteBulletin(id: number | undefined) {
		if (!id) return;
		if (isEnvBrowser()) { bulletins = bulletins.filter(b => b.id !== id); return; }
		try {
			const result = await fetchNui<{ success: boolean; message?: string }>(CB.DELETE_BULLETIN, { id }, { success: false });
			if (result?.success) { showStatus('Bulletin deleted'); await loadBulletins(); }
			else showStatus(result?.message || 'Failed to delete bulletin', 'error');
		} catch { showStatus('Failed to delete bulletin', 'error'); }
	}

	// ── Categories ─────────────────────────────────────────────

	async function loadCategories() {
		try {
			categoriesLoading = true;
			const result = await fetchNui<BulletinCategory[]>(CB.GET_CATEGORIES, {}, []);
			if (Array.isArray(result) && result.length > 0) categories = result;
		} catch { /* keep defaults */ }
		finally { categoriesLoading = false; }
	}

	async function saveCategory(cat: BulletinCategory) {
		if (isEnvBrowser()) { showStatus(`"${cat.label}" saved`); return; }
		savingCat = cat.value;
		try {
			const result = await fetchNui<{ success: boolean; message?: string }>(
				CB.UPDATE_CATEGORY, { value: cat.value, label: cat.label, icon: cat.icon, color: cat.color }, { success: false }
			);
			if (result?.success) showStatus(`"${cat.label}" updated`);
			else showStatus(result?.message || 'Failed to save', 'error');
		} finally { savingCat = null; }
	}

	async function addCategory() {
		const label = newCatLabel.trim();
		if (!label) return;
		const value = slugify(label);
		if (!value)                            { showStatus('Label needs at least one letter or number', 'error'); return; }
		if (categories.find(c => c.value === value)) { showStatus(`Key "${value}" already exists`, 'error'); return; }
		if (categories.length >= 20)           { showStatus('Maximum of 20 categories reached', 'error'); return; }

		if (isEnvBrowser()) {
			categories = [...categories, { value, label, icon: newCatIcon, color: newCatColor, is_default: false }];
			showStatus(`"${label}" added`); resetAddForm(); return;
		}

		addingCat = true;
		try {
			const payload = { label, icon: newCatIcon, color: newCatColor };
			const result  = await fetchNui<{ success: boolean; message?: string }>(CB.ADD_CATEGORY, payload, { success: false });
			if (result?.success) { showStatus(`"${label}" added`); resetAddForm(); await loadCategories(); }
			else showStatus(result?.message || 'Failed to add category', 'error');
		} catch { showStatus('Failed to add category', 'error'); }
		finally { addingCat = false; }
	}

	async function removeCategory(value: string) {
		const cat = categories.find(c => c.value === value);
		if (!cat) return;
		if (categories.length <= 1) { showStatus('Cannot remove the last category', 'error'); return; }
		if (isEnvBrowser()) { categories = categories.filter(c => c.value !== value); showStatus(`"${cat.label}" removed`); return; }
		removingCat = value;
		try {
			const result = await fetchNui<{ success: boolean; message?: string }>(CB.REMOVE_CATEGORY, { value }, { success: false });
			if (result?.success) { showStatus(`"${cat.label}" removed`); await loadCategories(); }
			else showStatus(result?.message || 'Failed to remove', 'error');
		} finally { removingCat = null; }
	}

	function resetAddForm() { newCatLabel = ''; newCatIcon = 'label'; newCatColor = '#6B7280'; showAddForm = false; }
</script>

<div class="management-panel">
	{#if statusMessage}
		<div class="status-toast {statusMessage.type}">{statusMessage.text}</div>
	{/if}

	<!-- ════════════════════════ MotD ═══════════════════════════ -->
	<div class="section">
		<div class="section-title-row">
			<span class="section-title">Message of the Day</span>
		</div>

		<div class="new-bulletin">
			<div class="bulletin-fields">
				<input class="bulletin-title-input" type="text"
					placeholder="Title (e.g. TRAINING, BOLO REMINDER)" bind:value={newTitle} />
				<textarea class="bulletin-input" placeholder="Write a bulletin..." rows="2" bind:value={newContent}></textarea>
			</div>
			<button class="btn-post" onclick={handleSubmit}
				disabled={(!newContent.trim() && !newTitle.trim()) || isSubmitting}>
				{isSubmitting ? 'Posting...' : 'Post'}
			</button>
		</div>

		{#if isLoading}
			<div class="empty-state"><div class="loading-spinner"></div><p>Loading bulletins...</p></div>
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
							<button class="delete-btn" onclick={() => deleteBulletin(bulletin.id)} aria-label="Delete">
								<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
								</svg>
							</button>
						{/if}
					</div>
				{:else}
					<div class="empty-state">No bulletins posted.</div>
				{/each}
			</div>
		{/if}
	</div>

	<!-- ═══════════════════ Bulletin Categories ═════════════════ -->
	<div class="section">
		<div class="section-title-row">
			<span class="section-title">
				Bulletin Board Categories
				<span class="cat-count-badge">{categories.length}/20</span>
			</span>
			<button class="btn-add-cat"
				onclick={() => { showAddForm = !showAddForm; showIconPicker = null; }}
				disabled={categories.length >= 20}
				title={categories.length >= 20 ? 'Maximum categories reached' : 'Add new category'}>
				<span class="material-icons" style="font-size:13px;">add</span>
				Add Category
			</button>
		</div>

		<p class="section-hint">
			Drag <span class="hint-icon">⠿</span> to reorder &nbsp;·&nbsp; Click icon circle to change icon &nbsp;·&nbsp;
			Click color dot to pick color &nbsp;·&nbsp;
			<a href="https://fonts.google.com/icons" target="_blank" rel="noreferrer">Icon reference</a>
		</p>

		<!-- ── Add Form ── -->
		{#if showAddForm}
			<div class="add-cat-form">
				<div class="add-cat-row">
					<div class="add-color-wrap" title="Pick color">
						<input type="color" bind:value={newCatColor} class="color-input-hidden" id="new-cat-color" />
						<label for="new-cat-color" class="color-swatch-lg" style="background:{newCatColor};">
							<span class="material-icons" style="font-size:11px;color:rgba(255,255,255,0.65);">colorize</span>
						</label>
					</div>
					<div class="add-icon-preview" style="border-color:{newCatColor}55;color:{newCatColor};">
						<span class="material-icons">{newCatIcon || 'help_outline'}</span>
					</div>
					<input class="cat-input cat-input-mono add-icon-input" type="text"
						placeholder="icon name..." bind:value={newCatIcon} maxlength="48" />
					<input class="cat-input add-label-input" type="text"
						placeholder="Category label (e.g. Warrants)" bind:value={newCatLabel} maxlength="48"
						onkeydown={(e) => e.key === 'Enter' && addCategory()} />
					{#if newCatLabel.trim()}
						<span class="key-preview" title="Will be saved as this key">{slugify(newCatLabel)}</span>
					{/if}
				</div>

				<div class="icon-suggestions">
					{#each ICON_SUGGESTIONS as icon}
						<button class="icon-chip" class:active={newCatIcon === icon}
							onclick={() => newCatIcon = icon} title={icon}>
							<span class="material-icons">{icon}</span>
						</button>
					{/each}
				</div>

				<div class="add-cat-actions">
					<button class="btn-cancel-add" onclick={resetAddForm}>Cancel</button>
					<button class="btn-confirm-add" onclick={addCategory}
						disabled={addingCat || !newCatLabel.trim()}>
						{#if addingCat}<div class="spinner-xs"></div>
						{:else}<span class="material-icons" style="font-size:12px;">add</span>{/if}
						Save
					</button>
				</div>
			</div>
		{/if}

		<!-- ── Category List ── -->
		{#if categoriesLoading}
			<div class="empty-state" style="min-height:80px;">
				<div class="loading-spinner"></div><p>Loading categories...</p>
			</div>
		{:else}
			<div class="categories-list" class:no-select={isDragging}>
				{#each categories as cat, idx (cat.value)}
					<div
						class="category-row"
						class:drag-src={drag?.active && drag.idx === idx}
						class:drag-over={dragOverIdx === idx}
						data-cat-idx={idx}
					>
						<!-- Mouse-drag handle -->
						<div class="drag-handle" title="Drag to reorder"
							role="button" tabindex="-1" aria-label="Drag to reorder"
							onmousedown={(e) => onHandleMouseDown(e, idx)}>⠿</div>

						<!-- Color picker -->
						<div class="color-wrap" title="Category color">
							<input type="color" bind:value={cat.color} class="color-input-hidden" id="color-{cat.value}" />
							<label for="color-{cat.value}" class="color-dot" style="background:{cat.color};"></label>
						</div>

						<!-- Icon circle → opens inline picker -->
						<button class="cat-icon-circle"
							style="border-color:{cat.color}50;color:{cat.color};"
							onclick={() => showIconPicker = showIconPicker === cat.value ? null : cat.value}
							title="Click to change icon">
							<span class="material-icons">{cat.icon || 'help_outline'}</span>
						</button>

						<!-- Label field -->
						<div class="cat-field">
							<span class="cat-field-label">Label</span>
							<input class="cat-input" type="text" placeholder="Category label..."
								bind:value={cat.label} maxlength="48" />
						</div>

						<!-- Icon name field -->
						<div class="cat-field cat-field-icon">
							<span class="cat-field-label">Icon</span>
							<input class="cat-input cat-input-mono" type="text"
								placeholder="icon name..." bind:value={cat.icon} maxlength="48" />
						</div>

						<!-- DB key badge -->
						<div class="cat-value-badge" title="Database key (read-only)">{cat.value}</div>

						{#if cat.is_default}
							<span class="default-badge" title="Built-in default">default</span>
						{/if}

						<!-- Save -->
						<button class="btn-row-icon btn-save" onclick={() => saveCategory(cat)}
							disabled={savingCat === cat.value} title="Save changes">
							{#if savingCat === cat.value}
								<div class="spinner-xs"></div>
							{:else}
								<span class="material-icons">save</span>
							{/if}
						</button>

						<!-- Remove -->
						<button class="btn-row-icon btn-remove" onclick={() => removeCategory(cat.value)}
							disabled={removingCat === cat.value || categories.length <= 1}
							title={categories.length <= 1 ? 'Cannot remove last category' : 'Remove category'}>
							{#if removingCat === cat.value}
								<div class="spinner-xs"></div>
							{:else}
								<span class="material-icons">delete_outline</span>
							{/if}
						</button>
					</div>

					<!-- Inline icon picker -->
					{#if showIconPicker === cat.value}
						<div class="icon-picker-inline">
							{#each ICON_SUGGESTIONS as icon}
								<button class="icon-chip" class:active={cat.icon === icon}
									onclick={() => { cat.icon = icon; showIconPicker = null; }} title={icon}>
									<span class="material-icons">{icon}</span>
								</button>
							{/each}
						</div>
					{/if}
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.management-panel {
		display: flex; flex-direction: column; height: 100%; background: transparent;
		overflow-y: auto; scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.06) transparent;
	}

	/* Toast */
	.status-toast { padding: 6px 12px; font-size: 10px; font-weight: 500; flex-shrink: 0; margin: 8px 16px 0; border-radius: 3px; }
	.status-toast.success { background: rgba(16,185,129,0.08); color: rgba(110,231,183,0.8); border: 1px solid rgba(16,185,129,0.1); }
	.status-toast.error   { background: rgba(239,68,68,0.08);  color: rgba(252,165,165,0.8); border: 1px solid rgba(239,68,68,0.1); }

	/* Sections */
	.section { border-bottom: 1px solid rgba(255,255,255,0.06); padding: 0 0 16px; flex-shrink: 0; }
	.section:last-child { border-bottom: none; }
	.section-title-row { display: flex; align-items: center; justify-content: space-between; padding: 12px 16px 8px; gap: 8px; }
	.section-title { display: flex; align-items: center; gap: 7px; font-size: 9px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.7px; color: rgba(255,255,255,0.35); }
	.cat-count-badge { background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.08); border-radius: 3px; padding: 1px 5px; font-size: 9px; color: rgba(255,255,255,0.3); font-weight: 600; letter-spacing: 0; }
	.section-hint { margin: 0 16px 10px; font-size: 10px; color: rgba(255,255,255,0.3); line-height: 1.5; }
	.section-hint a { color: rgba(147,197,253,0.6); text-decoration: none; }
	.section-hint a:hover { color: rgba(147,197,253,0.9); text-decoration: underline; }
	.hint-icon { font-family: monospace; opacity: 0.6; }

	/* MotD */
	.new-bulletin { display: flex; gap: 10px; padding: 4px 16px 10px; align-items: flex-end; }
	.bulletin-fields { flex: 1; display: flex; flex-direction: column; gap: 5px; }
	.bulletin-title-input { background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.06); border-radius: 3px; padding: 5px 8px; color: rgba(255,255,255,0.9); font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.3px; outline: none; }
	.bulletin-title-input:focus { border-color: rgba(255,255,255,0.12); }
	.bulletin-title-input::placeholder { color: rgba(255,255,255,0.35); font-weight: 400; text-transform: none; letter-spacing: 0; }
	.bulletin-input { background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.06); border-radius: 3px; padding: 6px 8px; color: rgba(255,255,255,0.8); font-size: 11px; font-family: inherit; resize: vertical; min-height: 32px; outline: none; }
	.bulletin-input:focus { border-color: rgba(255,255,255,0.12); }
	.bulletin-input::placeholder { color: rgba(255,255,255,0.2); }
	.btn-post { background: rgba(var(--accent-rgb),0.06); border: 1px solid rgba(var(--accent-rgb),0.1); border-radius: 3px; padding: 5px 12px; color: rgba(var(--accent-text-rgb),0.7); font-size: 10px; font-weight: 600; cursor: pointer; transition: all 0.1s; flex-shrink: 0; }
	.btn-post:hover:not(:disabled) { background: rgba(var(--accent-rgb),0.12); color: rgba(var(--accent-text-rgb),0.9); }
	.btn-post:disabled { opacity: 0.3; cursor: not-allowed; }
	.bulletins-list { max-height: 220px; overflow-y: auto; scrollbar-width: thin; scrollbar-color: rgba(255,255,255,0.06) transparent; }
	.bulletin-row { display: flex; align-items: flex-start; gap: 10px; padding: 8px 16px; border-bottom: 1px solid rgba(255,255,255,0.03); transition: background 0.1s; }
	.bulletin-row:hover { background: rgba(255,255,255,0.02); }
	.bulletin-row:last-child { border-bottom: none; }
	.bulletin-body { flex: 1; display: flex; flex-direction: column; gap: 2px; min-width: 0; }
	.bulletin-title { font-size: 9px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; color: rgba(255,255,255,0.35); }
	.bulletin-text  { color: rgba(255,255,255,0.6); font-size: 11px; line-height: 1.5; margin: 0; }
	.delete-btn { background: none; border: none; color: rgba(255,255,255,0.3); cursor: pointer; padding: 3px; border-radius: 3px; display: flex; align-items: center; flex-shrink: 0; transition: all 0.1s; opacity: 0; }
	.bulletin-row:hover .delete-btn { opacity: 1; }
	.delete-btn:hover { color: rgba(252,165,165,0.8); background: rgba(239,68,68,0.08); }

	/* Add category */
	.btn-add-cat { display: flex; align-items: center; gap: 4px; background: rgba(16,185,129,0.06); border: 1px solid rgba(16,185,129,0.1); border-radius: 3px; padding: 3px 10px; color: rgba(52,211,153,0.7); font-size: 10px; font-weight: 600; cursor: pointer; transition: all 0.1s; flex-shrink: 0; }
	.btn-add-cat:hover:not(:disabled) { background: rgba(16,185,129,0.12); color: rgba(110,231,183,0.9); }
	.btn-add-cat:disabled { opacity: 0.3; cursor: not-allowed; }

	/* Add form */
	.add-cat-form { margin: 0 16px 10px; background: rgba(255,255,255,0.02); border: 1px solid rgba(255,255,255,0.06); border-radius: 5px; padding: 10px; display: flex; flex-direction: column; gap: 8px; }
	.add-cat-row { display: flex; align-items: center; gap: 7px; flex-wrap: wrap; }
	.add-color-wrap { position: relative; flex-shrink: 0; }
	.color-input-hidden { position: absolute; width: 0; height: 0; opacity: 0; pointer-events: none; }
	.color-swatch-lg { display: flex; align-items: center; justify-content: center; width: 30px; height: 30px; border-radius: 5px; cursor: pointer; border: 1px solid rgba(255,255,255,0.12); transition: border-color 0.1s; }
	.color-swatch-lg:hover { border-color: rgba(255,255,255,0.25); }
	.add-icon-preview { width: 30px; height: 30px; border-radius: 50%; background: rgba(255,255,255,0.03); border: 1px solid; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
	.add-icon-preview .material-icons { font-size: 16px; }
	.add-icon-input { width: 110px; flex-shrink: 0; }
	.add-label-input { flex: 1; min-width: 130px; }
	.key-preview { font-size: 9px; font-family: monospace; color: rgba(255,255,255,0.22); background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.05); border-radius: 3px; padding: 2px 6px; white-space: nowrap; flex-shrink: 0; }
	.icon-suggestions { display: flex; flex-wrap: wrap; gap: 4px; }
	.icon-chip { display: flex; align-items: center; justify-content: center; width: 28px; height: 28px; background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.06); border-radius: 4px; cursor: pointer; transition: all 0.1s; color: rgba(255,255,255,0.4); }
	.icon-chip:hover  { background: rgba(255,255,255,0.07); color: rgba(255,255,255,0.8); }
	.icon-chip.active { background: rgba(var(--accent-rgb),0.12); border-color: rgba(var(--accent-rgb),0.3); color: rgba(var(--accent-text-rgb),0.9); }
	.icon-chip .material-icons { font-size: 15px; }
	.add-cat-actions { display: flex; align-items: center; justify-content: flex-end; gap: 6px; padding-top: 4px; border-top: 1px solid rgba(255,255,255,0.04); }
	.btn-cancel-add { background: transparent; border: 1px solid rgba(255,255,255,0.06); border-radius: 3px; padding: 3px 10px; color: rgba(255,255,255,0.35); font-size: 10px; font-weight: 500; cursor: pointer; }
	.btn-cancel-add:hover { color: rgba(255,255,255,0.6); }
	.btn-confirm-add { display: flex; align-items: center; gap: 4px; background: rgba(16,185,129,0.06); border: 1px solid rgba(16,185,129,0.1); border-radius: 3px; padding: 3px 12px; color: rgba(52,211,153,0.7); font-size: 10px; font-weight: 600; cursor: pointer; transition: all 0.1s; }
	.btn-confirm-add:hover:not(:disabled) { background: rgba(16,185,129,0.12); color: rgba(110,231,183,0.9); }
	.btn-confirm-add:disabled { opacity: 0.3; cursor: not-allowed; }

	/* Category list */
	.categories-list { display: flex; flex-direction: column; gap: 0; padding: 0 16px; }
	.categories-list.no-select { user-select: none; }

	/* Ghost (appended to document.body by JS) */
	:global(.cat-drag-ghost) {
		position: fixed; z-index: 9999; pointer-events: none;
		padding: 5px 10px; border-radius: 5px;
		background: rgba(22,22,22,0.97); border: 1px solid rgba(255,255,255,0.14);
		color: rgba(255,255,255,0.88); font-size: 11px; font-weight: 600;
		white-space: nowrap; box-shadow: 0 4px 16px rgba(0,0,0,0.45);
		transform: rotate(1.5deg);
	}

	.category-row { display: flex; align-items: center; gap: 7px; padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.03); transition: background 0.1s, opacity 0.1s; user-select: none; }
	.category-row:last-child { border-bottom: none; }
	.category-row.drag-src  { opacity: 0.35; }
	.category-row.drag-over { background: rgba(255,255,255,0.04); border-radius: 4px; box-shadow: 0 0 0 1px rgba(var(--accent-rgb),0.3); }

	.drag-handle { font-family: monospace; font-size: 14px; line-height: 1; color: rgba(255,255,255,0.2); cursor: grab; flex-shrink: 0; padding: 0 2px; }
	.drag-handle:active { cursor: grabbing; }

	.color-wrap { position: relative; flex-shrink: 0; width: 18px; height: 18px; }
	.color-dot { display: block; width: 18px; height: 18px; border-radius: 50%; cursor: pointer; border: 2px solid rgba(255,255,255,0.15); transition: border-color 0.1s; }
	.color-dot:hover { border-color: rgba(255,255,255,0.35); }

	.cat-icon-circle { width: 28px; height: 28px; border-radius: 50%; background: rgba(255,255,255,0.03); border: 1px solid; display: flex; align-items: center; justify-content: center; flex-shrink: 0; cursor: pointer; transition: all 0.15s; padding: 0; }
	.cat-icon-circle:hover { background: rgba(255,255,255,0.07); }
	.cat-icon-circle .material-icons { font-size: 15px; }

	.cat-field { flex: 1; display: flex; flex-direction: column; gap: 2px; min-width: 0; }
	.cat-field-icon { max-width: 120px; }
	.cat-field-label { font-size: 8px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; color: rgba(255,255,255,0.25); }
	.cat-input { background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.06); border-radius: 3px; padding: 4px 7px; color: rgba(255,255,255,0.8); font-size: 11px; font-family: inherit; outline: none; transition: border-color 0.1s; width: 100%; }
	.cat-input:focus { border-color: rgba(255,255,255,0.12); }
	.cat-input::placeholder { color: rgba(255,255,255,0.18); }
	.cat-input-mono { font-family: monospace; font-size: 10px; letter-spacing: 0.3px; }

	.cat-value-badge { font-size: 9px; font-family: monospace; color: rgba(255,255,255,0.25); background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.05); border-radius: 3px; padding: 2px 6px; white-space: nowrap; flex-shrink: 0; }
	.default-badge { font-size: 8px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.4px; color: rgba(var(--accent-rgb),0.6); background: rgba(var(--accent-rgb),0.06); border: 1px solid rgba(var(--accent-rgb),0.12); border-radius: 3px; padding: 1px 5px; white-space: nowrap; flex-shrink: 0; }

	.btn-row-icon { display: flex; align-items: center; justify-content: center; width: 24px; height: 24px; border-radius: 3px; cursor: pointer; transition: all 0.1s; flex-shrink: 0; }
	.btn-row-icon .material-icons { font-size: 13px; }
	.btn-row-icon:disabled { opacity: 0.25; cursor: not-allowed; }
	.btn-save   { background: rgba(16,185,129,0.06); border: 1px solid rgba(16,185,129,0.1); color: rgba(52,211,153,0.6); }
	.btn-save:hover:not(:disabled)   { background: rgba(16,185,129,0.14); color: rgba(110,231,183,0.9); }
	.btn-remove { background: rgba(220,70,60,0.04); border: 1px solid rgba(220,70,60,0.1); color: rgba(220,70,60,0.5); }
	.btn-remove:hover:not(:disabled) { background: rgba(220,70,60,0.12); color: rgba(220,70,60,0.9); }

	.icon-picker-inline { display: flex; flex-wrap: wrap; gap: 4px; padding: 8px 0 8px 36px; border-bottom: 1px solid rgba(255,255,255,0.03); background: rgba(255,255,255,0.01); }

	.empty-state { display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 80px; color: rgba(255,255,255,0.35); font-size: 11px; }
	.loading-spinner { width: 20px; height: 20px; border: 2px solid rgba(255,255,255,0.06); border-left: 2px solid rgba(var(--accent-rgb),0.5); border-radius: 50%; animation: spin 0.8s linear infinite; margin-bottom: 8px; }
	.spinner-xs { width: 10px; height: 10px; border: 1.5px solid rgba(255,255,255,0.1); border-left-color: currentColor; border-radius: 50%; animation: spin 0.8s linear infinite; }
	@keyframes spin { 0%{transform:rotate(0deg)} 100%{transform:rotate(360deg)} }
</style>