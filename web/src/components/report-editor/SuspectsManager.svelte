<script lang="ts">
	import type { Suspect } from "../../interfaces/IReportEditor";
	import PersonnelSection from "./PersonnelSection.svelte";
	import PersonnelCard from "./PersonnelCard.svelte";

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
				<span class="warning-text">No mugshot on file for <strong>{suspect.fullName}</strong>.</span>
				<div class="warning-actions">
					{#if onUploadPhoto}
						<button
							class="warning-action-btn"
							onclick={() => onUploadPhoto(suspect)}
							disabled={!suspect.citizenid}
							type="button"
							title="Upload a photo"
						>
							<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
							Upload
						</button>
					{/if}
					{#if onTakeMugshot}
						<button
							class="warning-action-btn"
							onclick={() => onTakeMugshot(suspect)}
							disabled={!suspect.citizenid}
							type="button"
							title="Take mugshot (suspect must be online)"
						>
							<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z"/><circle cx="12" cy="13" r="4"/></svg>
							Take Mugshot
						</button>
					{/if}
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
</style>
