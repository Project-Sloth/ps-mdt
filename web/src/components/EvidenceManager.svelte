<script lang="ts">
	import { EVIDENCE_TYPES } from "../constants";
	import type { Report, Evidence } from "../interfaces/IReportEditor";

	export let report: Report;
	export let onAddEvidence: (evidence: Partial<Evidence>) => void;
	export let onUpdateEvidence: (
		evidenceId: string,
		evidence: Partial<Evidence>,
	) => void;
	export let onRemoveEvidence: (evidenceId: string) => void;
	export let onRemoveImage: (evidenceId: string, imageIndex: number) => void;

	let showEvidenceForm = false;
	let editingEvidence: Evidence | null = null;
	let newEvidence: Partial<Evidence> = {
		title: "",
		type: "",
		serial: "",
		notes: "",
		images: [],
	};

	function toggleEvidenceForm() {
		showEvidenceForm = !showEvidenceForm;
		if (!showEvidenceForm) {
			resetForm();
		}
	}

	function resetForm() {
		editingEvidence = null;
		newEvidence = {
			title: "",
			type: "",
			serial: "",
			notes: "",
			images: [],
		};
	}

	function editEvidence(evidence: Evidence) {
		editingEvidence = evidence;
		newEvidence = { ...evidence };
		showEvidenceForm = true;
	}

	function saveEvidence() {
		if (editingEvidence) {
			onUpdateEvidence(editingEvidence.id, newEvidence);
		} else {
			onAddEvidence(newEvidence);
		}
		toggleEvidenceForm();
	}

	function removeEvidence(evidenceId: string) {
		onRemoveEvidence(evidenceId);
	}

	function removeImage(evidenceId: string, imageIndex: number) {
		onRemoveImage(evidenceId, imageIndex);
	}

	$: formValid = newEvidence.title && newEvidence.type;
</script>

