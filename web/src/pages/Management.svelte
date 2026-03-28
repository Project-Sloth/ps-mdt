<script lang="ts">
	import ManagementPermissions from "../components/management/ManagementPermissions.svelte";
	import ManagementBulletins from "../components/management/ManagementBulletins.svelte";
	import ManagementActivity from "../components/management/ManagementActivity.svelte";
	import ManagementTracking from "../components/management/ManagementTracking.svelte";
	import ManagementTags from "../components/management/ManagementTags.svelte";
	import ManagementJailFines from "../components/management/ManagementJailFines.svelte";
	import ManagementTemplates from "../components/management/ManagementTemplates.svelte";
	import ManagementAwards from "../components/management/ManagementAwards.svelte";
	import ManagementLicenses from "../components/management/ManagementLicenses.svelte";
	import ManagementColors from "../components/management/ManagementColors.svelte";
	import ManagementSOP from "../components/management/ManagementSOP.svelte";
	import ManagementVisibility from "../components/management/ManagementVisibility.svelte";
	import ManagementFTO from "../components/management/ManagementFTO.svelte";
	import type { AuthService } from "../services/authService.svelte";

	let { authService }: { authService?: AuthService } = $props();

	type View = "activity" | "bulletins" | "permissions" | "tracking" | "tags" | "jailfines" | "templates" | "awards" | "licenses" | "colors" | "sop" | "visibility" | "fto";

	const EMS_HIDDEN_TABS: View[] = ["jailfines", "tracking", "awards"];
	const DOJ_HIDDEN_TABS: View[] = ["bulletins", "activity", "jailfines", "tracking", "licenses", "awards", "colors", "sop", "visibility", "fto", "tags", "templates"];

	const allTabs: { key: View; label: string; permission?: string }[] = [
		{ key: "bulletins", label: "Bulletins", permission: "management_bulletins" },
		{ key: "activity", label: "Activity", permission: "management_activity" },
		{ key: "permissions", label: "Permissions", permission: "management_permissions" },
		{ key: "tags", label: "Tags", permission: "management_tags" },
		{ key: "jailfines", label: "Jail / Fines", permission: "management_settings" },
		{ key: "tracking", label: "Tracking", permission: "management_tracking" },
		{ key: "templates", label: "Templates", permission: "management_settings" },
		{ key: "licenses", label: "Licenses", permission: "management_settings" },
		{ key: "awards", label: "Awards", permission: "management_settings" },
		{ key: "colors", label: "Colors", permission: "management_settings" },
		{ key: "sop", label: "SOP", permission: "sop_manage" },
		{ key: "fto", label: "FTO", permission: "fto_manage" },
		{ key: "visibility", label: "Visibility", permission: "management_permissions" },
	];

	let tabs = $derived(
		authService?.jobType === 'ems'
			? allTabs.filter(t => !EMS_HIDDEN_TABS.includes(t.key))
			: authService?.jobType === 'doj'
				? allTabs.filter(t => !DOJ_HIDDEN_TABS.includes(t.key))
				: allTabs
	);

	function canSeeTab(tab: { permission?: string }): boolean {
		if (!tab.permission || !authService) return true;
		return authService.hasPermission(tab.permission);
	}

	const defaultTab: View = authService?.jobType === 'doj' ? "permissions" : "bulletins";
	let firstVisibleTab = $derived(tabs.find((t) => canSeeTab(t))?.key || defaultTab);
	let view = $state<View>(defaultTab);
</script>

<div class="management-page">
	<div class="topbar">
		<div class="tab-buttons">
			{#each tabs as tab}
				{#if canSeeTab(tab)}
					<button class="tab-btn" class:active={view === tab.key} onclick={() => (view = tab.key)}>{tab.label}</button>
				{/if}
			{/each}
		</div>
	</div>
	<div class="management-content">
		{#if view === "bulletins"}
			<ManagementBulletins />
		{:else if view === "activity"}
			<ManagementActivity />
		{:else if view === "permissions"}
			<ManagementPermissions jobType={authService?.jobType} />
		{:else if view === "tags"}
			<ManagementTags jobType={authService?.jobType} />
		{:else if view === "jailfines"}
			<ManagementJailFines />
		{:else if view === "tracking"}
			<ManagementTracking />
		{:else if view === "templates"}
			<ManagementTemplates jobType={authService?.jobType} />
		{:else if view === "licenses"}
			<ManagementLicenses />
		{:else if view === "awards"}
			<ManagementAwards />
		{:else if view === "colors"}
			<ManagementColors />
		{:else if view === "sop"}
			<ManagementSOP {authService} />
		{:else if view === "fto"}
			<ManagementFTO jobType={authService?.jobType} />
		{:else if view === "visibility"}
			<ManagementVisibility jobType={authService?.jobType} />
		{/if}
	</div>
</div>

<style>
	.management-page {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
		overflow: hidden;
	}

	.topbar {
		flex-shrink: 0;
	}

	.tab-buttons {
		display: flex;
		gap: 0;
		padding: 0 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.tab-btn {
		background: transparent;
		border: none;
		border-bottom: 2px solid transparent;
		padding: 0 14px;
		height: 42px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
		margin-bottom: -1px;
		text-transform: uppercase;
		letter-spacing: 0.4px;
	}

	.tab-btn:hover {
		color: rgba(255, 255, 255, 0.6);
	}

	.tab-btn.active {
		color: rgba(255, 255, 255, 0.85);
		border-bottom-color: rgba(255, 255, 255, 0.4);
	}

	.management-content {
		flex: 1;
		min-height: 0;
		overflow: hidden;
	}
</style>
