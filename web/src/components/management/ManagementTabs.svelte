<script lang="ts">
	import { MANAGEMENT_TABS } from "@/constants/management";

	type View = "Activity" | "Bulletins" | "Permissions";

	interface Props {
		currentView: View;
		onViewChange: (view: View) => void;
	}

	let { currentView, onViewChange }: Props = $props();
</script>

<div class="viewSelector">
	{#each MANAGEMENT_TABS as tab}
		<button
			onclick={() => onViewChange(tab)}
			class:selected={currentView === tab}
		>
			{tab}
		</button>
	{/each}
</div>

<style>
	.viewSelector {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 1rem;
	}

	button {
		padding: 0.5rem 1rem;
		border: 1px solid #ccc;
		background: #f8f9fa;
		color: #333;
		border-radius: 4px;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	button:hover {
		background: #e9ecef;
	}

	button.selected {
		background: #007bff;
		color: white;
		border-color: #007bff;
	}

	button.selected:hover {
		background: #0056b3;
	}
</style>
