<script lang="ts">
	import type { CollabEditor } from "../../services/collabService.svelte";

	interface Props {
		editors: CollabEditor[];
		myColor: string;
	}

	let { editors, myColor }: Props = $props();

	function getInitials(name: string): string {
		const parts = name.trim().split(/\s+/);
		if (parts.length >= 2) {
			return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
		}
		return name.substring(0, 2).toUpperCase();
	}
</script>

{#if editors.length > 0}
	<div class="collab-bar">
		<div class="collab-indicator">
			<div class="pulse-dot" style="background: {myColor};"></div>
			<span class="collab-label">Live Editing</span>
		</div>
		<div class="collab-editors">
			{#each editors as editor}
				<div class="editor-avatar" style="background: {editor.color}; border-color: {editor.color};" title="{editor.name} is editing">
					<span class="editor-initials">{getInitials(editor.name)}</span>
					<div class="editor-active-dot"></div>
				</div>
			{/each}
		</div>
		<span class="collab-count">{editors.length} other{editors.length !== 1 ? 's' : ''} editing</span>
	</div>
{/if}

<style>
	.collab-bar {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 6px 14px;
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 8px;
		margin-bottom: 10px;
	}

	.collab-indicator {
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.pulse-dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		animation: pulse 2s ease-in-out infinite;
	}

	.collab-label {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.5);
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.collab-editors {
		display: flex;
		gap: 4px;
	}

	.editor-avatar {
		width: 26px;
		height: 26px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		position: relative;
		border: 2px solid;
		cursor: default;
	}

	.editor-initials {
		font-size: 9px;
		font-weight: 700;
		color: white;
		text-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
	}

	.editor-active-dot {
		position: absolute;
		bottom: -1px;
		right: -1px;
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: #22c55e;
		border: 2px solid var(--dark-bg, #111);
	}

	.collab-count {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.35);
		margin-left: auto;
	}

	@keyframes pulse {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.4; }
	}
</style>
