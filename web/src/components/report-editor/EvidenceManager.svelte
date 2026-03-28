<script lang="ts">
	import type { Evidence } from "../../interfaces/IReportEditor";

	interface Props {
		evidence: Evidence[];
		onAddEvidence: () => void;
		onRemoveEvidence: (id: string) => void;
		onUpdateEvidence: (evidence: Evidence) => void;
		onOpenImageUpload: (evidenceId: string) => void;
		onRemoveImage: (evidenceId: string, imageIndex: number) => void;
		onLinkEvidenceCase: (evidenceId: string, caseId: string) => void;
		onCreateCaseFromEvidence: (evidenceId: string) => void;
		onNavigateToCases?: () => void;
		onNavigateToEvidence?: () => void;
	}

	let {
		evidence,
		onAddEvidence,
		onRemoveEvidence,
		onUpdateEvidence,
		onOpenImageUpload,
		onRemoveImage,
		onLinkEvidenceCase,
		onCreateCaseFromEvidence,
		onNavigateToCases,
		onNavigateToEvidence,
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

	function updateEvidence(id: string, field: keyof Evidence, value: any) {
		const item = evidence.find((e) => e.id === id);
		if (item) {
			const updated = { ...item, [field]: value };
			onUpdateEvidence(updated);
		}
	}

	function linkEvidenceCase(evidenceId: string, caseId: string) {
		if (!caseId.trim()) return;
		onLinkEvidenceCase(evidenceId, caseId.trim());
	}
</script>

<div class="metadata-section">
	<div class="section-header">
		<span class="section-label">EVIDENCE</span>
		<button
			class="add-btn"
			onclick={onAddEvidence}
			title="Add Evidence"
			aria-label="Add Evidence"
		>+ Add</button>
	</div>

	{#if evidence.length > 0}
		{#each evidence as item}
			<div class="evidence-card">
				<div class="card-top">
					<div class="card-info">
						<input
							type="text"
							placeholder="Evidence Title"
							value={item.title}
							oninput={(e) => updateEvidence(item.id, "title", e.currentTarget.value)}
							class="title-input"
						/>
						{#if (item as any).caseId}
							{#if onNavigateToCases}
								<!-- svelte-ignore a11y_click_events_have_key_events -->
								<span class="case-badge nav-link" role="button" tabindex="-1" onclick={onNavigateToCases}>Case #{(item as any).caseId}</span>
							{:else}
								<span class="case-badge">Case #{(item as any).caseId}</span>
							{/if}
						{/if}
					</div>
					<button
						class="remove-btn"
						onclick={() => onRemoveEvidence(item.id)}
						aria-label="Remove evidence"
					>
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
							placeholder="Serial Number"
							value={item.serial}
							oninput={(e) => updateEvidence(item.id, "serial", e.currentTarget.value)}
							class="field-input"
						/>
					</div>
					<textarea
						placeholder="Notes"
						value={item.notes}
						oninput={(e) => updateEvidence(item.id, "notes", e.currentTarget.value)}
						class="notes-input"
					></textarea>
				</div>

				<div class="card-actions">
					<div class="link-row">
						<input
							type="text"
							class="field-input"
							placeholder="Case ID"
							value={(item as any).caseId || ""}
							onchange={(e) => linkEvidenceCase(item.id, e.currentTarget.value)}
						/>
						<button class="action-btn" onclick={() => onCreateCaseFromEvidence(item.id)}>
							Create Case
						</button>
					</div>
					<div class="image-actions">
						<button class="action-btn" onclick={() => onOpenImageUpload(item.id)}>
							Add Image
						</button>
						{#if item.images.length > 0}
							<span class="image-count">{item.images.length} image{item.images.length > 1 ? "s" : ""}</span>
						{/if}
					</div>
				</div>

				{#if item.images.length > 0}
					<div class="images-grid">
						{#each item.images as image, imageIndex}
							<div class="image-item">
								<img src={image} alt="Evidence" class="evidence-image" />
								<button
									class="image-remove-btn"
									onclick={() => onRemoveImage(item.id, imageIndex)}
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
	{/if}
</div>

<style>
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

	.add-btn:hover {
		color: rgba(255, 255, 255, 0.5);
	}

	.empty-text {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		text-align: center;
		padding: 10px;
		background: transparent;
		border: 1px dashed rgba(255, 255, 255, 0.04);
		border-radius: 3px;
	}

	.evidence-card {
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		border-radius: 0;
		padding: 8px 0;
		margin-bottom: 0;
	}

	.evidence-card:last-child {
		margin-bottom: 0;
	}

	.evidence-card:hover .remove-btn {
		opacity: 1;
	}

	.card-top {
		display: flex;
		justify-content: space-between;
		align-items: center;
		gap: 8px;
		margin-bottom: 8px;
	}

	.card-info {
		display: flex;
		flex-direction: column;
		gap: 2px;
		flex: 1;
	}

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

	.title-input:focus {
		outline: none;
		border-bottom-color: rgba(255, 255, 255, 0.1);
	}

	.title-input::placeholder {
		color: rgba(255, 255, 255, 0.4);
	}

	.case-badge {
		font-size: 11px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-weight: 500;
	}

	.nav-link {
		cursor: pointer;
		transition: all 0.12s ease;
	}

	.nav-link:hover {
		color: rgba(var(--accent-text-rgb), 1);
		text-decoration: underline;
	}

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
	}

	.remove-btn:hover {
		background: rgba(239, 68, 68, 0.3);
	}

	.card-fields {
		display: flex;
		flex-direction: column;
		gap: 6px;
		margin-bottom: 8px;
	}

	.field-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 6px;
	}

	.field-select {
		padding: 4px 24px 4px 8px;
		font-size: 11px;
		font-weight: 500;
		border-radius: 4px;
	}

	.field-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 4px;
		padding: 4px 8px;
		color: rgba(255, 255, 255, 0.7);
		font-size: 11px;
	}

	.field-input:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.1);
	}

	.field-input::placeholder {
		color: rgba(255, 255, 255, 0.4);
	}

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
	}

	.notes-input:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.1);
	}

	.notes-input::placeholder {
		color: rgba(255, 255, 255, 0.4);
	}

	.card-actions {
		display: flex;
		flex-direction: column;
		gap: 6px;
		padding-top: 8px;
		border-top: 1px solid rgba(255, 255, 255, 0.04);
	}

	.link-row {
		display: flex;
		gap: 6px;
		align-items: center;
	}

	.link-row .field-input {
		flex: 1;
		max-width: 100px;
	}

	.image-actions {
		display: flex;
		gap: 6px;
		align-items: center;
	}

	.image-count {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.5);
	}

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
	}

	.action-btn:hover {
		background: rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.7);
	}

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
	}

	.evidence-image {
		width: 100%;
		height: 100%;
		object-fit: cover;
		cursor: pointer;
	}

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
	}

	.image-item:hover .image-remove-btn {
		opacity: 1;
	}
</style>