<section class="evidence-manager" aria-label="Evidence management">
	<div class="evidence-header">
		<h3 class="section-title">Evidence ({report.evidence.length})</h3>
		<button
			type="button"
			on:click={toggleEvidenceForm}
			class="add-evidence-btn"
			aria-expanded={showEvidenceForm}
			aria-controls="evidence-form"
		>
			{showEvidenceForm ? "Cancel" : "Add Evidence"}
		</button>
	</div>

	{#if showEvidenceForm}
		<form
			id="evidence-form"
			class="evidence-form"
			on:submit|preventDefault={saveEvidence}
			role="region"
			aria-label={editingEvidence ? "Edit evidence" : "Add new evidence"}
		>
			<div class="form-row">
				<div class="form-field">
					<label for="evidence-title" class="form-label"
						>Title *</label
					>
					<input
						id="evidence-title"
						type="text"
						bind:value={newEvidence.title}
						class="form-input"
						required
						aria-describedby="evidence-title-help"
					/>
					<div id="evidence-title-help" class="sr-only">
						Enter a descriptive title for the evidence
					</div>
				</div>

				<div class="form-field">
					<label for="evidence-type" class="form-label">Type *</label>
					<select
						id="evidence-type"
						bind:value={newEvidence.type}
						class="form-select"
						required
						aria-describedby="evidence-type-help"
					>
						<option value="">Select type...</option>
						{#each EVIDENCE_TYPES as type}
							<option value={type}>{type}</option>
						{/each}
					</select>
					<div id="evidence-type-help" class="sr-only">
						Select the type of evidence
					</div>
				</div>
			</div>

			<div class="form-row">
				<div class="form-field">
					<label for="evidence-serial" class="form-label"
						>Serial Number</label
					>
					<input
						id="evidence-serial"
						type="text"
						bind:value={newEvidence.serial}
						class="form-input"
						aria-describedby="evidence-serial-help"
					/>
					<div id="evidence-serial-help" class="sr-only">
						Enter serial number if applicable
					</div>
				</div>
			</div>

			<div class="form-field">
				<label for="evidence-notes" class="form-label">Notes</label>
				<textarea
					id="evidence-notes"
					bind:value={newEvidence.notes}
					class="form-textarea"
					rows="3"
					aria-describedby="evidence-notes-help"
				></textarea>
				<div id="evidence-notes-help" class="sr-only">
					Additional notes about the evidence
				</div>
			</div>

			<div class="form-actions">
				<button
					type="submit"
					disabled={!formValid}
					class="save-btn"
					aria-describedby="save-btn-help"
				>
					{editingEvidence ? "Update Evidence" : "Add Evidence"}
				</button>
				<button
					type="button"
					on:click={toggleEvidenceForm}
					class="cancel-btn"
				>
					Cancel
				</button>
			</div>
			<div id="save-btn-help" class="sr-only">
				{formValid
					? "Form is valid and ready to submit"
					: "Please fill in required fields"}
			</div>
		</form>
	{/if}

	{#if report.evidence.length > 0}
		<div class="evidence-list" role="list" aria-label="Evidence items">
			{#each report.evidence as evidence}
				<article class="evidence-item" role="listitem">
					<div class="evidence-content">
						<div class="evidence-header-item">
							<h4 class="evidence-title">{evidence.title}</h4>
							<div class="evidence-type-badge">
								{evidence.type}
							</div>
						</div>

						{#if evidence.serial}
							<div class="evidence-detail">
								<span class="detail-label">Serial:</span>
								<span class="detail-value"
									>{evidence.serial}</span
								>
							</div>
						{/if}

						{#if evidence.notes}
							<div class="evidence-detail">
								<span class="detail-label">Notes:</span>
								<span class="detail-value"
									>{evidence.notes}</span
								>
							</div>
						{/if}

						{#if evidence.images && evidence.images.length > 0}
							<div
								class="evidence-images"
								role="group"
								aria-label="Evidence images"
							>
								<h5 class="images-title">
									Images ({evidence.images.length})
								</h5>
								<div class="images-grid">
									{#each evidence.images as image, imageIndex}
										<div class="image-item">
											<img
												src={image}
												alt="Evidence image {imageIndex +
													1}"
												class="evidence-image"
											/>
											<button
												type="button"
												on:click={() =>
													removeImage(
														evidence.id,
														imageIndex,
													)}
												class="remove-image-btn"
												aria-label="Remove image {imageIndex +
													1}"
											>
												×
											</button>
										</div>
									{/each}
								</div>
							</div>
						{/if}
					</div>

					<div class="evidence-actions">
						<button
							type="button"
							on:click={() => editEvidence(evidence)}
							class="edit-btn"
							aria-label="Edit evidence: {evidence.title}"
						>
							Edit
						</button>
						<button
							type="button"
							on:click={() => removeEvidence(evidence.id)}
							class="remove-btn"
							aria-label="Remove evidence: {evidence.title}"
						>
							Remove
						</button>
					</div>
				</article>
			{/each}
		</div>
	{:else}
		<p class="no-evidence">No evidence added</p>
	{/if}
</section>

<style>
	.evidence-manager {
		padding: 1rem;
		background: var(--surface-elevated);
		border-radius: 0.5rem;
		margin-bottom: 1rem;
	}

	.evidence-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1.5rem;
		gap: 1rem;
	}

	.section-title {
		font-size: 1.25rem;
		font-weight: 600;
		color: var(--text-primary);
		margin: 0;
	}

	.add-evidence-btn {
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

	.add-evidence-btn:hover {
		background: var(--primary-dark);
	}

	.evidence-form {
		padding: 1.5rem;
		background: var(--surface-color);
		border: 1px solid var(--border-color);
		border-radius: 0.5rem;
		margin-bottom: 1.5rem;
	}

	.form-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
		margin-bottom: 1rem;
	}

	.form-field {
		display: flex;
		flex-direction: column;
		gap: 0.375rem;
	}

	.form-label {
		font-size: 0.875rem;
		font-weight: 500;
		color: var(--text-primary);
	}

	.form-input,
	.form-textarea {
		padding: 0.5rem 0.75rem;
		border: 1px solid var(--border-color);
		border-radius: 0.375rem;
		background: var(--surface-elevated);
		color: var(--text-primary);
		font-size: 0.875rem;
	}

	.form-select {
		padding: 0.5rem 1.75rem 0.5rem 0.75rem;
		font-size: 0.875rem;
	}

	.form-input:focus,
	.form-select:focus,
	.form-textarea:focus {
		outline: 2px solid var(--primary-color);
		outline-offset: 2px;
		border-color: var(--primary-color);
	}

	.form-textarea {
		resize: vertical;
		min-height: 4rem;
	}

	.form-actions {
		display: flex;
		gap: 0.75rem;
		margin-top: 1.5rem;
	}

	.save-btn {
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

	.save-btn:hover:not(:disabled) {
		background: var(--primary-dark);
	}

	.save-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.cancel-btn {
		padding: 0.5rem 1rem;
		background: var(--surface-elevated);
		color: var(--text-primary);
		border: 1px solid var(--border-color);
		border-radius: 0.375rem;
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.cancel-btn:hover {
		background: var(--surface-hover);
	}

	.evidence-list {
		display: flex;
		flex-direction: column;
		gap: 1rem;
	}

	.evidence-item {
		display: flex;
		gap: 1rem;
		padding: 1rem;
		background: var(--surface-color);
		border: 1px solid var(--border-color);
		border-radius: 0.5rem;
	}

	.evidence-content {
		flex: 1;
		min-width: 0;
	}

	.evidence-header-item {
		display: flex;
		justify-content: space-between;
		align-items: flex-start;
		margin-bottom: 0.75rem;
		gap: 1rem;
	}

	.evidence-title {
		font-size: 1rem;
		font-weight: 600;
		color: var(--text-primary);
		margin: 0;
	}

	.evidence-type-badge {
		padding: 0.25rem 0.5rem;
		background: var(--accent-color);
		color: var(--accent-text);
		border-radius: 9999px;
		font-size: 0.75rem;
		font-weight: 500;
		flex-shrink: 0;
	}

	.evidence-detail {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 0.5rem;
		flex-wrap: wrap;
	}

	.detail-label {
		font-weight: 500;
		color: var(--text-secondary);
		flex-shrink: 0;
	}

	.detail-value {
		color: var(--text-primary);
		word-break: break-word;
	}

	.evidence-images {
		margin-top: 1rem;
	}

	.images-title {
		font-size: 0.875rem;
		font-weight: 500;
		color: var(--text-secondary);
		margin: 0 0 0.5rem 0;
	}

	.images-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(100px, 1fr));
		gap: 0.5rem;
	}

	.image-item {
		position: relative;
		aspect-ratio: 1;
		border-radius: 0.375rem;
		overflow: hidden;
		background: var(--surface-elevated);
	}

	.evidence-image {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.remove-image-btn {
		position: absolute;
		top: 0.25rem;
		right: 0.25rem;
		width: 1.5rem;
		height: 1.5rem;
		background: rgba(0, 0, 0, 0.7);
		color: white;
		border: none;
		border-radius: 50%;
		font-size: 0.875rem;
		font-weight: bold;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background-color 0.2s;
	}

	.remove-image-btn:hover {
		background: rgba(0, 0, 0, 0.9);
	}

	.evidence-actions {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		flex-shrink: 0;
	}

	.edit-btn,
	.remove-btn {
		padding: 0.375rem 0.75rem;
		border: none;
		border-radius: 0.375rem;
		font-size: 0.75rem;
		font-weight: 500;
		cursor: pointer;
		transition: background-color 0.2s;
	}

	.edit-btn {
		background: var(--accent-color);
		color: var(--accent-text);
	}

	.edit-btn:hover {
		background: var(--accent-dark);
	}

	.remove-btn {
		background: var(--danger-color);
		color: white;
	}

	.remove-btn:hover {
		background: var(--danger-dark);
	}

	.no-evidence {
		color: var(--text-secondary);
		font-style: italic;
		margin: 0;
		padding: 2rem;
		text-align: center;
		background: var(--surface-color);
		border: 1px dashed var(--border-color);
		border-radius: 0.375rem;
	}

	.sr-only {
		position: absolute;
		width: 1px;
		height: 1px;
		padding: 0;
		margin: -1px;
		overflow: hidden;
		clip: rect(0, 0, 0, 0);
		white-space: nowrap;
		border: 0;
	}

	@media (max-width: 768px) {
		.form-row {
			grid-template-columns: 1fr;
		}

		.evidence-header {
			flex-direction: column;
			align-items: stretch;
		}

		.evidence-item {
			flex-direction: column;
		}

		.evidence-actions {
			flex-direction: row;
			justify-content: flex-end;
		}
	}
</style>
