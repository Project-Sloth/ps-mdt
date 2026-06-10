<script lang="ts">
	import type { Evidence } from "../../interfaces/IReportEditor";

	interface EvidenceWithImages extends Omit<Evidence, "images"> {
    	images: string[];
		caseId?: string;
	}

	interface Props {
		evidence: EvidenceWithImages[];
		onAddEvidence: () => void;
		onRemoveEvidence: (id: string) => void;
		onUpdateEvidence: (evidence: EvidenceWithImages) => void;
		onRemoveImage: (evidenceId: string, imageIndex: number) => void;
		onLinkEvidenceCase: (evidenceId: string, caseId: string) => void;
		onCreateCaseFromEvidence: (evidenceId: string) => void;
		onNavigateToCases?: () => void;
	}

	let {
		evidence,
		onAddEvidence,
		onRemoveEvidence,
		onUpdateEvidence,
		onRemoveImage,
		onLinkEvidenceCase,
		onCreateCaseFromEvidence,
		onNavigateToCases,
	}: Props = $props();

	const evidenceTypes = [
		"Physical",
		"Digital",
		"Document",
		"Weapon",
		"Drug",
		"Vehicle",
		"Other",
	];

		function getSerialPlaceholder(type: string) {
		switch (type) {
			case "Physical": return "Item ID / Description";
			case "Digital": return "File Hash / ID";
			case "Document": return "Document Number";
			case "Weapon": return "Weapon Serial Number";
			case "Drug": return "Batch / Substance ID";
			case "Vehicle": return "VIN / License Plate";
			default: return "Reference ID";
		}
	}

	function getNotesPlaceholder(type: string) {
		switch (type) {
			case "Physical": return "Describe the physical evidence...";
			case "Digital": return "Describe the digital evidence...";
			case "Document": return "Document details...";
			case "Weapon": return "Weapon condition, caliber, etc...";
			case "Drug": return "Type, quantity, packaging...";
			case "Vehicle": return "Vehicle condition, location...";
			default: return "Additional notes...";
		}
	}
	
	function getTitlePlaceholder(type: string) {
		switch (type) {
			case "Physical": return "Item name (e.g. Blood-stained shirt)";
			case "Digital": return "File name (e.g. chat_log.txt)";
			case "Document": return "Document title (e.g. Contract)";
			case "Weapon": return "Weapon name + Serial Number (e.g. Glock 17)";
			case "Drug": return "Substance name (e.g. Cocaine)";
			case "Vehicle": return "Vehicle (e.g. Sultan RS)";
			default: return "Evidence title";
		}
	}

	// --- Add Image Modal state ---
	let addImgOpen = $state(false);
	let addImgEvidenceId = $state<string | null>(null);
	let addImgUrl = $state("");

	// --- Lightbox state ---
	let lightboxOpen = $state(false);
	let lightboxUrl = $state("");

	function updateEvidence(id: string, field: keyof EvidenceWithImages, value: any) {
		const item = evidence.find((e) => e.id === id);
		if (item) {
			onUpdateEvidence({ ...item, [field]: value });
		}
	}

	function openAddImage(evidenceId: string) {
		addImgEvidenceId = evidenceId;
		addImgUrl = "";
		addImgOpen = true;
	}

	function confirmAddImage() {
		const url = addImgUrl.trim();
		if (!url || !addImgEvidenceId) return;
		const item = evidence.find((e) => e.id === addImgEvidenceId);
		if (item) {
			onUpdateEvidence({
				...item,
				images: [...item.images, url],
			});
		}
		addImgOpen = false;
	}

	function openLightbox(url: string) {
		lightboxUrl = url;
		lightboxOpen = true;
	}

	function linkEvidenceCase(evidenceId: string, caseId: string) {
		if (!caseId.trim()) return;
		onLinkEvidenceCase(evidenceId, caseId.trim());
	}
</script>

