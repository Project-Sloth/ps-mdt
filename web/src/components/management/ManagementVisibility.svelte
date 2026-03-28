<script lang="ts">
	import { onMount } from "svelte";
	import { createManagementService } from "@/services/managementService.svelte";
	import { TAB_VISIBILITY_KEYS } from "@/constants/management";
	import { NAV_GROUPS, getTabsForJob, MDT_TABS } from "@/constants";
	import type { JobType } from "@/interfaces/IUser";

	let { jobType = 'leo' }: { jobType?: JobType } = $props();

	const mgmt = createManagementService();
	let selectedRole = $state<string | null>(null);
	let currentRole = $derived(mgmt.roles.find((r) => r.key === selectedRole));

	const HIDEABLE_GROUPS = NAV_GROUPS.filter(g => g.id !== "dashboard" && g.id !== "bottom");

	let jobTabs = $derived(new Set(getTabsForJob(jobType).map(t => t.name)));

	let visibleGroups = $derived(
		HIDEABLE_GROUPS.map(g => ({
			...g,
			tabs: g.tabs.filter(t => jobTabs.has(t)),
		})).filter(g => g.tabs.length > 0)
	);

	function getTabIcon(tabName: string): string {
		return MDT_TABS.find(t => t.name === tabName)?.icon || "tab";
	}

	function getHiddenKey(tabName: string): string {
		const entry = TAB_VISIBILITY_KEYS.find(t => t.tabName === tabName);
		return entry?.key || `tab_hidden_${tabName.toLowerCase()}`;
	}

	function getTabLabel(tabName: string): string {
		const entry = TAB_VISIBILITY_KEYS.find(t => t.tabName === tabName);
		return entry?.label || tabName;
	}

	function isTabVisible(tabName: string): boolean {
		if (!currentRole) return true;
		if (currentRole.isBoss) return true;
		return !mgmt.roleHasPermission(currentRole.key, getHiddenKey(tabName));
	}

	function toggleTab(tabName: string) {
		if (!currentRole || currentRole.isBoss) return;
		mgmt.togglePermission(currentRole.key, getHiddenKey(tabName));
	}

	function groupAllVisible(groupId: string): boolean {
		if (!currentRole) return true;
		const group = visibleGroups.find(g => g.id === groupId);
		if (!group) return true;
		return group.tabs.every(t => isTabVisible(t));
	}

	function toggleGroup(groupId: string) {
		if (!currentRole || currentRole.isBoss) return;
		const group = visibleGroups.find(g => g.id === groupId);
		if (!group) return;
		const allVisible = groupAllVisible(groupId);
		for (const tabName of group.tabs) {
			const key = getHiddenKey(tabName);
			const isHidden = mgmt.roleHasPermission(currentRole.key, key);
			if (allVisible && !isHidden) {
				mgmt.togglePermission(currentRole.key, key);
			} else if (!allVisible && isHidden) {
				mgmt.togglePermission(currentRole.key, key);
			}
		}
	}

	onMount(async () => {
		await mgmt.loadRoles();
		if (mgmt.roles.length > 0 && !selectedRole) {
			selectedRole = mgmt.roles[0].key;
		}
	});
</script>

