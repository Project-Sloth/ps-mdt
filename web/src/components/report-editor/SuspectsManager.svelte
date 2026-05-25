<script lang="ts">
	import type { Suspect } from "../../interfaces/IReportEditor";
	import PersonnelSection from "./PersonnelSection.svelte";
	import PersonnelCard from "./PersonnelCard.svelte";
	import { globalNotifications } from "../../services/notificationService.svelte";
	import { fetchNui } from "../../utils/fetchNui";
	import { NUI_EVENTS } from "../../constants/nuiEvents";

	let photoModalOpen = $state(false);
	let photoUrlInput = $state("");
	let photoSaving = $state(false);
	let photoTargetSuspect: Suspect | null = $state(null);

	function openPhotoModal(suspect: Suspect) {
		photoTargetSuspect = suspect;
		photoUrlInput = "";
		photoModalOpen = true;
	}

	function closePhotoModal() {
		photoModalOpen = false;
		photoUrlInput = "";
		photoTargetSuspect = null;
	}


	async function confirmPhotoUrl() {
		const url = photoUrlInput.trim();
		if (!url || !photoTargetSuspect || photoSaving) return;
		photoSaving = true;
		try {
			const result = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.CITIZEN.UPLOAD_SUSPECT_PHOTO,
				{ citizenid: photoTargetSuspect.citizenid, image: url },
				{ success: true, message: "Photo updated" },
			);
			if (result.success) {
				onUpdate({ ...photoTargetSuspect, profileImage: url });
				globalNotifications.success(result.message || "Photo updated successfully");
				closePhotoModal();
			} else {
				globalNotifications.error(result.message || "Failed to update photo");
			}
		} catch {
			globalNotifications.error("Failed to update photo");
		} finally {
			photoSaving = false;
		}
	}

	interface Props {
		suspects: Suspect[];
		onAdd: () => void;
		onRemove: (id: string) => void;
		onUpdate: (suspect: Suspect) => void;
		onIssueWarrant: (suspect: Suspect) => void;
		onIssueBenchWarrant?: (suspect: Suspect) => void;
		onIssueBolo?: (suspect: Suspect) => void;
		onTakeMugshot?: (suspect: Suspect) => void;
		onUploadPhoto?: (suspect: Suspect) => void;
		onAddFingerprint?: (suspect: Suspect) => void;
	}

	let {
		suspects,
		onAdd,
		onRemove,
		onUpdate,
		onIssueWarrant,
		onIssueBenchWarrant,
		onIssueBolo,
		onTakeMugshot,
		onUploadPhoto,
		onAddFingerprint,
	}: Props = $props();

	function updateSuspect(id: string, field: string, value: any) {
		const suspect = suspects.find((s) => s.id === id);
		if (suspect) {
			const updated = { ...suspect, [field]: value };
			onUpdate(updated);
		}
	}
</script>

