<script lang="ts">
	import type { ComponentId } from "../constants";
	import { COMPONENT_DISPLAY_NAMES } from "../constants";

	interface Props {
		componentId: ComponentId;
		message?: string;
	}

	let { componentId, message }: Props = $props();

	/**
	 * Gets the display name for the component.
	 */
	function getDisplayName(): string {
		return COMPONENT_DISPLAY_NAMES[componentId] || componentId;
	}
</script>

<div class="placeholder-content">
	<h2>{getDisplayName()}</h2>
	{#if message}
		<p>{message}</p>
	{/if}
</div>

<style>
	.placeholder-content {
		padding: 40px;
		text-align: center;
	}

	.placeholder-content h2 {
		color: var(--primary-text);
		margin-bottom: 16px;
		font-size: 24px;
		font-weight: 600;
	}

	.placeholder-content p {
		color: var(--secondary-text);
		margin-bottom: 8px;
		font-size: 16px;
	}
</style>
