<script lang="ts">
	import type { OFFICER_TYPES, VICTIM_TYPES } from "../../constants";
	import type { Snippet } from "svelte";
	interface Props {
		id: string;
		fullName: string;
		secondaryInfo: string;
		notes?: string;
		type?: string;
		typeOptions?: typeof VICTIM_TYPES | typeof OFFICER_TYPES;
		onRemove: (id: string) => void;
		onUpdate: (id: string, field: string, value: any) => void;
		actions?: Snippet;
	}

	let {
		id,
		fullName,
		secondaryInfo,
		notes = "",
		type,
		typeOptions,
		onRemove,
		onUpdate,
		actions,
	}: Props = $props();
</script>

<div class="person-card">
	<div class="card-header">
		<div class="person-info">
			<span class="person-name">{fullName}</span>
			<span class="person-secondary">{secondaryInfo}</span>
		</div>
		<button
			class="remove-btn"
			onclick={() => onRemove(id)}
			aria-label="Remove person"
		>
			<svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor">
				<path
					d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"
				/>
			</svg>
		</button>
	</div>
	<div class="card-details">
		{#if type && typeOptions && typeOptions.length > 0}
			<select
				value={type}
				onchange={(e) => onUpdate(id, "type", e.currentTarget.value)}
				class="detail-select"
			>
				{#each typeOptions as option}
					<option value={option}>{option}</option>
				{/each}
			</select>
		{/if}
		{#if notes !== undefined}
			<textarea
				placeholder="Notes"
				value={notes}
				oninput={(e) => onUpdate(id, "notes", e.currentTarget.value)}
				class="notes-input"
			></textarea>
		{/if}
		<div class="card-actions">
			{@render actions?.()}
		</div>
	</div>
</div>

<style>
	.person-card {
		background: transparent;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		border-radius: 0;
		padding: 8px 0;
		margin-bottom: 0;
	}

	.person-card:last-child {
		border-bottom: none;
		margin-bottom: 0;
	}

	.person-card:hover .remove-btn {
		opacity: 1;
	}

	.card-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 5px;
		gap: 8px;
	}

	.person-info {
		display: flex;
		align-items: baseline;
		gap: 7px;
		flex: 1;
	}

	.person-name {
		font-weight: 500;
		color: rgba(255, 255, 255, 0.85);
		font-size: 12px;
	}

	.person-secondary {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.3);
	}

	.remove-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 14px;
		height: 14px;
		background: rgba(239, 68, 68, 0.12);
		border: none;
		border-radius: 50%;
		color: rgba(255, 255, 255, 0.5);
		cursor: pointer;
		flex-shrink: 0;
		opacity: 0;
		transition: opacity 0.1s;
	}

	.remove-btn:hover {
		background: rgba(239, 68, 68, 0.25);
	}

	.card-details {
		display: flex;
		flex-direction: column;
		gap: 5px;
	}

	.card-actions {
		display: flex;
		flex-wrap: wrap;
		gap: 5px;
		align-items: center;
	}

	.card-actions :global(.action-btn) {
		padding: 3px 7px;
		border-radius: 3px;
		border: 1px solid rgba(255, 255, 255, 0.05);
		background: transparent;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		cursor: pointer;
		transition: all 0.1s;
	}

	.card-actions :global(.action-btn:hover) {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.6);
	}

	.card-actions :global(.action-btn.primary) {
		background: rgba(var(--accent-rgb), 0.06);
		border-color: rgba(var(--accent-rgb), 0.1);
		color: rgba(var(--accent-text-rgb), 0.7);
	}

	.card-actions :global(.action-btn.primary:hover) {
		background: rgba(var(--accent-rgb), 0.1);
	}

	.card-actions :global(.action-btn.danger) {
		background: rgba(239, 68, 68, 0.06);
		border-color: rgba(239, 68, 68, 0.1);
		color: rgba(252, 165, 165, 0.7);
	}

	.card-actions :global(.action-btn.danger:hover) {
		background: rgba(239, 68, 68, 0.1);
	}

	.card-actions :global(.action-btn:disabled) {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.detail-select {
		padding: 3px 22px 3px 6px;
		font-size: 10px;
		font-weight: 500;
		border-radius: 3px;
	}

	.notes-input {
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.04);
		border-radius: 3px;
		padding: 4px 7px;
		color: rgba(255, 255, 255, 0.6);
		font-size: 10px;
		min-height: 32px;
		resize: vertical;
		font-family: inherit;
	}

	.notes-input:focus {
		outline: none;
		border-color: rgba(255, 255, 255, 0.08);
	}

	.notes-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}
</style>