<div class="visibility-panel">
	{#if mgmt.statusMessage}
		<div class="status-toast {mgmt.statusMessage.type}">
			{mgmt.statusMessage.text}
		</div>
	{/if}

	<div class="visibility-header">
		<span class="header-label">Tab Visibility</span>
		{#if mgmt.jobLabel}
			<span class="job-tag">{mgmt.jobLabel}</span>
		{/if}
	</div>

	{#if mgmt.isLoading}
		<div class="empty-state">
			<div class="loading-spinner"></div>
			<p>Loading roles...</p>
		</div>
	{:else if mgmt.roles.length === 0}
		<div class="empty-state">
			<p>No roles available</p>
		</div>
	{:else}
		<div class="visibility-body">
			<div class="roles-sidebar">
				{#each mgmt.roles as role}
					<button
						class="role-btn"
						class:active={selectedRole === role.key}
						onclick={() => (selectedRole = role.key)}
					>
						<span class="role-name">{role.label}</span>
						{#if role.isBoss}
							<span class="boss-tag">All</span>
						{/if}
					</button>
				{/each}
			</div>

			<div class="visibility-content">
				{#if currentRole}
					<div class="role-title-row">
						<span class="role-title">{currentRole.label}</span>
						{#if currentRole.isBoss}
							<span class="boss-note">Boss roles always see all tabs</span>
						{/if}
					</div>

					<div class="groups-list">
						{#each visibleGroups as group}
							<div class="group-section">
								<div class="group-header">
									<div class="group-label-row">
										<span class="material-icons group-icon">{group.icon}</span>
										<span class="group-label">{group.label}</span>
									</div>
									{#if !currentRole.isBoss}
										<button
											class="group-toggle-btn"
											class:all-hidden={!groupAllVisible(group.id)}
											onclick={() => toggleGroup(group.id)}
										>
											{groupAllVisible(group.id) ? "Hide All" : "Show All"}
										</button>
									{/if}
								</div>
								<div class="group-tabs">
									{#each group.tabs as tabName}
										<div class="tab-row">
											<div class="tab-info">
												<span class="material-icons tab-icon">{getTabIcon(tabName)}</span>
												<span class="tab-label">{getTabLabel(tabName)}</span>
											</div>
											<label class="toggle">
												<input
													type="checkbox"
													checked={isTabVisible(tabName)}
													disabled={currentRole.isBoss}
													onchange={() => toggleTab(tabName)}
												/>
												<span class="toggle-slider"></span>
											</label>
										</div>
									{/each}
								</div>
							</div>
						{/each}
					</div>

					{#if !currentRole.isBoss}
						<div class="save-row">
							<button
								class="save-btn"
								onclick={() => mgmt.saveAllRoles()}
								disabled={mgmt.isSaving}
							>
								{mgmt.isSaving ? "Saving..." : "Save Visibility"}
							</button>
						</div>
					{/if}
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	.visibility-panel {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: transparent;
		overflow: hidden;
		position: relative;
	}

	.status-toast {
		position: absolute;
		top: 8px;
		right: 16px;
		z-index: 10;
		padding: 4px 12px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 500;
	}

	.status-toast.success {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(110, 231, 183, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.status-toast.error {
		background: rgba(239, 68, 68, 0.08);
		color: rgba(252, 165, 165, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.1);
	}

	.visibility-header {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 0 16px;
		height: 36px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
	}

	.header-label {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.45);
	}

	.job-tag {
		font-size: 9px;
		color: rgba(255, 255, 255, 0.35);
		background: rgba(255, 255, 255, 0.03);
		padding: 1px 6px;
		border-radius: 3px;
	}

	.visibility-body {
		display: flex;
		flex: 1;
		min-height: 0;
	}

	.roles-sidebar {
		width: 140px;
		flex-shrink: 0;
		border-right: 1px solid rgba(255, 255, 255, 0.06);
		padding: 6px;
		overflow-y: auto;
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.roles-sidebar::-webkit-scrollbar { width: 3px; }
	.roles-sidebar::-webkit-scrollbar-track { background: transparent; }
	.roles-sidebar::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	.role-btn {
		display: flex;
		align-items: center;
		gap: 6px;
		width: 100%;
		padding: 5px 8px;
		background: transparent;
		border: none;
		border-radius: 3px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 11px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
		text-align: left;
	}

	.role-btn:hover { background: rgba(255, 255, 255, 0.03); color: rgba(255, 255, 255, 0.6); }
	.role-btn.active { background: rgba(255, 255, 255, 0.05); color: rgba(255, 255, 255, 0.85); }
	.role-name { flex: 1; }

	.boss-tag {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		color: rgba(110, 231, 183, 0.8);
		background: rgba(16, 185, 129, 0.08);
		border: 1px solid rgba(16, 185, 129, 0.1);
		padding: 1px 5px;
		border-radius: 3px;
	}

	.visibility-content {
		flex: 1;
		display: flex;
		flex-direction: column;
		overflow-y: auto;
		min-height: 0;
	}

	.visibility-content::-webkit-scrollbar { width: 4px; }
	.visibility-content::-webkit-scrollbar-track { background: transparent; }
	.visibility-content::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	.role-title-row {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		flex-shrink: 0;
	}

	.role-title { font-size: 11px; font-weight: 600; color: rgba(255, 255, 255, 0.8); }
	.boss-note { font-size: 10px; color: rgba(110, 231, 183, 0.6); }

	.groups-list { flex: 1; }

	.group-section { border-bottom: 1px solid rgba(255, 255, 255, 0.04); }
	.group-section:last-child { border-bottom: none; }

	.group-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 16px;
		background: rgba(255, 255, 255, 0.015);
	}

	.group-label-row { display: flex; align-items: center; gap: 6px; }

	.group-icon { font-size: 13px; color: rgba(255, 255, 255, 0.3); }

	.group-label {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(255, 255, 255, 0.4);
	}

	.group-toggle-btn {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
		padding: 2px 8px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.group-toggle-btn:hover { background: rgba(255, 255, 255, 0.04); color: rgba(255, 255, 255, 0.6); }

	.group-toggle-btn.all-hidden {
		color: rgba(239, 68, 68, 0.5);
		border-color: rgba(239, 68, 68, 0.1);
	}

	.group-toggle-btn.all-hidden:hover {
		background: rgba(239, 68, 68, 0.06);
		color: rgba(239, 68, 68, 0.7);
	}

	.group-tabs { padding: 0 16px; }

	.tab-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 6px 0 6px 20px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.02);
	}

	.tab-row:last-child { border-bottom: none; }

	.tab-info { display: flex; align-items: center; gap: 8px; }
	.tab-icon { font-size: 14px; color: rgba(255, 255, 255, 0.3); }
	.tab-label { color: rgba(255, 255, 255, 0.7); font-size: 11px; font-weight: 500; }

	.toggle {
		position: relative;
		display: inline-block;
		width: 32px;
		height: 18px;
		flex-shrink: 0;
	}

	.toggle input { opacity: 0; width: 0; height: 0; }

	.toggle-slider {
		position: absolute;
		cursor: pointer;
		top: 0; left: 0; right: 0; bottom: 0;
		background: rgba(255, 255, 255, 0.06);
		border-radius: 18px;
		transition: background 0.2s ease;
	}

	.toggle-slider::before {
		content: "";
		position: absolute;
		height: 12px;
		width: 12px;
		left: 3px;
		bottom: 3px;
		background: rgba(255, 255, 255, 0.4);
		border-radius: 50%;
		transition: transform 0.2s ease;
	}

	.toggle input:checked + .toggle-slider { background: rgba(var(--accent-rgb), 0.35); }
	.toggle input:checked + .toggle-slider::before { transform: translateX(14px); background: rgba(255, 255, 255, 0.85); }
	.toggle input:disabled + .toggle-slider { opacity: 0.4; cursor: not-allowed; }

	.save-row {
		padding: 10px 16px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
	}

	.save-btn {
		background: rgba(var(--accent-rgb), 0.06);
		color: rgba(var(--accent-text-rgb), 0.7);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		padding: 5px 16px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}

	.save-btn:hover:not(:disabled) { background: rgba(var(--accent-rgb), 0.12); color: rgba(var(--accent-text-rgb), 0.9); }
	.save-btn:disabled { opacity: 0.3; cursor: not-allowed; }

	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 200px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
	}

	.loading-spinner {
		width: 24px;
		height: 24px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left: 2px solid rgba(var(--accent-rgb), 0.5);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 10px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
</style>
