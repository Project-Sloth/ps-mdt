<script lang="ts">
	import { onMount } from "svelte";
	import { createManagementService } from "@/services/managementService.svelte";
	import { PERMISSION_CATEGORIES } from "@/constants/management";
	import type { JobType } from "@/interfaces/IUser";

	let { jobType = 'leo' }: { jobType?: JobType } = $props();

	/** Permission categories hidden for EMS */
	const EMS_HIDDEN_CATEGORIES = ['bolos', 'vehicles', 'weapons', 'cases', 'evidence', 'warrants', 'charges'];
	/** Individual permissions hidden for EMS within visible categories */
	const EMS_HIDDEN_PERMISSIONS = ['cameras_view', 'management_tracking'];
	const DOJ_VISIBLE_CATEGORIES = ['citizens', 'cases', 'evidence', 'charges', 'management'];
	const DOJ_HIDDEN_PERMISSIONS = ['management_bulletins', 'management_activity', 'management_tags', 'management_tracking', 'management_settings', 'citizens_edit_licenses'];

	let visibleCategories = $derived(
		jobType === 'ems'
			? PERMISSION_CATEGORIES
				.filter(c => !EMS_HIDDEN_CATEGORIES.includes(c.key))
				.map(c => ({
					...c,
					permissions: c.permissions.filter(p => !EMS_HIDDEN_PERMISSIONS.includes(p.key))
				}))
				.filter(c => c.permissions.length > 0)
			: jobType === 'doj'
				? PERMISSION_CATEGORIES
					.filter(c => DOJ_VISIBLE_CATEGORIES.includes(c.key))
					.map(c => ({
						...c,
						permissions: c.permissions.filter(p => !DOJ_HIDDEN_PERMISSIONS.includes(p.key))
					}))
					.filter(c => c.permissions.length > 0)
				: PERMISSION_CATEGORIES
	);

	const mgmt = createManagementService();

	let selectedRole = $state<string | null>(null);

	let currentRole = $derived(mgmt.roles.find((r) => r.key === selectedRole));

	function categoryAllEnabled(catKey: string): boolean {
		if (!currentRole) return false;
		const cat = PERMISSION_CATEGORIES.find((c) => c.key === catKey);
		if (!cat) return false;
		return cat.permissions.every((p) => mgmt.roleHasPermission(currentRole!.key, p.key));
	}

	function categoryNoneEnabled(catKey: string): boolean {
		if (!currentRole) return true;
		const cat = PERMISSION_CATEGORIES.find((c) => c.key === catKey);
		if (!cat) return true;
		return cat.permissions.every((p) => !mgmt.roleHasPermission(currentRole!.key, p.key));
	}

	function toggleCategory(catKey: string) {
		if (!currentRole || currentRole.isBoss) return;
		const cat = PERMISSION_CATEGORIES.find((c) => c.key === catKey);
		if (!cat) return;
		const keys = cat.permissions.map((p) => p.key);
		if (categoryAllEnabled(catKey)) {
			mgmt.disableCategoryForRole(currentRole.key, keys);
		} else {
			mgmt.enableCategoryForRole(currentRole.key, keys);
		}
	}

	onMount(async () => {
		await mgmt.loadRoles();
		if (mgmt.roles.length > 0 && !selectedRole) {
			selectedRole = mgmt.roles[0].key;
		}
	});
</script>

