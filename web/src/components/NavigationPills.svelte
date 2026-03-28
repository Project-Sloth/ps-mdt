<script lang="ts">
	import { MDT_TABS, NAV_GROUPS, DOJ_NAV_GROUPS, getTabsForJob, type MDTTab, type ComponentId } from "../constants";
	import type { createTabService } from "../services/tabService.svelte";
	import type { JobType } from "../interfaces/IUser";
	import type { AuthService } from "../services/authService.svelte";

	interface Props {
		tabService: ReturnType<typeof createTabService>;
		jobType?: JobType;
		authService?: AuthService;
	}

	let { tabService, jobType = 'leo', authService }: Props = $props();

	function isTabHidden(tabName: string): boolean {
		if (!authService) return false;
		const key = `tab_hidden_${tabName.toLowerCase()}`;
		return authService.hasRawPermission(key);
	}

	let visibleTabs = $derived(getTabsForJob(jobType).filter(t => !isTabHidden(t.name)));
	let visibleTabNames = $derived(new Set(visibleTabs.map(t => t.name)));

	let collapsed = $state(false);
	let collapsedGroups = $state<Record<string, boolean>>({});

	function collapseSidebar() {
		collapsed = !collapsed;
	}

	function toggleGroup(groupId: string) {
		collapsedGroups[groupId] = !collapsedGroups[groupId];
	}

	function handleTabClick(tab: { name: string; icon: string }) {
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, tab.name as MDTTab);
		} else {
			tabService.setActiveTab(tab.name as MDTTab);
		}
	}

	function getTabData(tabName: string) {
		return MDT_TABS.find(t => t.name === tabName);
	}

	// Compute visible groups: filter out groups with no visible tabs
	let navGroups = $derived(jobType === 'doj' ? DOJ_NAV_GROUPS : NAV_GROUPS);

	let visibleGroups = $derived.by(() => {
		return navGroups
			.map(group => ({
				...group,
				visibleTabs: group.tabs.filter(t => visibleTabNames.has(t)),
			}))
			.filter(g => g.visibleTabs.length > 0);
	});

	let activeTab = $derived(tabService.getActiveInstanceTab());
	$effect(() => {
		if (!activeTab) return;
		if (!visibleTabNames.has(activeTab)) {
			const inst = tabService.getActiveInstance();
			if (inst) tabService.setInstanceTab(inst.id, "Dashboard");
			return;
		}
		for (const group of navGroups) {
			if (group.label && group.tabs.includes(activeTab)) {
				if (collapsedGroups[group.id]) {
					collapsedGroups[group.id] = false;
				}
				break;
			}
		}
	});

	function isGroupCollapsed(groupId: string): boolean {
		return collapsedGroups[groupId] ?? false;
	}
</script>

