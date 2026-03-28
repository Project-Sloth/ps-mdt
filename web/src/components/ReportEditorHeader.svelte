<script lang="ts">
	import type { CollabEditor } from "../services/collabService.svelte";

	let {
		reportId,
		onClose,
		onSave,
		onDelete,
		isSaving = false,
		isLoading = false,
		collabEditors = [],
		myColor = "",
		myName = "",
		collabActive = false,
	}: {
		reportId: string | null;
		onClose: () => void;
		onSave: () => void;
		onDelete?: () => void;
		isSaving?: boolean;
		isLoading?: boolean;
		collabEditors?: CollabEditor[];
		myColor?: string;
		myName?: string;
		collabActive?: boolean;
	} = $props();

	let showDeleteConfirm = $state(false);
	let hoveredAvatar = $state<string | null>(null);

	function getInitials(name: string): string {
		const parts = name.trim().split(/\s+/);
		if (parts.length >= 2) {
			return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
		}
		return name.substring(0, 2).toUpperCase();
	}
</script>

<div class="editor-header">
	<span class="report-title">
		{reportId ? "Edit Report" : "Create New Report"}
	</span>

	{#if collabActive}
		<div class="collab-section">
			<div class="collab-live-badge" class:has-others={collabEditors.length > 0}>
				<span class="live-dot"></span>
				<span class="live-text">{collabEditors.length > 0 ? 'Live Editing' : 'Connected'}</span>
			</div>
			<div class="collab-avatars">
				{#if myName && myColor}
					<div
						class="collab-avatar me"
						style="background: {myColor};"
						onmouseenter={() => hoveredAvatar = '__me__'}
						onmouseleave={() => hoveredAvatar = null}
					>
						You
						{#if hoveredAvatar === '__me__'}
							<div class="avatar-tooltip">{myName}</div>
						{/if}
					</div>
				{/if}
				{#each collabEditors as editor}
					<div
						class="collab-avatar"
						style="background: {editor.color};"
						onmouseenter={() => hoveredAvatar = editor.name}
						onmouseleave={() => hoveredAvatar = null}
					>
						{getInitials(editor.name)}
						{#if hoveredAvatar === editor.name}
							<div class="avatar-tooltip">{editor.name}</div>
						{/if}
					</div>
				{/each}
			</div>
		</div>
	{/if}

	<div class="header-actions">
		{#if reportId && onDelete}
			{#if showDeleteConfirm}
				<span class="delete-confirm-group">
					<span class="delete-confirm-text">Delete?</span>
					<button
						class="action-btn delete-confirm-btn"
						onclick={() => { showDeleteConfirm = false; onDelete(); }}
						type="button"
					>
						Yes
					</button>
					<button
						class="action-btn cancel-btn"
						onclick={() => (showDeleteConfirm = false)}
						type="button"
					>
						No
					</button>
				</span>
			{:else}
				<button
					class="action-btn delete-btn"
					onclick={() => (showDeleteConfirm = true)}
					disabled={isSaving || isLoading}
					type="button"
					aria-label="Delete report"
				>
					Delete
				</button>
			{/if}
		{/if}
		<button
			class="action-btn cancel-btn"
			onclick={onClose}
			disabled={isSaving}
			type="button"
			aria-label="Cancel report editing"
		>
			Cancel
		</button>
		<button
			class="action-btn save-btn"
			onclick={onSave}
			disabled={isSaving || isLoading}
			type="button"
			aria-label={isSaving ? "Saving report" : "Save report"}
		>
			{isSaving ? "Saving..." : "Save Report"}
		</button>
	</div>
</div>

<style>
	.editor-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0 16px;
		height: 40px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.report-title {
		color: rgba(255, 255, 255, 0.7);
		font-size: 12px;
		font-weight: 500;
	}

	.collab-section {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-left: auto;
		margin-right: 12px;
	}

	.collab-live-badge {
		display: flex;
		align-items: center;
		gap: 5px;
		padding: 3px 8px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 10px;
	}

	.live-dot {
		width: 6px;
		height: 6px;
		border-radius: 50%;
		background: rgba(255, 255, 255, 0.35);
		animation: pulse 2s ease-in-out infinite;
	}

	.live-text {
		font-size: 9px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.4);
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.collab-avatars {
		display: flex;
		gap: 0;
	}

	.collab-avatar {
		width: 24px;
		height: 24px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 8px;
		font-weight: 700;
		color: white;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
		border: 2px solid var(--dark-bg, #111);
		margin-left: -6px;
		cursor: default;
		position: relative;
	}

	.collab-avatar:first-child {
		margin-left: 0;
	}

	.collab-avatar.me {
		box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.2);
		width: auto;
		border-radius: 12px;
		padding: 0 8px;
	}

	.avatar-tooltip {
		position: absolute;
		top: calc(100% + 6px);
		left: 50%;
		transform: translateX(-50%);
		background: rgba(0, 0, 0, 0.95);
		color: rgba(255, 255, 255, 0.9);
		font-size: 10px;
		font-weight: 500;
		padding: 4px 10px;
		border-radius: 4px;
		white-space: nowrap;
		pointer-events: none;
		z-index: 9999;
		border: 1px solid rgba(255, 255, 255, 0.12);
	}

	.avatar-tooltip::before {
		content: '';
		position: absolute;
		bottom: 100%;
		left: 50%;
		transform: translateX(-50%);
		border: 4px solid transparent;
		border-bottom-color: rgba(0, 0, 0, 0.95);
	}

	.collab-live-badge.has-others {
		background: rgba(34, 197, 94, 0.08);
		border-color: rgba(34, 197, 94, 0.15);
	}

	.collab-live-badge.has-others .live-text {
		color: rgba(34, 197, 94, 0.8);
	}

	.collab-live-badge.has-others .live-dot {
		background: #22c55e;
	}

	@keyframes pulse {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.4; }
	}

	.header-actions {
		display: flex;
		gap: 5px;
	}

	.action-btn {
		display: inline-flex;
		align-items: center;
		padding: 4px 10px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		white-space: nowrap;
		transition: all 0.1s;
	}

	.cancel-btn {
		background: transparent;
		color: rgba(255, 255, 255, 0.3);
		border: 1px solid rgba(255, 255, 255, 0.06);
	}

	.cancel-btn:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.6);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.save-btn {
		background: rgba(var(--accent-rgb), 0.08);
		color: rgba(var(--accent-text-rgb), 0.8);
		border: 1px solid rgba(var(--accent-rgb), 0.12);
	}

	.save-btn:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.14);
	}

	.save-btn:disabled,
	.cancel-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.delete-btn {
		background: transparent;
		color: rgba(239, 68, 68, 0.5);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	.delete-btn:hover:not(:disabled) {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(252, 165, 165, 0.8);
	}

	.delete-confirm-group {
		display: flex;
		align-items: center;
		gap: 4px;
	}

	.delete-confirm-text {
		font-size: 10px;
		color: rgba(252, 165, 165, 0.8);
		font-weight: 500;
		margin-right: 2px;
	}

	.delete-confirm-btn {
		background: rgba(239, 68, 68, 0.1);
		color: rgba(252, 165, 165, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.2);
	}

	.delete-confirm-btn:hover {
		background: rgba(239, 68, 68, 0.2);
	}

	@media (max-width: 640px) {
		.editor-header {
			flex-direction: column;
			height: auto;
			gap: 8px;
			padding: 8px 16px;
			align-items: stretch;
		}

		.header-actions {
			justify-content: stretch;
		}
	}
</style>