<!-- Add Image Modal -->
{#if addImgOpen}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		class="modal-backdrop"
		onclick={(e) => { if (e.target === e.currentTarget) addImgOpen = false; }}
	>
		<div class="modal" role="dialog" aria-modal="true" tabindex="-1">
			<div class="modal-header">
				<h3>Add Image</h3>
				<button class="close-btn" aria-label="Close" onclick={() => (addImgOpen = false)}>
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>
			<div class="modal-body form-body">
				<div class="form-group">
					<span class="field-label">Image URL</span>
					<input
						class="form-input"
						type="url"
						placeholder="https://example.com/photo.jpg"
						bind:value={addImgUrl}
					/>
					{#if addImgUrl.trim()}
						<span class="url-hint">
							<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
							</svg>
							Use <a href="https://fivemanage.com" target="_blank" rel="noopener noreferrer">FiveManage</a> to make sure your links persist forever.
						</span>
					{/if}
				</div>
			</div>
			<div class="modal-footer">
				<button class="cancel-btn" onclick={() => (addImgOpen = false)}>Cancel</button>
				<button class="primary-btn" onclick={confirmAddImage}>Add Image</button>
			</div>
		</div>
	</div>
{/if}

<!-- Lightbox -->
{#if lightboxOpen}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div
		class="modal-backdrop"
		onclick={(e) => { if (e.target === e.currentTarget) lightboxOpen = false; }}
	>
		<div class="modal lightbox-modal" role="dialog" aria-modal="true" tabindex="-1">
			<div class="modal-header">
				<h3>Evidence Image</h3>
				<button class="close-btn" aria-label="Close" onclick={() => (lightboxOpen = false)}>
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>
			<div class="modal-body lightbox-body">
				<img class="lightbox-img" src={lightboxUrl} alt="Evidence" />
			</div>
		</div>
	</div>
{/if}

<div class="metadata-section">
	<div class="section-header">
		<span class="section-label">EVIDENCE</span>
		<button class="add-btn" onclick={onAddEvidence} aria-label="Add Evidence">+ Add</button>
	</div>

	{#each evidence as item}
		<div class="evidence-card">
			<div class="card-top">
				<div class="card-info">
					<input
						type="text"
						placeholder={getTitlePlaceholder(item.type)}
						value={item.title}
						oninput={(e) => updateEvidence(item.id, "title", e.currentTarget.value)}
						class="title-input"
					/>
					{#if item.caseId}
						{#if onNavigateToCases}
							<!-- svelte-ignore a11y_click_events_have_key_events -->
							<span class="case-badge nav-link" role="button" tabindex="-1" onclick={onNavigateToCases}>
								Case #{item.caseId}
							</span>
						{:else}
							<span class="case-badge">Case #{item.caseId}</span>
						{/if}
					{/if}
				</div>
				<button class="remove-btn" onclick={() => onRemoveEvidence(item.id)} aria-label="Remove evidence">
					<svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor">
						<path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" />
					</svg>
				</button>
			</div>

			<div class="card-fields">
				<div class="field-row">
					<select
						value={item.type}
						onchange={(e) => updateEvidence(item.id, "type", e.currentTarget.value)}
						class="field-select"
					>
						{#each evidenceTypes as type}
							<option value={type}>{type}</option>
						{/each}
					</select>
					<input
						type="text"
						placeholder={getSerialPlaceholder(item.type)}
						value={item.serial}
						oninput={(e) => updateEvidence(item.id, "serial", e.currentTarget.value)}
						class="field-input"
					/>
				</div>
				<textarea
					placeholder={getNotesPlaceholder(item.type)}
					value={item.notes}
					oninput={(e) => updateEvidence(item.id, "notes", e.currentTarget.value)}
					class="notes-input"
				></textarea>
			</div>

			<div class="card-actions">
				<div class="image-actions">
					<button class="action-btn" onclick={() => openAddImage(item.id)}>
						Add Image
					</button>
					{#if item.images.length > 0}
						<span class="image-count">
							{item.images.length} image{item.images.length > 1 ? "s" : ""}
						</span>
					{/if}
				</div>
			</div>

			{#if item.images.length > 0}
				<div class="images-grid">
					{#each item.images as image, imageIndex}
						<!-- svelte-ignore a11y_click_events_have_key_events -->
						<div
							class="image-item"
							role="button"
							tabindex="0"
							onclick={() => openLightbox(image)}
							onkeydown={(e) => e.key === "Enter" && openLightbox(image)}
						>
							<img src={image} alt={"Evidence"} class="evidence-image" />
							<button
								class="image-remove-btn"
								onclick={(e) => { e.stopPropagation(); onRemoveImage(item.id, imageIndex); }}
								aria-label="Remove image"
							>
								<svg width="8" height="8" viewBox="0 0 24 24" fill="currentColor">
									<path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" />
								</svg>
							</button>
						</div>
					{/each}
				</div>
			{/if}
		</div>
	{/each}
</div>

<style>
	/* ── Section ── */
	.metadata-section {
		padding-bottom: 12px;
		margin-bottom: 12px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}
	.section-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 8px;
	}
	.section-label {
		font-size: 10px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.3);
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}
	.add-btn {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.35);
		cursor: pointer;
		font-size: 10px;
		font-weight: 500;
		padding: 2px 6px;
		transition: color 0.1s;
	}
	.add-btn:hover { color: rgba(255, 255, 255, 0.55); }

	/* ── Evidence card ── */
	.evidence-card {
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		padding: 8px 0;
	}
	.evidence-card:last-child { margin-bottom: 0; }
	.evidence-card:hover .remove-btn { opacity: 1; }

	.card-top {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 8px;
		margin-bottom: 8px;
	}
	.card-info { display: flex; flex-direction: column; gap: 2px; flex: 1; }

	.title-input {
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.9);
		font-size: 12px;
		font-weight: 500;
		padding: 2px 0;
		width: 100%;
	}
	.title-input:focus { outline: none; border-bottom-color: rgba(255, 255, 255, 0.1); }
	.title-input::placeholder { color: rgba(255, 255, 255, 0.4); }

	.case-badge { font-size: 11px; color: rgba(var(--accent-text-rgb), 0.7); font-weight: 500; }
	.nav-link { cursor: pointer; transition: color 0.12s; }
	.nav-link:hover { color: rgba(var(--accent-text-rgb), 1); text-decoration: underline; }

	.remove-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 16px;
		height: 16px;
		background: rgba(239, 68, 68, 0.15);
		border: none;
		border-radius: 50%;
		color: rgba(255, 255, 255, 0.6);
		cursor: pointer;
		flex-shrink: 0;
		opacity: 0;
		transition: opacity 0.15s, background 0.15s;
	}
	.remove-btn:hover { background: rgba(239, 68, 68, 0.3); }

	/* ── Fields ── */
	.card-fields { display: flex; flex-direction: column; gap: 6px; margin-bottom: 8px; }
	.field-row { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; }

	.field-select {
		padding: 4px 24px 4px 8px;
		font-size: 11px;
		font-weight: 500;
		border-radius: 4px;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.7);
	}
	.field-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 4px;
		padding: 4px 8px;
		color: rgba(255, 255, 255, 0.7);
		font-size: 11px;
	}
	.field-input:focus { outline: none; border-color: rgba(255, 255, 255, 0.1); }
	.field-input::placeholder { color: rgba(255, 255, 255, 0.4); }

	.notes-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 4px;
		padding: 4px 8px;
		color: rgba(255, 255, 255, 0.7);
		font-size: 11px;
		min-height: 36px;
		resize: vertical;
		font-family: inherit;
		width: 100%;
	}
	.notes-input:focus { outline: none; border-color: rgba(255, 255, 255, 0.1); }
	.notes-input::placeholder { color: rgba(255, 255, 255, 0.4); }

	/* ── Card actions ── */
	.card-actions {
		display: flex;
		flex-direction: column;
		gap: 6px;
		padding-top: 8px;
		border-top: 1px solid rgba(255, 255, 255, 0.04);
	}
	.link-row { display: flex; gap: 6px; align-items: center; }
	.link-row .field-input { flex: 1; max-width: 100px; }
	.image-actions { display: flex; gap: 6px; align-items: center; }
	.image-count { font-size: 11px; color: rgba(255, 255, 255, 0.5); }
	.action-btn {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.5);
		border: 1px solid rgba(255, 255, 255, 0.06);
		padding: 4px 10px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 500;
		cursor: pointer;
		white-space: nowrap;
		transition: background 0.12s, color 0.12s;
	}
	.action-btn:hover { background: rgba(255, 255, 255, 0.07); color: rgba(255, 255, 255, 0.75); }

	/* ── Images grid ── */
	.images-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(60px, 1fr));
		gap: 6px;
		margin-top: 8px;
		padding-top: 8px;
		border-top: 1px solid rgba(255, 255, 255, 0.04);
	}
	.image-item {
		position: relative;
		aspect-ratio: 1;
		border-radius: 4px;
		overflow: hidden;
		border: 1px solid rgba(255, 255, 255, 0.06);
		cursor: pointer;
	}
	.evidence-image {
		width: 100%;
		height: 100%;
		object-fit: cover;
		display: block;
		transition: transform 0.2s ease;
	}
	.image-item:hover .evidence-image { transform: scale(1.04); }

	.img-tooltip {
		position: absolute;
		bottom: 0;
		left: 0;
		right: 0;
		background: rgba(0, 0, 0, 0.75);
		color: rgba(255, 255, 255, 0.85);
		font-size: 10px;
		padding: 4px 5px;
		transform: translateY(100%);
		transition: transform 0.18s ease;
		pointer-events: none;
		word-break: break-word;
		line-height: 1.3;
	}
	.image-item:hover .img-tooltip { transform: translateY(0); }

	.image-remove-btn {
		position: absolute;
		top: 2px;
		right: 2px;
		width: 14px;
		height: 14px;
		background: rgba(239, 68, 68, 0.8);
		border: none;
		border-radius: 50%;
		color: #fff;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		opacity: 0;
		transition: opacity 0.15s;
	}
	.image-item:hover .image-remove-btn { opacity: 1; }

	/* ── Modal — matches BOLO design ── */
	.modal-backdrop {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.7);
		backdrop-filter: blur(4px);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 999;
	}
	.modal {
		background: var(--card-dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 6px;
		width: min(400px, 92vw);
		max-height: 85vh;
		overflow: hidden;
		display: flex;
		flex-direction: column;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
	}
	.lightbox-modal { width: min(640px, 92vw); }

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 10px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}
	.modal-header h3 {
		margin: 0;
		font-size: 12px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}
	.close-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		background: transparent;
		color: rgba(255, 255, 255, 0.3);
		border: 1px solid rgba(255, 255, 255, 0.06);
		padding: 4px;
		border-radius: 3px;
		cursor: pointer;
		transition: all 0.1s;
	}
	.close-btn:hover { color: rgba(255, 255, 255, 0.7); border-color: rgba(255, 255, 255, 0.1); }

	.modal-body { padding: 14px 16px; overflow-y: auto; }

	.form-body { display: flex; flex-direction: column; gap: 10px; }
	.form-group { display: flex; flex-direction: column; gap: 3px; }

	.field-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}
	.field-value {
		color: rgba(255, 255, 255, 0.7);
		font-size: 11px;
		font-weight: 500;
		margin: 2px 0 0;
	}

	.form-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		transition: border-color 0.1s;
		font-family: inherit;
		width: 100%;
	}
	.form-input:focus { outline: none; border-color: rgba(255, 255, 255, 0.1); }
	.form-input::placeholder { color: rgba(255, 255, 255, 0.2); }

	/* FiveManage hint — appears when URL is typed */
	.url-hint {
		display: flex;
		align-items: center;
		gap: 5px;
		margin-top: 5px;
		font-size: 10px;
		color: rgba(255, 255, 255, 0.25);
		line-height: 1.4;
	}
	.url-hint svg { flex-shrink: 0; opacity: 0.45; }
	.url-hint a {
		color: rgba(var(--accent-text-rgb), 0.5);
		text-decoration: none;
		transition: color 0.1s;
	}
	.url-hint a:hover { color: rgba(var(--accent-text-rgb), 0.85); text-decoration: underline; }

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		align-items: center;
		gap: 6px;
		padding: 10px 16px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}
	.modal-footer-end { justify-content: flex-end; }

	.cancel-btn {
		background: transparent;
		color: rgba(255, 255, 255, 0.4);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 10px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}
	.cancel-btn:hover { color: rgba(255, 255, 255, 0.7); border-color: rgba(255, 255, 255, 0.1); }

	.primary-btn {
		background: rgba(16, 185, 129, 0.06);
		color: rgba(52, 211, 153, 0.7);
		border: 1px solid rgba(16, 185, 129, 0.1);
		border-radius: 3px;
		padding: 4px 12px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}
	.primary-btn:hover { background: rgba(16, 185, 129, 0.12); color: rgba(110, 231, 183, 0.9); }

	/* ── Lightbox body ── */
	.lightbox-body { display: flex; flex-direction: column; gap: 12px; }
	.lightbox-img {
		width: 100%;
		max-height: 60vh;
		object-fit: contain;
		border-radius: 4px;
		border: 1px solid rgba(255, 255, 255, 0.06);
	}
</style>