<script lang="ts">
	import type { Snippet } from "svelte";

	interface Props {
		title: string;
		onAdd: () => void;
		children: Snippet;
	}

	let { title, onAdd, children }: Props = $props();
</script>

<div class="metadata-section">
	<div class="section-title">
		<span class="section-label">{title.toUpperCase()}</span>
		<button
			class="add-btn"
			onclick={onAdd}
			title="Add {title}"
			aria-label="Add {title}"
		>+ Add</button>
	</div>
	{@render children()}
</div>

<style>
	.metadata-section {
		padding-bottom: 12px;
		margin-bottom: 12px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.metadata-section:last-child {
		margin-bottom: 0;
		padding-bottom: 0;
		border-bottom: none;
	}

	.section-title {
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
</style>
