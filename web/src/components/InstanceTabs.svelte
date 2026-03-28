<script lang="ts">
	import type { ComponentId, MDTTab } from "../constants";
	import InstanceTabButton from "./InstanceTabButton.svelte";
	import type {
		TabInstance,
		createTabService,
	} from "../services/tabService.svelte.ts";
	import { globalNotifications } from "../services/notificationService.svelte";

	const MAX_TABS = 10;

	interface Props {
		tabService: ReturnType<typeof createTabService>;
		onInstanceClick?: (instanceName: string) => void;
	}

	let { tabService, onInstanceClick }: Props = $props();

	let canAddTab = $derived(tabService.instances.length < MAX_TABS);

	function handleInstanceClick(instanceId: ComponentId): void {
		tabService.setActiveInstance(instanceId);
	}

	function handleInstanceClose(instanceId: ComponentId): void {
		tabService.removeInstance(instanceId);
	}

	function handleAddNewInstance(): void {
		if (!canAddTab) {
			globalNotifications.error(`Maximum ${MAX_TABS} tabs allowed`);
			return;
		}
		const instanceNumber = tabService.instances.length + 1;
		const instanceName = `Instance ${instanceNumber}`;
		const instanceId = `instance-${Date.now()}` as ComponentId;
		tabService.addInstance(instanceId, instanceName);
	}
</script>

<div class="instance-tabs-bar">
	<div class="tabs-area">
		{#each tabService.instances as instance (instance.id)}
			<InstanceTabButton
				{instance}
				showCloseButton={tabService.instances.length > 1}
				onInstanceClick={handleInstanceClick}
				onInstanceClose={handleInstanceClose}
			/>
		{/each}

		{#if canAddTab}
			<button
				class="add-instance-btn"
				onclick={handleAddNewInstance}
				aria-label="Add new instance"
			>
				<span class="material-icons">add</span>
			</button>
		{/if}
	</div>

	{#if globalNotifications.notifications.length > 0}
		<div class="notifications-area">
			{#each globalNotifications.notifications as notif (notif.id)}
				<div class="notification {notif.type}" role="status">
					{#if notif.type === "success"}
						<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
					{:else if notif.type === "error"}
						<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>
					{:else}
						<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>
					{/if}
					<span class="notif-text">{notif.text}</span>
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.instance-tabs-bar {
		display: flex;
		align-items: center;
		padding: 6px 16px;
		width: 100%;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		gap: 8px;
		min-height: 36px;
	}

	.tabs-area {
		display: flex;
		gap: 4px;
		align-items: center;
		overflow-x: auto;
		flex-shrink: 0;
	}

	.tabs-area::-webkit-scrollbar {
		height: 3px;
	}

	.tabs-area::-webkit-scrollbar-track {
		background: transparent;
	}

	.tabs-area::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.08);
		border-radius: 2px;
	}

	.notifications-area {
		display: flex;
		gap: 6px;
		align-items: center;
		margin-left: auto;
		flex-shrink: 0;
		overflow: hidden;
	}

	.notification {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		padding: 3px 10px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 500;
		white-space: nowrap;
		animation: notif-in 0.2s ease-out;
	}

	.notification.success {
		background: rgba(16, 185, 129, 0.1);
		border: 1px solid rgba(16, 185, 129, 0.2);
		color: #6ee7b7;
	}

	.notification.error {
		background: rgba(239, 68, 68, 0.1);
		border: 1px solid rgba(239, 68, 68, 0.2);
		color: #fca5a5;
	}

	.notification.info {
		background: rgba(var(--accent-rgb), 0.1);
		border: 1px solid rgba(var(--accent-rgb), 0.2);
		color: #93c5fd;
	}

	.notif-text {
		max-width: 250px;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.add-instance-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 24px;
		height: 24px;
		border-radius: 4px;
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.45);
		cursor: pointer;
		transition: all 0.15s ease;
		flex-shrink: 0;
		margin-left: 4px;
	}

	.add-instance-btn:hover {
		background: rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.6);
	}

	.add-instance-btn .material-icons {
		font-size: 16px;
	}

	@keyframes notif-in {
		from {
			opacity: 0;
			transform: translateX(10px);
		}
		to {
			opacity: 1;
			transform: translateX(0);
		}
	}
</style>