<div class="permissions-panel">
	{#if mgmt.statusMessage}
		<div class="status-toast {mgmt.statusMessage.type}">
			{mgmt.statusMessage.text}
		</div>
	{/if}

	<div class="permissions-header">
		<span class="header-label">Permissions</span>
		{#if mgmt.jobLabel}
			<span class="job-tag">{mgmt.jobLabel}</span>
		{/if}
	</div>

	{#if mgmt.isLoading}
		<div class="empty-state">
			<div class="loading-spinner"></div>
			<p>Loading permissions...</p>
		</div>
	{:else if mgmt.roles.length === 0}
		<div class="empty-state">
			<p>No roles available</p>
		</div>
	{:else}
		<div class="permissions-body">
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

			<div class="permissions-content">
				{#if currentRole}
					<div class="role-title-row">
						<span class="role-title">{currentRole.label}</span>
						{#if currentRole.isBoss}
							<span class="boss-note">Boss roles have all permissions enabled</span>
						{/if}
					</div>

					<div class="categories-list">
						{#each visibleCategories as category}
							<div class="category-section">
								<div class="category-header">
									<div class="category-label-row">
										<span class="material-icons category-icon">{category.icon}</span>
										<span class="category-label">{category.label}</span>
									</div>
									{#if !currentRole.isBoss}
										<div class="category-actions">
											<button
												class="cat-toggle-btn"
												class:all-on={categoryAllEnabled(category.key)}
												onclick={() => toggleCategory(category.key)}
											>
												{categoryAllEnabled(category.key) ? "Disable All" : "Enable All"}
											</button>
										</div>
									{/if}
								</div>
								<div class="category-perms">
									{#each category.permissions as perm}
										<div class="permission-row">
											<div class="permission-info">
												<span class="permission-label">{perm.label}</span>
												<span class="permission-desc">{perm.description}</span>
											</div>
											<label class="toggle">
												<input
													type="checkbox"
													checked={mgmt.roleHasPermission(currentRole.key, perm.key)}
													disabled={currentRole.isBoss}
													onchange={() => mgmt.togglePermission(currentRole.key, perm.key)}
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
								{mgmt.isSaving ? "Saving..." : "Save Permissions"}
							</button>
						</div>
					{/if}
				{/if}
			</div>
		</div>
	{/if}
</div>

<style>
	.permissions-panel {
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

	.permissions-header {
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

	.permissions-body {
		display: flex;
		flex: 1;
		min-height: 0;
	}

	/* Roles sidebar */
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

	.roles-sidebar::-webkit-scrollbar {
		width: 3px;
	}

	.roles-sidebar::-webkit-scrollbar-track {
		background: transparent;
	}

	.roles-sidebar::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

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

	.role-btn:hover {
		background: rgba(255, 255, 255, 0.03);
		color: rgba(255, 255, 255, 0.6);
	}

	.role-btn.active {
		background: rgba(255, 255, 255, 0.05);
		color: rgba(255, 255, 255, 0.85);
	}

	.role-name {
		flex: 1;
	}

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

	/* Content area */
	.permissions-content {
		flex: 1;
		display: flex;
		flex-direction: column;
		overflow-y: auto;
		min-height: 0;
	}

	.permissions-content::-webkit-scrollbar {
		width: 4px;
	}

	.permissions-content::-webkit-scrollbar-track {
		background: transparent;
	}

	.permissions-content::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	.role-title-row {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		flex-shrink: 0;
	}

	.role-title {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.8);
	}

	.boss-note {
		font-size: 10px;
		color: rgba(110, 231, 183, 0.6);
	}

	/* Categories */
	.categories-list {
		flex: 1;
	}

	.category-section {
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.category-section:last-child {
		border-bottom: none;
	}

	.category-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 16px;
		background: rgba(255, 255, 255, 0.015);
	}

	.category-label-row {
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.category-icon {
		font-size: 13px;
		color: rgba(255, 255, 255, 0.3);
	}

	.category-label {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(255, 255, 255, 0.4);
	}

	.category-actions {
		display: flex;
		gap: 4px;
	}

	.cat-toggle-btn {
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

	.cat-toggle-btn:hover {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.6);
	}

	.cat-toggle-btn.all-on {
		color: rgba(239, 68, 68, 0.5);
		border-color: rgba(239, 68, 68, 0.1);
	}

	.cat-toggle-btn.all-on:hover {
		background: rgba(239, 68, 68, 0.06);
		color: rgba(239, 68, 68, 0.7);
	}

	.category-perms {
		padding: 0 16px;
	}

	.permission-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 6px 0 6px 20px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.02);
	}

	.permission-row:last-child {
		border-bottom: none;
	}

	.permission-info {
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.permission-label {
		color: rgba(255, 255, 255, 0.7);
		font-size: 11px;
		font-weight: 500;
	}

	.permission-desc {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	/* Toggle switch */
	.toggle {
		position: relative;
		display: inline-block;
		width: 32px;
		height: 18px;
		flex-shrink: 0;
	}

	.toggle input {
		opacity: 0;
		width: 0;
		height: 0;
	}

	.toggle-slider {
		position: absolute;
		cursor: pointer;
		top: 0;
		left: 0;
		right: 0;
		bottom: 0;
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

	.toggle input:checked + .toggle-slider {
		background: rgba(var(--accent-rgb), 0.35);
	}

	.toggle input:checked + .toggle-slider::before {
		transform: translateX(14px);
		background: rgba(255, 255, 255, 0.85);
	}

	.toggle input:disabled + .toggle-slider {
		opacity: 0.4;
		cursor: not-allowed;
	}

	/* Save */
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

	.save-btn:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.save-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	/* Empty states */
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
