<script lang="ts">
	interface Props {
		label: string;
		isSelected: boolean;
		onClick: () => void;
	}

	let { label, isSelected, onClick }: Props = $props();
</script>

<button onclick={onClick} class:selected={isSelected}>
	{label}
</button>

<style>
	button {
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 8px;
		padding: 7px 16px;
		color: rgba(255, 255, 255, 0.5);
		font-size: 12px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.15s ease;
	}

	button:hover {
		background: rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.7);
	}

	button.selected {
		background: rgba(255, 255, 255, 0.08);
		border-color: rgba(255, 255, 255, 0.12);
		color: rgba(255, 255, 255, 0.9);
	}
</style>