<PersonnelSection title="Suspects" {onAdd}>
	{#each suspects as suspect}
		{#if !suspect.profileImage}
			<div class="image-warning">
				<svg class="warning-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
				<span class="warning-text">No Picture on file for <strong>{suspect.fullName}</strong>.</span>
				<div class="warning-actions">
					<button
						class="warning-action-btn"
						onclick={() => openPhotoModal(suspect)}
						disabled={!suspect.citizenid}
						type="button"
						title="Upload a photo"
					>
						<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
						Upload a photo
					</button>
				</div>
			</div>
		{/if}
		{#if !suspect.fingerprint}
			<div class="image-warning fingerprint-warning">
				<svg class="warning-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
				<span class="warning-text">No fingerprint on file for <strong>{suspect.fullName}</strong>.</span>
				<div class="warning-actions">
					{#if onAddFingerprint}
						<button
							class="warning-action-btn"
							onclick={() => onAddFingerprint(suspect)}
							disabled={!suspect.citizenid}
							type="button"
							title="Add fingerprint to suspect's record"
						>
							<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 11c0 3.517-1.009 6.799-2.753 9.571m-3.44-2.04l.054-.09A13.916 13.916 0 008 11a4 4 0 118 0c0 1.017-.07 2.019-.203 3m-2.118 6.844A21.88 21.88 0 0015.171 17m3.839-1.132c.645-2.266.99-4.659.99-7.132A8 8 0 008 4.07M3 15.364c.64-1.319 1-2.8 1-4.364 0-1.457.39-2.823 1.07-4"/></svg>
							Add Fingerprint
						</button>
					{/if}
				</div>
			</div>
		{/if}
		<PersonnelCard
			id={suspect.id}
			fullName={suspect.fullName}
			secondaryInfo={`ID: ${suspect.citizenid}`}
			notes={suspect.notes}
			{onRemove}
			onUpdate={updateSuspect}
		>
			{#snippet actions()}
				<div class="suspect-actions-row">
					<button
						class="action-btn primary"
						onclick={() => onIssueWarrant(suspect)}
						disabled={!suspect.citizenid}
						type="button"
						aria-label="Issue warrant"
					>
						Issue Warrant
					</button>
					{#if onIssueBenchWarrant}
						<button
							class="action-btn bench-warrant"
							onclick={() => onIssueBenchWarrant(suspect)}
							disabled={!suspect.citizenid}
							type="button"
							aria-label="Issue bench warrant"
						>
							Issue Bench Warrant
						</button>
					{/if}
					{#if onIssueBolo}
						<button
							class="action-btn bolo"
							onclick={() => onIssueBolo(suspect)}
							disabled={!suspect.citizenid}
							type="button"
							aria-label="Issue BOLO"
						>
							Issue BOLO
						</button>
					{/if}
				</div>
			{/snippet}
		</PersonnelCard>
	{/each}

	{#if photoModalOpen}
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div class="modal-overlay" onclick={(e) => { if (e.target === e.currentTarget) closePhotoModal(); }}>
			<div class="modal-card photo-modal" onclick={(e) => e.stopPropagation()} role="dialog">
				<div class="modal-header">
					<h3>Set Profile Photo</h3>
					<button class="modal-close" onclick={closePhotoModal}>
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
					</button>
				</div>
				<div class="modal-body photo-modal-body">
					<div class="photo-form-group">
						<span class="photo-label">Image URL</span>
						<input
							class="photo-input"
							type="url"
							placeholder="https://example.com/photo.jpg"
							bind:value={photoUrlInput}
							onkeydown={(e) => { if (e.key === 'Enter') confirmPhotoUrl(); if (e.key === 'Escape') closePhotoModal(); }}
						/>
					</div>
				</div>
				<div class="modal-footer-row">
					<button class="photo-cancel-btn" onclick={closePhotoModal} disabled={photoSaving}>Cancel</button>
					<button class="photo-confirm-btn" onclick={confirmPhotoUrl} disabled={photoSaving || !photoUrlInput.trim()}>
						{photoSaving ? "Saving…" : "Set Photo"}
					</button>
				</div>
			</div>
		</div>
	{/if}
</PersonnelSection>

<style>
	.image-warning {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 6px 10px;
		margin-bottom: 4px;
		background: rgba(245, 158, 11, 0.08);
		border: 1px solid rgba(245, 158, 11, 0.15);
		border-radius: 5px;
		font-size: 10px;
		color: rgba(251, 191, 36, 0.85);
		line-height: 1.3;
		flex-wrap: wrap;
	}

	.warning-icon {
		flex-shrink: 0;
		color: rgba(251, 191, 36, 0.7);
	}

	.image-warning strong {
		font-weight: 600;
	}

	.warning-text {
		flex: 1;
		min-width: 0;
	}

	.warning-actions {
		display: flex;
		gap: 4px;
		margin-left: auto;
	}

	.warning-action-btn {
		display: inline-flex;
		align-items: center;
		gap: 3px;
		padding: 2px 7px;
		border-radius: 3px;
		border: 1px solid rgba(251, 191, 36, 0.25);
		background: rgba(251, 191, 36, 0.1);
		color: rgba(251, 191, 36, 0.9);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		white-space: nowrap;
		transition: all 0.12s ease;
	}

	.warning-action-btn:hover:not(:disabled) {
		background: rgba(251, 191, 36, 0.2);
		border-color: rgba(251, 191, 36, 0.4);
	}

	.warning-action-btn:disabled {
		opacity: 0.35;
		cursor: default;
	}

	.warning-action-btn svg {
		flex-shrink: 0;
	}

	.suspect-actions-row {
		display: flex;
		flex-wrap: wrap;
		gap: 4px;
	}

	.suspect-actions-row :global(.action-btn.bench-warrant) {
		background: rgba(239, 68, 68, 0.08);
		border-color: rgba(239, 68, 68, 0.15);
		color: rgba(252, 129, 129, 0.85);
	}

	.suspect-actions-row :global(.action-btn.bench-warrant:hover) {
		background: rgba(239, 68, 68, 0.15);
	}

	.suspect-actions-row :global(.action-btn.bolo) {
		background: rgba(245, 158, 11, 0.08);
		border-color: rgba(245, 158, 11, 0.15);
		color: rgba(251, 191, 36, 0.85);
	}

	.suspect-actions-row :global(.action-btn.bolo:hover) {
		background: rgba(245, 158, 11, 0.15);
	}

	.modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.6);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 9999;
		backdrop-filter: blur(2px);
	}

	.modal-card {
		background: var(--dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 8px;
		width: 360px;
		max-height: 80%;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
	}

	.photo-modal {
		width: min(380px, 92vw);
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 10px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
	}

	.modal-header h3 {
		margin: 0;
		font-size: 12px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}

	.modal-close {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		color: rgba(255, 255, 255, 0.3);
		cursor: pointer;
		padding: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: all 0.1s;
	}

	.modal-close:hover {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.modal-body {
		padding: 0;
	}

	.photo-modal-body {
		padding: 14px 16px;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.photo-form-group {
		display: flex;
		align-items: center;
		flex-direction: column;
		gap: 4px;
	}

	.photo-label {
		color: rgba(255, 255, 255, 0.35);
		font-size: 9px;
		font-weight: 600;
		margin-top: 5px;
		text-transform: uppercase;
		letter-spacing: 0.6px;
	}

	.photo-input {
		display: flex;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.8);
		font-size: 11px;
		transition: border-color 0.1s;
		font-family: inherit;
		width: 90%;
	}

	.photo-input:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.1);
	}

	.photo-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.modal-footer-row {
		display: flex;
		justify-content: flex-end;
		gap: 6px;
		padding: 10px 16px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}

	.photo-cancel-btn {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.photo-cancel-btn:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.photo-cancel-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.photo-confirm-btn {
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

	.photo-confirm-btn:hover:not(:disabled) {
		background: rgba(16, 185, 129, 0.12);
		color: rgba(110, 231, 183, 0.9);
	}

	.photo-confirm-btn:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}
</style>