<div class="nav-pills" class:collapsed>
	{#each visibleGroups as group}
		{#if group.label && !collapsed}
			<!-- Collapsible group with header -->
			<div class="nav-group">
				<button class="nav-group-header" onclick={() => toggleGroup(group.id)}>
					<span class="material-icons nav-group-icon">{group.icon}</span>
					<span class="nav-group-label">{group.label}</span>
					<span class="material-icons nav-group-chevron" class:rotated={!isGroupCollapsed(group.id)}>expand_more</span>
				</button>
				{#if !isGroupCollapsed(group.id)}
					<div class="nav-group-items">
						{#each group.visibleTabs as tabName}
							{@const tab = getTabData(tabName)}
							{#if tab}
								<button
									class="nav-pill grouped"
									class:active={activeTab === tab.name}
									onclick={() => handleTabClick(tab)}
								>
									<span class="material-icons nav-icon">{tab.icon}</span>
									<span>{tab.name}</span>
								</button>
							{/if}
						{/each}
					</div>
				{/if}
			</div>
		{:else}
			<!-- Ungrouped items (Dashboard, Preferences, Settings) or collapsed sidebar -->
			{#each group.visibleTabs as tabName}
				{@const tab = getTabData(tabName)}
				{#if tab}
					<button
						class="nav-pill"
						class:active={activeTab === tab.name}
						onclick={() => handleTabClick(tab)}
					>
						<span class="material-icons nav-icon">{tab.icon}</span>
						<span class:hide={collapsed}>{tab.name}</span>
					</button>
				{/if}
			{/each}
		{/if}
	{/each}

	<button class="nav-pill collapse-button" onclick={collapseSidebar}>
		<span class="material-icons nav-icon"
			>{collapsed
				? "keyboard_double_arrow_right"
				: "keyboard_double_arrow_left"}</span
		>
		{collapsed ? "" : "Collapse"}
	</button>
</div>

<style>
	.hide {
		display: none;
	}

	.nav-pills {
		display: flex;
		flex-direction: column;
		height: 100%;
		overflow-y: auto;
		overflow-x: hidden;
		scrollbar-width: none;
		padding-top: 2px;
	}

	.nav-pills::-webkit-scrollbar {
		display: none;
	}

	.nav-pill {
		padding: 10px 24px;
		width: 100%;
		font-size: 13px;
		cursor: pointer;
		transition: all 0.15s ease;
		flex-shrink: 0;
		gap: 8px;
		text-align: left;
		display: flex;
		align-items: center;
		background: none;
		border: none;
		color: inherit;
	}

	.nav-pill.grouped {
		padding-left: 38px;
		font-size: 12px;
	}

	.nav-icon {
		font-size: 20px;
		flex-shrink: 0;
	}

	.nav-pill:hover {
		background: var(--btn-secondary-hover);
	}

	.nav-pill.active {
		background: var(--btn-secondary-active);
		color: var(--primary-text);
	}

	.nav-pill.active:hover {
		background: var(--active-bg);
	}

	:global([data-job-type="ems"]) .nav-pill:hover {
		background: rgba(220, 50, 50, 0.06);
	}

	:global([data-job-type="ems"]) .nav-pill.active {
		background: rgba(220, 50, 50, 0.1);
		color: rgba(252, 165, 165, 0.95);
		border-right: 2px solid rgba(220, 50, 50, 0.35);
	}

	:global([data-job-type="ems"]) .nav-pill.active:hover {
		background: rgba(220, 50, 50, 0.14);
	}

	:global([data-job-type="doj"]) .nav-pill:hover {
		background: rgba(30, 58, 138, 0.06);
	}

	:global([data-job-type="doj"]) .nav-pill.active {
		background: rgba(30, 58, 138, 0.1);
		color: rgba(196, 181, 125, 0.95);
		border-right: 2px solid rgba(180, 150, 60, 0.35);
	}

	:global([data-job-type="doj"]) .nav-pill.active:hover {
		background: rgba(30, 58, 138, 0.14);
	}

	/* ===== GROUP ===== */
	.nav-group {
		display: flex;
		flex-direction: column;
	}

	.nav-group-header {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 8px 16px;
		margin: 4px 8px 0;
		background: none;
		border: none;
		color: rgba(255, 255, 255, 0.3);
		font-size: 9px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.8px;
		cursor: pointer;
		transition: color 0.15s;
		border-radius: 4px;
	}

	.nav-group-header:hover {
		color: rgba(255, 255, 255, 0.5);
		background: rgba(255, 255, 255, 0.02);
	}

	.nav-group-icon {
		font-size: 14px;
		opacity: 0.6;
	}

	.nav-group-label {
		flex: 1;
		text-align: left;
	}

	.nav-group-chevron {
		font-size: 16px;
		transition: transform 0.2s ease;
		transform: rotate(-90deg);
	}

	.nav-group-chevron.rotated {
		transform: rotate(0deg);
	}

	.nav-group-items {
		display: flex;
		flex-direction: column;
	}

	/* ===== COLLAPSE BUTTON ===== */
	.collapse-button {
		margin-top: auto;
		margin-bottom: 16px;
	}
</style>
