<script lang="ts">
	import type { ComponentId, MDTTab } from "../constants";
	import { MDT_TABS } from "../constants";
	import type { TabInstance } from "../services/tabService.svelte.ts";

	interface Props {
		instance: TabInstance;
		showCloseButton: boolean;
		onInstanceClick: (instanceId: ComponentId) => void;
		onInstanceClose: (instanceId: ComponentId, event: MouseEvent) => void;
	}

	let { instance, showCloseButton, onInstanceClick, onInstanceClose }: Props =
		$props();

	let tabIcon = $derived(
		MDT_TABS.find((t) => t.name === instance.currentTab)?.icon || "tab",
	);

	function handleInstanceClick(): void {
		onInstanceClick(instance.id);
	}

	function handleCloseClick(event: MouseEvent): void {
		event.stopPropagation();
		onInstanceClose(instance.id, event);
	}

	function handleCloseKeydown(event: KeyboardEvent): void {
		if (event.key === "Enter" || event.key === " ") {
			event.preventDefault();
			event.stopPropagation();
			// Create a synthetic mouse event for compatibility
			const syntheticEvent = new MouseEvent("click");
			onInstanceClose(instance.id, syntheticEvent);
		}
	}
</script>

<div class="instance-tab-container">
	<button
		class="instance-tab"
		class:active={instance.isActive}
		onclick={handleInstanceClick}
		aria-label="Switch to {instance.currentTab}"
	>
		<span class="tab-icon material-icons">{tabIcon}</span>
		<span class="tab-name">{instance.currentTab}</span>
		{#if showCloseButton}
			<span
				class="close-btn"
				onclick={handleCloseClick}
				onkeydown={handleCloseKeydown}
				aria-label="Close {instance.currentTab}"
				role="button"
				tabindex="0"
			>
				<span class="material-icons">close</span>
			</span>
		{/if}
	</button>
</div>

<style>
	.instance-tab-container {
		display: flex;
		align-items: center;
		background: transparent;
		border-radius: 0;
		border: none;
		border-bottom: 2px solid transparent;
		transition: all 0.15s ease;
		flex-shrink: 0;
	}

	.instance-tab-container:hover {
		background: rgba(255, 255, 255, 0.03);
	}

	.instance-tab-container:has(.active) {
		border-bottom-color: rgba(255, 255, 255, 0.5);
	}

	.instance-tab {
		display: flex;
		align-items: center;
		padding: 6px 10px;
		text-align: left;
		border-radius: 0;
		font-size: 12px;
		cursor: pointer;
		transition: all 0.15s ease;
		flex-shrink: 0;
		gap: 6px;
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.4);
		width: 100%;
	}

	.instance-tab.active {
		color: rgba(255, 255, 255, 0.9);
	}

	.tab-icon {
		font-size: 13px;
		pointer-events: none;
		opacity: 0.5;
	}

	.instance-tab.active .tab-icon {
		opacity: 0.85;
	}

	.tab-name {
		pointer-events: none;
		flex: 1;
		white-space: nowrap;
	}

	.close-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 14px;
		height: 14px;
		background: transparent;
		border: none;
		border-radius: 3px;
		cursor: pointer;
		font-size: 14px;
		line-height: 1;
		transition: all 0.15s ease;
		color: rgba(255, 255, 255, 0.4);
		opacity: 0;
	}

	.instance-tab-container:hover .close-btn {
		opacity: 1;
	}

	.close-btn:hover {
		background: rgba(239, 68, 68, 0.15);
		color: #fca5a5;
	}

	.close-btn .material-icons {
		font-size: 11px;
		line-height: 1;
	}
</style>
